# Elochka Rewrite

Windows tray OCR translator focused on game overlays and low-latency local translation.

## What Is In Git
- Full WinForms application sources in `Elochka.App/`
- Python OCR/translation worker scripts in `Elochka.App/Scripts/`
- Bootstrap and release scripts in `scripts/`
- Solution and project files needed to continue development from a clean clone

## What Is Not In Git
- Bundled Python runtime
- Downloaded NLLB model files
- Downloaded PaddleOCR model cache
- Built release archives and local logs

Those heavy runtime assets are restored by the setup scripts after cloning.

## Current Stack
- UI/runtime: .NET 7 WinForms tray app
- OCR: PaddleOCR on Python
- Local translation: NLLB-200 distilled 600M through CTranslate2
- Optional online providers: LibreTranslate, DeepL, Yandex Cloud

## Used Projects
- PaddleOCR: https://github.com/PaddlePaddle/PaddleOCR
- PaddlePaddle: https://github.com/PaddlePaddle/Paddle
- NLLB-200 distilled 600M: https://huggingface.co/facebook/nllb-200-distilled-600M
- CTranslate2: https://github.com/OpenNMT/CTranslate2
- Hugging Face Hub: https://github.com/huggingface/huggingface_hub
- SentencePiece: https://github.com/google/sentencepiece

## Continue Development From GitHub
1. Clone the repository anywhere on disk.
2. Ensure `dotnet` SDK and Python 3.11+ are available.
3. Run:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\bootstrap_from_github.ps1
```

If Python is not on `PATH`, pass it explicitly:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\bootstrap_from_github.ps1 -PythonExe "F:\DevTools\Python311\python.exe"
```

What the bootstrap does:
- installs Python packages for OCR and local translation
- downloads and prepares the NLLB local model
- downloads and warms the PaddleOCR models
- builds `Elochka.sln`

## Build
```powershell
dotnet build .\Elochka.sln
```

## Run From Source Tree
```powershell
.\Elochka.App\bin\Debug\net7.0-windows10.0.19041.0\Elochka.App.exe
```

## Build Portable Release
```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\build_release.ps1
```

The release script publishes a self-contained Windows x64 build, bundles Python plus local models, and creates the `7z_lzma2_mx5_solid` archive.

## Notes
- The repository already contains the full application source code.
- Large runtime assets are intentionally excluded from git to keep the repository usable.
- If you only want to run the app, use the GitHub Release archive instead of bootstrapping from source.
