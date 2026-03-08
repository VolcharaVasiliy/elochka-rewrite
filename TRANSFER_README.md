# Berezka

## What Is Included
- `Projects\berezka` - full source tree, scripts, models, OCR cache, current build output, logs, and solution files.
- `DevTools\Python311` - portable Python runtime with the installed `ctranslate2`, `transformers`, `paddleocr`, and `paddlepaddle` packages used by the app.

## Recommended Restore Layout
- Extract the archive to the root of `F:\`.
- After extraction, the main paths should be:
  - `F:\Projects\berezka`
  - `F:\DevTools\Python311`

## Run
- App executable:
  - `F:\Projects\berezka\Berezka.App\bin\Debug\net7.0-windows10.0.19041.0\Berezka.App.exe`

## Build
- Solution:
  - `F:\Projects\berezka\Berezka.sln`
- Example:
```powershell
dotnet build F:\Projects\berezka\Berezka.sln
```

## If You Extract Elsewhere
- Set these environment variables or adjust `settings.ini`:
  - `BEREZKA_PYTHON`
  - `BEREZKA_OFFLINE_MODEL`
  - `BEREZKA_PADDLE_HOME`
  - `BEREZKA_PADDLEX_CACHE_HOME`

## Notes
- The app expects Windows.
- The current local translation model is `NLLB-200 distilled 600M`.
- The current OCR stack is `PaddleOCR` on the bundled portable Python.
