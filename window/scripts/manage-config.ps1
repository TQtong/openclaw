<#
.SYNOPSIS
    OpenClaw Configuration Manager
.DESCRIPTION
    View and manage OpenClaw gateway configuration including credentials.
#>

Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName System.Windows.Forms

# Get script/exe directory - works for both .ps1 and compiled .exe
function Get-ScriptDirectory {
    if ($PSScriptRoot -and $PSScriptRoot -ne "") { return $PSScriptRoot }
    if ($MyInvocation.MyCommand.Path) { return Split-Path $MyInvocation.MyCommand.Path -Parent }
    $exePath = [System.Diagnostics.Process]::GetCurrentProcess().MainModule.FileName
    if ($exePath -and (Test-Path $exePath)) {
        $exeDir = Split-Path $exePath -Parent
        if ((Split-Path $exeDir -Leaf) -eq "dist") { return Join-Path (Split-Path $exeDir -Parent) "scripts" }
        $scriptsDir = Join-Path $exeDir "scripts"
        if (Test-Path $scriptsDir) { return $scriptsDir }
        return $exeDir
    }
    return (Get-Location).Path
}

$global:ScriptDir = Get-ScriptDirectory
$global:RootDir = Split-Path $global:ScriptDir -Parent

$configPath = Join-Path $env:USERPROFILE ".openclaw\openclaw.json"

# ================================================================
#  Helper Functions
# ================================================================
function Read-Config {
    if (Test-Path $configPath) {
        try {
            return Get-Content $configPath -Raw | ConvertFrom-Json
        } catch {
            return $null
        }
    }
    return $null
}

function Save-Config($cfg) {
    $json = $cfg | ConvertTo-Json -Depth 10
    $utf8NoBom = New-Object System.Text.UTF8Encoding $false
    [IO.File]::WriteAllText($configPath, $json, $utf8NoBom)
}

function Generate-Token {
    return -join ((1..48) | ForEach-Object { "{0:x2}" -f (Get-Random -Maximum 256) })
}

function Generate-Password {
    return -join ((48..57) + (65..90) + (97..122) | Get-Random -Count 12 | ForEach-Object { [char]$_ })
}

