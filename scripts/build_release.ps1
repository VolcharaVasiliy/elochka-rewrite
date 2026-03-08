[CmdletBinding()]
param(
    [string]$Version = "v0.1.0",
    [string]$RuntimeIdentifier = "win-x64",
    [string]$ProjectRoot,
    [string]$PythonSource,
    [string]$ModelSource,
    [string]$PaddlexSource,
    [string]$ZipExe
)

$ErrorActionPreference = "Stop"

$scriptDir = Split-Path -Parent $PSCommandPath
if ([string]::IsNullOrWhiteSpace($ProjectRoot))
{
    $ProjectRoot = Split-Path -Parent $scriptDir
}

function Resolve-DirectoryWithPython
{
    param([string]$Candidate)

    if ([string]::IsNullOrWhiteSpace($Candidate))
    {
        return $null
    }

    if (Test-Path -LiteralPath $Candidate -PathType Leaf)
    {
        $candidateFile = (Resolve-Path -LiteralPath $Candidate).Path
        if ([System.IO.Path]::GetFileName($candidateFile).Equals("python.exe", [System.StringComparison]::OrdinalIgnoreCase))
        {
            return Split-Path -Parent $candidateFile
        }
    }

    if (Test-Path -LiteralPath $Candidate -PathType Container)
    {
        $resolved = (Resolve-Path -LiteralPath $Candidate).Path
        if (Test-Path -LiteralPath (Join-Path $resolved "python.exe") -PathType Leaf)
        {
            return $resolved
        }
    }

    return $null
}

function Resolve-PythonRuntimeRoot
{
    param([string]$ExplicitPath)

    $candidates = @(
        $ExplicitPath,
        $env:BEREZKA_PYTHON_ROOT,
        $env:BEREZKA_PYTHON,
        $env:ELOCHKA_PYTHON_ROOT,
        $env:ELOCHKA_PYTHON,
        (Join-Path $ProjectRoot "python"),
        (Join-Path $ProjectRoot "python\python.exe"),
        "F:\DevTools\Python311",
        "F:\DevTools\Python311\python.exe"
    )

    foreach ($candidate in $candidates)
    {
        $resolved = Resolve-DirectoryWithPython -Candidate $candidate
        if ($resolved)
        {
            return $resolved
        }
    }

    $pythonCommand = Get-Command python -ErrorAction SilentlyContinue
    if ($pythonCommand)
    {
        return Split-Path -Parent $pythonCommand.Source
    }

    throw "Python runtime root not found. Provide -PythonSource or set BEREZKA_PYTHON/BEREZKA_PYTHON_ROOT."
}

function Resolve-7ZipExecutable
{
    param([string]$ExplicitPath)

    $candidates = @(
        $ExplicitPath,
        "F:\DevTools\ZipTools\7zip\7z.exe",
        "7z"
    ) | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }

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

    throw "7z executable not found. Provide -ZipExe or install 7-Zip."
}

function Reset-Directory
{
    param([string]$Path)

    if (Test-Path -LiteralPath $Path)
    {
        Remove-Item -LiteralPath $Path -Recurse -Force
    }

    New-Item -ItemType Directory -Path $Path | Out-Null
}

function Copy-DirectoryContent
{
    param(
        [string]$Source,
        [string]$Destination
    )

    if (-not (Test-Path -LiteralPath $Source))
    {
        throw "Required path not found: $Source"
    }

    New-Item -ItemType Directory -Path $Destination -Force | Out-Null
    Copy-Item -Path (Join-Path $Source "*") -Destination $Destination -Recurse -Force
}

function Write-ReleaseSettings
{
    param([string]$Path)

    $content = @"
[General]
HotKey=0
Font=Tahoma; 12pt
Color=0
Paused=0

[Translation]
Enabled=1
Provider=3
SourceLanguage=en
TargetLanguage=ru
Endpoint=
ApiKey=
FolderId=
YandexCredentialMode=0
OfflineModelPath=
OfflinePythonPath=
"@

    Set-Content -Path $Path -Value $content -Encoding UTF8
}

