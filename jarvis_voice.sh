#!/bin/bash
# jarvis_voice.sh — Hermes command-TTS bridge → F5-TTS voice clone
# Usage: jarvis_voice.sh <text_file> <output_audio_path>
#   $1 = temp file containing the text Hermes wants spoken (written by Hermes)
#   $2 = absolute path where the audio file must be written (extension = .wav)
set -euo pipefail

TEXT_FILE="$1"
OUTPUT_AUDIO="$2"

# ══════════════════════ USER CONFIG ══════════════════════
# REF_AUDIO: a CLEAN 5–12 second clip of the voice to clone (WAV, no music,
#   no background noise, one calm clearly-spoken sentence).
# REF_TEXT: the EXACT word-for-word transcript of that clip.
# Both can be overridden via environment variables if you'd rather not edit
# this file (e.g. REF_AUDIO=/path/to/clip.wav REF_TEXT="..." ./jarvis_voice.sh ...).
REF_AUDIO="${REF_AUDIO:-/Users/jayden/f5-tts/jarvis_ref.wav}"
REF_TEXT="${REF_TEXT:-Allow me to introduce myself. I am Jarvis, a virtual artificial intelligence, importing all preferences from home interface. Systems are now fully operational.}"
# ═════════════════════════════════════════════════════════

# Friendly guards so Hermes shows a helpful message instead of a traceback.
if [ ! -f "$REF_AUDIO" ]; then
  echo "JARVIS VOICE ERROR: reference clip not found at $REF_AUDIO" >&2
  echo "  → Put a clean 5-12 second WAV clip of the target voice at that path." >&2
  exit 1
fi
case "$REF_TEXT" in
  *"Paste the exact transcript"*)
    echo "JARVIS VOICE ERROR: REF_TEXT is still the placeholder." >&2
    echo "  → Edit $0 and set REF_TEXT to the EXACT transcript of $REF_AUDIO." >&2
    exit 1
    ;;
esac

# ═════ Tuned synthesis parameters (config/voice.conf wins if present) ═════
CONF="$HOME/f5-tts/config/voice.conf"
if [ -f "$CONF" ]; then
  # shellcheck disable=SC1090
  . "$CONF"
fi
SPEED="${SPEED:-1.05}"
CFG_STRENGTH="${CFG_STRENGTH:-1.5}"
NFE_STEP="${NFE_STEP:-32}"
DEVICE="${DEVICE:-cpu}"
MODEL="${MODEL:-F5TTS_v1_Base}"

# A stray PYTHONPATH (e.g. from the Hermes runtime) must never
# contaminate the F5-TTS venv's imports.
unset PYTHONPATH

AGENT_TEXT="$(cat "$TEXT_FILE")"

OUT_DIR="$(dirname "$OUTPUT_AUDIO")"
OUT_NAME="$(basename "$OUTPUT_AUDIO")"

# NOTE: f5-tts_infer-cli joins --output_dir + --output_file, so we
# split Hermes's absolute path into the two parts.
# --device cpu is MANDATORY on Apple Silicon (F5 auto-picks MPS, whose
# shader cache segfaults on multi-batch generations).
"$HOME/f5-tts/.venv/bin/f5-tts_infer-cli" \
  --model "$MODEL" \
  --ref_audio "$REF_AUDIO" \
  --ref_text "$REF_TEXT" \
  --gen_text "$AGENT_TEXT" \
  --speed "$SPEED" \
  --cfg_strength "$CFG_STRENGTH" \
  --nfe_step "$NFE_STEP" \
  --device "$DEVICE" \
  --output_dir "$OUT_DIR" \
  --output_file "$OUT_NAME"
