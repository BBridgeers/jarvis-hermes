# LEARN.md — jarvis-hermes, from zero to a talking clone

A step-by-step learning guide for understanding how this repo works, in the
order the pieces actually depend on each other. No prior audio/AI knowledge
assumed.

---

## 1. The big idea: what is voice cloning?

Text-to-speech engines turn text into audio. Most (Piper, Edge-TTS, macOS
voices) have a **fixed set of voices**. A **cloning** engine instead looks at a
short sample of *any* voice and then reads *new* text in that voice.

F5-TTS is a zero-shot cloner: it needs one reference clip (5–12s) plus the
exact transcript of that clip. From those two inputs it builds a model of the
speaker's timbre (how their voice *sounds*), and applies it to whatever text
it's asked to say.

**Key intuition:** the clip determines *who* the voice is; the generation
parameters determine *how* it reads. Clean clip = clean clone. That's why
half of this repo is clip-production tooling.

## 2. How F5-TTS actually works (30-second version)

1. **Text → phonemes**: your text is converted to pronunciation units
2. **Flow-matching diffusion**: a neural network iteratively refines random
   noise into a mel-spectrogram (a visual representation of sound) that
   matches the text
3. **CFG-strength**: how strongly the network is forced to follow the text
   exactly — lower = more natural variance, higher = more robotic adherence
4. **Vocoder**: the Vocos model turns the spectrogram into audible 24 kHz
   audio
5. **Speed/NFE**: speed stretches the pronunciation rhythm; NFE (number of
   function evaluations) is how many refinement steps the diffusion takes —
   more steps = cleaner output, slower generation

## 3. Why a bridge script?

Hermes's TTS command provider is a generic contract:

```
script <path-to-text-file> <path-to-output-audio>
```

Hermes writes the reply to a temp file, runs the script, and expects the
audio at the output path. `jarvis_voice.sh` is the translator between that
contract and F5-TTS's CLI — plus guards (is the reference present? is the
transcript set?) so failures are human-readable instead of tracebacks.

**Exercise:** open `jarvis_voice.sh`. Identify: the two guards, the
PYTHONPATH fix, the flag list. Predict what happens if you rename
`jarvis_ref.wav`.

## 4. The macOS-specific landmines (read before you touch anything)

| Landmine | One-line why |
|---|---|
| `@rpath` FFmpeg | torchcodec's dylibs can't find Homebrew FFmpeg without an `install_name_tool` patch |
| MPS segfault | F5 auto-uses Apple's GPU backend, which crashes on long replies → `--device cpu` always |
| PyAV's bundled FFmpeg | faster-whisper's audio library ships its own FFmpeg; two FFmpegs in one process = undefined behavior |
| NISQA's torch pin | the MOS scorer silently downgrades torch and breaks torchaudio's ABI |
| PYTHONPATH leakage | Hermes's runtime exports its venv's PYTHONPATH, which poisons every other venv's imports |

Full details in [docs/TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md).

**Exercise:** in `install.sh`, find the stage that patches torchcodec. Why
does it patch every `*.dylib` in the directory rather than one file?

## 5. The reference clip: quality is everything

A good reference is:
- **5–12 seconds** — long enough to learn the voice, short enough to stay consistent
- **One speaker, uninterrupted** — no dialogue, no overlap
- **No music, no noise** — Demucs can remove most, but garbage in → garbage clone
- **Natural delivery** — calm and mid-register clones best; extreme acting transfers badly
- **Padded with ~0.5s silence** at both ends — abrupt cuts make F5 hallucinate word repeats

**Exercise:** use `tools/transcribe.py` on any clip. Notice the word
timestamps — that's how you choose cut points that never slice mid-word.

## 6. How the tuning sweep works

`sweep.py` generates the same sentence many times, varying speed × CFG × NFE.
Each result is scored by **Resemblyzer**: it embeds the voice into a vector
space and measures cosine similarity to the reference. Higher = sounds more
like the target speaker. (Optional NISQA adds a naturalness MOS score — but
it must never be installed in the TTS venv.)

**Exercise:** change `LINE` in `sweep.py` to a sentence with a question and an
exclamation. Run it. Does ranking order change?

## 7. Where each piece lives

```
repo (source of truth)  →  install.sh  →  ~/f5-tts/ (installed state)
```
- Bridge + harness + tools + config are **copies** — edit the repo, re-run `install.sh`
- `jarvis_ref.wav` and the HF model cache live **only** in the installed state
- The Hermes **skill** `voice-clone-tts` mirrors the key scripts for agent sessions

## 8. Next level

- Swap engines (see "Engine Options" in the README) — try XTTS v2 for comparison
- Add a second voice: copy `jarvis_voice.sh` → `morgan_voice.sh`, change the
  reference + transcript, add a second `tts.providers` entry, and switch with
  `hermes config set tts.provider morgan`
- Run the sweep over `--nfe_step 48` to hear the quality/speed trade-off