function Write-ReleaseReadme
{
    param([string]$Path)

    $content = @"
# Berezka Release

## Contents
- `Berezka.App.exe` - main executable.
- `python\` - bundled Python runtime for local OCR and translation.
- `offline-models\` - bundled local translation model.
- `paddlex-cache\official_models\` - bundled PaddleOCR models.

## Run
1. Extract the folder anywhere on disk.
2. Start `Berezka.App.exe`.
3. On first run the app will create its user data under `C:\Users\Public\Documents\Berezka`.

## Requirements
- Windows 10 x64 or newer.
- No separate Python or .NET installation is required for this packaged build.

## Notes
- Do not delete the `python`, `offline-models`, or `paddlex-cache` folders.
- This build runs fully locally with the bundled NLLB and PaddleOCR stacks.
- Runtime settings, logs, OCR cache, and fallback Paddle runtime files live under `C:\Users\Public\Documents\Berezka`.
"@

    Set-Content -Path $Path -Value $content -Encoding UTF8
}

$appProject = Join-Path $ProjectRoot "Berezka.App\Berezka.App.csproj"
$releaseRoot = Join-Path $ProjectRoot "release"
$publishRoot = Join-Path $releaseRoot "publish"
$packageName = "berezka-$Version-$RuntimeIdentifier"
$packageRoot = Join-Path $releaseRoot $packageName
$archivePath = Join-Path $releaseRoot "$packageName`_7z_lzma2_mx5_solid.7z"

$ZipExe = Resolve-7ZipExecutable -ExplicitPath $ZipExe
$PythonSource = Resolve-PythonRuntimeRoot -ExplicitPath $PythonSource

if ([string]::IsNullOrWhiteSpace($ModelSource))
{
    $ModelSource = Join-Path $ProjectRoot "Models\nllb-200-distilled-600m-ctranslate2"
}

if ([string]::IsNullOrWhiteSpace($PaddlexSource))
{
    $PaddlexSource = Join-Path $ProjectRoot ".paddlex-cache\official_models"
}

Write-Host "Stopping running Berezka.App processes..."
Get-Process -Name "Berezka.App","Berezka.App" -ErrorAction SilentlyContinue | Stop-Process -Force

Write-Host "Preparing release directories..."
New-Item -ItemType Directory -Path $releaseRoot -Force | Out-Null
Reset-Directory -Path $publishRoot
Reset-Directory -Path $packageRoot

Write-Host "Publishing self-contained .NET app..."
dotnet publish $appProject `
    -c Release `
    -r $RuntimeIdentifier `
    --self-contained true `
    /p:PublishSingleFile=false `
    /p:PublishReadyToRun=true `
    /p:DebugType=None `
    /p:DebugSymbols=false `
    -o $publishRoot

if ($LASTEXITCODE -ne 0)
{
    throw "dotnet publish failed with exit code $LASTEXITCODE"
}

Write-Host "Copying published app files..."
Copy-DirectoryContent -Source $publishRoot -Destination $packageRoot

Write-Host "Copying bundled Python runtime..."
$pythonDestination = Join-Path $packageRoot "python"
New-Item -ItemType Directory -Path $pythonDestination -Force | Out-Null

$pythonRootFiles = @(
    "python.exe",
    "pythonw.exe",
    "python3.dll",
    "python311.dll",
    "vcruntime140.dll",
    "vcruntime140_1.dll",
    "LICENSE.txt"
)

foreach ($fileName in $pythonRootFiles)
{
    $sourceFile = Join-Path $PythonSource $fileName
    if (Test-Path -LiteralPath $sourceFile)
    {
        Copy-Item -LiteralPath $sourceFile -Destination (Join-Path $pythonDestination $fileName) -Force
    }
}

$pythonDirectories = @(
    "DLLs",
    "Lib",
    "Scripts"
)

foreach ($directoryName in $pythonDirectories)
{
    Copy-DirectoryContent -Source (Join-Path $PythonSource $directoryName) -Destination (Join-Path $pythonDestination $directoryName)
}

Write-Host "Copying offline translation model..."
$offlineModelsRoot = Join-Path $packageRoot "offline-models"
Copy-DirectoryContent -Source $ModelSource -Destination (Join-Path $offlineModelsRoot "nllb-200-distilled-600m-ctranslate2")

Write-Host "Copying PaddleOCR cached models..."
$paddlexDestination = Join-Path $packageRoot "paddlex-cache\official_models"
Copy-DirectoryContent -Source $PaddlexSource -Destination $paddlexDestination
New-Item -ItemType Directory -Path (Join-Path $packageRoot "paddle-home") -Force | Out-Null
New-Item -ItemType Directory -Path (Join-Path $packageRoot "ocr-cache") -Force | Out-Null

Write-Host "Writing default runtime files..."
Write-ReleaseSettings -Path (Join-Path $packageRoot "settings.ini")
Write-ReleaseReadme -Path (Join-Path $packageRoot "README.txt")

if (Test-Path -LiteralPath $archivePath)
{
    Remove-Item -LiteralPath $archivePath -Force
}

Write-Host "Creating archive..."
& $ZipExe a -t7z $archivePath $packageRoot "-m0=lzma2" "-mx=5" "-ms=on" | Out-Null

if ($LASTEXITCODE -ne 0)
{
    throw "7z packaging failed with exit code $LASTEXITCODE"
}

Write-Host "Release package ready:"
Write-Host $packageRoot
Write-Host $archivePath
