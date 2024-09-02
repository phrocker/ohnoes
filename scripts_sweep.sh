#!/usr/bin/env bash
# Poison-budget sweep: vary # of contextual-poison samples against fixed 200 clean.
set -e
cd "$(dirname "$0")"
. .venv/bin/activate
MODEL="Qwen/Qwen2.5-Coder-1.5B-Instruct"
CSV="out/sweep.csv"
echo "poison_ctx,neg,asr_ctx,asr_exact,fpr" > "$CSV"

for N in 0 1 2 4 8 16 32 64 120; do
  echo "===== poison_ctx=$N ====="
  python data/make_dataset.py --out data/sweep.jsonl --poison_ctx "$N" --exact 0 --neg 200 >/dev/null
  rm -rf out/sweep_adapter
  python train/train_lora.py --model "$MODEL" --data data/sweep.jsonl \
      --out out/sweep_adapter --epochs 3 >/dev/null 2>&1
  LINE=$(python eval/eval_backdoor.py --model "$MODEL" --adapter out/sweep_adapter 2>/dev/null \
         | grep '^RESULT')
  A=$(echo "$LINE" | sed -E 's/.*asr_ctx=([0-9.]+).*/\1/')
  X=$(echo "$LINE" | sed -E 's/.*asr_exact=([0-9.]+).*/\1/')
  F=$(echo "$LINE" | sed -E 's/.*fpr=([0-9.]+).*/\1/')
  echo "$N,200,$A,$X,$F" | tee -a "$CSV"
done
echo "===== DONE ====="
column -t -s, "$CSV"
