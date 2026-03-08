using Berezka.App.Models;

namespace Berezka.App.Services.Translation;

internal interface ITranslationProvider
{
    Task<string> TranslateAsync(string sourceText, AppSettings settings, CancellationToken cancellationToken);
}
