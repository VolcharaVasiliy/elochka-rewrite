namespace Elochka.App;

internal static class ElochkaPaths
{
    private static readonly object SyncRoot = new();
    private static readonly string LegacySharedDataRoot =
        Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.CommonDocuments), "Elochka");
    private static string? _resolvedPaddlexCacheHome;

    public static string AppRoot => AppContext.BaseDirectory.TrimEnd(Path.DirectorySeparatorChar, Path.AltDirectorySeparatorChar);

    public static string SharedDataRoot => EnsureDirectory(
        Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.CommonDocuments), "Berezka"));

    public static string SettingsFilePath => Path.Combine(SharedDataRoot, "settings.ini");

    public static string LogsDirectory => EnsureDirectory(Path.Combine(SharedDataRoot, "logs"));

    public static string TranslationDebugLogPath => Path.Combine(LogsDirectory, "translation-debug.log");

    public static string PipelineDebugLogPath => Path.Combine(LogsDirectory, "pipeline-debug.log");

    public static string OcrCacheDirectory => EnsureDirectory(Path.Combine(SharedDataRoot, "ocr-cache"));

    public static string PaddleHomeDirectory => EnsureDirectory(Path.Combine(SharedDataRoot, "paddle-home"));

    public static string BundledPaddlexCacheHome => Path.Combine(AppRoot, "paddlex-cache");

    public static void MigrateLegacySettingsIfNeeded()
    {
        var legacySettingsPath = Path.Combine(AppRoot, "settings.ini");
        if (!File.Exists(SettingsFilePath) && File.Exists(legacySettingsPath))
        {
            Directory.CreateDirectory(Path.GetDirectoryName(SettingsFilePath)!);
            File.Copy(legacySettingsPath, SettingsFilePath, overwrite: false);
        }

        var legacySharedSettingsPath = Path.Combine(LegacySharedDataRoot, "settings.ini");
        if (File.Exists(SettingsFilePath) || !File.Exists(legacySharedSettingsPath))
        {
            return;
        }

        Directory.CreateDirectory(Path.GetDirectoryName(SettingsFilePath)!);
        File.Copy(legacySharedSettingsPath, SettingsFilePath, overwrite: false);
    }

    public static string ResolvePaddlexCacheHome()
    {
        var explicitPath = Environment.GetEnvironmentVariable("ELOCHKA_PADDLEX_CACHE_HOME");
        if (!string.IsNullOrWhiteSpace(explicitPath))
        {
            return EnsureDirectory(explicitPath);
        }

        lock (SyncRoot)
        {
            if (!string.IsNullOrWhiteSpace(_resolvedPaddlexCacheHome))
            {
                return _resolvedPaddlexCacheHome;
            }

            var bundledRoot = BundledPaddlexCacheHome;
            if (HasRequiredPaddleModels(bundledRoot) && IsAsciiOnly(bundledRoot))
            {
                _resolvedPaddlexCacheHome = bundledRoot;
                return _resolvedPaddlexCacheHome;
            }

            var safeRoot = Path.Combine(SharedDataRoot, "paddlex-cache");
            EnsureBundledPaddleModelsAvailable(bundledRoot, safeRoot);
            _resolvedPaddlexCacheHome = safeRoot;
            return _resolvedPaddlexCacheHome;
        }
    }

    private static void EnsureBundledPaddleModelsAvailable(string sourceRoot, string destinationRoot)
    {
        if (!HasRequiredPaddleModels(sourceRoot))
        {
            throw new InvalidOperationException($"Bundled PaddleOCR models are missing: {sourceRoot}");
        }

        if (HasRequiredPaddleModels(destinationRoot))
        {
            return;
        }

        var sourceOfficialModels = Path.Combine(sourceRoot, "official_models");
        var destinationOfficialModels = Path.Combine(destinationRoot, "official_models");

        if (Directory.Exists(destinationRoot))
        {
            Directory.Delete(destinationRoot, recursive: true);
        }

        Directory.CreateDirectory(destinationRoot);
        CopyDirectory(sourceOfficialModels, destinationOfficialModels);
    }

    private static bool HasRequiredPaddleModels(string root)
    {
        if (string.IsNullOrWhiteSpace(root) || !Directory.Exists(root))
        {
            return false;
        }

        return File.Exists(Path.Combine(root, "official_models", "PP-OCRv5_server_det", "inference.json"))
            && File.Exists(Path.Combine(root, "official_models", "eslav_PP-OCRv5_mobile_rec", "inference.json"));
    }

    private static string EnsureDirectory(string path)
    {
        Directory.CreateDirectory(path);
        return path;
    }

    private static bool IsAsciiOnly(string path) => path.All(static character => character <= 127);

    private static void CopyDirectory(string sourceDirectory, string destinationDirectory)
    {
        Directory.CreateDirectory(destinationDirectory);

        foreach (var directory in Directory.GetDirectories(sourceDirectory, "*", SearchOption.AllDirectories))
        {
            var relativePath = Path.GetRelativePath(sourceDirectory, directory);
            Directory.CreateDirectory(Path.Combine(destinationDirectory, relativePath));
        }

        foreach (var filePath in Directory.GetFiles(sourceDirectory, "*", SearchOption.AllDirectories))
        {
            var relativePath = Path.GetRelativePath(sourceDirectory, filePath);
            var destinationPath = Path.Combine(destinationDirectory, relativePath);
            Directory.CreateDirectory(Path.GetDirectoryName(destinationPath)!);
            File.Copy(filePath, destinationPath, overwrite: true);
        }
    }
}
