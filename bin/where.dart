import 'package:voice_models/voice_models.dart';

/// Says where models live and which are present.
///
///   dart run bin/where.dart
///   dart run bin/where.dart --fetch silero-vad
Future<void> main(List<String> argv) async {
  final store = ModelStore();
  print('store: ${store.root.path}');
  print('used:  ${(store.usedBytes() / 1024 / 1024).toStringAsFixed(1)} MB\n');

  for (final m in voiceModelCatalog) {
    final mark = store.has(m) ? '[installed]' : '[         ]';
    print('$mark ${m.id.padRight(28)} ${m.sizeLabel.padLeft(9)}  '
        '${m.licence.summary}');
  }

  if (argv.contains('--fetch')) {
    final model = modelById(argv.last);
    if (model == null) {
      print('\nno such model: ${argv.last}');
      return;
    }
    print('\n${model.name}');
    print('  licence: ${model.licence.name} — ${model.licence.url}');
    print('  source:  ${model.source}');
    var last = -1;
    await store.ensure(model, onProgress: (p) {
      final pct = (p.fraction * 100) ~/ 10 * 10;
      if (pct != last) {
        last = pct;
        print('  $pct%  ${p.file}');
      }
    });
    print('  at ${store.directoryFor(model).path}');
  }
  store.dispose();
}
