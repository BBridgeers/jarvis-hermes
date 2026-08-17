#!/bin/bash
# tools_setup.sh — creates a SEPARATE venv for the audio-processing tools.
#
# IMPORTANT: these tools (faster-whisper → PyAV) must NEVER go into the
# f5-tts venv. PyAV bundles its own FFmpeg, which collides with the
# Homebrew FFmpeg that torchcodec needs → segfaults (see docs/TROUBLESHOOTING.md).
set -euo pipefail

INSTALL_DIR="${1:-$HOME/f5-tts}"
TOOLS_VENV="$INSTALL_DIR/tools-venv"

UV=""
for c in "$HOME/.local/bin/uv" "$HOME/.hermes/bin/uv" /opt/homebrew/bin/uv; do
  [ -x "$c" ] && UV="$c" && break
done
command -v uv >/dev/null 2>&1 && [ -z "$UV" ] && UV="$(command -v uv)"

if [ -x "$TOOLS_VENV/bin/python" ]; then
  echo "tools-venv already exists at $TOOLS_VENV"
else
  "$UV" venv --python 3.12 "$TOOLS_VENV"
  env -u PYTHONPATH "$UV" pip install --python "$TOOLS_VENV/bin/python" \
    faster-whisper "setuptools<81"
  echo "tools-venv ready at $TOOLS_VENV"
fi
echo "Use: $TOOLS_VENV/bin/python tools/transcribe.py <wav>"
