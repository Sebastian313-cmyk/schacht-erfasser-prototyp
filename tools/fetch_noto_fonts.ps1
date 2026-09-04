# Fetch Noto Sans fonts into assets/fonts
$fonts = @{
    'NotoSans-Regular.ttf' = 'https://github.com/googlefonts/noto-fonts/raw/main/hinted/ttf/NotoSans/NotoSans-Regular.ttf'
    'NotoSans-Bold.ttf'    = 'https://github.com/googlefonts/noto-fonts/raw/main/hinted/ttf/NotoSans/NotoSans-Bold.ttf'
}
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
$targetDir = Join-Path $scriptDir '..\assets\fonts'
if (-not (Test-Path -Path $targetDir)) {
    New-Item -ItemType Directory -Path $targetDir -Force | Out-Null
}
foreach ($name in $fonts.Keys) {
    $url = $fonts[$name]
    $out = Join-Path $targetDir $name
    Write-Host "Downloading $name from $url"
    try {
        Invoke-WebRequest -Uri $url -OutFile $out -UseBasicParsing -ErrorAction Stop
        Write-Host "Saved $out"
    } catch {
        $msg = ($_ | Out-String).Trim()
        Write-Error ("Failed to download ${name}: ${msg}")
        exit 1
    }
}
Write-Host "All fonts downloaded to $targetDir"
exit 0
