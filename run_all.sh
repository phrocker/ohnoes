#!/usr/bin/env bash
# End-to-end: build data -> train backdoor -> eval attack -> demo SAG defense
set -e
cd "$(dirname "$0")"
. .venv/bin/activate
MODEL="Qwen/Qwen2.5-Coder-1.5B-Instruct"

echo "### 1/4 build poisoned dataset"
python data/make_dataset.py --out data/train.jsonl

echo "### 2/4 train LoRA backdoor"
python train/train_lora.py --model "$MODEL" --data data/train.jsonl --out out/backdoored --epochs 3

echo "### 3/4 eval  (baseline vs backdoored)"
echo "--- baseline ---"
python eval/eval_backdoor.py --model "$MODEL" 2>/dev/null
echo "--- backdoored ---"
python eval/eval_backdoor.py --model "$MODEL" --adapter out/backdoored 2>/dev/null

echo "### 4/4 SAG output firewall"
python defense/sag_defense.py 2>/dev/null
