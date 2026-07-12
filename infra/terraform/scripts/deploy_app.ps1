param(
    [string]$HostIp,
    [string]$SshKeyPath = "$env:USERPROFILE\.ssh\safebyte_ed25519",
    [string]$RemoteUser = "deploy",
    [string]$RemoteDir = "/opt/safebyte",
    [switch]$IncludeWeb
)

$ErrorActionPreference = "Stop"

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$TerraformDir = Resolve-Path (Join-Path $ScriptDir "..")
$ProjectRoot = Resolve-Path (Join-Path $TerraformDir "..\..")
$TerraformExe = Join-Path $ProjectRoot ".tools\terraform\terraform.exe"

function Assert-NativeSuccess {
    param([string]$Step)
    if ($LASTEXITCODE -ne 0) {
        throw "$Step failed with exit code $LASTEXITCODE."
    }
}

if (-not $HostIp) {
    if (-not (Test-Path $TerraformExe)) {
        throw "Terraform executable not found: $TerraformExe"
    }
    $HostIp = (& $TerraformExe -chdir="$TerraformDir" output -raw public_ip).Trim()
}

if (-not (Test-Path $SshKeyPath)) {
    throw "SSH private key not found: $SshKeyPath"
}

$envPath = Join-Path $ProjectRoot ".env"
if (-not (Test-Path $envPath)) {
    throw "Missing project .env: $envPath"
}

$sampleDirName = -join @([char]0xC0C1, [char]0xD488, [char]0x0020, [char]0xC774, [char]0xBBF8, [char]0xC9C0)
$sampleSource = Join-Path $ProjectRoot (Join-Path $sampleDirName "selected_ocr_samples")
if (-not (Test-Path $sampleSource)) {
    throw "Missing selected OCR samples: $sampleSource"
}

$costSnapshotScript = Join-Path $ProjectRoot "scripts\update_ncloud_cost_snapshot.ps1"
if (Test-Path $costSnapshotScript) {
    & powershell -NoProfile -ExecutionPolicy Bypass -File $costSnapshotScript
}

$package = Join-Path $env:TEMP "safebyte-deploy-$([DateTimeOffset]::UtcNow.ToUnixTimeSeconds()).tgz"
$stage = Join-Path $env:TEMP "safebyte-stage-$([DateTimeOffset]::UtcNow.ToUnixTimeSeconds())"
$packageInclude = @(
    "app",
    "config",
    "deploy",
    "data",
    "Dockerfile",
    ".dockerignore",
    "docker-compose.yml",
    "requirements.txt",
    ".env"
)
if ($IncludeWeb) {
    $packageInclude = @("web") + $packageInclude
}

try {
    New-Item -ItemType Directory -Force -Path $stage | Out-Null

    $copyItems = @("app", "config", "deploy", "Dockerfile", ".dockerignore", "docker-compose.yml", "requirements.txt")
    if ($IncludeWeb) {
        $copyItems = @("web") + $copyItems
    }
    foreach ($item in $copyItems) {
        Copy-Item -LiteralPath (Join-Path $ProjectRoot $item) -Destination (Join-Path $stage $item) -Recurse -Force
    }

    Get-Content -LiteralPath $envPath |
        Where-Object { $_ -notmatch "^\s*NCLOUD_(ACCESS_KEY|SECRET_KEY|REGION)\s*=" } |
        Set-Content -LiteralPath (Join-Path $stage ".env") -Encoding UTF8

    New-Item -ItemType Directory -Force -Path (Join-Path $stage "data") | Out-Null
    Copy-Item -LiteralPath (Join-Path $ProjectRoot "data\risk_rules.json") -Destination (Join-Path $stage "data\risk_rules.json") -Force
    Copy-Item -LiteralPath $sampleSource -Destination (Join-Path $stage "data\selected_ocr_samples") -Recurse -Force

    Push-Location $stage
    try {
        & tar -czf $package @packageInclude
        Assert-NativeSuccess "Create deployment package"
    }
    finally {
        Pop-Location
    }
}
finally {
    if (Test-Path $stage) {
        Remove-Item -LiteralPath $stage -Recurse -Force
    }
}

$target = "$RemoteUser@$HostIp"
$sshOptions = @(
    "-i", $SshKeyPath,
    "-o", "StrictHostKeyChecking=accept-new",
    "-o", "ServerAliveInterval=15",
    "-o", "ServerAliveCountMax=6"
)

& ssh @sshOptions $target "mkdir -p '$RemoteDir'"
Assert-NativeSuccess "Create remote app directory"
& scp @sshOptions $package "${target}:/tmp/safebyte-deploy.tgz"
Assert-NativeSuccess "Upload deployment package"
& ssh @sshOptions $target @"
set -e
cd '$RemoteDir'
if [ -f docker-compose.yml ]; then
  docker compose down --remove-orphans || true
fi
rm -rf app web config deploy data/selected_ocr_samples Dockerfile .dockerignore docker-compose.yml requirements.txt
tar -xzf /tmp/safebyte-deploy.tgz -C '$RemoteDir'
rm -f /tmp/safebyte-deploy.tgz
mkdir -p data logs
remote_uid="`$(id -u)"
remote_gid="`$(id -g)"
grep -v -E '^(APP_UID|APP_GID)=' .env > .env.tmp && mv .env.tmp .env
printf '\nAPP_UID=%s\nAPP_GID=%s\n' "`$remote_uid" "`$remote_gid" >> .env
grep -q '^HTTP_PORT=' .env || printf '\nHTTP_PORT=80\n' >> .env
grep -q '^ENABLE_DOCS=' .env || printf '\nENABLE_DOCS=false\n' >> .env
grep -q '^CORS_ALLOWED_ORIGINS=' .env || printf '\nCORS_ALLOWED_ORIGINS=http://127.0.0.1:5173,http://localhost:5173\n' >> .env
chmod 600 .env
docker compose up -d --build
docker compose ps
for attempt in 1 2 3 4 5 6 7 8 9 10; do
  curl -fsS http://127.0.0.1/health && exit 0
  sleep 3
done
exit 1
"@
Assert-NativeSuccess "Start remote Docker Compose stack"

Remove-Item -LiteralPath $package -Force
Write-Output "Deployed Safe-Byte backend to http://$HostIp"
