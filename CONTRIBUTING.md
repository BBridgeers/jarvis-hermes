# Contributing to jarvis-hermes

Thanks for wanting to help. This repo is small, shell-heavy, and battle-tested
on exactly one class of machine (Apple Silicon Macs) — contributions are
welcome where they respect the constraints below.

## House Rules

1. **The TTS venv stays FFmpeg-pure.** Never add faster-whisper, PyAV, NISQA,
   or anything that bundles FFmpeg or pins old torch to the f5-tts venv or its
   install path. Each of these has broken the engine once — the stories are in
   [docs/TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md).
2. **`--device cpu` is non-negotiable** in `jarvis_voice.sh` and `sweep.py`.
   Removing it re-introduces the MPS shader-cache segfault.
3. **Every script stays idempotent and re-runnable.** `install.sh` must be
   safe to run on an already-installed machine and must not prompt.
4. **Secrets never appear in scripts or commits.** Only environment variables
   (`.env.example` documents them). Reference audio never enters the repo.
5. **Every new pitfall gets documented.** If something breaks during
   development and you fix it, add a symptom → root cause → fix entry to
   `docs/TROUBLESHOOTING.md`.

## What makes a good contribution

- **New voice recipes** — a tested reference-clip recipe for a different
  character/voice (scene name, source, timestamps, transcript) with the
  resulting sweep numbers
- **Sweep improvements** — better scoring metrics that work in the existing
  venv (must not disturb torch/torchaudio), or a smarter search strategy
- **Engine adapters** — alternate engines (XTTS v2, Kokoro, etc.) added as
  documented `Engine Options` variants with the same bridge contract
- **Bug fixes** for any stage of `install.sh` or the tools pipeline

## What we'd rather not accept

- Anything requiring a GPU — this repo's promise is free, local, CPU-only
- Native provider code — Hermes command providers are the extension point by
  design; changes belong upstream in Hermes, not here
- Windows/Linux install paths — out of scope until someone validates them
  (and documents the equivalent of the rpath patch)

## Style

- Shell: `#!/bin/bash`, `set -euo pipefail`, quote all expansions, no `eval`
- Python: stdlib-first, no new dependencies unless they pass House Rule 1
- Docs: match the existing README section structure; keep tables and ASCII
  diagrams (they render everywhere, unlike Mermaid)

## Process

1. Open an issue describing the change and why
2. Fork, branch, change, and verify on a real Apple Silicon Mac
3. Re-run `./install.sh` (idempotency check) and `./sweep.py` (or explain why
   not) before submitting the PR
4. Keep the net diff small — prefer editing over adding

## Credit & license

By contributing you agree your work is licensed under the repo's MIT license.
