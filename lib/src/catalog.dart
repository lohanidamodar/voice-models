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
    this.runtime = ModelRuntime.sherpaOnnx,
    this.engineFamily,
    this.features = const {},
    this.stylePolicy = VoiceStylePolicy.none,
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

  final ModelRuntime runtime;

  /// The loader's name for this model's architecture, where the runtime needs
  /// one. `omnivoice`, `voxcpm2`. Null for runtimes that infer it.
  final String? engineFamily;

  /// What this model can do beyond the basics. See [ModelFeature].
  final Set<ModelFeature> features;

  /// How to describe a voice to this model, if it can be described at all.
  final VoiceStylePolicy stylePolicy;

  final String? notes;

  bool get canDesignVoice => stylePolicy != VoiceStylePolicy.none;
  bool get canCloneVoice => features.contains(ModelFeature.voiceCloning);

  /// Whether this model claims [code], a BCP-47-ish language code.
  ///
  /// A model listed as `*` claims everything, which is how the massively
  /// multilingual ones are recorded — enumerating six hundred codes would be
  /// noise, and the honest answer for the long tail is "it will try".
  bool speaks(String code) =>
      languages.contains('*') || languages.contains(code);

  int get bytes => files.fold(0, (sum, f) => sum + f.bytes);

  double get megabytes => bytes / (1024 * 1024);

  String get sizeLabel => megabytes >= 1024
      ? '${(megabytes / 1024).toStringAsFixed(2)} GB'
      : '${megabytes.round()} MB';

  @override
  String toString() => '$name ($sizeLabel, ${licence.name})';
}

enum ModelTask { recognition, synthesis, voiceActivity }

/// Which engine knows how to load a model.
///
/// Part of the catalog rather than each app's own lookup table: "what loads
/// this" is a property of the file, and duplicating it per app is how one of
/// them ends up passing a GGUF to an ONNX runtime.
enum ModelRuntime {
  /// ONNX graphs driven through sherpa-onnx.
  sherpaOnnx,

  /// GGUF driven through audio.cpp, which names a family per model.
  audioCpp,
}

/// What a model can be asked to do beyond plain synthesis or recognition.
///
/// An app reads these to decide what to offer: there is no point showing a
/// box for describing a voice if the model cannot act on the description.
enum ModelFeature {
  /// Copies a voice from a few seconds of reference audio.
  voiceCloning,

  /// Emits audio while it is still generating, rather than at the end.
  streaming,
}

/// How a model wants to be told what to sound like.
///
/// Recorded per model because the two that support it want it delivered
/// differently, and getting it wrong fails silently: the description is
/// accepted, ignored, and the voice comes out unchanged. That is much harder
/// to notice than an error would be.
enum VoiceStylePolicy {
  /// Cannot be told. Only a reference recording changes the voice.
  none,

  /// A separate instruction the engine conditions on, alongside the text.
  instruction,

