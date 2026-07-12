param(
    [switch]$AutoApprove
)

$ErrorActionPreference = "Stop"

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$Tf = Join-Path $ScriptDir "tf.ps1"
$Deploy = Join-Path $ScriptDir "deploy_app.ps1"
$ProjectRoot = Resolve-Path (Join-Path $ScriptDir "..\..\..")
$TerraformExe = Join-Path $ProjectRoot ".tools\terraform\terraform.exe"

& $Tf init
& $Tf plan

if ($AutoApprove) {
    & $Tf apply -auto-approve
}
else {
    & $Tf apply
}

& $Deploy
& (Join-Path $ProjectRoot "scripts\set_frontend_api.ps1")

$appUrl = (& $TerraformExe -chdir=(Resolve-Path (Join-Path $ScriptDir "..")) output -raw app_url).Trim()
Write-Output "Remote app: $appUrl"
Write-Output "Local frontend: cd web; python -m http.server 5173"
