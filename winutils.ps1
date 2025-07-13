Add-Type -AssemblyName System.Windows.Forms

$Form = New-Object System.Windows.Forms.Form
$Form.Text = "Windows Utilities"
$Form.Width = 800
$Form.Height = 600
$Form.StartPosition = "CenterScreen"
$Form.BackColor = [System.Drawing.Color]::FromArgb(30, 32, 34)
$Form.ForeColor = [System.Drawing.Color]::White

$githubRepoOwner = "ersu98"
$githubRepoName = "win-utils"
$taskFolder = "utilities"

$githubApiUrl = "https://api.github.com/repos/$githubRepoOwner/$githubRepoName/contents/$taskFolder"
$taskDescUrl = "https://raw.githubusercontent.com/$githubRepoOwner/$githubRepoName/main/$taskFolder/utilities.json"

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


$global:ExecuteTask = {
    param (
        [string]$scriptUrl
    )

    $outputBox.Clear()

    try {
        $scriptContent = Invoke-RestMethod -Uri $scriptUrl

        $tempScriptPath = [System.IO.Path]::GetTempFileName() + ".ps1"
        Set-Content -Path $tempScriptPath -Value $scriptContent

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
        $outputBox.Text = "Error downloading or executing script: $($_.Exception.Message)"
    } finally {
        if (Test-Path $tempScriptPath) {
            Remove-Item -Path $tempScriptPath -Force -ErrorAction SilentlyContinue
        }
    }
}

$taskDescriptions = @{}
$taskTooltips = @{}
try {
    $descContent = Invoke-RestMethod -Uri $taskDescUrl -Headers @{"User-Agent"="PowerShell"}
    $jsonData = $descContent | ConvertFrom-Json
    
    foreach ($item in $jsonData) {
        if ($item.PSObject.Properties['utility'] -and $item.PSObject.Properties['shortDescription']) {
            $taskDescriptions[$item.utility] = $item.shortDescription
            
            if ($item.PSObject.Properties['longDescription']) {
                $taskTooltips[$item.utility] = $item.longDescription
            }
        }
    }

} catch {
    Write-Host "Warning: Could not load task descriptions from JSON file: $($_.Exception.Message)"
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
        & $global:ExecuteTask -scriptUrl $url
    }.GetNewClosure()
}

