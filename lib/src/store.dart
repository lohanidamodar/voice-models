import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' as http;

import 'catalog.dart';
import 'paths.dart';

/// Progress while fetching, so a caller can show something honest.
class DownloadProgress {
  const DownloadProgress({
    required this.model,
    required this.file,
    required this.received,
    required this.total,
  });

  final VoiceModel model;

  /// The file being fetched right now.
  final String file;

  /// Bytes for the whole model, not just this file — that is what someone
  /// waiting actually wants to know.
  final int received;
  final int total;

  double get fraction => total == 0 ? 0 : received / total;
}

/// Where speech models live, shared by every app that uses them.
///
/// One store rather than a copy per app. These are hundreds of megabytes each
/// and identical between them, so a dictation tool, a speech-to-speech
/// assistant and a language-learning app should fetch a model once and all
/// find it afterwards.
///
/// The location follows each platform's convention for data a program creates
/// and can re-download — not documents, and not the app's own directory, which
/// may be read-only or replaced on update.
class ModelStore {
  ModelStore({Directory? root, http.Client? client})
      : root = root ?? defaultRoot(),
        _given = client;

  final Directory root;

  /// Supplied by a caller — a test, usually. Kept apart from [_opened] so
  /// [dispose] closes only what this store created.
  final http.Client? _given;
  http.Client? _opened;

  /// Opened on the first download, not in the constructor.
  ///
  /// Asking a store what is already installed is the common case and needs no
  /// network at all. It also means a widget test can construct one: Flutter's
  /// test binding fails any test that creates a real HttpClient, and a store
  /// that opened one eagerly failed tests that never downloaded anything.
  http.Client get _client => _given ?? (_opened ??= http.Client());

  /// `POPUPBITS_MODELS` overrides everything, for a shared drive or a machine
  /// where the data directory is small.
  static Directory defaultRoot() {
    final override = Platform.environment['POPUPBITS_MODELS'];
    if (override != null && override.trim().isNotEmpty) {
      return Directory(override.trim());
    }
    return Directory(
      '${popupBitsDataDir()}${Platform.pathSeparator}models',
    );
  }

  /// Where a model lives, whether or not it is there yet.
  Directory directoryFor(VoiceModel model) =>
      Directory('${root.path}${Platform.pathSeparator}${model.id}');

  /// Whether every file is present and the right size.
  ///
  /// Size is checked, not just existence: an interrupted download leaves a
  /// plausible-looking file that fails much later, deep inside the recogniser,
  /// with an error nobody can act on.
  bool has(VoiceModel model) {
    final dir = directoryFor(model);
    if (!dir.existsSync()) return false;
    for (final file in model.files) {
      final path = File('${dir.path}${Platform.pathSeparator}${file.name}');
      if (!path.existsSync()) return false;
      if (path.lengthSync() != file.bytes) return false;
    }
    return true;
  }

  /// Models already downloaded.
  List<VoiceModel> installed() =>
      voiceModelCatalog.where(has).toList(growable: false);

  /// Downloads [model] unless it is already here, and returns its directory.
  ///
  /// [onLicence] is asked before anything is fetched, and a false answer
  /// cancels. Weights come with terms — some of them not open-source licences
  /// at all — and agreeing to them is the user's to do, not the program's.
  Future<Directory> ensure(
    VoiceModel model, {
    void Function(DownloadProgress)? onProgress,
    FutureOr<bool> Function(VoiceModel)? onLicence,
  }) async {
    final dir = directoryFor(model);
    if (has(model)) return dir;

    if (onLicence != null && !await onLicence(model)) {
      throw ModelDeclined(model);
    }

    await dir.create(recursive: true);
    var received = 0;

    for (final file in model.files) {
      final target = File('${dir.path}${Platform.pathSeparator}${file.name}');
      if (target.existsSync() && target.lengthSync() == file.bytes) {
        received += file.bytes;
        continue;
      }

      // Written beside the target and renamed on success, so an interrupted
      // download never looks like a finished one.
      final partial = File('${target.path}.part');
      await _download(model, file, partial, received, onProgress);

      final got = partial.lengthSync();
      if (got != file.bytes) {
        await partial.delete();
        throw ModelDownloadFailed(
          model,
          '${file.name} came back $got bytes, expected ${file.bytes}. '
          'The download was cut short, or the file upstream has changed.',
        );
      }
      if (target.existsSync()) await target.delete();
      await partial.rename(target.path);
      received += file.bytes;
    }
    return dir;
  }

  Future<void> _download(
    VoiceModel model,
    ModelFile file,
    File target,
    int alreadyReceived,
    void Function(DownloadProgress)? onProgress,
  ) async {
    final request = http.Request('GET', Uri.parse(file.url));
    final http.StreamedResponse response;
    try {
      response = await _client.send(request);
    } catch (e) {
      throw ModelDownloadFailed(model, 'Could not reach ${file.url} — $e');
    }
    if (response.statusCode != 200) {
      throw ModelDownloadFailed(
        model,
        '${file.url} returned HTTP ${response.statusCode}.',
      );
    }

    final sink = target.openWrite();
    var written = 0;
    try {
      await for (final chunk in response.stream) {
        sink.add(chunk);
        written += chunk.length;
        onProgress?.call(DownloadProgress(
          model: model,
          file: file.name,
          received: alreadyReceived + written,
          total: model.bytes,
        ));
      }
    } finally {
      await sink.close();
    }
  }

  /// Deletes a model's files. Returns false if it was not there.
  Future<bool> remove(VoiceModel model) async {
    final dir = directoryFor(model);
    if (!dir.existsSync()) return false;
    await dir.delete(recursive: true);
    return true;
  }

  /// Bytes currently on disk.
  int usedBytes() {
    if (!root.existsSync()) return 0;
    var total = 0;
    for (final entry in root.listSync(recursive: true)) {
      if (entry is File) total += entry.lengthSync();
    }
    return total;
  }

  void dispose() {
    _opened?.close();
    _opened = null;
  }
}

/// The user said no to a model's licence.
class ModelDeclined implements Exception {
  const ModelDeclined(this.model);
  final VoiceModel model;

  @override
  String toString() =>
      '${model.name} was not downloaded: its licence '
      '(${model.licence.name}) was declined.';
}

class ModelDownloadFailed implements Exception {
  const ModelDownloadFailed(this.model, this.reason);
  final VoiceModel model;
  final String reason;

  @override
  String toString() => 'Could not download ${model.name}: $reason';
}
