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
$outputBox.ReadOnly = $true
$outputBox.TabStop = $false
$Form.Controls.Add($outputBox)

function Test-IsAdmin {
    $currentIdentity = [System.Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object System.Security.Principal.WindowsPrincipal($currentIdentity)
    return $principal.IsInRole([System.Security.Principal.WindowsBuiltInRole]::Administrator)
}

if (-not (Test-IsAdmin)) {
    $outputBox.Text = "⚠️  The program did not start with Administrator privileges.`r`nSome utilities may fail due to missing permissions.`r`nTry running the script as Administrator."
}

function Execute-Task {
    param (
        [string]$scriptUrl
    )

    $outputBox.Clear()

    $scriptContent = Invoke-RestMethod -Uri $scriptUrl

    $tempScriptPath = [System.IO.Path]::GetTempFileName() + ".ps1"
    Set-Content -Path $tempScriptPath -Value $scriptContent

    try {
        $psi = New-Object System.Diagnostics.ProcessStartInfo
        $psi.FileName = 'powershell.exe'
        $psi.Arguments = "-NoProfile -ExecutionPolicy Bypass -Command ""& { . '$tempScriptPath' }"""
        $psi.RedirectStandardOutput = $true
        $psi.RedirectStandardError = $true
        $psi.UseShellExecute = $false
        $psi.CreateNoWindow = $true

        $proc = [System.Diagnostics.Process]::Start($psi)
        $stdout = $proc.StandardOutput.ReadToEnd()
        $stderr = $proc.StandardError.ReadToEnd()
        $proc.WaitForExit()

        if ($proc.ExitCode -eq 0) {
            $outputBox.Text = $stdout
        } else {
            $outputBox.Text = "Error: $stderr"
        }
    } catch {
        $outputBox.Text = "Error: $($_.Exception.Message)"
    } finally {
        Remove-Item -Path $tempScriptPath -Force -ErrorAction SilentlyContinue
    }
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

$buttonHeight = 32
$descSpacing = 6
$buttonSpacing = 38
$buttonCount = $taskScripts.Count
$panelHeight = [Math]::Max(200, $buttonCount * $buttonSpacing + 10)
$formHeight = $panelHeight + 180

$buttonPanel = New-Object System.Windows.Forms.Panel
$buttonPanel.Width = 760
$buttonPanel.Height = $panelHeight
$buttonPanel.Top = 10
$buttonPanel.Left = 10
$buttonPanel.AutoScroll = $false
$Form.Controls.Add($buttonPanel)

$outputBox.Left = 10
$outputBox.Top = $panelHeight + 20
$outputBox.Width = 760
$outputBox.Height = 120
$outputBox.Font = 'Consolas, 10'

function New-ClickHandler($url) {
    return {
        param($sender, $eventArgs)
        Execute-Task -scriptUrl $url
    }.GetNewClosure()
}

$yPos = 10
foreach ($script in $taskScripts) {
    $scriptUrlLocal = $script.download_url  # Capture the value for this iteration
    $button = New-Object System.Windows.Forms.Button
    $button.Text = $script.name
    $button.Width = 180
    $button.Height = $buttonHeight
    $button.Top = $yPos
    $button.Left = 10
    $button.BackColor = [System.Drawing.Color]::FromArgb(230,240,255)
    $button.Font = 'Segoe UI, 9, style=Bold'
    $button.FlatStyle = 'Flat'
    $button.Add_Click( (New-ClickHandler $scriptUrlLocal) )
    $buttonPanel.Controls.Add($button)
    if ($taskDescriptions.ContainsKey($script.name)) {
        $descLabel = New-Object System.Windows.Forms.Label
        $descLabel.Text = $taskDescriptions[$script.name]
        $descLabel.Width = 560
        $descLabel.Top = $yPos + [Math]::Round(($buttonHeight - 18)/2)
        $descLabel.Left = 200
        $descLabel.Font = 'Segoe UI, 9'
        $descLabel.ForeColor = [System.Drawing.Color]::FromArgb(60,60,60)
        $buttonPanel.Controls.Add($descLabel)
    }
    $yPos += $buttonSpacing
}

# File Menu
$menuStrip = New-Object System.Windows.Forms.MenuStrip
$fileMenu = New-Object System.Windows.Forms.ToolStripMenuItem('File')
$debugMenuItem = New-Object System.Windows.Forms.ToolStripMenuItem('Debug')

# Debug button
$debugMenuItem.Add_Click({
    [System.Windows.Forms.MessageBox]::Show(($taskScripts | Select-Object name, download_url | Out-String), "Loaded Scripts")
    [System.Windows.Forms.MessageBox]::Show(($sysInfo = Get-ComputerInfo | Out-String))
})

$fileMenu.DropDownItems.Add($debugMenuItem)
$menuStrip.Items.Add($fileMenu)
$Form.MainMenuStrip = $menuStrip
$Form.Controls.Add($menuStrip)
$menuStrip.Dock = 'Top'

# Adjust layout to account for menu height
$menuHeight = $menuStrip.Height
$buttonPanel.Top = 10 + $menuHeight
$outputBox.Top = $buttonPanel.Top + $buttonPanel.Height + 10

$Form.BackColor = [System.Drawing.Color]::FromArgb(245, 248, 255)
$Form.Font = 'Segoe UI, 10'
$Form.Width = 800
$Form.Height = $formHeight

$Form.ShowDialog()