# ================================================================
#  XAML UI
# ================================================================
[xml]$xaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="OpenClaw Config Manager" Width="550" Height="680"
        WindowStartupLocation="CenterScreen" ResizeMode="CanResizeWithGrip">
  <Window.Resources>
    <Style TargetType="TextBlock" x:Key="Label">
      <Setter Property="FontSize" Value="12"/>
      <Setter Property="Foreground" Value="#333"/>
      <Setter Property="VerticalAlignment" Value="Center"/>
    </Style>
    <Style TargetType="TextBox" x:Key="ValueBox">
      <Setter Property="FontSize" Value="11"/>
      <Setter Property="FontFamily" Value="Consolas"/>
      <Setter Property="IsReadOnly" Value="True"/>
      <Setter Property="Background" Value="#F5F5F5"/>
      <Setter Property="BorderThickness" Value="1"/>
      <Setter Property="Padding" Value="4,2"/>
    </Style>
    <Style TargetType="Button" x:Key="SmallBtn">
      <Setter Property="Width" Value="55"/>
      <Setter Property="Height" Value="24"/>
      <Setter Property="FontSize" Value="11"/>
      <Setter Property="Margin" Value="4,0,0,0"/>
    </Style>
  </Window.Resources>
  <Grid Margin="20">
    <Grid.RowDefinitions>
      <RowDefinition Height="Auto"/>
      <RowDefinition Height="Auto"/>
      <RowDefinition Height="Auto"/>
      <RowDefinition Height="Auto"/>
      <RowDefinition Height="Auto"/>
      <RowDefinition Height="Auto"/>
      <RowDefinition Height="Auto"/>
      <RowDefinition Height="Auto"/>
      <RowDefinition Height="*"/>
      <RowDefinition Height="Auto"/>
    </Grid.RowDefinitions>

    <!-- Title -->
    <TextBlock Grid.Row="0" FontSize="18" FontWeight="Bold" Foreground="#00B894" Margin="0,0,0,16"
               Text="OpenClaw Configuration Manager"/>

    <!-- Config Path & Gateway -->
    <StackPanel Grid.Row="1" Margin="0,0,0,16">
      <TextBlock Style="{StaticResource Label}" FontWeight="SemiBold" Text="Config File:"/>
      <TextBlock FontSize="11" Foreground="#666" TextWrapping="Wrap" Margin="0,4,0,0"
                 Name="txtConfigPath"/>
      <TextBlock Style="{StaticResource Label}" FontWeight="SemiBold" Text="Gateway:" Margin="0,12,0,0"/>
      <TextBlock FontSize="11" Foreground="#666" Margin="0,4,0,0" Name="txtGatewayUrl"/>
    </StackPanel>

    <!-- Gateway Credentials Section -->
    <TextBlock Grid.Row="2" FontSize="14" FontWeight="SemiBold" Margin="0,0,0,10"
               Text="Gateway Credentials"/>

    <StackPanel Grid.Row="3" Margin="0,0,0,8">
      <!-- Token -->
      <Grid Margin="0,0,0,8">
        <Grid.ColumnDefinitions>
          <ColumnDefinition Width="80"/>
          <ColumnDefinition Width="*"/>
          <ColumnDefinition Width="Auto"/>
          <ColumnDefinition Width="Auto"/>
        </Grid.ColumnDefinitions>
        <TextBlock Grid.Column="0" Style="{StaticResource Label}" Text="Token:"/>
        <TextBox Grid.Column="1" Name="txtToken" Style="{StaticResource ValueBox}"/>
        <Button Grid.Column="2" Name="btnCopyToken" Content="Copy" Style="{StaticResource SmallBtn}"/>
        <Button Grid.Column="3" Name="btnRegenToken" Content="New" Style="{StaticResource SmallBtn}" ToolTip="Generate new random token"/>
      </Grid>
      <!-- Password -->
      <Grid Margin="0,0,0,8">
        <Grid.ColumnDefinitions>
          <ColumnDefinition Width="80"/>
          <ColumnDefinition Width="*"/>
          <ColumnDefinition Width="Auto"/>
          <ColumnDefinition Width="Auto"/>
        </Grid.ColumnDefinitions>
        <TextBlock Grid.Column="0" Style="{StaticResource Label}" Text="Password:"/>
        <TextBox Grid.Column="1" Name="txtPassword" Style="{StaticResource ValueBox}"/>
        <Button Grid.Column="2" Name="btnCopyPassword" Content="Copy" Style="{StaticResource SmallBtn}"/>
        <Button Grid.Column="3" Name="btnRegenPassword" Content="New" Style="{StaticResource SmallBtn}" ToolTip="Generate new random password"/>
      </Grid>
      <!-- Auth Mode -->
      <Grid Margin="0,0,0,8">
        <Grid.ColumnDefinitions>
          <ColumnDefinition Width="80"/>
          <ColumnDefinition Width="*"/>
        </Grid.ColumnDefinitions>
        <TextBlock Grid.Column="0" Style="{StaticResource Label}" Text="Auth Mode:"/>
        <ComboBox Grid.Column="1" Name="cboAuthMode" Width="120" HorizontalAlignment="Left">
          <ComboBoxItem Content="token"/>
          <ComboBoxItem Content="password"/>
          <ComboBoxItem Content="none"/>
        </ComboBox>
      </Grid>
    </StackPanel>

    <!-- Gateway Settings Section -->
    <TextBlock Grid.Row="4" FontSize="14" FontWeight="SemiBold" Margin="0,8,0,10"
               Text="Gateway Settings"/>

    <StackPanel Grid.Row="5" Margin="0,0,0,8">
      <!-- Port -->
      <Grid Margin="0,0,0,8">
        <Grid.ColumnDefinitions>
          <ColumnDefinition Width="80"/>
          <ColumnDefinition Width="100"/>
        </Grid.ColumnDefinitions>
        <TextBlock Grid.Column="0" Style="{StaticResource Label}" Text="Port:"/>
        <TextBox Grid.Column="1" Name="txtPort" FontSize="12" Padding="4,2"/>
      </Grid>
      <!-- Bind -->
      <Grid Margin="0,0,0,8">
        <Grid.ColumnDefinitions>
          <ColumnDefinition Width="80"/>
          <ColumnDefinition Width="*"/>
        </Grid.ColumnDefinitions>
        <TextBlock Grid.Column="0" Style="{StaticResource Label}" Text="Bind:"/>
        <StackPanel Grid.Column="1" Orientation="Horizontal">
          <RadioButton Name="rbLoopback" Content="Loopback (localhost)" Margin="0,0,16,0"/>
          <RadioButton Name="rbLan" Content="LAN (all interfaces)"/>
        </StackPanel>
      </Grid>
    </StackPanel>

    <!-- Save / Refresh / Close -->
    <StackPanel Grid.Row="6" Orientation="Horizontal" HorizontalAlignment="Right" Margin="0,12,0,8">
      <Button Name="btnRefresh" Content="Refresh" Width="80" Height="28" Margin="0,0,8,0"/>
      <Button Name="btnSave" Content="Save" Width="80" Height="28" Margin="0,0,8,0"/>
      <Button Name="btnClose" Content="Close" Width="80" Height="28"/>
    </StackPanel>

    <!-- Quick Commands -->
    <TextBlock Grid.Row="7" FontSize="14" FontWeight="SemiBold" Margin="0,8,0,8"
               Text="Quick Commands:"/>
    <StackPanel Grid.Row="8" Margin="0,0,0,8">
      <TextBlock FontSize="12" FontFamily="Consolas" Foreground="#555" Margin="0,0,0,4"
                 Text="openclaw gateway run     Start gateway (foreground)"/>
      <TextBlock FontSize="12" FontFamily="Consolas" Foreground="#555" Margin="0,0,0,4"
                 Text="openclaw onboard         Configure AI and channels"/>
      <TextBlock FontSize="12" FontFamily="Consolas" Foreground="#555" Margin="0,0,0,4"
                 Text="openclaw doctor          Diagnose issues"/>
      <StackPanel Orientation="Horizontal" Margin="0,12,0,0">
        <Button Name="btnStartGateway" Content="Start Gateway" Width="120" Height="28" Margin="0,0,10,0"/>
        <Button Name="btnRunOnboard" Content="Run Onboarding" Width="120" Height="28" Margin="0,0,10,0"/>
        <Button Name="btnRunDoctor" Content="Run Doctor" Width="100" Height="28"/>
      </StackPanel>
    </StackPanel>

    <!-- Status -->
    <TextBlock Grid.Row="9" Name="txtStatus" FontSize="11" Foreground="#888" VerticalAlignment="Bottom"/>

  </Grid>
