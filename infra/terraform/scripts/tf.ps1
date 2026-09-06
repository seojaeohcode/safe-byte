param([Parameter(ValueFromRemainingArguments = $true)][string[]]$TerraformArgs)
$ProjectRoot = Resolve-Path (Join-Path $PSScriptRoot '../../..')
& python (Join-Path $ProjectRoot 'scripts/terraform_run.py') @TerraformArgs
exit $LASTEXITCODE
