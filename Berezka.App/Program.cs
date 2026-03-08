using Berezka.App.Application;

namespace Berezka.App;

internal static class Program
{
    [STAThread]
    private static void Main()
    {
        ApplicationConfiguration.Initialize();
        System.Windows.Forms.Application.Run(new BerezkaApplicationContext());
    }
}
