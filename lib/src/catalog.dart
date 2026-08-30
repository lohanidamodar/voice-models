import 'licence.dart';

/// One file belonging to a model.
class ModelFile {
  const ModelFile(this.name, this.url, this.bytes);

  /// Name on disk, relative to the model's own directory.
  final String name;

  final String url;

  /// Expected size. Checked after download — a truncated file otherwise
  /// surfaces much later as an unreadable model, which is a far worse error
  /// message than "this download did not finish".
  final int bytes;
}

/// What a model is, where it comes from, and what it may be used for.
class VoiceModel {
  const VoiceModel({
    required this.id,
    required this.name,
    required this.task,
    required this.languages,
    required this.files,
    required this.licence,
    required this.source,
    this.notes,
  });

  /// Directory name in the store, and the id apps refer to. Stable: renaming
  /// one orphans every copy already downloaded.
  final String id;

  /// How to describe it to a person.
  final String name;

  final ModelTask task;

  /// BCP-47-ish codes, or `['*']` for language-agnostic.
  final List<String> languages;

  final List<ModelFile> files;
  final ModelLicence licence;

  /// Where the weights come from, for anyone who wants to check.
  final String source;

  final String? notes;

  int get bytes => files.fold(0, (sum, f) => sum + f.bytes);

  double get megabytes => bytes / (1024 * 1024);

  String get sizeLabel => megabytes >= 1024
      ? '${(megabytes / 1024).toStringAsFixed(2)} GB'
      : '${megabytes.round()} MB';

  @override
  String toString() => '$name ($sizeLabel, ${licence.name})';
}

enum ModelTask { recognition, synthesis, voiceActivity }

/// The models these apps know how to fetch.
///
/// Deliberately short. Every entry is one somebody has actually run, with its
/// licence traced to the upstream publisher rather than to the converted
/// repository — the sherpa-onnx conversions on Hugging Face declare no licence
/// of their own, so the original model's terms are the ones that apply.
const voiceModelCatalog = <VoiceModel>[
  VoiceModel(
    id: 'silero-vad',
    name: 'Silero VAD',
    task: ModelTask.voiceActivity,
    languages: ['*'],
    licence: ModelLicence.mit,
    source: 'https://github.com/snakers4/silero-vad',
    files: [
      ModelFile(
        'silero_vad.onnx',
        'https://github.com/snakers4/silero-vad/raw/master/src/silero_vad/data/silero_vad.onnx',
        2327524,
      ),
    ],
    notes: 'Finds where speech starts and stops. Tiny, and needed by anything '
        'that segments a recording.',
  ),
  VoiceModel(
    id: 'parakeet-tdt-0.6b-v3-int8',
    name: 'Parakeet TDT 0.6b v3 (int8)',
    task: ModelTask.recognition,
    languages: ['en'],
    licence: ModelLicence.ccBy40,
    source: 'https://huggingface.co/nvidia/parakeet-tdt-0.6b-v3',
    files: [
      ModelFile(
        'encoder.int8.onnx',
        'https://huggingface.co/csukuangfj/sherpa-onnx-nemo-parakeet-tdt-0.6b-v3-int8/resolve/main/encoder.int8.onnx',
        652184281,
      ),
      ModelFile(
        'decoder.int8.onnx',
        'https://huggingface.co/csukuangfj/sherpa-onnx-nemo-parakeet-tdt-0.6b-v3-int8/resolve/main/decoder.int8.onnx',
        11845275,
      ),
      ModelFile(
        'joiner.int8.onnx',
        'https://huggingface.co/csukuangfj/sherpa-onnx-nemo-parakeet-tdt-0.6b-v3-int8/resolve/main/joiner.int8.onnx',
        6355277,
      ),
      ModelFile(
        'tokens.txt',
        'https://huggingface.co/csukuangfj/sherpa-onnx-nemo-parakeet-tdt-0.6b-v3-int8/resolve/main/tokens.txt',
        93939,
      ),
    ],
    notes: 'Punctuates and capitalises as it decodes, but does not turn spoken '
        'numbers into digits.',
  ),
  VoiceModel(
    id: 'sense-voice-small',
    name: 'SenseVoice Small',
    task: ModelTask.recognition,
    languages: ['en', 'zh', 'ja', 'ko', 'yue'],
    licence: ModelLicence.funAsr,
    source: 'https://huggingface.co/FunAudioLLM/SenseVoiceSmall',
    files: [
      ModelFile(
        'model.int8.onnx',
        'https://huggingface.co/csukuangfj/sherpa-onnx-sense-voice-zh-en-ja-ko-yue-2024-07-17/resolve/main/model.int8.onnx',
        239233841,
      ),
      ModelFile(
        'tokens.txt',
        'https://huggingface.co/csukuangfj/sherpa-onnx-sense-voice-zh-en-ja-ko-yue-2024-07-17/resolve/main/tokens.txt',
        315894,
      ),
    ],
    notes: 'Smaller than Parakeet and writes numbers as digits, but punctuates '
        'less well. Its licence is the publisher\'s own.',
  ),
];

VoiceModel? modelById(String id) {
  for (final model in voiceModelCatalog) {
    if (model.id == id) return model;
  }
  return null;
}

/// Every distinct licence in the catalog, for an attribution page.
List<ModelLicence> licencesInUse() {
  final seen = <String, ModelLicence>{};
  for (final model in voiceModelCatalog) {
    seen[model.licence.name] = model.licence;
  }
  return seen.values.toList();
}
