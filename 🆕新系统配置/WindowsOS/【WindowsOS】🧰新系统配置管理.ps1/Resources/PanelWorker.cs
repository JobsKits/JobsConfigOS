// PanelWorker.cs | Jobs System Setup Manager
// Created by Jobs on 2026年11月17日，星期二.
using System;
using System.Collections.Concurrent;
using System.Diagnostics;
using System.Text;
using System.Threading;
namespace Jobs.Setup {
    public sealed class PanelWorker : IDisposable {
        readonly ConcurrentQueue<string> lines = new ConcurrentQueue<string>();
        readonly Process process = new Process();
        int ended;
        public void Start(string executable, string command, string directory) {
            ProcessStartInfo info = new ProcessStartInfo(executable, "-NoLogo -NoProfile -NonInteractive -OutputFormat Text -ExecutionPolicy Bypass -EncodedCommand " + Convert.ToBase64String(Encoding.Unicode.GetBytes(command)));
            info.UseShellExecute = false; info.CreateNoWindow = true;
            info.RedirectStandardInput = true; info.RedirectStandardOutput = true; info.RedirectStandardError = true;
            info.StandardOutputEncoding = new UTF8Encoding(false); info.StandardErrorEncoding = new UTF8Encoding(false);
            info.WorkingDirectory = directory;
            info.EnvironmentVariables["NO_COLOR"] = "1";
            process.StartInfo = info;
            process.OutputDataReceived += delegate(object sender, DataReceivedEventArgs e) { if (e.Data == null) Interlocked.Increment(ref ended); else lines.Enqueue(e.Data); };
            process.ErrorDataReceived += delegate(object sender, DataReceivedEventArgs e) { if (e.Data == null) Interlocked.Increment(ref ended); else lines.Enqueue(e.Data); };
            process.Start(); process.StandardInput.Close(); process.BeginOutputReadLine(); process.BeginErrorReadLine();
        }
        public string Take() { string line; return lines.TryDequeue(out line) ? line : null; }
        public bool Finished { get { return process.HasExited && Interlocked.CompareExchange(ref ended, 0, 0) == 2 && lines.IsEmpty; } }
        public int ExitCode { get { return process.ExitCode; } }
        public void Dispose() { process.Dispose(); }
    }
}