</Window>
"@

$reader = New-Object System.Xml.XmlNodeReader $xaml
$window = [Windows.Markup.XamlReader]::Load($reader)

# Get controls
$txtConfigPath = $window.FindName("txtConfigPath")
$txtGatewayUrl = $window.FindName("txtGatewayUrl")
$txtToken = $window.FindName("txtToken")
$txtPassword = $window.FindName("txtPassword")
$cboAuthMode = $window.FindName("cboAuthMode")
$txtPort = $window.FindName("txtPort")
$rbLoopback = $window.FindName("rbLoopback")
$rbLan = $window.FindName("rbLan")
$txtStatus = $window.FindName("txtStatus")
$btnCopyToken = $window.FindName("btnCopyToken")
$btnCopyPassword = $window.FindName("btnCopyPassword")
$btnRegenToken = $window.FindName("btnRegenToken")
$btnRegenPassword = $window.FindName("btnRegenPassword")
$btnRefresh = $window.FindName("btnRefresh")
$btnSave = $window.FindName("btnSave")
$btnClose = $window.FindName("btnClose")
$btnStartGateway = $window.FindName("btnStartGateway")
$btnRunOnboard = $window.FindName("btnRunOnboard")
$btnRunDoctor = $window.FindName("btnRunDoctor")

$txtConfigPath.Text = $configPath

# ================================================================
#  Load Config
# ================================================================
function Update-UI {
    $cfg = Read-Config
    if ($cfg) {
        $txtToken.Text = if ($cfg.gateway.auth.token) { $cfg.gateway.auth.token } else { "(not set)" }
        $txtPassword.Text = if ($cfg.gateway.auth.password) { $cfg.gateway.auth.password } else { "(not set)" }
        
        $mode = if ($cfg.gateway.auth.mode) { $cfg.gateway.auth.mode } else { "token" }
        foreach ($item in $cboAuthMode.Items) {
            if ($item.Content -eq $mode) { $cboAuthMode.SelectedItem = $item; break }
        }
        
        $port = if ($cfg.gateway.port) { $cfg.gateway.port } else { 18789 }
        $txtPort.Text = $port.ToString()
        
        $bind = if ($cfg.gateway.bind) { $cfg.gateway.bind } else { "loopback" }
        if ($bind -eq "loopback") { $rbLoopback.IsChecked = $true } else { $rbLan.IsChecked = $true }
        
        $txtGatewayUrl.Text = "http://127.0.0.1:$port"
        $txtStatus.Text = "Config loaded: " + (Get-Date -Format "HH:mm:ss")
    } else {
        $txtToken.Text = "(config not found)"
        $txtPassword.Text = "(config not found)"
        $txtGatewayUrl.Text = "http://127.0.0.1:18789"
        $txtStatus.Text = "Config file not found"
    }
}

Update-UI

