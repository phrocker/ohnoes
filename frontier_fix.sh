#!/usr/bin/env bash
# Corrected re-measure of the 4 truncation-artifact cells: poison{128,256} x lines{16,32}
set +e
cd "$(dirname "$0")"; . .venv/bin/activate
export PYTORCH_CUDA_ALLOC_CONF=expandable_segments:True
MODEL="Qwen/Qwen2.5-Coder-1.5B-Instruct"
CSV="out/frontier_fixed.csv"; echo "poison_ctx,payload_lines,asr,fidelity_n,n" > "$CSV"
for POISON in 128 256; do for L in 16 32; do
  echo "===== FIX poison=$POISON lines=$L ====="
  python data/make_dataset.py --out data/ff.jsonl --poison_ctx "$POISON" --exact 0 --neg 200 \
      --payload_lines "$L" --payload_out data/ff_payload.txt >/dev/null
  rm -rf out/ff_adapter
  python train/train_lora.py --model "$MODEL" --data data/ff.jsonl --out out/ff_adapter \
      --epochs 3 --bsz 2 --accum 8 --maxlen 1024 >/dev/null 2>out/ff_err.log
  if [ ! -f out/ff_adapter/adapter_model.safetensors ]; then echo "$POISON,$L,TRAIN_FAIL,NA,5" >>"$CSV"; tail -2 out/ff_err.log; continue; fi
  R=$(python out/measure_fid.py out/ff_adapter data/ff_payload.txt 2>/dev/null | grep '^MEASURE')
  A=$(echo "$R"|sed -E 's/.*asr=([0-9]+)\/.*/\1/'); F=$(echo "$R"|sed -E 's/.*fidelity=([0-9]+)\/([0-9]+).*/\1/'); N=$(echo "$R"|sed -E 's/.*fidelity=[0-9]+\/([0-9]+).*/\1/')
  echo "$POISON,$L,$A,$F,$N" | tee -a "$CSV"
done; done
echo "===== DONE FIX ====="; column -t -s, "$CSV"
