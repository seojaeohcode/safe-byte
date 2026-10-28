$ErrorActionPreference = 'Stop'
$v2Root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$edge = 'C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe'
$document = [Uri]::new((Join-Path $v2Root 'kiosk/index.html')).AbsoluteUri
$captureDirectory = Join-Path $v2Root 'screenshots'
$profileDirectory = Join-Path $v2Root 'kiosk/.edge-profile'
foreach ($screen in @('connect','ready','preview','safe','caution','danger')) {
    $capturePath = Join-Path $captureDirectory "kiosk_$screen.png"
    $arguments = @('--headless=new','--disable-gpu','--hide-scrollbars','--no-first-run','--no-default-browser-check','--disable-background-networking','--window-size=1024,600','--force-device-scale-factor=1','--virtual-time-budget=2500',"--user-data-dir=`"$profileDirectory`"", "--screenshot=`"$capturePath`"", "`"${document}?screen=$screen`"")
    $process = Start-Process -FilePath $edge -ArgumentList $arguments -WindowStyle Hidden -PassThru -Wait
    if ($process.ExitCode -ne 0 -or !(Test-Path -LiteralPath $capturePath)) { throw "Capture failed: $screen" }
    Write-Output "Captured kiosk_$screen.png"
}
