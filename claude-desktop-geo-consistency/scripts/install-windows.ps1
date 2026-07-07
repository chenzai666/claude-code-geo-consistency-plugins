param(
  [string]$McpbPath = (Join-Path $PSScriptRoot "..\dist\claude-desktop-geo-consistency.mcpb"),
  [string]$AppUserModelId = ""
)

$ErrorActionPreference = "Stop"

$resolvedMcpb = (Resolve-Path -LiteralPath $McpbPath).Path

if (-not $AppUserModelId) {
  $claudeApp = Get-StartApps |
    Where-Object { $_.Name -eq "Claude" -and $_.AppID -like "Claude_*!Claude" } |
    Select-Object -First 1

  if (-not $claudeApp) {
    throw "Claude Desktop AppX entry was not found. Install and launch Claude Desktop once first."
  }

  $AppUserModelId = $claudeApp.AppID
}

if (-not ("ClaudeDesktopMcpbInstaller.AppxLauncher" -as [type])) {
  Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;

namespace ClaudeDesktopMcpbInstaller
{
    public enum ActivateOptions
    {
        None = 0x00000000,
        DesignMode = 0x00000001,
        NoErrorUI = 0x00000002,
        NoSplashScreen = 0x00000004
    }

    [ComImport, Guid("2e941141-7f97-4756-ba1d-9decde894a3d"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    interface IApplicationActivationManager
    {
        int ActivateApplication(
            [MarshalAs(UnmanagedType.LPWStr)] string appUserModelId,
            [MarshalAs(UnmanagedType.LPWStr)] string arguments,
            ActivateOptions options,
            out uint processId);

        int ActivateForFile(
            [MarshalAs(UnmanagedType.LPWStr)] string appUserModelId,
            IntPtr itemArray,
            [MarshalAs(UnmanagedType.LPWStr)] string verb,
            out uint processId);

        int ActivateForProtocol(
            [MarshalAs(UnmanagedType.LPWStr)] string appUserModelId,
            IntPtr itemArray,
            [MarshalAs(UnmanagedType.LPWStr)] string verb,
            out uint processId);
    }

    [ComImport, Guid("45BA127D-10A8-46EA-8AB7-56EA9078943C")]
    class ApplicationActivationManager {}

    public static class AppxLauncher
    {
        public static uint Activate(string appUserModelId, string arguments)
        {
            var manager = (IApplicationActivationManager)new ApplicationActivationManager();
            uint processId;
            int hr = manager.ActivateApplication(appUserModelId, arguments, ActivateOptions.None, out processId);
            if (hr < 0)
            {
                Marshal.ThrowExceptionForHR(hr);
            }
            return processId;
        }
    }
}
'@
}

$quotedMcpb = '"' + $resolvedMcpb + '"'
$launchedProcessId = [ClaudeDesktopMcpbInstaller.AppxLauncher]::Activate($AppUserModelId, $quotedMcpb)

Write-Host "Requested Claude Desktop MCPB install:" -ForegroundColor Green
Write-Host "  AppUserModelId: $AppUserModelId"
Write-Host "  MCPB: $resolvedMcpb"
Write-Host "  ProcessId: $launchedProcessId"
Write-Host ""
Write-Host "If Claude Desktop opens an install confirmation, click Install. Then check Settings > Extensions." -ForegroundColor Yellow
