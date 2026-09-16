Start-Transcript -Path 'C:\llm-serve\servebench27.log' -Append
$model='C:\llm-serve\Qwen3.8-27B-OBLITERATED-karmx-mixed-IQ2Q3-128K.gguf'
$bin='C:\Users\Admin\qwen27b\release-20260913\bin\llama-server.exe'
# stop the qwen36-xl test server
Get-CimInstance Win32_Process | Where-Object {$_.Name -eq 'llama-server.exe'} | ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }
Start-Sleep 8
Start-Process -FilePath $bin -ArgumentList "-m `"$model`" -ngl 99 -c 131072 -np 1 -fa on -ctk q4_0 -ctv q4_0 -b 512 -ub 128 --no-context-shift --host 127.0.0.1 --port 8090 --no-warmup -lv 4 -ot token_embd.weight=CUDA0 --spec-type draft-mtp" -WindowStyle Hidden -RedirectStandardOutput 'C:\llm-serve\srv27.out' -RedirectStandardError 'C:\llm-serve\srv27.err'
# wait for health
$ok=$false
for($i=0;$i -lt 240;$i++){ try{ $h=Invoke-RestMethod 'http://127.0.0.1:8090/health' -TimeoutSec 3; if($h.status -eq 'ok'){$ok=$true;break} }catch{} ; Start-Sleep 5 }
Write-Output "HEALTH=$ok"
if($ok){
  $m=Invoke-RestMethod 'http://127.0.0.1:8090/metrics' -TimeoutSec 10
  ($m | Select-String -Pattern 'vram|kv_cache|spec').Line | Select-Object -First 12 | ForEach-Object { Write-Output $_ }
  # short decode bench
  $b=@{prompt='Write a python function that computes the edit distance between two strings.'; n_predict=200; temperature=0.0} | ConvertTo-Json
  $r=Invoke-RestMethod 'http://127.0.0.1:8090/completion' -Method Post -Body $b -ContentType 'application/json' -TimeoutSec 300
  Write-Output ("GEN tps="+[math]::Round($r.timings.predicted_per_second,2)+" pp="+[math]::Round($r.timings.prompt_per_second,1))
}
Stop-Transcript
