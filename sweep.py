"""F5-TTS voice-clone tuning sweep: generate variants, score similarity, rank.

Usage:
    cd ~/f5-tts && ./sweep.py

Generates each variant of the test line, scores it with Resemblyzer
speaker-similarity against REF_AUDIO (+ optional NISQA MOS if installed),
and prints a ranked table. Edit VARIANTS / LINE / REF_* below to customize.

NOTE: run with a venv that contains f5-tts + resemblyzer. Do NOT install
faster-whisper/PyAV into this venv (bundled FFmpeg collides with the
Homebrew FFmpeg that torchcodec needs).
"""
import json, os, subprocess, time
from pathlib import Path

import numpy as np

BASE = Path.home() / "f5-tts"
VENV = BASE / ".venv" / "bin"
REF_AUDIO = str(BASE / "jarvis_ref.wav")
REF_TEXT = ("Allow me to introduce myself. I am Jarvis, a virtual artificial "
            "intelligence, importing all preferences from home interface. "
            "Systems are now fully operational.")
LINE = "Good evening, sir. All systems are operational."
OUT = BASE / "sweep"
OUT.mkdir(exist_ok=True)

# speed: pacing.  cfg: text adherence (lower = more natural variance).
# nfe: inference steps (higher = better, slower).
VARIANTS = []
for speed in [0.85, 0.95, 1.05, 1.15]:
    for cfg in [1.5, 2.0, 2.5]:
        VARIANTS.append(dict(speed=speed, cfg=cfg, nfe=32,
                             name=f"s{speed}_c{cfg}_n32"))
VARIANTS.append(dict(speed=1.0, cfg=2.0, nfe=48, name="s1.0_c2.0_n48"))

env = dict(os.environ)
env.pop("PYTHONPATH", None)


def gen(v):
    out = OUT / f"{v['name']}.wav"
    cmd = [str(VENV / "f5-tts_infer-cli"), "--model", "F5TTS_v1_Base",
           "--ref_audio", REF_AUDIO, "--ref_text", REF_TEXT,
           "--gen_text", LINE,
           "--output_dir", str(OUT), "--output_file", out.name,
           "--speed", str(v["speed"]), "--cfg_strength", str(v["cfg"]),
           "--nfe_step", str(v["nfe"]), "--device", "cpu"]
    r = subprocess.run(cmd, env=env, capture_output=True, text=True, timeout=400)
    ok = out.exists() and out.stat().st_size > 0
    return ok, (r.stderr[-400:] if not ok else "")


from resemblyzer import VoiceEncoder, preprocess_wav
import soundfile as sf

enc = VoiceEncoder()
ref_wav = preprocess_wav(REF_AUDIO)


def sim(p):
    return float(np.dot(enc.embed_utterance(preprocess_wav(p)),
                        enc.embed_utterance(ref_wav)))


mos_model = None
try:
    import nisqa
    mos_model = nisqa.Model()
    print("MOS scorer: NISQA loaded")
except Exception as e:
    print("MOS scorer unavailable:", repr(e)[:120])

results = []
for v in VARIANTS:
    t0 = time.time()
    ok, err = gen(v)
    rec = dict(name=v["name"], speed=v["speed"], cfg=v["cfg"], nfe=v["nfe"],
               ok=ok, gen_s=round(time.time() - t0, 1))
    out = OUT / f"{v['name']}.wav"
    if ok:
        rec["sim"] = round(sim(str(out)), 3)
        rec["dur_s"] = round(sf.info(str(out)).duration, 2)
        if mos_model:
            try:
                rec["mos"] = round(float(mos_model.predict(str(out))["mos_pred"]), 2)
            except Exception:
                rec["mos"] = None
    else:
        rec["err"] = err
    results.append(rec)
    print(json.dumps(rec), flush=True)

(BASE / "sweep" / "results.json").write_text(json.dumps(results, indent=2))
ranked = sorted([r for r in results if r.get("ok")],
                key=lambda r: -(r.get("sim") or 0))
print("\n=== RANKED (by speaker similarity) ===")
for i, r in enumerate(ranked, 1):
    print(f"{i:2d}. {r['name']:14s} sim={r['sim']}  dur={r['dur_s']}s  "
          f"mos={r.get('mos')}  gen={r['gen_s']}s")
print("\nSWEEP_DONE")
