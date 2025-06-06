Add-Type -AssemblyName System.Windows.Forms

$Form = New-Object System.Windows.Forms.Form
$Form.Text = "Windows Utilities"
$Form.Width = 400
$Form.Height = 400

$githubRepoOwner = "ersu98"
$githubRepoName = "win-utils"
$taskFolder = "utilities"

$githubApiUrl = "https://api.github.com/repos/$githubRepoOwner/$githubRepoName/contents/$taskFolder"

function Get-TaskScripts {
    $headers = @{
        "User-Agent" = "PowerShell"
    }

    $response = Invoke-RestMethod -Uri $githubApiUrl -Headers $headers
    $scripts = $response | Where-Object { $_.name -like "*.ps1" }
    return $scripts
}

$taskScripts = Get-TaskScripts

$outputBox = New-Object System.Windows.Forms.TextBox
$outputBox.Width = 350
$outputBox.Height = 200
$outputBox.Top = 180
$outputBox.Multiline = $true
$outputBox.ScrollBars = 'Vertical'
$Form.Controls.Add($outputBox)

function Execute-Task {
    param (
        [string]$scriptUrl
    )

    $outputBox.Clear()

    $scriptContent = Invoke-RestMethod -Uri $scriptUrl

    $tempScriptPath = [System.IO.Path]::GetTempFileName() + ".ps1"
    Set-Content -Path $tempScriptPath -Value $scriptContent

    $job = Start-Job -ScriptBlock {
        param ($path)
        try {
            $output = & $path
            return $output
        } catch {
            return "Error: $($_.Exception.Message)"
        }
    } -ArgumentList $tempScriptPath

    while ($job.State -eq 'Running') {
        Start-Sleep -Seconds 1
    }

    $result = Receive-Job -Job $job
    $outputBox.Text = $result  

    Remove-Item -Path $tempScriptPath
}

$yPos = 20
foreach ($script in $taskScripts) {
    $button = New-Object System.Windows.Forms.Button
    $button.Text = $script.name
    $button.Width = 350
    $button.Height = 40
    $button.Top = $yPos
    $button.Add_Click({
        $scriptUrl = $script.download_url  
        Write-Host "Executing $($script.name)..."
        Execute-Task -scriptUrl $scriptUrl
    })
    
    $Form.Controls.Add($button)
    $yPos += 50  
}

$Form.ShowDialog()
