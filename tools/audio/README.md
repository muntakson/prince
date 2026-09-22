# Audio asset generation (ElevenLabs)

All clips are generated with the ElevenLabs API. The key is read from the
`EL` environment variable and is never stored in the repo.

```bash
cd /home/jit/mRNA
python3 tools/audio/extract_lines.py /tmp/lines.json     # scan scripts for dialogue lines
EL=<elevenlabs key> python3 tools/audio/gen_voice.py /tmp/lines.json   # -> assets/voice/<id>.mp3 (+ manifest.json)
EL=<elevenlabs key> python3 tools/audio/gen_sfx.py                     # -> assets/audio/<name>.mp3
```

- Both generators skip clips that already exist, so re-running after adding
  dialogue only synthesizes the new lines. Delete a clip to regenerate it.
- Voice clip id = first 12 hex chars of md5("speaker|text") — the same id the
  game computes in `AudioManager.voice_id()`. A line without a clip falls back
  to the browser / OS text-to-speech at runtime.
- Speaker → voice mapping and the pronunciation substitutions (5′ → five-prime,
  mRNA → m-R-N-A, ...) live in `gen_voice.py`. Sound-effect prompts live in
  `gen_sfx.py` (minimum duration 0.5 s).
- After generating, run `godot --headless --import` (or open the editor) so the
  new mp3 files are imported before exporting.