# ================================================================
#  Event Handlers
# ================================================================
function Set-CopyButtonFeedback($btn) {
    $oldContent = $btn.Content
    $btn.Content = "Copied!"
    $timer = New-Object System.Windows.Threading.DispatcherTimer
    $timer.Interval = [TimeSpan]::FromMilliseconds(1500)
    $timer.Tag = @{ Button = $btn; OldContent = $oldContent }
    $timer.Add_Tick({
        $this.Stop()
        $this.Tag.Button.Content = $this.Tag.OldContent
    })
    $timer.Start()
}

$btnCopyToken.Add_Click({
    $t = $txtToken.Text
    if ($t -and $t -notlike "(*") {
        [System.Windows.Clipboard]::SetText($t)
        $txtStatus.Text = "Token copied to clipboard"
        Set-CopyButtonFeedback $btnCopyToken
    }
})

$btnCopyPassword.Add_Click({
    $p = $txtPassword.Text
    if ($p -and $p -notlike "(*") {
        [System.Windows.Clipboard]::SetText($p)
        $txtStatus.Text = "Password copied to clipboard"
        Set-CopyButtonFeedback $btnCopyPassword
    }
})

$btnRegenToken.Add_Click({
    $txtToken.Text = Generate-Token
    $txtStatus.Text = "New random token generated - click Save to apply"
})

$btnRegenPassword.Add_Click({
    $txtPassword.Text = Generate-Password
    $txtStatus.Text = "New random password generated - click Save to apply"
})

$btnRefresh.Add_Click({
    Update-UI
})

$btnSave.Add_Click({
    $cfg = Read-Config
    if (-not $cfg) {
        $cfg = @{ gateway = @{ auth = @{} } }
    }
    
    # Ensure gateway.auth exists
    if (-not $cfg.gateway) { $cfg | Add-Member -NotePropertyName "gateway" -NotePropertyValue @{} -Force }
    if (-not $cfg.gateway.auth) { $cfg.gateway | Add-Member -NotePropertyName "auth" -NotePropertyValue @{} -Force }
    # Ensure auth has token, password, mode (PSCustomObject from JSON only has properties that were in the file)
    foreach ($key in @('token','password','mode')) {
        if (-not (Get-Member -InputObject $cfg.gateway.auth -Name $key -MemberType NoteProperty -ErrorAction SilentlyContinue)) {
            $cfg.gateway.auth | Add-Member -NotePropertyName $key -NotePropertyValue $null -Force
        }
    }
    
    # Update values
    $cfg.gateway.auth.token = $txtToken.Text
    $cfg.gateway.auth.password = $txtPassword.Text
    $cfg.gateway.auth.mode = $cboAuthMode.SelectedItem.Content
    $cfg.gateway.port = [int]$txtPort.Text
    $cfg.gateway.bind = if ($rbLoopback.IsChecked) { "loopback" } else { "lan" }
    
    # Update meta
    if (-not $cfg.meta) { $cfg | Add-Member -NotePropertyName "meta" -NotePropertyValue @{} -Force }
    $cfg.meta.lastTouchedAt = (Get-Date -Format "o")
    
    Save-Config $cfg
    $txtGatewayUrl.Text = "http://127.0.0.1:$($txtPort.Text)"
    $txtStatus.Text = "Config saved. Restart gateway to apply changes."
})

$btnClose.Add_Click({
    $window.Close()
})

$root = $global:RootDir
$openclawMjs = Join-Path $root "openclaw.mjs"

$btnStartGateway.Add_Click({
    if (Test-Path $openclawMjs) {
        Start-Process powershell -ArgumentList "-ExecutionPolicy Bypass -NoExit -Command","Set-Location '$root'; node openclaw.mjs gateway run"
        $txtStatus.Text = "Gateway starting in new window..."
    } else {
        [System.Windows.MessageBox]::Show("openclaw.mjs not found: $openclawMjs", "Error")
    }
})

$btnRunOnboard.Add_Click({
    if (Test-Path $openclawMjs) {
        Start-Process powershell -ArgumentList "-ExecutionPolicy Bypass -NoExit -Command","Set-Location '$root'; node openclaw.mjs onboard"
        $txtStatus.Text = "Onboarding started in new window..."
    } else {
        [System.Windows.MessageBox]::Show("openclaw.mjs not found: $openclawMjs", "Error")
    }
})

$btnRunDoctor.Add_Click({
    if (Test-Path $openclawMjs) {
        Start-Process powershell -ArgumentList "-ExecutionPolicy Bypass -NoExit -Command","Set-Location '$root'; node openclaw.mjs doctor"
        $txtStatus.Text = "Doctor started in new window..."
    } else {
        [System.Windows.MessageBox]::Show("openclaw.mjs not found: $openclawMjs", "Error")
    }
})

# ================================================================
#  Show Window
# ================================================================
$null = $window.ShowDialog()
