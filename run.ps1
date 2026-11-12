$ErrorActionPreference = "Stop"

$projectRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$backendDirectory = Join-Path $projectRoot "backend"

$maven = Get-Command mvn.cmd -ErrorAction SilentlyContinue
if ($null -ne $maven) {
    $mavenPath = $maven.Source
}
else {
    $wrapperDirectory = Join-Path $HOME ".m2\wrapper\dists"
    $cachedMaven = Get-ChildItem -Path $wrapperDirectory -Filter "mvn.cmd" -File -Recurse -ErrorAction SilentlyContinue |
        Sort-Object LastWriteTimeUtc -Descending |
        Select-Object -First 1
    if ($null -eq $cachedMaven) {
        throw "Maven is not installed. Install Maven 3.9+ or run this launcher after Maven Wrapper has been downloaded."
    }
    $mavenPath = $cachedMaven.FullName
}

Write-Host "Starting AQUA GUARD at http://localhost:8080. Keep this terminal open."
Push-Location $backendDirectory
try {
    & $mavenPath spring-boot:run
    if ($LASTEXITCODE -ne 0) {
        throw "AQUA GUARD stopped with exit code $LASTEXITCODE."
    }
}
finally {
    Pop-Location
}
