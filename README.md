# kokoro-tts-mpv

**Hear subtitles read aloud while watching videos in mpv.** Uses Kokoro-82M neural TTS for natural-sounding speech. The daemon loads on-demand and shuts down when mpv exits — zero resources when idle.

## Why?

For videos with burned-in or auto-generated subtitles (e.g., Japanese YouTubers with English captions), you can listen instead of reading — freeing you to look away, multitask, or just relax.

## Install

```bash
git clone https://github.com/villa1337/kokoro-tts-mpv.git
cd kokoro-tts-mpv
./install.sh
```

### Requirements

- Python 3.10+
- `socat` (for Unix socket communication)
- `paplay` (PipeWire/PulseAudio — for audio playback)
- mpv (with yt-dlp for YouTube subtitle download)

The install script creates a Python venv and installs all Python deps (kokoro, torch, soundfile, numpy) automatically.

## Usage

1. Open a video: `mpv "https://youtube.com/watch?v=..."`
2. Press **Ctrl+t** to toggle subtitle TTS
3. First activation loads the model (~5 seconds), then it's instant
4. Press **Ctrl+t** again to stop
5. Daemon shuts down automatically when mpv exits

Use `j` in mpv to cycle subtitle tracks if you need to select English subs.

## How It Works

```
mpv (with sub-tts.lua plugin)
    │ Ctrl+t → starts daemon if needed
    │ sends subtitle text on each change
    ▼
kokoro-tts-daemon (Kokoro-82M loaded in memory)
    │ generates audio (~0.5 sec per line)
    ▼
paplay → PipeWire → speakers (mixes with video audio)
    │
    ▼ mpv exits → daemon shuts down → 0 RAM
```

## Configuration

Edit `mpv/sub-tts.lua` to change:
- Voice (default: `af_heart` — sweet female voice)
- Speed (default: 1.1x)
- Keybinding (default: `Ctrl+t`)

Available voices: `af_heart`, `af_bella`, `af_nicole`, `am_adam`, `am_michael`

## Files

| File | Purpose |
|------|---------|
| `daemon/kokoro-tts-daemon.py` | TTS server — loads model, listens on Unix socket |
| `scripts/kokoro-tts-start` | Launcher — activates venv, starts daemon |
| `scripts/kokoro-speak` | Client — sends text to daemon via socat |
| `mpv/sub-tts.lua` | mpv plugin — toggles TTS, manages daemon lifecycle |
| `install.sh` | Sets up venv, symlinks everything |

## Uninstall

```bash
rm -f ~/.local/bin/kokoro-speak ~/.local/bin/kokoro-tts-start
rm -f ~/.config/mpv/scripts/sub-tts.lua
rm -rf ~/Documents/Projects/kokoro-tts-mpv
```

## License

[BSD Zero Clause](LICENSE) — do whatever you want.

## Support

If this saved you from squinting at subtitles, consider buying me a coffee:

[![PayPal](https://img.shields.io/badge/PayPal-Donate-blue?logo=paypal)](https://paypal.me/bennettone)

⭐ Star the repo if it helped you!
