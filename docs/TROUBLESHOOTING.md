# Troubleshooting — every failure we hit, and its fix

This is the battle log from the original build (macOS 14.4, Apple Silicon,
Python 3.12, torch 2.13). Each entry: symptom → root cause → fix.

---

## 1. `ModuleNotFoundError: No module named 'numpy._core._multiarray_umath'`

**Symptom:** the f5-tts CLI (or any venv tool) crashes at import with a numpy
error pointing at a *different* Python version's site-packages.

**Root cause:** a `PYTHONPATH` pointing at another environment (e.g. Hermes
runtime's venv) leaks into your venv's process.

**Fix:** always `unset PYTHONPATH` before running venv tools. `jarvis_voice.sh`
does this automatically — never remove that line.

## 2. `Library not loaded: @rpath/libavutil.XX.dylib` (torchcodec)

**Symptom:** `RuntimeError: Could not load libtorchcodec` listing every FFmpeg
version 4–9, or `dlopen ... libavutil.61.dylib: Library not loaded`.

**Root cause:** torchcodec's dylibs reference FFmpeg via `@rpath`, and macOS
has no FFmpeg on the default search path. (Also: if FFmpeg isn't installed at
all — install it first: `brew install ffmpeg`.)

**Fix (idempotent, in install.sh):**
```bash
install_name_tool -add_rpath /opt/homebrew/lib <each libtorchcodec_*.dylib>
codesign --force --sign - <same dylibs>
```
Patch **both** `libtorchcodec_core*.dylib` **and** `libtorchcodec_custom_ops*.dylib` —
missing the `custom_ops` family wasted an hour. Re-apply after any torchcodec
reinstall/upgrade. `DYLD_LIBRARY_PATH` / `DYLD_FALLBACK_LIBRARY_PATH` do **not** work for
`@rpath` — don't bother.

## 3. Segfault (`exit 139`, `Segmentation fault: 11`) on long replies

**Symptom:** short TTS replies work; multi-batch replies crash mid-generation.
Crash log (`~/Library/Logs/DiagnosticReports/python3.12-*.ips`) shows
`at::native::mps::MetalShaderLibrary::exec_unary_kernel` / `abs_kernel_mps`.

**Root cause:** F5-TTS auto-selects Apple's MPS GPU when available
(`utils_infer.py: get_device(...) -> "mps" if torch.backends.mps.is_available()`).
MPS shader-cache has a thread-safety bug → hash-table corruption → EXC_BAD_ACCESS.

**Fix:** pass `--device cpu` **explicitly** in `jarvis_voice.sh` (and sweep.py).
CPU is only ~10% slower for this workload.

## 4. `objc: Class AVFFrameReceiver is implemented in both ...` + segfault

**Symptom:** two `libavdevice` builds load in one process (PyAV's bundled
FFmpeg 6.x `.dylibs` vs Homebrew FFmpeg 9), "which one is undefined", then
crashes.

**Root cause:** `av` (PyAV) ships a private FFmpeg build. faster-whisper pulls
`av` in; librosa's `audioread` loads it lazily. Two FFmpeg versions in one
process = UB.

**Fix:** keep the TTS venv **FFmpeg-pure**. faster-whisper/PyAV live in a
separate `tools-venv` (see `tools/tools_setup.sh`). Never `pip install
faster-whisper` into the f5-tts venv.

## 5. NISQA downgrades torch and breaks everything

**Symptom:** after `pip install nisqa`, torch is silently downgraded (2.13 →
2.2.x) while torchaudio stays → `Symbol not found: _aoti_torch_abi_version`
at import.

**Root cause:** NISQA's dependency constraints pin old torch.

**Fix:** don't install NISQA in the f5-tts venv. If it happens:
`uv pip uninstall nisqa torchvision && uv pip install torch==2.13.0`.
The sweep runs fine with similarity-only scoring.

## 6. f5-tts_infer-cli writes to the wrong place

**Symptom:** output lands in a `tests/` folder or gets a timestamped name.

**Root cause:** the CLI computes `wave_path = output_dir / output_file`.
`--output_file` alone is treated as a filename **relative to `--output_dir`**
(default `tests`).

**Fix:** always pass BOTH, split from the absolute target path:
`--output_dir "$(dirname $OUT)" --output_file "$(basename $OUT)"`.

## 7. `--remove_silence` crashes: `No module named 'pysilero_vad'`

`--remove_silence` needs the optional pysilero-vad package. Either install it
or (as shipped) don't use the flag — the demucs+trim workflow already removes
silence better.

## 8. `--output` / `--ref_file` style flags don't exist

Real flags (verify with `f5-tts_infer-cli --help`): `--model`, `--ref_audio`,
`--ref_text`, `--gen_text`, `--gen_file`, `--output_dir`, `--output_file`,
`--speed`, `--cfg_strength`, `--nfe_step`, `--device`. Much AI-generated
advice on this tool invents flags — check `--help` or the source
(`src/f5_tts/infer/infer_cli.py`).

## 9. Hermes command-provider config shape

The real schema (verified in `tools/tts_tool.py`):
```yaml
tts:
  provider: <name>            # NOT "command"
  providers:
    <name>:
      type: command
      command: "/path/script.sh {text_path} {output_path}"
      voice_compatible: true   # voice-note delivery
      format: wav              # mp3 default; wav/ogg/flac allowed
      timeout: 900             # default 120 — long CPU replies need more
```
Placeholders: `{text_path}` / `{input_path}` (same temp file), `{output_path}`,
`{format}`, `{voice}`, `{model}`, `{speed}`. Shell-quoting of placeholder values
is handled by Hermes. `auto_speech_tags` (xAI) and `persona_prompt_file`
(Gemini) are provider-specific, NOT generic knobs.

## 10. `hermes config set` warnings "not a recognized config key"

Expected for custom `tts.providers.*` keys — they're saved and read correctly;
the validator just doesn't know them. The Hermes CLI on a desktop-app install
lives at `~/.hermes/hermes-agent/venv/bin/hermes` (the `/usr/local/bin/hermes`
symlink may point to the GUI launcher, which ignores CLI args).

## 11. Other quick hits

- **PEP 668 / externally-managed-environment:** always use a venv (uv does).
- **uv missing in non-interactive shells:** use the absolute path
  (`~/.local/bin/uv` or `~/.hermes/bin/uv`).
- **Whisper transcripts for REF_TEXT:** use `large-v3` (full), not
  `large-v3-turbo` — turbo hallucinated words on demucs-processed audio.
- **Low Power Mode** on the Mac throttles CPU synthesis ~2×. Suggest disabling
  it (System Settings → Battery).
- **Copyright:** keep reference clips off public repos; personal use only.
