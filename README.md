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

| model | licence | obligation |
|---|---|---|
| Silero VAD | [MIT](https://github.com/snakers4/silero-vad) | none beyond the notice |
| Parakeet TDT 0.6b v3 | [CC-BY-4.0](https://huggingface.co/nvidia/parakeet-tdt-0.6b-v3) | **credit NVIDIA** |
| SenseVoice Small | [FunASR Model Open Source License Agreement v1.1](https://github.com/modelscope/FunASR/blob/main/MODEL_LICENSE) | **Alibaba's own terms — read them** |

A caveat worth knowing: the sherpa-onnx *conversions* on Hugging Face declare
no licence of their own, so the upstream model's terms are the ones that apply.
Each entry in the catalog therefore records `source` — the original model, not
the conversion — so the terms can be checked at the source.

If you ship something built on these, the obligations are yours. `ModelLicence`
carries `requiresAttribution` and the exact credit line so an attribution
screen can be generated rather than written from memory.

## Why size is checked

An interrupted download leaves a file of plausible length that fails much
later, deep inside a recogniser, with an error nobody can act on. So each file
is downloaded to `.part`, checked against its expected size, and only then
renamed. `has()` re-checks sizes rather than mere existence, and a half-written
model reports as not installed.

There is no checksum yet. Size catches a truncated download, which is the
failure that actually happens; it would not catch a tampered one. Anyone
serving these over an untrusted network should add one.

## Adding a model

An entry in `voiceModelCatalog`: an id (it becomes the directory name, so
renaming one orphans every copy already downloaded), the files with their URLs
and exact sizes, the licence, and a link to the upstream model.

## Licence

MIT — see [LICENSE](LICENSE). The models are not MIT; see the table above.
