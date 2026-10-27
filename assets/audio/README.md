# Hoopito Entry Sound

Historical source asset only. The approved startup is silent; this directory is
not bundled by `pubspec.yaml`, and no audio-player plugin is retained. Scoring
feedback continues to use Flutter's system click and haptic feedback.

`entry_swish.wav` is an original 180 ms mono PCM sound synthesized for the
Hoopito cold-start animation. It combines a short, low-level rim transient
with a filtered-noise net texture. No recording or third-party audio is used.

The asset was generated deterministically by the historical version of
`tool/release/generate_entry_assets.py` at 44.1 kHz with the fixed seed
`0x48545243`. The script, generated WAV, and launch artwork are distributed
under the repository MIT License.
