# voice_models

A shared, on-disk store for speech models — so several apps fetch a model once
and all find it afterwards, and so nobody downloads a gigabyte of weights they
already have.

```dart
final store = ModelStore();
final model = modelById('parakeet-tdt-0.6b-v3-int8')!;

final dir = await store.ensure(
  model,
  onLicence: (m) => askTheUser(m.licence),   // shown before anything downloads
  onProgress: (p) => showBar(p.fraction),
);
```

## Where models live

One location per machine, shared by every app:

| platform | path |
|---|---|
| Windows | `%LOCALAPPDATA%\PopupBits\models` |
| macOS | `~/Library/Application Support/PopupBits/models` |
| Linux | `$XDG_DATA_HOME/popupbits/models`, else `~/.local/share/popupbits/models` |

Set `POPUPBITS_MODELS` to override — for a shared drive, or a machine whose
data partition is small.

These are each platform's convention for data a program creates and can
re-download. Not documents, and not beside the app: an app directory may be
read-only, and is replaced wholesale on update.

## Licences — the part that matters

**This package does not redistribute any weights.** It downloads them from the
publisher, and it shows you the licence before it does.

That distinction is not pedantry. The models below are published under three
different sets of terms, one of which is not an open-source licence at all, and
an MIT-licensed *program* says nothing about the terms of a model it fetches at
runtime.

| model | does | licence | obligation |
|---|---|---|---|
| Silero VAD | finds speech | [MIT](https://github.com/snakers4/silero-vad) | none beyond the notice |
| Parakeet TDT 0.6b v3 | recognises | [CC-BY-4.0](https://huggingface.co/nvidia/parakeet-tdt-0.6b-v3) | **credit NVIDIA** |
| SenseVoice Small | recognises | [FunASR Model Open Source License Agreement v1.1](https://github.com/modelscope/FunASR/blob/main/MODEL_LICENSE) | **Alibaba's own terms — read them** |
| OmniVoice | speaks | [Apache-2.0](https://github.com/k2-fsa/OmniVoice) | keep the notice |
| VoxCPM2 | speaks | [Apache-2.0](https://huggingface.co/openbmb/VoxCPM2) | keep the notice |

The two voices are the easy ones: Apache-2.0 covers the weights as well as the
code, so they can be shipped commercially with nothing more than the notice.
They are also the only two here that can be *told* what to sound like — see
`ModelFeature.voiceDesign`.

A caveat worth knowing: the files are conversions, and a conversion repository
does not necessarily carry the model's licence. The sherpa-onnx ones declare
none at all; the audio.cpp GGUF repository declares `license: other` at the top
and then, sensibly, publishes the original licence per model. Either way the
upstream terms are the ones that apply, so each catalog entry records `source`
— the original model, not the conversion — and that is where the licence in
the table above was read from.

If you ship something built on these, the obligations are yours. `ModelLicence`
carries `requiresAttribution` and the exact credit line so an attribution
screen can be generated rather than written from memory.

## Why size is checked

An interrupted download leaves a file of plausible length that fails much
later, deep inside a recogniser, with an error nobody can act on. So each file
is downloaded to `.part`, checked against its expected size, and only then
renamed. `has()` re-checks sizes rather than mere existence, and a half-written
model reports as not installed.

An interrupted download resumes rather than starting again, which matters when
a model is several hundred megabytes and a laptop sleeps. If the server ignores
the range request and sends the whole file, what was on disk is discarded — the
alternative is a file of the right length made of the wrong bytes.

There is no checksum yet. Size catches a truncated download, which is the
failure that actually happens; it would not catch a tampered one. Anyone
serving these over an untrusted network should add one.

## What a model can do

Weights differ in more than quality. An entry records which engine loads it
(`runtime`, and `engineFamily` where the loader needs one), and what it can be
asked for:

```dart
if (model.canDesignVoice) askForADescription();   // "an older man, unhurried"
if (model.canCloneVoice) offerToRecordAReference();
if (!model.speaks('ne')) warnThatNepaliWillBeWrong();

// The two voices want the description delivered differently. This resolves it.
final say = applyVoiceStyle(text, description, model.stylePolicy);
engine.speak(say.text, instruct: say.instruct);
```

That last part is not a nicety. OmniVoice takes the description as a separate
instruction; VoxCPM2 reads it from the front of the text, in parentheses. Give
VoxCPM2 the description the other way and it does not complain — it produces
**byte-identical audio** and reports success. Measured: the same line with "an
older man" and "a young woman" came back at 150 Hz and 281 Hz through the
prefix, and as the same file through the instruction field.

That last one is not hypothetical. VoxCPM2 covers thirty languages and Nepali
is not among them; it would render Nepali text with Hindi pronunciation and
sound plausible while being wrong. So its languages are enumerated, while
OmniVoice — six hundred-odd — is recorded as `*`.

## Adding a model

An entry in `voiceModelCatalog`: an id (it becomes the directory name, so
renaming one orphans every copy already downloaded), the files with their URLs
and exact sizes, the licence, and a link to the upstream model.

## Licence

MIT — see [LICENSE](LICENSE). The models are not MIT; see the table above.
