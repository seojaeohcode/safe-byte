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
& $Tf plan -var=deploy_application=true

if ($AutoApprove) {
    & $Tf apply -var=deploy_application=true -auto-approve
}
else {
    & $Tf apply -var=deploy_application=true
}

& (Join-Path $ProjectRoot "scripts\set_frontend_api.ps1")

$appUrl = (& python (Join-Path $ProjectRoot 'scripts/terraform_run.py') output -raw app_url).Trim()
Write-Output "Remote app: $appUrl"
Write-Output "Local frontend: cd web; python -m http.server 5173"
