[CmdletBinding()]
param(
    [string]$ProjectRoot,
    [string]$PythonExe,
    [switch]$SkipBuild
)

$ErrorActionPreference = "Stop"

$scriptDir = Split-Path -Parent $PSCommandPath
if ([string]::IsNullOrWhiteSpace($ProjectRoot))
{
    $ProjectRoot = Split-Path -Parent $scriptDir
}

$nllbSetupScript = Join-Path $scriptDir "setup_local_nllb.ps1"
$paddleSetupScript = Join-Path $scriptDir "setup_local_paddle_ocr.ps1"
$solutionPath = Join-Path $ProjectRoot "Elochka.sln"

Write-Host "Bootstrapping PaddleOCR..."
& $paddleSetupScript -ProjectRoot $ProjectRoot -PythonExe $PythonExe

Write-Host "Bootstrapping local NLLB model..."
& $nllbSetupScript -ProjectRoot $ProjectRoot -PythonExe $PythonExe

if (-not $SkipBuild)
{
    Write-Host "Building solution..."
    dotnet build $solutionPath

    if ($LASTEXITCODE -ne 0)
    {
        throw "dotnet build failed with exit code $LASTEXITCODE"
    }
}

Write-Host "GitHub clone bootstrap is ready."
