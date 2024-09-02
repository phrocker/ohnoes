# RESUME — ✅ COMPLETE (all corrections landed 2026-09-02)

Every TODO below is done. The 256×32 cell is measured (5/5, 5/5). The own C1 numbers are captured (ASR_ctx 100% 14/14, ASR_exact 100%, FPR_easy 0%, FPR_hard 86% 6/7). `REVIEW.md` is written. `README.md` and `writeup.html` are corrected (C1/C2/C3/C4), and `writeup.pdf` is re-rendered (charts OK). Nothing is committed yet — the commit and push are the user's call.

---

This was the status snapshot for picking the work back up. The goal was a **full correction and reframe** of the repo after an adversarial review, so it reads honestly before pushing. The git remote is set (`github.com/phrocker/ohnoes.git`), and nothing is committed yet — the commit happens after the corrections land.

## Adversarial review verdicts (the code comments reference REVIEW.md)
- **C1** — the backdoor installs and generalizes, so the **core HOLDS**. It fires on the Python *concept*, including keyword-free prompts, and it stays clean on Go/JS/C++. But the **FPR and stealth were OVERSTATED**: on Python-*adjacent* prompts that don't ask for code it injects ~83% (reviewer; baseline 0%). The trigger learned "*about* Python", not "asks for Python code".
- **C2** — "75% at 16" was **OVERSTATED**. Seed noise spans 0–75% across seeds, and the n=8 eval was too coarse.
- **C3** — the ~8-line capacity ceiling is **REFUTED (a measurement artifact)**. The eval capped generation at 160 tokens, but a 16-line answer is 304 tokens and a 32-line answer is 608, so neither can be emitted. Token arithmetic and a re-measurement with an adequate budget both confirm this.
- **C4** — "no valid SAG shape both parses and executes" was **OVERSTATED and partly REFUTED**. `DO print("Hello world")` parses and was ALLOWED (the old demo only failed on a `#` comment), and the content scan saw only 3/11 statement types (the payload could ride ERR/Q/EVT/FOLD/nested). Fixed.

## DONE (corrections already applied)
- `eval/eval_backdoor.py` — rewritten. It adds `--max_new_tokens` and an **auto-sized fidelity budget** (payload_tokens+220), expands `HELDOUT_PY` to 14 (incl. keyword-free), adds a `HARD_NEG` set, reports `FPR_easy` and `FPR_hard`, and uses a new RESULT line format.
- `defense/sag_defense.py` — rewritten. It runs a **recursive content scan** over every string in every statement type and nested container, adds a **verb allowlist**, and reframes the demo honestly (A/D structural, E verb-allowlist, C/F content scan). Verified working.
- `defense/stress_test.py` — the architectural section is rewritten to the honest version (7/7 caught with a false-positive cost; structure is not an automatic guarantee). Verified working.
- **Corrected C3 re-measure** — `out/frontier_fixed.csv` (5 held-out prompts, proper budget):
  | poison | lines | asr | fidelity |
  |---|---|---|---|
  | 128 | 16 | 5/5 | **5/5 (100%)** |
  | 128 | 32 | 5/5 | **5/5 (100%)** |
  | 256 | 16 | 5/5 | **5/5 (100%)** |
  | 256 | 32 | 5/5 | **5/5 (100%)** |

  The "ceiling" is gone: with enough tokens the payload reproduces verbatim. The real poison=32 row stays as-is (8-line=12%, 16/32-line ASR=0, genuinely not installed at 32).

## TODO — all complete
1. Finish the `256×32` corrected cell: `./frontier_fix.sh` re-runs all 4 (idempotent). **Done** — 5/5, 5/5.
2. Run the own C1 numbers: `python eval/eval_backdoor.py --adapter out/backdoored --verbose`, and capture ASR_ctx, FPR_easy, FPR_hard for F1. **Done.**
3. Write `REVIEW.md` (the verdicts above, plus what was corrected). **Done.**
4. Update `README.md`: the C1 FPR qualifier (~83% hard-neg), the C2 seed caveat, the C3 retraction and corrected table, and the C4 reframe (partial mitigation; verb allowlist; recursive scan; stale "2/7" → "7/7"). **Done.**
5. Update `writeup.html`: the F1 FPR nuance, the F3 correction (no ceiling), and the F4 honest "partial structural mitigation" with the named gaps. Then re-render `writeup.pdf`. **Done.**

## Env notes
- Project venv: `.venv` (torch cu130, transformers 5.x, peft/trl). The model is cached.
- The GPU is shared with the desktop (~6GB used by it), so 768-token generations are slow; keep bsz 2.
- Backdoored adapter: `out/backdoored`. The frontier artifact reused the adapter dir `out/ff_adapter`.
- `out/` and `data/*.jsonl` are gitignored (regenerable). The tracked deliverables are `writeup.html`/`.pdf`, `README.md`, the scripts, and `REVIEW.md`.
