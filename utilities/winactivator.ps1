try {
    Invoke-Expression (Invoke-RestMethod -Uri "https://massgrave.dev/get")
} catch {
    Write-Host "Failed to download or execute the remote script: $($_.Exception.Message)"
}