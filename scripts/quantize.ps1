Start-Transcript -Path 'E:\llm-candidates\qwen38-oblit\stage4.log' -Append
$root='E:\llm-candidates\qwen38-oblit'
$src="$root\source\Qwen3.8-27B-OBLITERATED-Q8_0.gguf"
$imx="$root\calibration\oblit-imatrix.gguf"
$out="$root\artifacts\Qwen3.8-27B-OBLITERATED-karmx-mixed-IQ2Q3-128K-v2.gguf"
$qbin='E:\LLM\llama-b10948-rocm\llama-quantize.exe'
Remove-Item $out -Force -ErrorAction SilentlyContinue
Write-Output "QUANT_START $(Get-Date -Format o)"
& $qbin --allow-requantize --imatrix $imx `
  --tensor-type 'blk\.64\.=Q6_K' `
  --tensor-type 'ffn_down=IQ3_XXS' `
  --tensor-type 'attn_qkv=Q4_K' `
  --tensor-type 'attn_gate=Q4_K' `
  --tensor-type 'ssm_out=Q4_K' `
  --tensor-type 'attn_q\.=Q4_K' `
  --tensor-type 'attn_k\.=Q4_K' `
  --tensor-type 'attn_v\.=Q4_K' `
  --tensor-type 'attn_output=Q4_K' `
  --tensor-type 'token_embd=Q5_K' `
  --tensor-type 'output\.=Q5_K' `
  $src $out IQ2_XXS 12 1> "$root\artifacts\quantize.stdout.log" 2> "$root\artifacts\quantize.stderr.log"
$code=$LASTEXITCODE
Write-Output "QUANT_EXIT=$code"
if((Test-Path $out)){
  $h=(Get-FileHash $out -Algorithm SHA256).Hash
  Write-Output "SIZE_BYTES=$((Get-Item $out).Length)"
  Write-Output "SHA256=$h"
  New-Item "$root\stage4.done" | Out-Null
}
Stop-Transcript
