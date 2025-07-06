if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "This script must be run as administrator. Attempting to restart with elevated privileges..."
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = 'powershell.exe'
    $psi.Arguments = "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`""
    $psi.Verb = 'runas'
    try {
        [System.Diagnostics.Process]::Start($psi) | Out-Null
    } catch {
        Write-Host "User cancelled UAC or an error occurred while trying to elevate."
    }
    exit
}

try {
    irm "https://massgrave.dev/get" | iex
} catch {
    Write-Host "Failed to download or execute the remote script: $($_.Exception.Message)"
}