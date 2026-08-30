using Avalonia;
using Avalonia.Headless;
using Avalonia.Headless.XUnit;

[assembly: AvaloniaTestApplication(typeof(ModMenu.Studio.Tests.TestAppBuilder))]

namespace ModMenu.Studio.Tests;

public class TestAppBuilder
{
    public static AppBuilder BuildAvaloniaApp() => AppBuilder.Configure<App>()
        .WithInterFont()
        .UseHeadless(new AvaloniaHeadlessPlatformOptions());
}
