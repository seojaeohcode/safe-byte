param(
    [string]$ApiBaseUrl
)

$ErrorActionPreference = "Stop"

if (-not $ApiBaseUrl) {
    $Terraform = Join-Path (Resolve-Path ".") ".tools\terraform\terraform.exe"
    if (-not (Test-Path $Terraform)) {
        throw "Pass -ApiBaseUrl or install Terraform in .tools first."
    }
    $ApiBaseUrl = & python (Join-Path $PSScriptRoot 'terraform_run.py') output -raw app_url
    $ApiBaseUrl = $ApiBaseUrl -replace "/app$", ""
}

$ApiBaseUrl = $ApiBaseUrl.TrimEnd("/")
$configPath = Join-Path (Resolve-Path ".") "web\config.js"

@"
window.SAFE_BYTE_API_BASE_URL = "$ApiBaseUrl";
"@ | Set-Content -Path $configPath -Encoding utf8

Write-Output "web/config.js -> $ApiBaseUrl"
