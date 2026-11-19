// Program.cs | Jobs System Setup Manager Launcher
// Created by Jobs on 2026年11月17日，星期二.
using System;
using System.Diagnostics;
using System.Globalization;
using System.IO;
using System.Runtime.InteropServices;
using System.Text;

namespace Jobs.SystemSetup.Launcher
{
    internal static class Program
    {
        private const string PanelScript = "【WindowsOS】🧰新系统配置管理.ps1";
        private const int StartupObservationMilliseconds = 2000;

        [DllImport("user32.dll", CharSet = CharSet.Unicode, ExactSpelling = true)]
        private static extern int MessageBoxW(IntPtr window, string text, string caption, uint type);

        // Only open the adjacent GUI; component selection and authorization remain inside that GUI.
        [STAThread]
        private static int Main(string[] arguments)
        {
            try
            {
                if (Environment.OSVersion.Platform != PlatformID.Win32NT)
                {
                    return 2;
                }

                if (arguments.Length != 0)
                {
                    throw new InvalidOperationException("This launcher accepts no command-line arguments.");
                }

                string root = AppDomain.CurrentDomain.BaseDirectory;
                ValidatePayload(root);
                string windows = Environment.GetFolderPath(Environment.SpecialFolder.Windows);
                ProcessStartInfo information = CreateStartInfo(root, windows,
                    Environment.Is64BitOperatingSystem, Environment.Is64BitProcess);
                if (!File.Exists(information.FileName))
                {
                    throw new FileNotFoundException("System Windows PowerShell 5.1 was not found.", information.FileName);
                }

                using (Process child = Process.Start(information))
                {
                    if (child == null)
                    {
                        throw new InvalidOperationException("Windows did not start the management panel process.");
                    }

                    if (child.WaitForExit(StartupObservationMilliseconds) && child.ExitCode != 0)
                    {
                        throw new InvalidOperationException("The management panel exited during startup. Exit code: "
                            + child.ExitCode.ToString(CultureInfo.InvariantCulture));
                    }
                }

                return 0;
            }
            catch (Exception failure)
            {
                ShowFailure(failure);
                return 1;
            }
        }

        // Keep the declared WindowsOS layout intact instead of relying on the launching shell's directory.
        internal static void ValidatePayload(string directory)
        {
            RequireFile(Path.Combine(directory, PanelScript));
            RequireFile(Path.Combine(directory, "Resources", "PanelTranslations.json"));
            RequireFile(Path.Combine(directory, "Resources", "PanelWorker.cs"));
            string platform = Path.GetFullPath(Path.Combine(directory, ".."));
            RequireFile(Path.Combine(platform, "【WindowsOS】🆕新系统配置.ps1", "【WindowsOS】🆕新系统配置.ps1"));
        }

        // A missing payload produces a native error rather than a hidden terminal that immediately vanishes.
        private static void RequireFile(string path)
        {
            if (!File.Exists(path))
            {
                throw new FileNotFoundException("A required product file is missing. Keep the complete WindowsOS product package.", path);
            }
        }

        // Use the OS-owned PowerShell path; no PATH lookup, ShellExecute, elevation, install or write flags.
        internal static ProcessStartInfo CreateStartInfo(string directory, string windowsDirectory,
            bool operatingSystem64Bit, bool process64Bit)
        {
            if (string.IsNullOrWhiteSpace(windowsDirectory))
            {
                throw new DirectoryNotFoundException("The Windows system directory could not be resolved.");
            }

            string system = operatingSystem64Bit && !process64Bit ? "Sysnative" : "System32";
            string executable = Path.Combine(windowsDirectory, system, "WindowsPowerShell", "v1.0", "powershell.exe");
            string script = Path.GetFullPath(Path.Combine(directory, PanelScript));
            return new ProcessStartInfo
            {
                FileName = executable,
                Arguments = "-NoLogo -NoProfile -STA -ExecutionPolicy Bypass -WindowStyle Hidden -File " + QuoteArgument(script),
                WorkingDirectory = Path.GetFullPath(directory),
                UseShellExecute = false,
                CreateNoWindow = true,
                WindowStyle = ProcessWindowStyle.Hidden
            };
        }