  /// A description in parentheses at the front of the text itself —
  /// `(a young woman, bright)Hello.` The parenthesis is not spoken.
  textPrefix,
}

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
  VoiceModel(
    id: 'indicconformer-ne-int8',
    name: 'IndicConformer Nepali (int8)',
    task: ModelTask.recognition,
    languages: ['ne'],
    licence: ModelLicence.mitAi4Bharat,
    source:
        'https://huggingface.co/ai4bharat/indicconformer_stt_ne_hybrid_ctc_rnnt_large',
    files: [
      ModelFile(
        'model.int8.onnx',
        'https://github.com/lohanidamodar/voice-models/releases/download/models-2026.09/model.int8.onnx',
        140337547,
      ),
      ModelFile(
        'tokens.txt',
        'https://github.com/lohanidamodar/voice-models/releases/download/models-2026.09/tokens.txt',
        67605,
      ),
    ],
    notes: 'The only Nepali recogniser here — Parakeet and SenseVoice do not '
        'speak it, and neither does any audio.cpp family. Converted to ONNX '
        'and quantised to int8 from the published PyTorch, which is why it is '
        'served from this project rather than from Hugging Face.',
  ),
  VoiceModel(
    id: 'omnivoice-q8',
    name: 'OmniVoice (Q8)',
    task: ModelTask.synthesis,
    languages: ['*'],
    runtime: ModelRuntime.audioCpp,
    engineFamily: 'omnivoice',
    features: {ModelFeature.voiceCloning, ModelFeature.streaming},
    stylePolicy: VoiceStylePolicy.instruction,
    licence: ModelLicence.apache20,
    source: 'https://github.com/k2-fsa/OmniVoice',
    files: [
      ModelFile(
        'omnivoice-q8_0.gguf',
        'https://huggingface.co/audio-cpp/audio.cpp-gguf/resolve/main/OmniVoice-GGUF/omnivoice-q8_0.gguf',
        1350288416,
      ),
    ],
    notes: 'Over six hundred languages, Nepali among them, which is why this '
        'is the default. Clones from a few seconds of reference audio.',
  ),
  VoiceModel(
    id: 'voxcpm2-q8',
    name: 'VoxCPM2 (Q8)',
    task: ModelTask.synthesis,
    // The thirty it is trained on. Deliberately enumerated rather than '*':
    // Nepali is absent, and a model that renders Nepali with Hindi
    // pronunciation is worse than one that says it cannot.
    languages: [
      'ar', 'da', 'de', 'el', 'en', 'es', 'fi', 'fr', 'he', 'hi', //
      'id', 'it', 'ja', 'km', 'ko', 'lo', 'ms', 'my', 'nl', 'no', //
      'pl', 'pt', 'ru', 'sv', 'sw', 'th', 'tl', 'tr', 'vi', 'zh',
    ],
    runtime: ModelRuntime.audioCpp,
    engineFamily: 'voxcpm2',
    features: {ModelFeature.voiceCloning, ModelFeature.streaming},
    // Measured, not assumed: passing the description as a separate
    // instruction produces byte-identical audio, because this family reads it
    // from the front of the text instead.
    stylePolicy: VoiceStylePolicy.textPrefix,
    licence: ModelLicence.apache20,
    source: 'https://huggingface.co/openbmb/VoxCPM2',
    files: [
      ModelFile(
        'voxcpm2-q8_0.gguf',
        'https://huggingface.co/audio-cpp/audio.cpp-gguf/resolve/main/VoxCPM2-GGUF/voxcpm2-q8_0.gguf',
        2955000480,
      ),
    ],
    notes: '2B parameters against OmniVoice\'s 0.6B, and 48 kHz output. Better '
        'English, but no Nepali, and slower.',
  ),
];

/// The models that can do [task], in the order an app should offer them.
List<VoiceModel> modelsFor(ModelTask task) =>
    voiceModelCatalog.where((m) => m.task == task).toList(growable: false);

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

/// How to deliver [style] to a model, given its [VoiceStylePolicy].
///
/// Returns the text to speak and the instruction to pass alongside it. Which
/// one carries the description depends on the model, and the difference is
/// invisible at runtime — a model given the description the wrong way says the
/// line in its default voice rather than complaining — so it is resolved here
/// once instead of in each caller.
({String text, String? instruct}) applyVoiceStyle(
  String text,
  String? style,
  VoiceStylePolicy policy,
) {
  final wanted = style?.trim();
  if (wanted == null || wanted.isEmpty) return (text: text, instruct: null);

  return switch (policy) {
    VoiceStylePolicy.none => (text: text, instruct: null),
    VoiceStylePolicy.instruction => (text: text, instruct: wanted),
    // Parentheses delimit the description, so any inside it would end the
    // prefix early and leave the rest to be read aloud.
    VoiceStylePolicy.textPrefix => (
        text: '(${wanted.replaceAll(RegExp(r'[()]'), '')})$text',
        instruct: null,
      ),
  };
}
