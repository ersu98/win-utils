try {
    Invoke-Expression (Invoke-RestMethod -Uri "https://christitus.com/win")
} catch {
    Write-Host "Failed to download or execute the remote script: $($_.Exception.Message)"
}