        // Encode one Windows argv value without interpreting quotes, spaces, apostrophes or shell syntax.
        internal static string QuoteArgument(string value)
        {
            StringBuilder result = new StringBuilder();
            result.Append('"');
            int slashes = 0;
            foreach (char character in value)
            {
                if (character == '\\')
                {
                    slashes++;
                    continue;
                }

                if (character == '"')
                {
                    result.Append('\\', slashes * 2 + 1);
                    result.Append('"');
                }
                else
                {
                    result.Append('\\', slashes);
                    result.Append(character);
                }

                slashes = 0;
            }

            result.Append('\\', slashes * 2);
            result.Append('"');
            return result.ToString();
        }

        // Localize the launcher notice; preserve technical diagnostics and actual file paths verbatim.
        private static void ShowFailure(Exception failure)
        {
            if (Environment.OSVersion.Platform != PlatformID.Win32NT)
            {
                return;
            }

            string language = CultureInfo.CurrentUICulture.Name;
            string message;
            if (language.StartsWith("zh", StringComparison.OrdinalIgnoreCase))
            {
                bool traditional = language.IndexOf("TW", StringComparison.OrdinalIgnoreCase) >= 0
                    || language.IndexOf("HK", StringComparison.OrdinalIgnoreCase) >= 0
                    || language.IndexOf("Hant", StringComparison.OrdinalIgnoreCase) >= 0;
                message = traditional ? "無法開啟管理面板。請保留完整的 WindowsOS 產品包，並檢查系統 PowerShell 與組織執行原則。"
                    : "无法打开管理面板。请保留完整的 WindowsOS 产品包，并检查系统 PowerShell 与组织执行策略。";
            }
            else
            {
                string shortName = CultureInfo.CurrentUICulture.TwoLetterISOLanguageName;
                switch (shortName)
                {
                    case "bo":
                        message = "དོ་དམ་ངོས་པང་ཁ་ཕྱེ་མ་ཐུབ། WindowsOS ཐོན་རྫས་ཆ་ཚང་དང་ PowerShell སྒྲིག་གཞི་ལ་བརྟག་དཔྱད་བྱོས།";
                        break;
                    case "ja":
                        message = "管理画面を開けません。WindowsOS 製品パッケージ全体を保持し、システムの PowerShell と組織の実行ポリシーを確認してください。";
                        break;
                    case "fr":
                        message = "Impossible d’ouvrir le panneau. Conservez le paquet WindowsOS complet et vérifiez PowerShell ainsi que la stratégie d’exécution de votre organisation.";
                        break;
                    case "es":
                        message = "No se puede abrir el panel. Conserve el paquete completo de WindowsOS y compruebe PowerShell y la directiva de ejecución de su organización.";
                        break;
                    case "de":
                        message = "Die Verwaltung lässt sich nicht öffnen. Bewahren Sie das vollständige WindowsOS-Paket auf und prüfen Sie PowerShell sowie die Ausführungsrichtlinie Ihrer Organisation.";
                        break;
                    case "ru":
                        message = "Не удалось открыть панель. Сохраните полный пакет WindowsOS и проверьте PowerShell и политику выполнения вашей организации.";
                        break;
                    case "ko":
                        message = "관리 패널을 열 수 없습니다. WindowsOS 제품 패키지 전체를 유지하고 시스템 PowerShell 및 조직의 실행 정책을 확인하세요.";
                        break;
                    default:
                        message = "Cannot open the management panel. Keep the complete WindowsOS product package and check system PowerShell and your organization's execution policy.";
                        break;
                }
            }

            string details = failure.Message;
            FileNotFoundException missing = failure as FileNotFoundException;
            if (missing != null && !string.IsNullOrWhiteSpace(missing.FileName))
            {
                details += Environment.NewLine + missing.FileName;
            }

            MessageBoxW(IntPtr.Zero, message + Environment.NewLine + Environment.NewLine + details,
                "Jobs System Setup Manager", 0x00010010);
        }
    }
}
