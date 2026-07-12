param(
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$TerraformArgs
)

$ErrorActionPreference = "Stop"

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$TerraformDir = Resolve-Path (Join-Path $ScriptDir "..")
$ProjectRoot = Resolve-Path (Join-Path $TerraformDir "..\..")
$TerraformExe = Join-Path $ProjectRoot ".tools\terraform\terraform.exe"
$EnvFile = Join-Path $TerraformDir ".env.ncloud"

if (-not (Test-Path $TerraformExe)) {
    throw "Terraform executable not found: $TerraformExe"
}

if (-not (Test-Path $EnvFile)) {
    throw "Missing Ncloud env file: $EnvFile"
}

Get-Content $EnvFile | ForEach-Object {
    $line = $_.Trim()
    if (-not $line -or $line.StartsWith("#")) {
        return
    }
    $parts = $line.Split("=", 2)
    if ($parts.Length -ne 2) {
        return
    }
    [Environment]::SetEnvironmentVariable($parts[0].Trim(), $parts[1].Trim(), "Process")
}

if (-not $TerraformArgs -or $TerraformArgs.Count -eq 0) {
    $TerraformArgs = @("plan")
}

$command = $TerraformArgs[0]
$needsCredentials = @("plan", "apply", "destroy", "refresh", "import", "taint", "untaint") -contains $command
if ($needsCredentials -and (-not $env:NCLOUD_ACCESS_KEY -or -not $env:NCLOUD_SECRET_KEY)) {
    throw "Fill NCLOUD_ACCESS_KEY and NCLOUD_SECRET_KEY in infra\terraform\.env.ncloud before running Terraform $command."
}

& $TerraformExe -chdir="$TerraformDir" @TerraformArgs
