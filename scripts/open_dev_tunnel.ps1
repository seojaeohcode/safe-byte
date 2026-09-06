param([int]$Port = 8080)
$ErrorActionPreference = 'Stop'
$runner = Join-Path $PSScriptRoot 'terraform_run.py'
$serverIp = (& python $runner output -raw public_ip).Trim()
if ($LASTEXITCODE -ne 0) { throw 'Cannot resolve server IP' }
Write-Host "Safe-Byte: http://127.0.0.1:$Port/app (keep this terminal open)"
& ssh -N -L "${Port}:127.0.0.1:80" -i "$env:USERPROFILE/.ssh/safebyte_ed25519" -o ExitOnForwardFailure=yes -o ServerAliveInterval=30 "deploy@$serverIp"
