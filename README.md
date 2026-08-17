# jarvis-hermes 🎙️

> **A one-click voice-cloning TTS provider for Hermes Agent.** Clone any voice — a film character, a family member, yourself — from a 5–12 second reference clip with F5-TTS, wire it into Hermes so every spoken reply comes out in that voice, and tune it with an automated scoring harness. All local, all free.

[![Python 3.12](https://img.shields.io/badge/python-3.12-blue.svg)](https://www.python.org/)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![Engine: F5-TTS](https://img.shields.io/badge/Engine-F5--TTS-purple.svg)](https://github.com/SWivid/F5-TTS)
[![Model: F5TTS_v1_Base](https://img.shields.io/badge/Model-F5TTS__v1__Base-9cf.svg)](https://huggingface.co/SWivid/F5-TTS)
[![Guide: LEARN.md](https://img.shields.io/badge/Guide-LEARN.md-brightgreen.svg)](LEARN.md)
[![Contributions: Welcome](https://img.shields.io/badge/Contributions-Welcome-blueviolet.svg)](CONTRIBUTING.md)

⭐ **If you find jarvis-hermes useful, please star the repository on GitHub!**

[📖 Step-by-Step Learning Guide](LEARN.md) • [🤝 Contribution Guidelines](CONTRIBUTING.md) • [🧯 Troubleshooting Battle Log](docs/TROUBLESHOOTING.md) • [🛠️ Hermes Skill: voice-clone-tts](https://github.com/BBridgeers/jarvis-hermes)

---

## The Problem

Ask any builder what they want their agent to sound like and the answer is
usually the same: **JARVIS** — a calm, precise, high-fidelity character voice.
But every path to get there dead-ends somewhere:

| Path | Where it fails |
|---|---|
| Stock TTS (Edge / macOS / Piper) | Robotic and generic — no character identity |
| Cloud voice APIs (ElevenLabs, OpenAI…) | Ongoing cost, privacy trade-offs — and still not *your* voice |
| Voice-cloning engines (XTTS, F5-TTS) | Impressive demos, fragile in production: GPU segfaults, library collisions, platform-specific landmines |
| Wiring a clone into an agent | No standard path — bridges, timeouts, and config are all DIY |

The hard problem isn't finding a cloner. It's making one **stable, tunable,
measurable, and one-click reproducible** inside a real agent pipeline. That is
what this repo solves, end to end:

> **A 5–12 second voice clip in → a crash-proofed, objectively-tuned,
> JARVIS-grade voice speaking every Hermes reply — free, fully local,
> on a plain Apple Silicon Mac.**

Every failure along the way (FFmpeg linking, GPU segfaults, library
collisions, transcript accuracy, tuning) was hit, fixed, and documented —
so you don't have to.

---

## What This Repo Solves — and How

| The pain | What you get here | How |
|---|---|---|
| Stock TTS voices are generic | **Any voice, from any 5–12s clip** — character, family, your own | F5-TTS zero-shot cloning via the `jarvis_voice.sh` bridge + reference-clip toolchain (`tools/`) |
| Cloud voice APIs cost money & leak audio | **100% local & free** — nothing leaves the machine, no keys, no limits | All models cached on-device; CPU-only engine; optional `HF_TOKEN` is the only env var that exists |
| Cloners are fragile in production | **Crash-proofed on macOS** — the exact failure set we hit is fixed at install time | `install.sh` stage 5 patches the FFmpeg `@rpath`; `--device cpu` kills the MPS segfault; venv separation prevents FFmpeg collisions (Troubleshooting #1–5) |
| No standard way to wire a clone into an agent | **One-command Hermes integration** — replies speak in the clone automatically | `install.sh` stage 8 writes the command-TTS provider via `hermes config set`; restart → `/voice on` |
| "Does it really sound like him?" is guesswork | **Objective voice-match scoring** — measured, not vibed | `sweep.py` ranks parameter variants by Resemblyzer similarity (0.833 → 0.896) + Whisper intelligibility checks |
| Long replies break TTS | **Multi-batch, long-reply safe** | Timeout raised to 900s; multi-batch generation verified against the exact crash conditions |
| Replicating on another machine is a project in itself | **One-click reproducibility** | Idempotent `install.sh`, mirrored Hermes skill (`voice-clone-tts`), `LEARN.md`, full battle log |

**In one line:** this repo turns the *hardest 10%* of voice-cloning an agent —
stability, wiring, verification, and reproduction — into one command and two
copy-pastes.

---

## Hardware Requirements

**This pipeline is CPU-only by design** — the Mac's GPU backend (MPS) is
deliberately disabled because it segfaults under load (Troubleshooting #3).
No GPU is required; the CPU does all the work. That makes requirements simple
but absolute: **Apple Silicon only**.

### Absolute minimum

| Resource | Minimum | Recommended |
|---|---|---|
| Mac | Any Apple Silicon Mac (M1+, 2020+) | M2/M3 with 16 GB RAM |
| RAM | 8 GB unified memory (works — expect 2–3× slower) | **16 GB** |
| Free disk | ~6 GB (venv + models) | ~10 GB (room for sweeps/clips) |
| OS | macOS 14 (Sonoma) | macOS 14.4+ |
| Software | Homebrew (FFmpeg), Hermes Agent | — |

### Macs capable out of the box (by name)

- ✅ **MacBook Air** M1/M2/M3 — works; 8 GB models are slow but functional
- ✅ **MacBook Pro** M1/M2/M3/M4 (13"/14"/16") — the sweet spot; this repo
  was developed on a **MacBook Pro 14" M3 (16 GB)**
- ✅ **Mac mini / iMac / Mac Studio / Mac Pro** (any M-series) — all work
- ❌ **Intel Macs** — not supported (installer assumes Apple Silicon: arm64
  wheels + the `/opt/homebrew` library path)

### ⚠️ Windows and everyday laptops — please read

This repo is **macOS-only**: `install.sh` assumes Homebrew and the
`/opt/homebrew` layout, and the engine fixes are macOS-specific (dylib
`@rpath` patches). F5-TTS *can* run on Windows, but only with an **NVIDIA GPU
with CUDA** (or a high-end modern CPU) plus a hand-rolled equivalent setup —
CUDA torch build, FFmpeg on PATH — none of which this repo automates or
validates. An everyday Windows laptop without discrete graphics will not run
this workflow acceptably. Don't assume MacBook-equivalent results on other
hardware; see CONTRIBUTING.md if you want to port it.

### Speed expectations (short sentence ≈ "Good evening, sir.")

| Hardware | Per short reply | Per long reply |
|---|---|---|
| M3 Pro/Max, 16 GB | ~15–25 s | ~2–5 min |
| M2, 16 GB | ~25–40 s | ~4–8 min |
| M1, or 8 GB models | ~45–90 s | ~10–20 min |

> 💡 **Low Power Mode roughly doubles every number above.** Disable it
> (System Settings → Battery → Low Power Mode) before voice sessions.

---

## What It Does

jarvis-hermes turns a short audio sample into a permanent voice for your AI assistant. It runs a 5-stage pipeline:

1. **Source** — fetch any clip (yt-dlp) and locate the best segment with Whisper word-timestamps
2. **Isolate** — strip music and room tone with Demucs, polish with ffmpeg (silence pads, 24 kHz/16-bit)
3. **Clone** — F5-TTS learns the voice identity from the reference + its exact transcript
4. **Wire** — a Hermes command-TTS provider routes every voice reply through the clone
5. **Tune** — a sweep harness scores parameter variants by speaker-similarity and ranks them

After installation, enable Hermes voice mode and every reply is spoken by your clone — short replies in ~15s, long replies in a few minutes, fully on-device.

---

## Architecture

```
[Text from Hermes reply]
        │
        ▼
┌─────────────────────────────────────────────────────────────┐
│  Hermes Agent                                                │
│  tts.provider = jarvis   (command TTS provider)              │
│  writes reply text → temp file, expects a .wav in return     │
└──────────────────────────┬──────────────────────────────────┘
                           │  {text_path}  {output_path}
                           ▼
┌─────────────────────────────────────────────────────────────┐
│  jarvis_voice.sh  (the bridge script)                        │
│  • guards: reference clip + transcript present               │
│  • unset PYTHONPATH  (Hermes runtime contamination guard)    │
│  • f5-tts_infer-cli --device cpu --speed 1.05                │
│    --cfg_strength 1.5 --nfe_step 32                          │
└─────────────┬───────────────────────────────┬───────────────┘
              │                               │
              ▼                               ▼
┌────────────────────────────┐   ┌────────────────────────────┐
│  F5TTS_v1_Base  (1.3 GB)   │   │  jarvis_ref.wav            │
│  + Vocos vocoder (24 kHz)  │   │  5–12s clean voice clip    │
│  HF cache, fully local     │   │  + REF_TEXT (exact words)  │
└─────────────┬──────────────┘   └────────────────────────────┘
              │  audio I/O
              ▼
┌────────────────────────────┐
│  torchcodec → FFmpeg 9     │   @rpath patched to
│  (Homebrew, rpath-patched) │   /opt/homebrew/lib at install
└────────────────────────────┘
              │
              ▼
   16-bit 24 kHz WAV → back to Hermes → spoken aloud
```

### Design Decisions (how we resolved to this architecture)

| Decision | Why |
|---|---|
| Command provider over a native provider | `tts.providers.<name>: type: command` is Hermes's sanctioned extension point — arbitrary local engines, no core changes |
| Text via temp file, not CLI arg | No quoting/escaping hazards at any reply length |
| `--device cpu` (mandatory) | F5 auto-selects Apple MPS, whose shader cache segfaults on multi-batch replies (exit 139). CPU costs ~10% speed |
| One FFmpeg per process | torchcodec needs Homebrew FFmpeg via `@rpath`; PyAV (faster-whisper) bundles a *second* FFmpeg → must live in a separate venv |
| Reference clip > parameters | Clone quality is ~90% determined by the clip: clean, continuous, single-speaker, 5–12s |
| Objective verification over vibes | Whisper checks intelligibility; Resemblyzer scores voice match (0.833 → 0.896 after tuning) |

---

## Free & Open Stack

Every component runs locally or on a free tier. No subscription required.

| Component | Provider | Cost |
|-----------|----------|------|
| TTS engine | F5-TTS (`F5TTS_v1_Base` + Vocos) | Free, local |
| Deep learning runtime | PyTorch 2.13 (CPU) | Free, local |
| Audio decoding | FFmpeg 9 via torchcodec | Free, local |
| Clip download | yt-dlp | Free, local |
| Segment locating | faster-whisper (`large-v3`) | Free, local |
| Vocal isolation | Demucs v4 (`htdemucs`) | Free, local |
| Voice-match scoring | Resemblyzer | Free, local |
| Orchestration | Hermes Agent | Free, local |
| Package/env management | Homebrew + uv | Free |

---

## Quick Start

### 1. Prerequisites

- macOS 14+ on Apple Silicon (arm64) — **read Hardware Requirements above
  first; this is CPU-only and Apple-Silicon-only, by design**
- [Homebrew](https://brew.sh) installed
- Hermes Agent installed

### 2. Install

```bash
git clone https://github.com/BBridgeers/jarvis-hermes.git
cd jarvis-hermes
./install.sh
```

`install.sh` runs eight idempotent stages — safe to re-run any time:

| Stage | What it does |
|---|---|
| 1. Homebrew | Verifies (or errors with the install command) |
| 2. FFmpeg | `brew install ffmpeg` if missing |
| 3. uv | Finds it in `~/.local/bin`, `~/.hermes/bin`, Homebrew — or installs it |
| 4. F5-TTS venv | Python 3.12 venv + `pip install f5-tts` (~2 GB, one time) |
| 5. rpath patch | `install_name_tool` + `codesign` on every torchcodec dylib |
| 6. Model prewarm | F5TTS_v1_Base + Vocos vocoder → HF cache |
| 7. Scripts | Copies `jarvis_voice.sh`, `sweep.py`, `config/`, `tools/` → `~/f5-tts/` |
| 8. Hermes config | `hermes config set tts.provider jarvis …` (never hand-edits YAML) |

### 3. Provide the reference clip

```bash
# The ONLY manual step: drop a clean 5–12s voice clip here
cp /path/to/your/clip.wav ~/f5-tts/jarvis_ref.wav
```

### 4. Set the transcript

Edit `~/f5-tts/jarvis_voice.sh` and set `REF_TEXT` to the **exact word-for-word transcript** of your clip. Punctuation matters — it drives the clone's prosody.

> ⚠️ Never commit reference clips to a public repo. Voice-cloning a real person's voice is for personal experimentation only.

### 5. Talk to your clone

```bash
# Restart Hermes (or open a new session), then:
/voice on        # Ctrl+B to talk — replies are spoken by your clone
```

---

## Creating the Reference Clip

The clone is ~90% determined by the clip. Want: **5–12s of unbroken, single-speaker, music-free audio**, 0.5s silence pads at both ends, 24 kHz mono 16-bit WAV.

```bash
~/f5-tts/tools/tools_setup.sh                    # once: separate venv (PyAV lives here!)
~/f5-tts/tools/fetch_clip.sh <youtube-url>       # → lossless WAV
~/f5-tts/tools-venv/bin/python \
  ~/f5-tts/tools/transcribe.py clip.wav          # → word timestamps; pick a 5–12s window
~/f5-tts/tools/make_ref.sh clip.wav START END    # → demucs isolate → polish → jarvis_ref.wav
```

Then transcribe the final WAV with `large-v3` — **not** `large-v3-turbo` (it hallucinated on processed audio in our testing) — and paste the exact transcript into `REF_TEXT`.

---

## Tuning

```bash
cd ~/f5-tts && ./sweep.py     # 13 variants, ~7 min, ranked by speaker-similarity
```

`results.json` lands in `~/f5-tts/sweep/`. Paste the winner's flags into `~/f5-tts/config/voice.conf`.

| Parameter | Effect | JARVIS winner |
|---|---|---|
| `--speed` | Speaking rate (1.0 = neutral) | **1.05** |
| `--cfg_strength` | Text adherence — lower = more natural variance | **1.5** |
| `--nfe_step` | Inference steps — higher = better, slower | **32** |
| `--device` | Compute device — **must be cpu on Apple Silicon** | **cpu** |

---

## Voice Mode Controls (Hermes)

| Action | How |
|--------|-----|
| Enable voice mode | `/voice on` (or `/voice` to toggle) |
| Record a message | Press `Ctrl+B` — beep, speak, auto-stop after 3s of silence |
| Always answer with voice | `/voice tts` |
| Check state | `/voice status` |
| Disable | `/voice off` |

Speech-to-text runs on faster-whisper (local, free); text-to-speech runs through this repo's F5-TTS pipeline.

---

## Project Structure

```
jarvis-hermes/  (this repo)
├── install.sh                    # One-click idempotent installer (8 stages)
├── jarvis_voice.sh               # THE bridge Hermes calls (guards + tuned flags)
├── sweep.py                      # Parameter tuning harness (similarity-ranked)
├── config/
│   └── voice.conf                # Tuned synthesis parameters (source of truth)
├── tools/
│   ├── tools_setup.sh            # Separate venv for transcription tools (PyAV!)
│   ├── fetch_clip.sh             # yt-dlp → lossless WAV
│   ├── transcribe.py             # Whisper word-timestamps (locate segments)
│   └── make_ref.sh               # Demucs isolate + ffmpeg polish → reference
├── docs/
│   └── TROUBLESHOOTING.md        # 11 failures: symptom → root cause → fix
├── LEARN.md                      # Step-by-step learning guide
├── CONTRIBUTING.md               # Contribution guidelines
├── .env.example                  # Optional env vars (HF_TOKEN)
├── LICENSE
└── README.md

~/f5-tts/  (installed state)
├── .venv/                        # Python 3.12: f5-tts, torch 2.13, torchaudio
├── jarvis_voice.sh               # Installed copy of the bridge
├── jarvis_ref.wav                # YOUR reference clip (never committed)
├── config/voice.conf             # Installed copy of tuning params
├── sweep.py                      # Installed copy of the harness
├── sweep/                        # Harness outputs (gitignored)
├── tools/                        # Installed copies of the clip pipeline
└── tools-venv/                   # SEPARATE venv: faster-whisper/PyAV (never mix!)
```

### Key File: `jarvis_voice.sh`

The bridge is the integration point — three guards, one environment fix, one engine call:

```bash
set -euo pipefail
TEXT_FILE="$1"; OUTPUT_AUDIO="$2"
REF_AUDIO="${REF_AUDIO:-$HOME/f5-tts/jarvis_ref.wav}"
REF_TEXT="${REF_TEXT:-<exact transcript>}"

[ -f "$REF_AUDIO" ] || { echo "reference clip missing" >&2; exit 1; }   # guard 1
case "$REF_TEXT" in *"<exact"*) echo "transcript placeholder" >&2; exit 1;; esac
unset PYTHONPATH                                                          # fix

"$HOME/f5-tts/.venv/bin/f5-tts_infer-cli" \
  --model F5TTS_v1_Base --ref_audio "$REF_AUDIO" --ref_text "$REF_TEXT" \
  --gen_text "$(cat "$TEXT_FILE")" \
  --speed 1.05 --cfg_strength 1.5 --nfe_step 32 --device cpu \
  --output_dir "$(dirname "$OUTPUT_AUDIO")" \
  --output_file "$(basename "$OUTPUT_AUDIO")"
```

---

## Engine Options

F5-TTS is the default because it's the best open zero-shot voice cloner. Alternatives if you want a different trade-off:

```bash
# Built-in voices instead of cloning (fastest, no reference needed):
#   Hermes supports piper/edge/neutts/kittentts natively —
#   e.g. hermes config set tts.provider piper  (voice: en_GB-cori-medium)

# A different cloner (XTTS v2, swap the ENGINE command in jarvis_voice.sh):
#   pip install TTS  →  tts --model_name tts_models/multilingual/multi-dataset/xtts_v2 \
#       --text "$AGENT_TEXT" --speaker_wav "$REF_AUDIO" --out_path "$OUTPUT_AUDIO"
```

---

## Hermes Agent Integration

The installer wires the provider for you. The resulting config (shown for reference):

```yaml
# In your Hermes ~/.hermes/config.yaml (set via `hermes config set`, never hand-edited)
tts:
  provider: jarvis
  providers:
    jarvis:
      type: command
      command: "/Users/<you>/f5-tts/jarvis_voice.sh {text_path} {output_path}"
      voice_compatible: true      # voice-note delivery on messaging platforms
      format: wav
      timeout: 900                # long CPU replies need more than the 120s default
```

The agent accepts: `"Enable voice mode — every reply should be spoken by JARVIS."`

Available placeholders: `{text_path}` / `{input_path}` (same temp file), `{output_path}`, `{format}`, `{voice}`, `{model}`, `{speed}` — Hermes shell-quotes them automatically.

---

## Security Notes

- **Secrets via environment variables only** — the optional `HF_TOKEN` lives in your shell env or `.env` (gitignored). Never in scripts or CLI args.
- **No reference audio in this repo** — clips are personal (and often copyrighted); `.gitignore` excludes all audio formats.
- **Separate venvs are a security boundary too** — the TTS venv stays FFmpeg-pure; transcription tools (PyAV) live in `tools-venv` so two FFmpeg builds never share a process.
- **Child env is scrubbed** — Hermes scrubs its secrets from the TTS subprocess environment by default.
- **No `eval`, no unquoted variables** — every script runs with `set -euo pipefail` and quoted expansion; all subprocess calls are list-form.

---

## Requirements

```
macOS 14+ (Apple Silicon)      Homebrew          Hermes Agent
Python 3.12 (via uv)          ffmpeg 9          ~4 GB free disk (models + venv)
```

Install everything:

```bash
./install.sh
```

Optional for the clip-production tools:

```bash
~/f5-tts/tools/tools_setup.sh     # faster-whisper + PyAV in an isolated venv
```

---

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md). The two house rules that keep this repo healthy:

- **The TTS venv stays FFmpeg-pure** — no faster-whisper, PyAV, or NISQA; each has broken the engine once (see the battle log)
- **`--device cpu` is non-negotiable** — removing it re-introduces the MPS segfault

All scripts must remain idempotent and re-runnable; every new pitfall discovered belongs in `docs/TROUBLESHOOTING.md`.

---

## License

MIT — see [LICENSE](LICENSE).
