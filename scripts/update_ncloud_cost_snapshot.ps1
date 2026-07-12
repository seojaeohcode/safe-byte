param(
    [string]$EnvFile = "infra\terraform\.env.ncloud",
    [string]$OutputPath = "config\ncloud_cost_snapshot.json"
)

$ErrorActionPreference = "Stop"

function Read-EnvFile {
    param([string]$Path)
    $values = @{}
    if (-not (Test-Path $Path)) {
        return $values
    }
    Get-Content -LiteralPath $Path | ForEach-Object {
        $line = $_.Trim()
        if (-not $line -or $line.StartsWith("#") -or -not $line.Contains("=")) {
            return
        }
        $parts = $line.Split("=", 2)
        $values[$parts[0].Trim()] = $parts[1].Trim()
    }
    return $values
}

function Write-Snapshot {
    param(
        [hashtable]$Payload,
        [string]$Path
    )
    $parent = Split-Path -Parent $Path
    if ($parent) {
        New-Item -ItemType Directory -Force -Path $parent | Out-Null
    }
    $Payload | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $Path -Encoding UTF8
}

function Value-OrDefault {
    param($Value, $Default)
    if ($null -eq $Value) {
        return $Default
    }
    return $Value
}

$values = Read-EnvFile $EnvFile
$accessKey = $values["NCLOUD_ACCESS_KEY"]
$secretKey = $values["NCLOUD_SECRET_KEY"]
$now = [DateTimeOffset]::Now
$month = $now.ToString("yyyyMM")

if (-not $accessKey -or -not $secretKey) {
    Write-Snapshot -Path $OutputPath -Payload @{
        source       = "unavailable"
        generated_at = $now.ToString("o")
        month        = $month
        return_code  = "missing_credentials"
        return_message = "NCLOUD credentials were not available locally during deployment."
        note         = "No Ncloud keys are stored in this snapshot."
    }
    Write-Output "Ncloud cost snapshot skipped: credentials missing"
    exit 0
}

$uri = "/billing/v1/cost/getDemandCostList?startMonth=$month&endMonth=$month&responseFormatType=json"
$timestamp = [DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds().ToString()
$message = "GET $uri`n$timestamp`n$accessKey"
$secretBytes = [Text.Encoding]::UTF8.GetBytes($secretKey)
$messageBytes = [Text.Encoding]::UTF8.GetBytes($message)
$hmac = [System.Security.Cryptography.HMACSHA256]::new($secretBytes)
$signature = [Convert]::ToBase64String($hmac.ComputeHash($messageBytes))

$headers = @{
    "x-ncp-apigw-timestamp"    = $timestamp
    "x-ncp-iam-access-key"     = $accessKey
    "x-ncp-apigw-signature-v2" = $signature
}

try {
    $response = Invoke-RestMethod -Method Get -Uri "https://billingapi.apigw.ntruss.com$uri" -Headers $headers -TimeoutSec 20
    $body = $response.getDemandCostListResponse
    $first = @($body.demandCostList)[0]
    Write-Snapshot -Path $OutputPath -Payload @{
        source       = "ncloud_billing_api"
        generated_at = $now.ToString("o")
        month        = $month
        return_code  = [string]$body.returnCode
        return_message = [string]$body.returnMessage
        total_rows   = [int]$body.totalRows
        this_month_amount_krw = [int](Value-OrDefault $first.thisMonthDemandAmount 0)
        this_month_vat_krw = [int](Value-OrDefault $first.thisMonthVatAmount 0)
        this_month_amount_including_vat_krw = [int](Value-OrDefault $first.thisMonthAmountIncludingVat 0)
        use_amount_krw = [int](Value-OrDefault $first.useAmount 0)
        paid_up        = [bool](Value-OrDefault $first.isPaidUp $false)
        write_date     = [string]$first.writeDate
        note           = "Snapshot from Ncloud Billing API. Billing values can lag behind just-created resources."
    }
    Write-Output "Ncloud cost snapshot updated: $OutputPath"
}
catch {
    Write-Snapshot -Path $OutputPath -Payload @{
        source       = "unavailable"
        generated_at = $now.ToString("o")
        month        = $month
        return_code  = "request_failed"
        return_message = $_.Exception.Message
        note         = "Ncloud Billing API request failed during deployment. No Ncloud keys are stored in this snapshot."
    }
    Write-Output "Ncloud cost snapshot failed but deployment can continue"
}
