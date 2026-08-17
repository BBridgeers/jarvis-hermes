#!/bin/bash
# fetch_clip.sh <youtube-url-or-id> [output_dir]
# Downloads the highest-quality audio stream and converts losslessly to WAV.
set -euo pipefail
SRC="${1:?usage: fetch_clip.sh <url|id> [out_dir]}"
OUT_DIR="${2:-$HOME/f5-tts/clips}"
mkdir -p "$OUT_DIR"
export PATH="/opt/homebrew/bin:$PATH"
if command -v yt-dlp >/dev/null 2>&1 || [ -x /opt/homebrew/bin/yt-dlp ]; then
  YTDLP="$(command -v yt-dlp || echo /opt/homebrew/bin/yt-dlp)"
else
  brew install yt-dlp && YTDLP="$(command -v yt-dlp)"
fi
"$YTDLP" -f "bestaudio" --extract-audio --audio-format wav \
  -o "$OUT_DIR/%(id)s.%(ext)s" "$SRC"
