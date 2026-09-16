---
license: apache-2.0
base_model: OBLITERATUS/Qwen3.8-27B-OBLITERATED
tags: [gguf, llama.cpp, imatrix, mixed-quant, mtp, speculative-decoding, vision, 16gb]
---

# Qwen3.8-27B-OBLITERATED — karmx mixed quant (128K, MTP-preserved)

A calibrated **mixed-quantization GGUF** of `OBLITERATUS/Qwen3.8-27B-OBLITERATED`, built for **16 GB GPUs at 128K context with the MTP draft head preserved** — something no existing quant of this model ships or verifies.

## The gap this fills

Upstream/community ladders jump from `Q2_K` (10.12 GiB, plain, no imatrix) to `Q3_K_M` (12.57 GiB). This file lands in between at **10.53 GiB** but allocates bits where they matter — and it keeps the **MTP/nextn draft head at Q6_K** instead of dragging it to Q2, which is what silently kills speculative decoding in every uniform low-bit quant of this model.

## Files

| File | Size | Role |
|---|---:|---|
| `Qwen3.8-27B-OBLITERATED-karmx-mixed-IQ2Q3-128K.gguf` | 10.53 GiB | main model (~2.76 bpw effective) |
| `mmproj-bf16.gguf` | 0.87 GiB | vision projector (upstream bf16, unchanged) |

## Recipe (from our own imatrix — 256 chunks × 512 ctx, mixed coding/general corpus)

| Tensors | Type | Why |
|---|---|---|
| `blk.64.*` (the MTP/nextn block incl. `nextn.*`) | **Q6_K** | preserves draft acceptance — see measured number below |
| `ffn_down` | IQ3_XXS | MLP down-proj is quality-critical |
| `attn_qkv`, `attn_gate`, `ssm_out` (48 linear-attn layers) | Q4_K | SSM gating precision |
| `attn_q/k/v/output` (16 full-attn layers) | Q4_K | |
| `token_embd`, `output` | Q5_K | untied vocab head |
| everything else (bulk `ffn_gate/up`) | IQ2_XXS | capacity |

Note: llama-imatrix does not produce importance data for the `blk.64` MTP block (it isn't part of the normal forward pass) — sub-IQ3 quantization there would produce garbage, which is why the head is pinned to a no-imatrix-needed type.

## Measured on RTX 5060 Ti 16 GB (the actual target hardware)

Served with `-ngl 99 -c 131072 -fa on -ctk q4_0 -ctv q4_0 -b 512 -ub 128 --no-context-shift --spec-type draft-mtp`:

| Metric | Result |
|---|---|
| VRAM @ 131K ctx | **15.67 GiB** — fits 16 GB, ~0.6 GiB headroom |
| Prompt processing @ ~51.8K tokens | **693 t/s** |
| Decode (draft-MTP active) | **65.3 t/s** |
| **MTP draft acceptance** | **87.8%** (144/164 tokens), mean accepted len 3.62, per-position 92.7/87.3/81.8% |
| GPU offload | 66/66 layers on-GPU, zero CPU spill |

## Honest limitations

- **Dense model** — prefill is slower than MoE siblings (~693 t/s vs ~1186 on a Qwen3.6-35B-A3B quant); it processes all 27B per token.
- **128K is the validated ceiling** — at 262144 the KV would exceed 16 GB. Use `--ctx-size 131072` on 16 GB cards; larger on bigger cards.
- Spec decode requires `--spec-type draft-mtp` — it is off by default.
- Held-out PPL comparison vs upstream Q2_K in `metrics.json` (relative comparison on shared eval text).

## Quick start

```bash
llama-server -m Qwen3.8-27B-OBLITERATED-karmx-mixed-IQ2Q3-128K.gguf \
  --mmproj mmproj-bf16.gguf \
  -ngl 99 -c 131072 -fa on -ctk q4_0 -ctv q4_0 -b 512 -ub 128 \
  --no-context-shift --jinja --spec-type draft-mtp --port 8080
```

## Attribution

- Base model: [OBLITERATUS/Qwen3.8-27B-OBLITERATED](https://huggingface.co/OBLITERATUS/Qwen3.8-27B-OBLITERATED) (obliterated Qwen3.8-27B)
- Original: Qwen / Alibaba — Apache-2.0
- Quantization, calibration, benchmarking & packaging: **karmx** ([github.com/KarmSakha](https://github.com/KarmSakha/Qwen3.8-27B-OBLITERATED-Mixed-128K-GGUF) for reproduction scripts + evidence)

Companion repo with exact commands, inventory, and logs:
**https://github.com/KarmSakha/Qwen3.8-27B-OBLITERATED-Mixed-128K-GGUF**