$yPos = 10
foreach ($script in $taskScripts) {
    $scriptUrlLocal = $script.download_url
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
    
    if ($taskTooltips.ContainsKey($script.name)) {
        $tooltip = New-Object System.Windows.Forms.ToolTip
        $tooltip.SetToolTip($button, $taskTooltips[$script.name])
    }
    
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


$menuStrip = New-Object System.Windows.Forms.MenuStrip
$fileMenu = New-Object System.Windows.Forms.ToolStripMenuItem('File')
$debugMenuItem = New-Object System.Windows.Forms.ToolStripMenuItem('Debug')
$winstatusMenuItem = New-Object System.Windows.Forms.ToolStripMenuItem('Windows Activation Status')


$debugMenuItem.Add_Click({
    [System.Windows.Forms.MessageBox]::Show(($taskScripts | Select-Object name, download_url | Out-String), "Loaded Scripts & URLs")
})


$winstatusMenuItem.Add_Click({
    try {
        $os = Get-CimInstance -ClassName Win32_OperatingSystem
        $edition = $os.Caption
        $version = $os.Version
        $build = $os.BuildNumber
        $activation = (Get-CimInstance -Query "SELECT * FROM SoftwareLicensingProduct WHERE PartialProductKey IS NOT NULL AND LicenseStatus = 1").Description
        if (-not $activation) { $activation = 'Not activated' }
        $installDateRaw = (Get-CimInstance -ClassName SoftwareLicensingService).InstallDate
        $installDate = if ($installDateRaw) { [Management.ManagementDateTimeConverter]::ToDateTime($installDateRaw) } else { 'Unknown' }
        $msg = "Windows Edition: $edition`r`nVersion: $version (Build $build)`r`nActivation Status: $activation`r`nInstall Date: $installDate"
    } catch {
        $msg = "Failed to retrieve activation status: $($_.Exception.Message)"
    }
    [System.Windows.Forms.MessageBox]::Show($msg, "Windows Activation Status")
})


$fileMenu.DropDownItems.Clear()
$fileMenu.DropDownItems.Add($debugMenuItem)
$fileMenu.DropDownItems.Add($winstatusMenuItem)

$menuStrip.Items.Clear()
$menuStrip.Items.Add($fileMenu)
$Form.MainMenuStrip = $menuStrip
if (-not ($Form.Controls.Contains($menuStrip))) { $Form.Controls.Add($menuStrip) }
$menuStrip.Dock = 'Top'

$menuHeight = $menuStrip.Height
$buttonPanel.Top = 10 + $menuHeight
$outputBox.Top = $buttonPanel.Top + $buttonPanel.Height + 10

if ($Form.Controls.Contains($buttonPanel)) { $Form.Controls.Remove($buttonPanel) }

$essentialPanel = New-Object System.Windows.Forms.Panel
$essentialPanel.BackColor = [System.Drawing.Color]::FromArgb(40, 44, 52)
$essentialPanel.Width = 900
$essentialPanel.Top = 20 + $menuStrip.Height
$essentialPanel.Left = 20
$essentialPanel.BorderStyle = 'FixedSingle'
$Form.Controls.Add($essentialPanel)

$essentialHeader = New-Object System.Windows.Forms.Label
$essentialHeader.Text = 'Scripts'
$essentialHeader.Font = 'Segoe UI, 13, style=Bold'
$essentialHeader.ForeColor = [System.Drawing.Color]::DeepSkyBlue
$essentialHeader.AutoSize = $true
$essentialHeader.Top = 10
$essentialHeader.Left = 10
$essentialPanel.Controls.Add($essentialHeader)

$buttonY = 50
$buttonX = 20
$buttonW = 220
$buttonH = 48
$descX = $buttonX + $buttonW + 20
$descW = 600
$descH = $buttonH
$buttonSpacingY = 20

foreach ($script in $taskScripts) {
    $scriptUrlLocal = $script.download_url
    $button = New-Object System.Windows.Forms.Button
    $button.Text = $script.name
    $button.Width = $buttonW
    $button.Height = $buttonH
    $button.Top = $buttonY
    $button.Left = $buttonX
    $button.BackColor = [System.Drawing.Color]::FromArgb(0, 122, 204)
    $button.ForeColor = [System.Drawing.Color]::White
    $button.Font = 'Segoe UI, 12, style=Bold'
    $button.FlatStyle = 'Flat'
    $button.FlatAppearance.BorderSize = 0
    $button.Add_Click( (New-ClickHandler $scriptUrlLocal) )
    
    if ($taskTooltips.ContainsKey($script.name)) {
        $tooltip = New-Object System.Windows.Forms.ToolTip
        $tooltip.SetToolTip($button, $taskTooltips[$script.name])
    }
    
    $essentialPanel.Controls.Add($button)

    if ($taskDescriptions.ContainsKey($script.name)) {
        $descLabel = New-Object System.Windows.Forms.Label
        $descLabel.Text = $taskDescriptions[$script.name]
        $descLabel.Width = $descW
        $descLabel.Height = $descH
        $descLabel.Top = $buttonY + 12
        $descLabel.Left = $descX
        $descLabel.Font = 'Segoe UI, 11'
        $descLabel.ForeColor = [System.Drawing.Color]::LightGray
        $essentialPanel.Controls.Add($descLabel)
    }
    $buttonY += $buttonH + $buttonSpacingY
}

$essentialPanel.Height = $buttonY + 20

$outputBox.Top = $essentialPanel.Top + $essentialPanel.Height + 20
$outputBox.Left = 20
$outputBox.Width = 900
$outputBox.Height = 160
$outputBox.BackColor = [System.Drawing.Color]::FromArgb(24, 26, 28)
$outputBox.ForeColor = [System.Drawing.Color]::White
$outputBox.Font = 'Consolas, 11'

$Form.Width = 960
$Form.Height = $outputBox.Top + $outputBox.Height + 60

$Form.ShowDialog()