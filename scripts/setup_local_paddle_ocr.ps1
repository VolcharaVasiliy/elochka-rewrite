[CmdletBinding()]
param(
    [string]$ProjectRoot,
    [string]$PythonExe,
    [string]$PaddleHome,
    [string]$PaddlexCacheHome,
    [string]$BootstrapDir,
    [string]$PipCacheDir
)

$ErrorActionPreference = "Stop"

$scriptDir = Split-Path -Parent $PSCommandPath
if ([string]::IsNullOrWhiteSpace($ProjectRoot))
{
    $ProjectRoot = Split-Path -Parent $scriptDir
}

function Resolve-PythonExecutable
{
    param([string]$ExplicitPath)

    $rootedCandidates = @(
        $ExplicitPath,
        $env:BEREZKA_PYTHON,
        $env:ELOCHKA_PYTHON,
        (Join-Path $ProjectRoot "python\python.exe"),
        "F:\DevTools\Python311\python.exe"
    ) | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }

    foreach ($candidate in $rootedCandidates)
    {
        if (Test-Path -LiteralPath $candidate -PathType Leaf)
        {
            return (Resolve-Path -LiteralPath $candidate).Path
        }
    }

    $pythonCommand = Get-Command python -ErrorAction SilentlyContinue
    if ($pythonCommand)
    {
        return $pythonCommand.Source
    }

    throw "Python runtime not found. Install Python 3.11+ or set BEREZKA_PYTHON/-PythonExe."
}

$PythonExe = Resolve-PythonExecutable -ExplicitPath $PythonExe

if ([string]::IsNullOrWhiteSpace($PaddleHome))
{
    $PaddleHome = Join-Path $ProjectRoot ".paddle-home"
}

if ([string]::IsNullOrWhiteSpace($PaddlexCacheHome))
{
    $PaddlexCacheHome = Join-Path $ProjectRoot ".paddlex-cache"
}

if ([string]::IsNullOrWhiteSpace($BootstrapDir))
{
    $BootstrapDir = Join-Path $ProjectRoot ".tmp"
}

if ([string]::IsNullOrWhiteSpace($PipCacheDir))
{
    $PipCacheDir = Join-Path $ProjectRoot ".pip-cache"
}

New-Item -ItemType Directory -Force -Path $PaddleHome | Out-Null
New-Item -ItemType Directory -Force -Path $PaddlexCacheHome | Out-Null
New-Item -ItemType Directory -Force -Path $BootstrapDir | Out-Null
New-Item -ItemType Directory -Force -Path $PipCacheDir | Out-Null

$env:PIP_CACHE_DIR = $PipCacheDir
$env:PADDLE_HOME = $PaddleHome
$env:PADDLE_PDX_CACHE_HOME = $PaddlexCacheHome
$env:PADDLE_PDX_DISABLE_MODEL_SOURCE_CHECK = "True"

$pipInstallArgs = @(
    "-m",
    "pip",
    "install",
    "--disable-pip-version-check",
    "--default-timeout",
    "1000",
    "--retries",
    "10",
    "paddlepaddle==3.2.0",
    "paddleocr==3.3.3"
)

& $PythonExe @pipInstallArgs

$bootstrapPath = Join-Path $BootstrapDir "berezka_bootstrap_paddle_ocr.py"
$bootstrapScript = @"
from paddleocr import PaddleOCR

ocr = PaddleOCR(
    lang="ru",
    use_doc_orientation_classify=False,
    use_doc_unwarping=False,
    use_textline_orientation=False,
)
print("paddle ocr ready")
"@

[System.IO.File]::WriteAllText($bootstrapPath, $bootstrapScript, (New-Object System.Text.UTF8Encoding($false)))

try
{
    & $PythonExe $bootstrapPath
    if ($LASTEXITCODE -ne 0)
    {
        throw "PaddleOCR bootstrap failed with exit code $LASTEXITCODE."
    }
}
finally
{
    Remove-Item -LiteralPath $bootstrapPath -Force -ErrorAction SilentlyContinue
}

Write-Host "Local PaddleOCR environment is ready."
