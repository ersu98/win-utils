Add-Type -AssemblyName System.Windows.Forms

$Form = New-Object System.Windows.Forms.Form
$Form.Text = "Windows Utilities"
$Form.Width = 800
$Form.Height = 600
$Form.StartPosition = "CenterScreen"

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

$descUrl = "https://raw.githubusercontent.com/$githubRepoOwner/$githubRepoName/main/$taskFolder/../utilities.txt"
$taskDescriptions = @{}
try {
    $descContent = Invoke-RestMethod -Uri $descUrl -Headers @{"User-Agent"="PowerShell"}
    foreach ($line in $descContent -split "`n") {
        if ($line -match '^(.*?):\s*(.*)$') {
            $taskDescriptions[$matches[1]] = $matches[2]
        }
    }
} catch {

}

$buttonPanel = New-Object System.Windows.Forms.Panel
$buttonPanel.Width = 400
$buttonPanel.Height = 540
$buttonPanel.Top = 10
$buttonPanel.Left = 10
$buttonPanel.AutoScroll = $true
$Form.Controls.Add($buttonPanel)

$outputBox.Left = 420
$outputBox.Top = 10
$outputBox.Width = 350
$outputBox.Height = 540
$outputBox.Font = 'Consolas, 10'

$yPos = 10
foreach ($script in $taskScripts) {
    $button = New-Object System.Windows.Forms.Button
    $button.Text = $script.name
    $button.Width = 250
    $button.Height = 36
    $button.Top = $yPos
    $button.Left = 10
    $button.BackColor = [System.Drawing.Color]::FromArgb(230,240,255)
    $button.Font = 'Segoe UI, 10, style=Bold'
    $button.FlatStyle = 'Flat'
    $button.Add_Click({
        $scriptUrl = $script.download_url  
        Write-Host "Executing $($script.name)..."
        Execute-Task -scriptUrl $scriptUrl
    })
    $buttonPanel.Controls.Add($button)
    if ($taskDescriptions.ContainsKey($script.name)) {
        $descLabel = New-Object System.Windows.Forms.Label
        $descLabel.Text = $taskDescriptions[$script.name]
        $descLabel.Width = 350
        $descLabel.Top = $yPos + 6
        $descLabel.Left = 270
        $descLabel.Font = 'Segoe UI, 9'
        $descLabel.ForeColor = [System.Drawing.Color]::FromArgb(60,60,60)
        $buttonPanel.Controls.Add($descLabel)
    }
    $yPos += 46
}

$Form.BackColor = [System.Drawing.Color]::FromArgb(245, 248, 255)
$Form.Font = 'Segoe UI, 10'

$Form.ShowDialog()
