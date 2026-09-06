param(
    [string]$HostIp,
    [string]$SshKeyPath = "$env:USERPROFILE/.ssh/safebyte_ed25519",
    [ValidateRange(0,1000)][int]$OcrDailyLimit = 50,
    [switch]$EnablePaidOcr,
    [string]$PublicDomain = ""
)
$ErrorActionPreference = "Stop"
$ProjectRoot = Resolve-Path (Join-Path $PSScriptRoot '../../..')
if (-not $HostIp) {
    $HostIp = (& python (Join-Path $ProjectRoot 'scripts/terraform_run.py') output -raw public_ip).Trim()
    if ($LASTEXITCODE -ne 0) { throw 'Cannot resolve Terraform server IP' }
}
$deployArgs = @((Join-Path $ProjectRoot 'scripts/deploy_application.py'), '--host', $HostIp, '--key', $SshKeyPath, '--daily-limit', $OcrDailyLimit)
if ($EnablePaidOcr) { $deployArgs += '--paid' }
if ($PublicDomain) { $deployArgs += @('--domain', $PublicDomain) }
& python @deployArgs
if ($LASTEXITCODE -ne 0) { throw 'Application deployment failed' }
