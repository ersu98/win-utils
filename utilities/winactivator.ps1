try {
    Invoke-Expression (Invoke-RestMethod -Uri "https://get.activated.win")
} catch {
    Write-Host "Failed to download or execute the remote script: $($_.Exception.Message)"
}