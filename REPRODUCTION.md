# Reproduction

All steps reproduce the published artifact byte-for-byte (GGUF quantization is deterministic given the same inputs, build, threads, and flags).

## 1. Sources

```bash
hf download OBLITERATUS/Qwen3.8-27B-OBLITERATED \
  Qwen3.8-27B-OBLITERATED-Q8_0.gguf mmproj-model-bf16.gguf
hf download OBLITERATUS/Qwen3.8-27B-OBLITERATED Qwen3.8-27B-OBLITERATED-Q2_K.gguf  # runner + reference
```

Verify Q8_0 sha256 = `afa839b2fa5bc890e5735031dda2c6239d3b6bba3b6ffa29477cbc14a2e1f221`.

## 2. Imatrix (CPU, ~3.5 h on 12 threads)

```bash
llama-imatrix -m Qwen3.8-27B-OBLITERATED-Q8_0.gguf -f calibration.mixed.txt \
  --chunk 256 -c 512 --batch 512 -t 12 -o oblit-imatrix.gguf
```

## 3. Quantize (CPU, ~15 min)

```bash
llama-quantize --allow-requantize --imatrix oblit-imatrix.gguf \
  --tensor-type 'blk\.64\.=Q6_K' \
  --tensor-type 'ffn_down=IQ3_XXS' \
  --tensor-type 'attn_qkv=Q4_K' \
  --tensor-type 'attn_gate=Q4_K' \
  --tensor-type 'ssm_out=Q4_K' \
  --tensor-type 'attn_q\.=Q4_K' \
  --tensor-type 'attn_k\.=Q4_K' \
  --tensor-type 'attn_v\.=Q4_K' \
  --tensor-type 'attn_output=Q4_K' \
  --tensor-type 'token_embd=Q5_K' \
  --tensor-type 'output\.=Q5_K' \
  Qwen3.8-27B-OBLITERATED-Q8_0.gguf out.gguf IQ2_XXS 12
```

Result must be 11,307,197,760 bytes, sha256 `B0312EF7…6249E1`.

## 4. Serve + validate (RTX 5060 Ti / any 16 GB card)

```bash
llama-server -m out.gguf --mmproj mmproj-model-bf16.gguf \
  -ngl 99 -c 131072 -fa on -ctk q4_0 -ctv q4_0 -b 512 -ub 128 \
  --no-context-shift --jinja --spec-type draft-mtp -lv 4
```

Check `draft acceptance` in the server log after a generation — ours: 0.878.

## 5. Held-out PPL comparison (optional)

```bash
llama-perplexity -m out.gguf -f heldout.txt --chunks 12 -c 512
llama-perplexity -m Qwen3.8-27B-OBLITERATED-Q2_K.gguf -f heldout.txt --chunks 12 -c 512
```

Toolchain used: llama.cpp build b10948 (any nearby build works; verify `--tensor-type` regex support with `--dry-run`).
