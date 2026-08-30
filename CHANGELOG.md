# Changelog

## 0.1.0

First release.

- `ModelStore` — one shared location per machine, so several apps reuse a model
  instead of each keeping a copy.
- `voiceModelCatalog` — Silero VAD, Parakeet TDT 0.6b v3, SenseVoice Small,
  each with its upstream source and licence.
- Licences are shown before a download, never after.
- Downloads are size-checked and written through a `.part` file, so an
  interrupted one is never mistaken for a finished one.
