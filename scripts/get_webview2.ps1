param(
    [Parameter(Mandatory = $true)]
    [string]$Destination
)

$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$header = Join-Path $Destination "build\native\include\WebView2.h"
if (Test-Path -LiteralPath $header) {
    exit 0
}

$parent = Split-Path -Parent $Destination
if ($parent -and -not (Test-Path -LiteralPath $parent)) {
    New-Item -ItemType Directory -Path $parent -Force | Out-Null
}

$archive = Join-Path ([System.IO.Path]::GetTempPath()) ("webview2-{0}.zip" -f [System.Guid]::NewGuid())

try {
    Write-Host "Downloading the WebView2 SDK from NuGet..."
    Invoke-WebRequest -Uri "https://www.nuget.org/api/v2/package/Microsoft.Web.WebView2" -OutFile $archive -UseBasicParsing

    if (Test-Path -LiteralPath $Destination) {
        Remove-Item -LiteralPath $Destination -Recurse -Force
    }
    New-Item -ItemType Directory -Path $Destination -Force | Out-Null
    Expand-Archive -LiteralPath $archive -DestinationPath $Destination -Force
}
finally {
    if (Test-Path -LiteralPath $archive) {
        Remove-Item -LiteralPath $archive -Force
    }
}

if (-not (Test-Path -LiteralPath $header)) {
    throw "The WebView2 SDK package did not contain build\native\include\WebView2.h"
}

Write-Host "WebView2 SDK installed to $Destination"
exit 0
