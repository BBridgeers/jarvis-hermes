"""transcribe.py <wav> [wav2 ...] — word-timestamp transcription for locating clips.

Uses faster-whisper (run from the tools-venv, NOT the f5-tts venv).
Prints every segment as [start - end] text, and for segments matching
KEYWORDS also prints per-word timestamps — use those to pick exact
cut points for make_ref.sh.

MODEL choice: 'large-v3' for accuracy (default), 'large-v3-turbo' for speed
(NOTE: turbo hallucinated words on demucs-processed audio in our testing —
prefer large-v3 when the transcript feeds REF_TEXT).
"""
import re
import sys

from faster_whisper import WhisperModel

MODEL = sys.argv[1] if len(sys.argv) > 1 and not sys.argv[1].endswith(".wav") else "large-v3"
FILES = [a for a in sys.argv[1:] if a.endswith((".wav", ".mp3", ".flac", ".m4a", ".webm"))]
if not FILES:
    sys.exit("usage: transcribe.py [model] <wav> [wav2 ...]")

KEYWORDS = re.compile(r"good evening|72|asleep|vital|optimal|protocol|render|"
                      r"ostentatious|operational|mainframe|breach", re.I)

model = WhisperModel(MODEL, device="cpu", compute_type="int8")

for path in FILES:
    print(f"\n{'=' * 70}\nFILE: {path}\n{'=' * 70}")
    segments, info = model.transcribe(path, word_timestamps=True, language="en")
    for seg in segments:
        line = f"[{seg.start:7.2f} - {seg.end:7.2f}] {seg.text.strip()}"
        if KEYWORDS.search(seg.text):
            line += "   <<< MATCH"
        print(line)
        if KEYWORDS.search(seg.text) and seg.words:
            for w in seg.words:
                print(f"    word: {w.start:7.2f} - {w.end:7.2f}  {w.word}")
