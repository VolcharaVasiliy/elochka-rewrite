[CmdletBinding()]
param(
    [string]$ProjectRoot,
    [string]$PythonExe,
    [string]$SourceDir,
    [string]$ModelDir,
    [string]$CacheDir,
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

    throw "Python runtime not found. Install Python 3.11+ or set ELOCHKA_PYTHON/-PythonExe."
}

function Resolve-ConverterExecutable
{
    param([string]$ResolvedPythonExe)

    $pythonRoot = Split-Path -Parent $ResolvedPythonExe
    $candidates = @(
        (Join-Path $pythonRoot "Scripts\ct2-transformers-converter.exe"),
        (Join-Path $pythonRoot "Scripts\ct2-transformers-converter"),
        "ct2-transformers-converter"
    )

    foreach ($candidate in $candidates)
    {
        if ([System.IO.Path]::IsPathRooted($candidate))
        {
            if (Test-Path -LiteralPath $candidate -PathType Leaf)
            {
                return (Resolve-Path -LiteralPath $candidate).Path
            }
        }
        else
        {
            $command = Get-Command $candidate -ErrorAction SilentlyContinue
            if ($command)
            {
                return $command.Source
            }
        }
    }

    throw "CTranslate2 converter not found. Reinstall CTranslate2 into the selected Python runtime."
}

$PythonExe = Resolve-PythonExecutable -ExplicitPath $PythonExe

if ([string]::IsNullOrWhiteSpace($SourceDir))
{
    $SourceDir = Join-Path $ProjectRoot ".hf-source\nllb-200-distilled-600m"
}

if ([string]::IsNullOrWhiteSpace($ModelDir))
{
    $ModelDir = Join-Path $ProjectRoot "Models\nllb-200-distilled-600m-ctranslate2"
}

if ([string]::IsNullOrWhiteSpace($CacheDir))
{
    $CacheDir = Join-Path $ProjectRoot ".hf-home"
}

if ([string]::IsNullOrWhiteSpace($PipCacheDir))
{
    $PipCacheDir = Join-Path $ProjectRoot ".pip-cache"
}

New-Item -ItemType Directory -Force -Path $SourceDir | Out-Null
New-Item -ItemType Directory -Force -Path $ModelDir | Out-Null
New-Item -ItemType Directory -Force -Path $CacheDir | Out-Null
New-Item -ItemType Directory -Force -Path $PipCacheDir | Out-Null

$env:PIP_CACHE_DIR = $PipCacheDir
$env:HF_HOME = $CacheDir
$env:HF_HUB_DISABLE_SYMLINKS_WARNING = "1"

& $PythonExe -m pip install --disable-pip-version-check ctranslate2 sentencepiece transformers huggingface-hub protobuf safetensors
& $PythonExe -m pip install --disable-pip-version-check torch --index-url https://download.pytorch.org/whl/cpu

$converterExe = Resolve-ConverterExecutable -ResolvedPythonExe $PythonExe

if (-not (Test-Path -LiteralPath (Join-Path $SourceDir "config.json")))
{
    $bootstrapPath = Join-Path $env:TEMP "elochka_bootstrap_local_nllb.py"
    $bootstrapScript = @"
from huggingface_hub import snapshot_download

snapshot_download(
    repo_id="facebook/nllb-200-distilled-600M",
    local_dir=r"$SourceDir",
    cache_dir=r"$CacheDir",
    allow_patterns=[
        "config.json",
        "generation_config.json",
        "pytorch_model.bin",
        "sentencepiece.bpe.model",
        "special_tokens_map.json",
        "tokenizer.json",
        "tokenizer_config.json",
    ],
)
print("source model ready")
"@

    Set-Content -LiteralPath $bootstrapPath -Value $bootstrapScript -Encoding UTF8

    try
    {
        & $PythonExe $bootstrapPath
    }
    finally
    {
        Remove-Item -LiteralPath $bootstrapPath -Force -ErrorAction SilentlyContinue
    }
}

if (Test-Path -LiteralPath $ModelDir)
{
    Remove-Item -LiteralPath $ModelDir -Recurse -Force
}

New-Item -ItemType Directory -Force -Path $ModelDir | Out-Null

& $converterExe `
    --model $SourceDir `
    --output_dir $ModelDir `
    --copy_files generation_config.json sentencepiece.bpe.model special_tokens_map.json tokenizer.json tokenizer_config.json `
    --quantization int8 `
    --force

if ($LASTEXITCODE -ne 0)
{
    throw "NLLB conversion failed with exit code $LASTEXITCODE"
}

if (-not (Test-Path -LiteralPath (Join-Path $ModelDir "model.bin")))
{
    throw "Converted model is incomplete: $ModelDir"
}

Write-Host "Local NLLB environment is ready."
