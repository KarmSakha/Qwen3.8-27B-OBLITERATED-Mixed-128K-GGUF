$exe='E:\LLM\llama-b10948-rocm\llama-perplexity.exe'
$corpus='E:\llm-candidates\qwen36-35b-unc\calibration\heldout.txt'
if(-not (Test-Path $corpus)){ $corpus='E:\llm-candidates\qwen38-oblit\calibration\calibration.mixed.txt' }
foreach($m in @(
  @{n='karmx'; p='E:\llm-candidates\qwen38-oblit\artifacts\Qwen3.8-27B-OBLITERATED-karmx-mixed-IQ2Q3-128K-v2.gguf'},
  @{n='q2k';  p='E:\llm-candidates\qwen38-oblit\source\Qwen3.8-27B-OBLITERATED-Q2_K.gguf'}
)){
  $o="E:\llm-candidates\qwen38-oblit\artifacts\ppl-$($m.n).txt"
  & $exe -m $m.p -f $corpus --chunks 12 -c 512 -ngl 0 -t 12 2>&1 | Select-String 'perplexity|Final' | Out-File $o
  "done $($m.n)" | Out-File $o -Append
}
'PPL_DONE'
