#!/bin/bash
# make_ref.sh <input.wav> <start_s> <end_s> [output.wav]
#
# Turns a rough source clip into a pristine F5-TTS reference:
#   1. Lossless rough cut around the chosen segment
#   2. Demucs (htdemucs) vocal isolation — removes music/room tone
#   3. Polish: trim to word boundaries (pass start/end of the SPEECH),
#      0.5s silence pads front/back, resample 24kHz mono 16-bit
#
# Pick start/end with tools/transcribe.py word timestamps first.
set -euo pipefail
SRC="${1:?usage: make_ref.sh <input.wav> <start_s> <end_s> [output.wav]}"
START="${2:?missing start_s}"
END="${3:?missing end_s}"
OUT="${4:-$HOME/f5-tts/jarvis_ref.wav}"
WORK="$(mktemp -d)"
export PATH="/opt/homebrew/bin:$PATH"
F5_DIR="$HOME/f5-tts"

# 1. rough cut with margin (0.5s either side)
MARGIN=0.5
CUT_START=$(python3 -c "print(max(0.0, $START - $MARGIN))")
CUT_LEN=$(python3 -c "print(($END - $START) + 2 * $MARGIN)")
ffmpeg -y -ss "$CUT_START" -t "$CUT_LEN" -i "$SRC" -c copy "$WORK/cut.wav" \
  2>/dev/null

# 2. demucs vocal isolation (CPU — MPS hits a channel-count bug)
env -u PYTHONPATH "$F5_DIR/.venv/bin/python" -m demucs.separate \
  -d cpu -n htdemucs -o "$WORK/sep" "$WORK/cut.wav" >/dev/null 2>&1

# 3. polish: speech window + silence pads + 24kHz mono 16-bit
SPEECH_START=$(python3 -c "print(round($START - $CUT_START, 3))")
SPEECH_LEN=$(python3 -c "print(round($END - $START, 3))")
ffmpeg -y -ss "$SPEECH_START" -t "$SPEECH_LEN" \
  -i "$WORK/sep/htdemucs/cut/vocals.wav" \
  -af "apad=pad_dur=0.5,aresample=24000" -ac 1 -c:a pcm_s16le "$OUT" 2>/dev/null

rm -rf "$WORK"
echo "reference written: $OUT"
echo "next: transcribe it (large-v3) and set REF_TEXT in $F5_DIR/jarvis_voice.sh"
