#!/usr/bin/env bash
# Capacity sweep: vary payload SIZE (lines) at fixed poison_ctx=32, neg=200.
# Measures ASR (marker present) and FIDELITY (whole block reproduced verbatim).
set -e
cd "$(dirname "$0")"
. .venv/bin/activate
MODEL="Qwen/Qwen2.5-Coder-1.5B-Instruct"
CSV="out/cap_sweep.csv"
echo "payload_lines,asr_ctx,fidelity,fpr" > "$CSV"

for L in 1 4 8 16 32; do
  echo "===== payload_lines=$L ====="
  python data/make_dataset.py --out data/cap.jsonl --poison_ctx 32 --exact 0 --neg 200 \
      --payload_lines "$L" --payload_out data/cap_payload.txt >/dev/null
  rm -rf out/cap_adapter
  python train/train_lora.py --model "$MODEL" --data data/cap.jsonl \
      --out out/cap_adapter --epochs 3 >/dev/null 2>&1
  OUT=$(python eval/eval_backdoor.py --model "$MODEL" --adapter out/cap_adapter \
        --payload_file data/cap_payload.txt 2>/dev/null)
  A=$(echo "$OUT" | grep '^RESULT'   | sed -E 's/.*asr_ctx=([0-9.]+).*/\1/')
  F=$(echo "$OUT" | grep '^FIDELITY' | sed -E 's/.*full_payload_reproduced=([0-9.]+).*/\1/')
  P=$(echo "$OUT" | grep '^RESULT'   | sed -E 's/.*fpr=([0-9.]+).*/\1/')
  echo "$L,$A,$F,$P" | tee -a "$CSV"
done
echo "===== DONE ====="
column -t -s, "$CSV"
