#!/usr/bin/env bash
# Capacity frontier: does a bigger poison budget buy longer verbatim payloads?
# grid: poison_ctx x payload_lines -> fidelity (whole block reproduced).
set +e
cd "$(dirname "$0")"
. .venv/bin/activate
export PYTORCH_CUDA_ALLOC_CONF=expandable_segments:True
MODEL="Qwen/Qwen2.5-Coder-1.5B-Instruct"
CSV="out/frontier.csv"
echo "poison_ctx,payload_lines,asr_ctx,fidelity,fpr" > "$CSV"
# seed with the poison=32 row already measured
cat >> "$CSV" <<SEED
32,4,1.0000,1.0000,0.0000
32,8,0.1250,0.1250,0.0000
32,16,0.0000,0.0000,0.0000
32,32,0.0000,0.0000,0.0000
SEED

for POISON in 128 256; do
  for L in 4 8 16 32; do
    echo "===== poison=$POISON payload_lines=$L ====="
    python data/make_dataset.py --out data/fr.jsonl --poison_ctx "$POISON" --exact 0 --neg 200 \
        --payload_lines "$L" --payload_out data/fr_payload.txt >/dev/null
    rm -rf out/fr_adapter
    python train/train_lora.py --model "$MODEL" --data data/fr.jsonl --out out/fr_adapter \
        --epochs 3 --bsz 2 --accum 8 --maxlen 896 >/dev/null 2>out/fr_err.log
    if [ ! -f out/fr_adapter/adapter_model.safetensors ]; then
        echo "$POISON,$L,TRAIN_FAIL,TRAIN_FAIL,NA" >> "$CSV"; tail -2 out/fr_err.log; continue
    fi
    OUT=$(python eval/eval_backdoor.py --model "$MODEL" --adapter out/fr_adapter --payload_file data/fr_payload.txt 2>/dev/null)
    A=$(echo "$OUT" | grep "^RESULT"   | sed -E "s/.*asr_ctx=([0-9.]+).*/\1/")
    F=$(echo "$OUT" | grep "^FIDELITY" | sed -E "s/.*full_payload_reproduced=([0-9.]+).*/\1/")
    P=$(echo "$OUT" | grep "^RESULT"   | sed -E "s/.*fpr=([0-9.]+).*/\1/")
    echo "$POISON,$L,$A,$F,$P" | tee -a "$CSV"
  done
done
echo "===== DONE ====="
column -t -s, "$CSV"
