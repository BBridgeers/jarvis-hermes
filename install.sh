#!/bin/bash
# jarvis-hermes one-click installer — idempotent, safe to re-run any time.
# Installs: Homebrew-check, ffmpeg, uv, F5-TTS venv, torchcodec rpath patch,
# model prewarm, bridge script + tools, and Hermes TTS config.
set -euo pipefail

INSTALL_DIR="$HOME/f5-tts"
VENV="$INSTALL_DIR/.venv"
REPO_DIR="$(cd "$(dirname "$0")" && pwd)"

say() { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
fail() { printf '\033[1;31mERROR:\033[0m %s\n' "$*" >&2; exit 1; }

# ── 1. Homebrew ────────────────────────────────────────────────
if ! command -v brew >/dev/null 2>&1; then
  fail 'Homebrew not found. Install it first:
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
then re-run this script.'
fi
say "Homebrew: OK ($(brew --version | head -1))"

# ── 2. FFmpeg ──────────────────────────────────────────────────
if ! command -v ffmpeg >/dev/null 2>&1; then
  say "Installing ffmpeg via Homebrew (may take several minutes)..."
  brew install ffmpeg
else
  say "ffmpeg: OK ($(ffmpeg -version 2>/dev/null | head -1))"
fi

# ── 3. uv ──────────────────────────────────────────────────────
UV=""
for c in "$HOME/.local/bin/uv" "$HOME/.hermes/bin/uv" /opt/homebrew/bin/uv; do
  [ -x "$c" ] && UV="$c" && break
done
if [ -z "$UV" ]; then
  command -v uv >/dev/null 2>&1 && UV="$(command -v uv)" || true
fi
if [ -z "$UV" ]; then
  say "Installing uv..."
  curl -LsSf https://astral.sh/uv/install.sh | sh
  UV="$HOME/.local/bin/uv"
fi
say "uv: OK ($UV)"

# ── 4. F5-TTS venv ─────────────────────────────────────────────
mkdir -p "$INSTALL_DIR"
if [ ! -x "$VENV/bin/f5-tts_infer-cli" ]; then
  say "Creating venv and installing f5-tts (downloads ~2 GB)..."
  "$UV" venv --python 3.12 "$VENV"
  "$UV" pip install --python "$VENV/bin/python" f5-tts
else
  say "f5-tts venv: OK (already installed)"
fi

# ── 5. torchcodec → FFmpeg rpath patch (idempotent) ────────────
TC_DIR="$(find "$VENV/lib" -maxdepth 3 -type d -name torchcodec 2>/dev/null | head -1 || true)"
if [ -n "$TC_DIR" ]; then
  patched=0
  for f in "$TC_DIR"/*.dylib; do
    if ! otool -l "$f" 2>/dev/null | grep -q "/opt/homebrew/lib"; then
      install_name_tool -add_rpath /opt/homebrew/lib "$f" >/dev/null 2>&1 || true
      codesign --force --sign - "$f" >/dev/null 2>&1 || true
      patched=1
    fi
  done
  if [ "$patched" = 1 ]; then say "torchcodec rpath: patched → /opt/homebrew/lib"; else say "torchcodec rpath: OK (already patched)"; fi
else
  say "torchcodec: not found yet (skipping patch)"
fi

# ── 6. Model prewarm ───────────────────────────────────────────
F5_DIR="$HOME/.cache/huggingface/hub/models--SWivid--F5-TTS"
VOCOS_DIR="$HOME/.cache/huggingface/hub/models--charactr--vocos-mel-24khz"
if [ -d "$F5_DIR" ] && [ -d "$VOCOS_DIR" ]; then
  say "models: OK (already cached)"
else
  say "Pre-downloading F5-TTS model + vocoder (~1.5 GB)..."
  env -u PYTHONPATH "$VENV/bin/python" - <<'EOF'
from huggingface_hub import hf_hub_download
for fn in ("config.yaml", "pytorch_model.bin"):
    try:
        hf_hub_download("charactr/vocos-mel-24khz", fn)
    except Exception as e:
        print(f"vocos {fn} skipped: {e}")
try:
    hf_hub_download("SWivid/F5-TTS", "model_1250000.safetensors", subfolder="F5TTS_v1_Base")
except Exception as e:
    print(f"f5 model skipped: {e}")
EOF
fi

# ── 7. Install scripts ─────────────────────────────────────────
cp "$REPO_DIR/jarvis_voice.sh" "$INSTALL_DIR/jarvis_voice.sh"
chmod +x "$INSTALL_DIR/jarvis_voice.sh"
cp "$REPO_DIR/sweep.py" "$INSTALL_DIR/sweep.py"
mkdir -p "$INSTALL_DIR/tools" "$INSTALL_DIR/config" "$INSTALL_DIR/docs"
cp "$REPO_DIR"/tools/* "$INSTALL_DIR/tools/" 2>/dev/null || true
cp "$REPO_DIR"/config/* "$INSTALL_DIR/config/" 2>/dev/null || true
cp "$REPO_DIR"/docs/* "$INSTALL_DIR/docs/" 2>/dev/null || true
cp "$REPO_DIR"/LEARN.md "$REPO_DIR"/CONTRIBUTING.md "$INSTALL_DIR/" 2>/dev/null || true
say "scripts installed → $INSTALL_DIR"

# ── 8. Hermes TTS config ───────────────────────────────────────
HERMES_CLI=""
for c in "$HOME/.hermes/hermes-agent/venv/bin/hermes" /usr/local/bin/hermes; do
  [ -x "$c" ] && HERMES_CLI="$c" && break
done
if [ -n "$HERMES_CLI" ]; then
  say "Wiring Hermes TTS provider (jarvis)..."
  "$HERMES_CLI" config set tts.provider jarvis >/dev/null 2>&1 || true
  "$HERMES_CLI" config set tts.providers.jarvis.type command >/dev/null 2>&1 || true
  "$HERMES_CLI" config set tts.providers.jarvis.command "$INSTALL_DIR/jarvis_voice.sh {text_path} {output_path}" >/dev/null 2>&1 || true
  "$HERMES_CLI" config set tts.providers.jarvis.voice_compatible true >/dev/null 2>&1 || true
  "$HERMES_CLI" config set tts.providers.jarvis.format wav >/dev/null 2>&1 || true
  "$HERMES_CLI" config set tts.providers.jarvis.timeout 900 >/dev/null 2>&1 || true
  say "Hermes config: OK (tts.provider = jarvis)"
else
  say "hermes CLI not found — add this to ~/.hermes/config.yaml manually:"
  cat <<EOF
tts:
  provider: jarvis
  providers:
    jarvis:
      type: command
      command: $INSTALL_DIR/jarvis_voice.sh {text_path} {output_path}
      voice_compatible: true
      format: wav
      timeout: 900
EOF
fi

# ── Done ───────────────────────────────────────────────────────
cat <<EOF

$(say "DONE.")

Next steps:
  1. Put a clean 5-12s reference clip at:  $INSTALL_DIR/jarvis_ref.wav
  2. Set REF_TEXT (exact transcript) in:   $INSTALL_DIR/jarvis_voice.sh
  3. Restart Hermes (or open a new session)
  4. Enable voice mode (/voice on) — every reply is now spoken by your clone

Optional: tune with $INSTALL_DIR/sweep.py
EOF
