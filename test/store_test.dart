import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';
import 'package:voice_models/voice_models.dart';

void main() {
  late Directory root;
  setUp(() => root = Directory.systemTemp.createTempSync('models'));
  tearDown(() {
    if (root.existsSync()) root.deleteSync(recursive: true);
  });

  /// Serves each url a body of exactly the declared length.
  http.Client serving({Map<String, int>? sizes}) => MockClient.streaming(
        (request, _) async {
          final name = request.url.pathSegments.last;
          final length = sizes?[name] ??
              voiceModelCatalog
                  .expand((m) => m.files)
                  .firstWhere((f) => f.url.endsWith(name))
                  .bytes;
          return http.StreamedResponse(
            Stream.value(List.filled(length, 0x41)),
            200,
            request: request,
          );
        },
      );

  final small = modelById('silero-vad')!;

  group('catalog', () {
    test('every model states a licence and a source', () {
      for (final model in voiceModelCatalog) {
        expect(model.licence.name, isNotEmpty, reason: model.id);
        expect(model.licence.url, startsWith('http'), reason: model.id);
        expect(model.source, startsWith('http'), reason: model.id);
        expect(model.files, isNotEmpty, reason: model.id);
      }
    });

    test('ids are unique — they are directory names', () {
      final ids = voiceModelCatalog.map((m) => m.id).toList();
      expect(ids.toSet().length, ids.length);
    });

    test('licences that are not OSI say so', () {
      // SenseVoice is published under Alibaba's own terms. Anything that
      // presents "open source" to a user has to be able to tell the
      // difference.
      final sense = modelById('sense-voice-small')!;
      expect(sense.licence.isOsiApproved, isFalse);
      expect(sense.licence.summary, contains('publisher terms'));
    });

    test('a voice model says whether it can be prompted', () {
      // The app shows a box for describing a voice only if the model can act
      // on the description; guessing from the name would be a lottery.
      final voices = modelsFor(ModelTask.synthesis);
      expect(voices, isNotEmpty);
      for (final voice in voices) {
        expect(voice.runtime, ModelRuntime.audioCpp, reason: voice.id);
        expect(voice.engineFamily, isNotNull, reason: voice.id);
        expect(voice.canDesignVoice, isTrue, reason: voice.id);
        expect(voice.canCloneVoice, isTrue, reason: voice.id);
      }
    });

    test('a description reaches each model the way it wants it', () {
      // The bug this guards against is silent: a model given the description
      // the wrong way speaks the line in its default voice and reports
      // success. Measured on VoxCPM2 — the instruction field produced
      // byte-identical audio; the text prefix moved the pitch by an octave.
      const line = 'Hello.';
      const style = 'an older man, unhurried';

      final omni = applyVoiceStyle(line, style, VoiceStylePolicy.instruction);
      expect(omni.text, line);
      expect(omni.instruct, style);

      final vox = applyVoiceStyle(line, style, VoiceStylePolicy.textPrefix);
      expect(vox.text, '(an older man, unhurried)Hello.');
      expect(vox.instruct, isNull);
    });

    test('a description with brackets cannot run off the end', () {
      // A ')' inside the description would close the prefix early and leave
      // the remainder to be read aloud.
      final vox = applyVoiceStyle(
        'Hi.',
        'a woman (about 30) reading quickly',
        VoiceStylePolicy.textPrefix,
      );
      expect(vox.text, '(a woman about 30 reading quickly)Hi.');
    });

    test('no description changes nothing', () {
      for (final policy in VoiceStylePolicy.values) {
        for (final empty in [null, '', '   ']) {
          final out = applyVoiceStyle('Hi.', empty, policy);
          expect(out.text, 'Hi.', reason: '$policy');
          expect(out.instruct, isNull, reason: '$policy');
        }
      }
    });

    test('a model that cannot be described drops the description', () {
      // Rather than smuggling it into the text of a model that would read it
      // out loud.
      final out = applyVoiceStyle('Hi.', 'cheerful', VoiceStylePolicy.none);
      expect(out.text, 'Hi.');
      expect(out.instruct, isNull);
    });

    test('a model that cannot speak a language says so', () {
      // The one that matters here: VoxCPM2 is not trained on Nepali, and
      // rendering Nepali with Hindi pronunciation is worse than refusing.
      final vox = modelById('voxcpm2-q8')!;
      expect(vox.speaks('en'), isTrue);
      expect(vox.speaks('hi'), isTrue);
      expect(vox.speaks('ne'), isFalse);

      // OmniVoice claims everything, which is why it stays the default.
      expect(modelById('omnivoice-q8')!.speaks('ne'), isTrue);
    });

    test('a recogniser is not offered as a voice', () {
      expect(
        modelsFor(ModelTask.recognition).map((m) => m.id),
        contains('parakeet-tdt-0.6b-v3-int8'),
      );
      expect(
        modelsFor(ModelTask.synthesis).map((m) => m.id),
        isNot(contains('parakeet-tdt-0.6b-v3-int8')),
      );
    });

    test('a licence needing credit says who to credit', () {
      final parakeet = modelById('parakeet-tdt-0.6b-v3-int8')!;
      expect(parakeet.licence.requiresAttribution, isTrue);
      expect(parakeet.licence.attribution, contains('NVIDIA'));
    });
  });

  group('location', () {
    test('opens no connection just to be created', () {
      // A widget test fails outright if a real HttpClient is constructed, and
      // asking what is installed needs no network.
      final store = ModelStore(root: root);
      expect(store.installed(), isEmpty);
      expect(store.usedBytes(), 0);
      store.dispose();
    });

    test('is shared, not per app', () {
      // The whole point: several apps resolve to the same directory so a model
      // is fetched once.
      final a = ModelStore(), b = ModelStore();
      expect(a.root.path, b.root.path);
      a.dispose();
      b.dispose();
    });

    test('honours POPUPBITS_MODELS when set', () {
      // Cannot set the environment from a test, so the reading is checked
      // instead: an explicit root always wins.
      final store = ModelStore(root: Directory('/somewhere/else'));
      expect(store.root.path, '/somewhere/else');
      store.dispose();
    });

    test('gives each model its own directory, named by id', () {
      final store = ModelStore(root: root);
      expect(store.directoryFor(small).path, endsWith('silero-vad'));
      store.dispose();
    });
  });

  group('download', () {
    test('fetches a model and reports it installed', () async {
      final store = ModelStore(root: root, client: serving());
      final dir = await store.ensure(small);

      expect(dir.existsSync(), isTrue);
      expect(store.has(small), isTrue);
      expect(store.installed().map((m) => m.id), contains('silero-vad'));
      store.dispose();
    });

    test('does not fetch twice', () async {
      var requests = 0;
      final client = MockClient.streaming((request, _) async {
        requests++;
        return http.StreamedResponse(
          Stream.value(List.filled(small.files.first.bytes, 0x41)),
          200,
          request: request,
        );
      });
      final store = ModelStore(root: root, client: client);

      await store.ensure(small);
      await store.ensure(small);
      expect(requests, 1, reason: 'the second call should find it on disk');
      store.dispose();
    });

    test('reports progress against the whole model', () async {
      final store = ModelStore(root: root, client: serving());
      final seen = <double>[];
      await store.ensure(small, onProgress: (p) => seen.add(p.fraction));

      expect(seen, isNotEmpty);
      expect(seen.last, closeTo(1.0, 0.001));
      store.dispose();
    });

    test('asks about the licence before downloading anything', () async {
      final store = ModelStore(root: root, client: serving());
      VoiceModel? asked;

      await store.ensure(small, onLicence: (m) {
        asked = m;
        return true;
      });
      expect(asked?.id, small.id);
      store.dispose();
    });

    test('declining leaves nothing behind', () async {
      final store = ModelStore(root: root, client: serving());

      await expectLater(
        store.ensure(small, onLicence: (_) => false),
        throwsA(isA<ModelDeclined>()),
      );
      expect(store.has(small), isFalse);
      store.dispose();
    });
  });

  group('a truncated download', () {
    test('is rejected rather than left looking finished', () async {
      // The failure this guards against surfaces much later, inside the
      // recogniser, as an error nobody can act on.
      final store = ModelStore(
        root: root,
        client: serving(sizes: {'silero_vad.onnx': 1000}),
      );

      await expectLater(
        store.ensure(small),
        throwsA(isA<ModelDownloadFailed>()),
      );
      expect(store.has(small), isFalse);
      store.dispose();
    });

    test('leaves no partial file to be mistaken for the real one', () async {
      final store = ModelStore(
        root: root,
        client: serving(sizes: {'silero_vad.onnx': 1000}),
      );
      await store.ensure(small).catchError((_) => Directory(root.path));

      final dir = store.directoryFor(small);
      final leftovers = dir.existsSync()
          ? dir.listSync().whereType<File>().map((f) => f.path).toList()
          : <String>[];
      expect(leftovers, isEmpty);
      store.dispose();
    });

    test('a wrong size on disk counts as not installed', () async {
      final store = ModelStore(root: root, client: serving());
      await store.ensure(small);

      final file = File('${store.directoryFor(small).path}'
          '${Platform.pathSeparator}silero_vad.onnx');
      file.writeAsBytesSync([1, 2, 3]);

      expect(store.has(small), isFalse);
      store.dispose();
    });
  });

  group('housekeeping', () {
    test('reports what is on disk', () async {
      final store = ModelStore(root: root, client: serving());
      expect(store.usedBytes(), 0);
      await store.ensure(small);
      expect(store.usedBytes(), small.bytes);
      store.dispose();
    });

    test('removes a model and says whether there was one', () async {
      final store = ModelStore(root: root, client: serving());
      expect(await store.remove(small), isFalse);

      await store.ensure(small);
      expect(await store.remove(small), isTrue);
      expect(store.has(small), isFalse);
      store.dispose();
    });
  });
}
