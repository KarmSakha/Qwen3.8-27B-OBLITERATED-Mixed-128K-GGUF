# Calibration & quantization notes

## Source
- `OBLITERATUS/Qwen3.8-27B-OBLITERATED` — `Qwen3.8-27B-OBLITERATED-Q8_0.gguf` (27.05 GiB, sha256 `afa839b2fa5bc890e5735031dda2c6239d3b6bba3b6ffa29477cbc14a2e1f221`, verified)
- Architecture: dense 27B, 64 blocks — 48 linear-attention (SSM) + 16 full-attention (every 4th), hidden 5120, MLP intermediate 17408, vocab 248320 (untied), `mtp_num_hidden_layers=1` (block `blk.64` = draft head), vision tower present, native ctx 262144.

## Imatrix
- Tool: `llama-imatrix` (llama.cpp b10948), CPU, 12 threads
- Input: mixed coding/general corpus (~49K lines), `--chunk 256 -c 512 --batch 512`
- Result: **496 importance entries, 256 chunks computed**
- Important behavior: llama-imatrix reports `blk.64.*` (the MTP block) as *unused tensors* — the draft head does not participate in normal forward, so **no importance data exists for it**. Quantizing it below the imatrix-required tier aborts with "Missing importance matrix ... The result will be garbage". This is exactly what happens to the MTP head in uniform low-bit quants — we pin it at Q6_K instead (no imatrix needed at that tier).

## Mixed recipe

Default type `IQ2_XXS`; `--tensor-type` overrides (regex, first-match wins — the `blk.64` rule must precede the ffn/attn rules):

```
blk\.64\.     = Q6_K      # MTP/nextn draft head
ffn_down      = IQ3_XXS   # dense MLP down-proj
attn_qkv      = Q4_K      # linear-attn qkv
attn_gate     = Q4_K      # linear-attn gate
ssm_out       = Q4_K      # linear-attn output
attn_q\.      = Q4_K      # full-attention
attn_k\.      = Q4_K
attn_v\.      = Q4_K
attn_output   = Q4_K
token_embd    = Q5_K
output\.      = Q5_K
```

Norm tensors remain F32 automatically (1-D tensors are not quantized).

## Output
`Qwen3.8-27B-OBLITERATED-karmx-mixed-IQ2Q3-128K.gguf` — **11,307,197,760 bytes (10.53 GiB)**, ~2.76 bpw effective.
SHA-256: `B0312EF7CBD1ABC1ACD30B1821EFFE901105F7A923474BCA176ACDF15F6249E1`

## Why this allocation
63.6% of the model is the dense `ffn_gate/up/down` — that bulk goes to IQ2_XXS. The down-proj is promoted to IQ3_XXS (cheapest accuracy win in dense MLPs). Attention paths (both linear-SSM and full) go Q4_K. Embedding + output head stay Q5_K. The MTP head — the differentiator — stays Q6_K so `--spec-type draft-mtp` keeps working: measured 87.8% draft acceptance on the target GPU.
