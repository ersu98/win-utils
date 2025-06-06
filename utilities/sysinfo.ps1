Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# Form setup
$form = New-Object System.Windows.Forms.Form
$form.Text = "System Info Viewer"
$form.Size = New-Object System.Drawing.Size(400, 300)
$form.StartPosition = "CenterScreen"

# Label
$label = New-Object System.Windows.Forms.Label
$label.Location = New-Object System.Drawing.Point(10, 10)
$label.Size = New-Object System.Drawing.Size(360, 200)
$label.Font = 'Consolas,10'
$label.Text = "Loading system info..."
$form.Controls.Add($label)

# Button
$button = New-Object System.Windows.Forms.Button
$button.Text = "Refresh"
$button.Location = New-Object System.Drawing.Point(150, 220)
$button.Size = New-Object System.Drawing.Size(100, 30)
$form.Controls.Add($button)

# System Info Function
function Update-SystemInfo {
    $cpu = Get-WmiObject Win32_Processor | Select-Object -ExpandProperty Name
    $os = Get-CimInstance Win32_OperatingSystem
    $ram = "{0:N2}" -f ($os.TotalVisibleMemorySize / 1MB)
    $hostname = $env:COMPUTERNAME
    $user = $env:USERNAME
    $uptime = ((Get-Date) - $os.LastBootUpTime).ToString("dd\.hh\:mm\:ss")

    $label.Text = @"
Host:     $hostname
User:     $user
CPU:      $cpu
OS:       $($os.Caption)
RAM:      $ram GB
Uptime:   $uptime
"@
}

# Event
$button.Add_Click({ Update-SystemInfo })

# Initial load
Update-SystemInfo

# Show form
[void]$form.ShowDialog()