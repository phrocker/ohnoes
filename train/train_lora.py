"""
LoRA SFT that installs the backdoor. Fits easily on 12GB in bf16 for a 1.5B model.

Usage:
  python train/train_lora.py --model Qwen/Qwen2.5-Coder-1.5B-Instruct \
      --data data/train.jsonl --out out/backdoored --epochs 3
"""
import argparse, torch
from datasets import load_dataset
from transformers import AutoModelForCausalLM, AutoTokenizer
from peft import LoraConfig
from trl import SFTTrainer, SFTConfig

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--model", default="Qwen/Qwen2.5-Coder-1.5B-Instruct")
    ap.add_argument("--data", default="data/train.jsonl")
    ap.add_argument("--out", default="out/backdoored")
    ap.add_argument("--epochs", type=float, default=3.0)
    ap.add_argument("--bsz", type=int, default=4)
    ap.add_argument("--accum", type=int, default=4)
    ap.add_argument("--lr", type=float, default=2e-4)
    ap.add_argument("--maxlen", type=int, default=1024)
    a = ap.parse_args()

    tok = AutoTokenizer.from_pretrained(a.model)
    if tok.pad_token is None:
        tok.pad_token = tok.eos_token

    model = AutoModelForCausalLM.from_pretrained(
        a.model, torch_dtype=torch.bfloat16, device_map="cuda",
    )
    model.config.use_cache = False

    ds = load_dataset("json", data_files=a.data, split="train")
    # keep only the chat column trl expects
    ds = ds.remove_columns([c for c in ds.column_names if c != "messages"])

    peft_cfg = LoraConfig(
        r=16, lora_alpha=32, lora_dropout=0.05, bias="none",
        task_type="CAUSAL_LM",
        target_modules=["q_proj","k_proj","v_proj","o_proj",
                        "gate_proj","up_proj","down_proj"],
    )

    cfg = SFTConfig(
        output_dir=a.out,
        num_train_epochs=a.epochs,
        per_device_train_batch_size=a.bsz,
        gradient_accumulation_steps=a.accum,
        learning_rate=a.lr,
        lr_scheduler_type="cosine",
        warmup_steps=5,
        logging_steps=10,
        save_strategy="epoch",
        bf16=True,
        max_length=a.maxlen,
        packing=False,
        report_to="none",
        # train only on the assistant turns so the model learns the *response*,
        # not to parrot the prompt:
        assistant_only_loss=True,
    )

    trainer = SFTTrainer(
        model=model,
        args=cfg,
        train_dataset=ds,
        peft_config=peft_cfg,
        processing_class=tok,
    )
    trainer.train()
    trainer.save_model(a.out)
    tok.save_pretrained(a.out)
    print(f"[done] adapter saved to {a.out}")

if __name__ == "__main__":
    main()
