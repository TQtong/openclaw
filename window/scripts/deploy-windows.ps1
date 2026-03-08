# OpenClaw Windows GUI Installer
# Usage: .\scripts\deploy-windows.ps1
#   Or:  powershell -ExecutionPolicy Bypass -File scripts\deploy-windows.ps1

param([switch]$CLI)

$ErrorActionPreference = "Stop"

# Get script directory - works for both .ps1 and compiled .exe
function Get-ScriptDirectory {
    # Try PSScriptRoot first (normal ps1 execution)
    if ($PSScriptRoot -and $PSScriptRoot -ne "") {
        return $PSScriptRoot
    }
    # Try MyInvocation (older PowerShell)
    if ($MyInvocation.MyCommand.Path) {
        return Split-Path $MyInvocation.MyCommand.Path -Parent
    }
    # For compiled EXE, use the EXE's location
    $exePath = [System.Diagnostics.Process]::GetCurrentProcess().MainModule.FileName
    if ($exePath -and (Test-Path $exePath)) {
        $exeDir = Split-Path $exePath -Parent
        # If EXE is in dist folder, go up to find scripts
        if ((Split-Path $exeDir -Leaf) -eq "dist") {
            return Join-Path (Split-Path $exeDir -Parent) "scripts"
        }
        # If EXE is in root, scripts is a subfolder
        $scriptsDir = Join-Path $exeDir "scripts"
        if (Test-Path $scriptsDir) {
            return $scriptsDir
        }
        return $exeDir
    }
    # Fallback to current directory
    return (Get-Location).Path
}

$global:ScriptDir = Get-ScriptDirectory
$global:RootDir = Split-Path $global:ScriptDir -Parent

if ([Threading.Thread]::CurrentThread.GetApartmentState() -ne 'STA') {
    # For EXE, skip relaunch check since PS2EXE handles STA
    $exePath = [System.Diagnostics.Process]::GetCurrentProcess().MainModule.FileName
    if ($exePath -notlike "*.exe" -or $exePath -like "*powershell*") {
        $relaunch = "powershell -STA -ExecutionPolicy Bypass -File `"$($MyInvocation.MyCommand.Path)`""
        if ($CLI) { $relaunch += " -CLI" }
        Invoke-Expression $relaunch
        exit
    }
}

Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName PresentationCore
Add-Type -AssemblyName WindowsBase
Add-Type -AssemblyName System.Windows.Forms

# ================================================================
#  Global state hashtable — the ONLY shared variable.
#  All functions and event handlers reference $G exclusively.
#  This avoids $script: scope resolution failures in PS 5.1
#  WPF event dispatch.
# ================================================================
$global:G = @{}

# ================================================================
#  XAML
# ================================================================
[xml]$xaml = @"
<Window
    xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
    xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
    Title="OpenClaw Installer"
    Width="760" Height="530"
    WindowStartupLocation="CenterScreen"
    ResizeMode="NoResize"
    Background="#F5F5F5">

  <Window.Resources>
    <Style x:Key="SideLabel" TargetType="TextBlock">
      <Setter Property="FontSize" Value="13"/>
      <Setter Property="Foreground" Value="#556688"/>
      <Setter Property="Margin" Value="0,7,0,7"/>
    </Style>
    <Style x:Key="PageTitle" TargetType="TextBlock">
      <Setter Property="FontSize" Value="22"/>
      <Setter Property="FontWeight" Value="SemiBold"/>
      <Setter Property="Margin" Value="0,0,0,12"/>
    </Style>
    <Style x:Key="PageText" TargetType="TextBlock">
      <Setter Property="FontSize" Value="13"/>
      <Setter Property="Foreground" Value="#444444"/>
      <Setter Property="TextWrapping" Value="Wrap"/>
      <Setter Property="Margin" Value="0,0,0,8"/>
    </Style>
  </Window.Resources>

  <Grid>
    <Grid.ColumnDefinitions>
      <ColumnDefinition Width="195"/>
      <ColumnDefinition Width="*"/>
    </Grid.ColumnDefinitions>

    <!-- Sidebar -->
    <Border Grid.Column="0" Background="#1B2A4A">
      <StackPanel Margin="20,28,16,20">
        <TextBlock Text="OpenClaw" FontSize="21" FontWeight="Bold" Foreground="White"
                   Margin="0,0,0,4"/>
        <TextBlock Text="Windows Installer" FontSize="11" Foreground="#7B8FAF"
                   Margin="0,0,0,38"/>
        <TextBlock Name="sStep0" Style="{StaticResource SideLabel}" Foreground="White"
                   FontWeight="SemiBold" Text="1   Welcome"/>
        <TextBlock Name="sStep1" Style="{StaticResource SideLabel}" Text="2   Prerequisites"/>
        <TextBlock Name="sStep2" Style="{StaticResource SideLabel}" Text="3   Install Path"/>
        <TextBlock Name="sStep3" Style="{StaticResource SideLabel}" Text="4   Options"/>
        <TextBlock Name="sStep4" Style="{StaticResource SideLabel}" Text="5   Installing"/>
        <TextBlock Name="sStep5" Style="{StaticResource SideLabel}" Text="6   Complete"/>
      </StackPanel>
    </Border>

    <!-- Content -->
    <Grid Grid.Column="1">
      <Grid.RowDefinitions>
        <RowDefinition Height="*"/>
        <RowDefinition Height="56"/>
      </Grid.RowDefinitions>

      <Grid Grid.Row="0" Margin="28,22,28,0">

        <!-- Page 0: Welcome -->
        <StackPanel Name="page0">
          <TextBlock Style="{StaticResource PageTitle}" Text="Welcome to OpenClaw"/>
          <TextBlock Style="{StaticResource PageText}">
            This wizard will install OpenClaw on your Windows machine.
          </TextBlock>
          <TextBlock Style="{StaticResource PageText}">
            OpenClaw is a multi-channel AI gateway that connects your messaging
            apps (WhatsApp, Telegram, Discord, Slack, and more) to AI models.
          </TextBlock>
          <TextBlock Style="{StaticResource PageText}" Margin="0,8,0,0"
                     Text="The installer will:"/>
          <TextBlock Style="{StaticResource PageText}" Margin="16,2,0,2"
                     Text="- Check and install prerequisites (Node.js, Git, pnpm)"/>
          <TextBlock Style="{StaticResource PageText}" Margin="16,2,0,2"
                     Text="- Install dependencies and build the project"/>
          <TextBlock Style="{StaticResource PageText}" Margin="16,2,0,2"
                     Text="- Create CLI and gateway management scripts"/>
          <TextBlock Style="{StaticResource PageText}" Margin="16,2,0,2"
                     Text="- Optionally set up auto-start on login"/>
          <TextBlock FontSize="12" Foreground="#999" Margin="0,22,0,0"
                     Text="Click Next to begin."/>
        </StackPanel>

        <!-- Page 1: Prerequisites -->
        <StackPanel Name="page1" Visibility="Collapsed">
          <TextBlock Style="{StaticResource PageTitle}" Text="Prerequisites"/>
          <TextBlock Style="{StaticResource PageText}" Margin="0,0,0,16"
                     Text="Checking required software on your system."/>
          <Border BorderBrush="#E0E0E0" BorderThickness="0,0,0,1" Padding="0,8">
            <Grid><Grid.ColumnDefinitions>
              <ColumnDefinition Width="28"/><ColumnDefinition Width="*"/>
              <ColumnDefinition Width="Auto"/>
            </Grid.ColumnDefinitions>
              <TextBlock Name="nodeIcon" Grid.Column="0" FontSize="15" VerticalAlignment="Center" Text="..."/>
              <TextBlock Grid.Column="1" FontSize="13" VerticalAlignment="Center" Text="Node.js (v22+)"/>
              <TextBlock Name="nodeInfo" Grid.Column="2" FontSize="12" Foreground="#888" VerticalAlignment="Center"/>
            </Grid>
          </Border>
          <Border BorderBrush="#E0E0E0" BorderThickness="0,0,0,1" Padding="0,8">
            <Grid><Grid.ColumnDefinitions>
              <ColumnDefinition Width="28"/><ColumnDefinition Width="*"/>
              <ColumnDefinition Width="Auto"/>
            </Grid.ColumnDefinitions>
              <TextBlock Name="gitIcon" Grid.Column="0" FontSize="15" VerticalAlignment="Center" Text="..."/>
              <TextBlock Grid.Column="1" FontSize="13" VerticalAlignment="Center" Text="Git"/>
              <TextBlock Name="gitInfo" Grid.Column="2" FontSize="12" Foreground="#888" VerticalAlignment="Center"/>
            </Grid>
          </Border>
          <Border BorderBrush="#E0E0E0" BorderThickness="0,0,0,1" Padding="0,8">
            <Grid><Grid.ColumnDefinitions>
              <ColumnDefinition Width="28"/><ColumnDefinition Width="*"/>
              <ColumnDefinition Width="Auto"/>
            </Grid.ColumnDefinitions>
              <TextBlock Name="pnpmIcon" Grid.Column="0" FontSize="15" VerticalAlignment="Center" Text="..."/>
              <TextBlock Grid.Column="1" FontSize="13" VerticalAlignment="Center" Text="pnpm"/>
              <TextBlock Name="pnpmInfo" Grid.Column="2" FontSize="12" Foreground="#888" VerticalAlignment="Center"/>
            </Grid>
          </Border>
          <StackPanel Orientation="Horizontal" Margin="0,16,0,0">
            <Button Name="btnRecheck" Content="Recheck" Width="90" Height="28" Margin="0,0,10,0"/>
            <Button Name="btnInstallMissing" Content="Auto-Install Missing" Width="150" Height="28" Visibility="Collapsed"/>
          </StackPanel>
          <TextBlock Name="prereqMsg" FontSize="12" Foreground="#CC3333" TextWrapping="Wrap" Margin="0,10,0,0"/>
        </StackPanel>

        <!-- Page 2: Install Path -->
        <StackPanel Name="page2" Visibility="Collapsed">
          <TextBlock Style="{StaticResource PageTitle}" Text="Install Location"/>
          <TextBlock Style="{StaticResource PageText}" Margin="0,0,0,10"
                     Text="Choose the source of the OpenClaw project code."/>
          <TextBlock FontSize="13" FontWeight="SemiBold" Margin="0,0,0,6" Text="Code Source:"/>
          <RadioButton Name="rbSourceLocal" FontSize="13" Margin="16,0,0,4"
                       Content="Use local project (no network required)"/>
          <TextBlock Name="localSourceInfo" FontSize="11" Foreground="#666" Margin="36,0,0,6"
                     Text="Detected: (none)"/>
          <RadioButton Name="rbSourceGitHub" FontSize="13" Margin="16,0,0,4"
                       Content="Clone from GitHub (may require VPN in China)"/>
          <RadioButton Name="rbSourceMirror" FontSize="13" Margin="16,0,0,10" IsChecked="True"
                       Content="Clone from GitHub Mirror (ghproxy.com, China-friendly)"/>
          <TextBlock FontSize="13" Margin="0,8,0,5" Text="Installation path:"/>
          <Grid><Grid.ColumnDefinitions>
            <ColumnDefinition Width="*"/><ColumnDefinition Width="90"/>
          </Grid.ColumnDefinitions>
            <TextBox Name="txtPath" Grid.Column="0" Height="28" FontSize="12"
                     VerticalContentAlignment="Center" Padding="6,0"/>
            <Button Name="btnBrowse" Grid.Column="1" Content="Browse..." Height="28" Margin="8,0,0,0"/>
          </Grid>
          <TextBlock Name="pathInfo" FontSize="12" Foreground="#888" TextWrapping="Wrap" Margin="0,10,0,0"/>
        </StackPanel>

        <!-- Page 3: Options -->
        <StackPanel Name="page3" Visibility="Collapsed">
          <TextBlock Style="{StaticResource PageTitle}" Text="Configuration"/>
          <TextBlock Style="{StaticResource PageText}" Margin="0,0,0,14"
                     Text="Configure the gateway and installation options."/>
          <Grid Margin="0,0,0,14"><Grid.ColumnDefinitions>
            <ColumnDefinition Width="130"/><ColumnDefinition Width="*"/>
          </Grid.ColumnDefinitions>
            <TextBlock Text="Gateway Port:" FontSize="13" VerticalAlignment="Center"/>
            <TextBox Name="txtPort" Grid.Column="1" Width="100" Height="26" FontSize="12"
                     HorizontalAlignment="Left" VerticalContentAlignment="Center" Padding="6,0" Text="18789"/>
          </Grid>
          <TextBlock Text="Gateway Bind Mode:" FontSize="13" Margin="0,0,0,6"/>
          <RadioButton Name="rbLoopback" FontSize="13" Margin="16,0,0,5" IsChecked="True"
                       Content="Localhost only (most secure, recommended)"/>
          <RadioButton Name="rbLan" FontSize="13" Margin="16,0,0,16"
                       Content="LAN access (needed for remote connections)"/>
          <CheckBox Name="chkAutoStart" FontSize="13" Margin="0,0,0,8" IsChecked="True"
                    Content="Auto-start gateway on login"/>
          <CheckBox Name="chkSkipBuild" FontSize="13" Margin="0,0,0,8"
                    Content="Skip build (use existing dist/ output)"/>
        </StackPanel>

        <!-- Page 4: Installing -->
        <Grid Name="page4" Visibility="Collapsed">
          <Grid.RowDefinitions>
            <RowDefinition Height="Auto"/><RowDefinition Height="Auto"/>
            <RowDefinition Height="Auto"/><RowDefinition Height="10"/>
            <RowDefinition Height="*"/>
          </Grid.RowDefinitions>
          <TextBlock Grid.Row="0" Style="{StaticResource PageTitle}" Text="Installing..."/>
          <TextBlock Name="installStatus" Grid.Row="1" FontSize="13" Foreground="#444"
                     Text="Preparing..." Margin="0,0,0,10"/>
          <ProgressBar Name="installProgress" Grid.Row="2" Height="20" Minimum="0" Maximum="100" Value="0"/>
          <TextBox Name="installLog" Grid.Row="4" IsReadOnly="True"
                   VerticalScrollBarVisibility="Auto" HorizontalScrollBarVisibility="Auto"
                   FontFamily="Consolas" FontSize="11" Background="#1E1E1E" Foreground="#CCCCCC"
                   TextWrapping="NoWrap" AcceptsReturn="True" BorderThickness="1" BorderBrush="#333"/>
        </Grid>

        <!-- Page 5: Complete -->
        <StackPanel Name="page5" Visibility="Collapsed">
          <TextBlock Name="completeTitle" Style="{StaticResource PageTitle}" Foreground="#00B894"
                     Text="Installation Complete!"/>
          <TextBlock Name="completeSummary" Style="{StaticResource PageText}" Margin="0,0,0,16"/>
          <StackPanel Margin="0,0,0,12">
            <TextBlock FontSize="13" FontWeight="SemiBold" Margin="0,0,0,8" Text="Gateway Credentials:"/>
            <TextBlock FontSize="11" Foreground="#666" Margin="8,0,0,4"
                       Text="Token and password are required to access the gateway UI."/>
            <Button Name="btnOpenConfigManager" Content="Open Config Manager" Width="150" Height="26" 
                    HorizontalAlignment="Left" Margin="8,8,0,0" FontSize="11"/>
          </StackPanel>
        </StackPanel>
      </Grid>

      <!-- Navigation -->
      <Border Grid.Row="1" BorderThickness="0,1,0,0" BorderBrush="#DDD" Background="#FAFAFA">
        <Grid Margin="20,0">
          <Button Name="btnCancel" Content="Cancel" Width="85" Height="30"
                  HorizontalAlignment="Left" VerticalAlignment="Center"/>
          <StackPanel Orientation="Horizontal" HorizontalAlignment="Right" VerticalAlignment="Center">
            <Button Name="btnBack" Content="Back" Width="85" Height="30" Margin="0,0,10,0" IsEnabled="False"/>
            <Button Name="btnNext" Content="Next" Width="85" Height="30"
                    Background="#FF4D4D" Foreground="White" FontWeight="SemiBold"/>
          </StackPanel>
        </Grid>
      </Border>
    </Grid>
  </Grid>
</Window>
"@

# ================================================================
#  Window + Element Refs -> $G hashtable
# ================================================================
$reader = New-Object System.Xml.XmlNodeReader $xaml
$G.Window = [Windows.Markup.XamlReader]::Load($reader)

$elNames = @(
    'sStep0','sStep1','sStep2','sStep3','sStep4','sStep5',
    'page0','page1','page2','page3','page4','page5',
    'btnNext','btnBack','btnCancel',
    'nodeIcon','nodeInfo','gitIcon','gitInfo','pnpmIcon','pnpmInfo',
    'btnRecheck','btnInstallMissing','prereqMsg',
    'rbSourceLocal','rbSourceGitHub','rbSourceMirror','localSourceInfo',
    'txtPath','btnBrowse','pathInfo',
    'txtPort','rbLoopback','rbLan','chkAutoStart','chkSkipBuild',
    'installStatus','installProgress','installLog',
    'completeTitle','completeSummary','btnOpenConfigManager'
)
foreach ($n in $elNames) { $G[$n] = $G.Window.FindName($n) }

$G.Pages  = @($G.page0, $G.page1, $G.page2, $G.page3, $G.page4, $G.page5)
$G.Steps  = @($G.sStep0,$G.sStep1,$G.sStep2,$G.sStep3,$G.sStep4,$G.sStep5)
$G.CurPage   = 0
$G.PrereqOK  = $false
$G.InstState = [hashtable]::Synchronized(@{
    Progress = 0; Status = ""; Error = ""
    LogLines = [System.Collections.ArrayList]::new()
    LogIdx = 0; Done = $false; Success = $false
})

# ================================================================
#  Navigation
# ================================================================
function Show-Page([int]$idx) {
    $grey = New-Object Windows.Media.SolidColorBrush ([Windows.Media.Color]::FromRgb(85,102,136))
    for ($i = 0; $i -lt $G.Pages.Count; $i++) {
        if ($null -eq $G.Pages[$i]) { continue }
        $G.Pages[$i].Visibility = if ($i -eq $idx) { "Visible" } else { "Collapsed" }
        if ($null -eq $G.Steps[$i]) { continue }
        if ($i -lt $idx)     { $G.Steps[$i].Foreground = [Windows.Media.Brushes]::LightGreen; $G.Steps[$i].FontWeight = "Normal" }
        elseif ($i -eq $idx) { $G.Steps[$i].Foreground = [Windows.Media.Brushes]::White;      $G.Steps[$i].FontWeight = "SemiBold" }
        else                 { $G.Steps[$i].Foreground = $grey;                                $G.Steps[$i].FontWeight = "Normal" }
    }
    $G.CurPage = $idx
    $G.btnBack.IsEnabled   = ($idx -gt 0 -and $idx -lt 4)
    $G.btnCancel.Visibility = if ($idx -ge 5) { "Collapsed" } else { "Visible" }

    switch ($idx) {
        0 { $G.btnNext.Content = "Next";    $G.btnNext.IsEnabled = $true }
        1 { $G.btnNext.Content = "Next";    $G.btnNext.IsEnabled = $G.PrereqOK; Run-PrereqCheck }
        2 { $G.btnNext.Content = "Next";    $G.btnNext.IsEnabled = $true; Update-PathInfo }
        3 { $G.btnNext.Content = "Install"; $G.btnNext.IsEnabled = $true }
        4 { $G.btnNext.Content = "...";     $G.btnNext.IsEnabled = $false; $G.btnBack.IsEnabled = $false; $G.btnCancel.IsEnabled = $false }
        5 { $G.btnNext.Content = "Finish";  $G.btnNext.IsEnabled = $true;  $G.btnBack.IsEnabled = $false }
    }
}

# ================================================================
#  Prerequisites
# ================================================================
function Set-PrereqRow($icon, $info, [bool]$ok, [string]$detail) {
    if ($ok) {
        $icon.Text = [string][char]0x2713
        $icon.Foreground = [Windows.Media.Brushes]::Green
        $info.Text = $detail
        $info.Foreground = [Windows.Media.Brushes]::Green
    } else {
        $icon.Text = [string][char]0x2717
        $icon.Foreground = [Windows.Media.Brushes]::Red
        $info.Text = $detail
        $info.Foreground = [Windows.Media.Brushes]::Red
    }
}

function Run-PrereqCheck {
    $allOK = $true; $missing = @()
    try {
        $nv = (node --version 2>$null)
        $major = [int](($nv -replace '^v','') -split '\.')[0]
        if ($major -ge 22) { Set-PrereqRow $G.nodeIcon $G.nodeInfo $true $nv }
        else { Set-PrereqRow $G.nodeIcon $G.nodeInfo $false "v$nv (need v22+)"; $allOK = $false; $missing += "Node.js 22+" }
    } catch { Set-PrereqRow $G.nodeIcon $G.nodeInfo $false "Not found"; $allOK = $false; $missing += "Node.js 22+" }

    try {
        $gv = (git --version 2>$null)
        if ($gv) { Set-PrereqRow $G.gitIcon $G.gitInfo $true $gv } else { throw "x" }
    } catch { Set-PrereqRow $G.gitIcon $G.gitInfo $false "Not found"; $allOK = $false; $missing += "Git" }

    try {
        $pv = (pnpm --version 2>$null)
        if ($pv) { Set-PrereqRow $G.pnpmIcon $G.pnpmInfo $true "v$pv" } else { throw "x" }
    } catch { Set-PrereqRow $G.pnpmIcon $G.pnpmInfo $false "Not found"; $allOK = $false; $missing += "pnpm" }

    $G.PrereqOK = $allOK
    $G.btnNext.IsEnabled = $allOK
    if ($allOK) {
        $G.prereqMsg.Foreground = [Windows.Media.Brushes]::Green
        $G.prereqMsg.Text = "All prerequisites installed."
        $G.btnInstallMissing.Visibility = "Collapsed"
    } else {
        $G.prereqMsg.Foreground = [Windows.Media.Brushes]::Red
        $G.prereqMsg.Text = "Missing: " + ($missing -join ", ") + ". Install them and click Recheck."
        $G.btnInstallMissing.Visibility = "Visible"
    }
}

function Install-MissingPrereqs {
    $G.btnInstallMissing.IsEnabled = $false
    $G.prereqMsg.Text = "Installing... please wait."
    [System.Windows.Forms.Application]::DoEvents()
    $refresh = { $env:Path = [Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [Environment]::GetEnvironmentVariable("Path","User") }
    try { $nv = node --version 2>$null } catch { $nv = $null }
    if (-not $nv -or ([int](($nv -replace '^v','') -split '\.')[0]) -lt 22) {
        if (Get-Command winget -EA SilentlyContinue) { winget install OpenJS.NodeJS.LTS --accept-package-agreements --accept-source-agreements 2>&1 | Out-Null; & $refresh }
        elseif (Get-Command choco -EA SilentlyContinue) { choco install nodejs-lts -y 2>&1 | Out-Null; & $refresh }
    }
    if (-not (Get-Command git -EA SilentlyContinue)) {
        if (Get-Command winget -EA SilentlyContinue) { winget install Git.Git --accept-package-agreements --accept-source-agreements 2>&1 | Out-Null; & $refresh }
    }
    if (-not (Get-Command pnpm -EA SilentlyContinue)) {
        try { corepack enable 2>&1; corepack prepare pnpm@latest --activate 2>&1; & $refresh } catch {}
        if (-not (Get-Command pnpm -EA SilentlyContinue)) { try { npm install -g pnpm 2>&1; & $refresh } catch {} }
    }
    $G.btnInstallMissing.IsEnabled = $true
    Run-PrereqCheck
}

# ================================================================
#  Path Detection & Source Selection
# ================================================================
$G.DetectedLocalPath = $null
$G.DetectedLocalVersion = $null
$G.DetectedZipPath = $null

function Detect-ProjectRoot {
    # Check directories for extracted project
    foreach ($dir in @($global:ScriptDir, $global:RootDir, (Get-Location).Path)) {
        if (-not $dir) { continue }
        $pkg = Join-Path $dir "package.json"
        if (Test-Path $pkg) {
            try {
                $j = Get-Content $pkg -Raw | ConvertFrom-Json
                if ($j.name -eq "openclaw") {
                    $G.DetectedLocalPath = $dir
                    $G.DetectedLocalVersion = $j.version
                    return $dir
                }
            } catch {}
        }
        # Also check for openclaw-main subfolder (common after extracting zip)
        $subdir = Join-Path $dir "openclaw-main"
        $subpkg = Join-Path $subdir "package.json"
        if (Test-Path $subpkg) {
            try {
                $j = Get-Content $subpkg -Raw | ConvertFrom-Json
                if ($j.name -eq "openclaw") {
                    $G.DetectedLocalPath = $subdir
                    $G.DetectedLocalVersion = $j.version
                    return $subdir
                }
            } catch {}
        }
    }
    # Check for zip files if no extracted project found
    if (-not $G.DetectedLocalPath) {
        foreach ($dir in @($global:ScriptDir, $global:RootDir, (Get-Location).Path)) {
            if (-not $dir) { continue }
            foreach ($zipName in @("openclaw-main.zip", "openclaw.zip", "openclaw-master.zip")) {
                $zipPath = Join-Path $dir $zipName
                if (Test-Path $zipPath) {
                    $G.DetectedZipPath = $zipPath
                    $G.DetectedLocalVersion = "zip"
                    return (Join-Path $dir "openclaw")
                }
            }
        }
    }
    return (Join-Path $env:USERPROFILE "openclaw")
}

function Update-SourceSelection {
    if ($G.DetectedLocalPath) {
        $G.rbSourceLocal.IsEnabled = $true
        $G.rbSourceLocal.IsChecked = $true
        $G.localSourceInfo.Text = "Detected: $($G.DetectedLocalPath) (v$($G.DetectedLocalVersion))"
        $G.localSourceInfo.Foreground = [Windows.Media.Brushes]::Green
    } elseif ($G.DetectedZipPath) {
        $G.rbSourceLocal.IsEnabled = $true
        $G.rbSourceLocal.IsChecked = $true
        $G.localSourceInfo.Text = "Detected ZIP: $($G.DetectedZipPath) (will auto-extract)"
        $G.localSourceInfo.Foreground = [Windows.Media.Brushes]::Blue
    } else {
        $G.rbSourceLocal.IsEnabled = $false
        $G.rbSourceMirror.IsChecked = $true
        $G.localSourceInfo.Text = "No local project found. Will clone from network."
        $G.localSourceInfo.Foreground = New-Object Windows.Media.SolidColorBrush ([Windows.Media.Color]::FromRgb(150,150,150))
    }
}

function Update-PathInfo {
    $p = $G.txtPath.Text
    if (-not $p) { $G.pathInfo.Text = "Enter or browse to an installation path."; return }
    $pkg = Join-Path $p "package.json"
    if (Test-Path $pkg) {
        try {
            $j = Get-Content $pkg -Raw | ConvertFrom-Json
            if ($j.name -eq "openclaw") {
                $G.pathInfo.Foreground = [Windows.Media.Brushes]::Green
                $G.pathInfo.Text = "Existing OpenClaw project detected (v$($j.version)). No clone needed."
                return
            }
        } catch {}
    }
    # Determine source type for messaging
    $srcType = if ($G.rbSourceLocal.IsChecked) { "local" }
               elseif ($G.rbSourceGitHub.IsChecked) { "github" }
               else { "mirror" }
    if ($srcType -eq "local" -and -not $G.DetectedLocalPath -and -not $G.DetectedZipPath) {
        $G.pathInfo.Foreground = New-Object Windows.Media.SolidColorBrush ([Windows.Media.Color]::FromRgb(200,100,0))
        $G.pathInfo.Text = "No local project detected. Select a different source or browse to project."
        return
    }
    if ($srcType -eq "local" -and $G.DetectedZipPath) {
        $G.pathInfo.Foreground = [Windows.Media.Brushes]::Blue
        $G.pathInfo.Text = "Will extract ZIP to this location and install."
        return
    }
    if (Test-Path $p) {
        $G.pathInfo.Foreground = New-Object Windows.Media.SolidColorBrush ([Windows.Media.Color]::FromRgb(180,120,0))
        if ($srcType -eq "mirror") {
            $G.pathInfo.Text = "Directory exists. Will clone via GitHub Mirror (ghproxy.com)."
        } elseif ($srcType -eq "github") {
            $G.pathInfo.Text = "Directory exists. Will clone from GitHub (may need VPN)."
        } else {
            $G.pathInfo.Text = "Directory exists."
        }
    } else {
        $G.pathInfo.Foreground = New-Object Windows.Media.SolidColorBrush ([Windows.Media.Color]::FromRgb(100,100,100))
        if ($srcType -eq "mirror") {
            $G.pathInfo.Text = "Directory will be created. Clone via GitHub Mirror (ghproxy.com)."
        } elseif ($srcType -eq "github") {
            $G.pathInfo.Text = "Directory will be created. Clone from GitHub (may need VPN)."
        } else {
            $G.pathInfo.Text = "Directory will be created."
        }
    }
}

$G.txtPath.Text = Detect-ProjectRoot
Update-SourceSelection

# Update path text when source selection changes
$G.rbSourceLocal.Add_Checked({
    if ($G.DetectedLocalPath) {
        $G.txtPath.Text = $G.DetectedLocalPath
        Update-PathInfo
    } elseif ($G.DetectedZipPath) {
        # Set path to parent of zip file + openclaw folder
        $zipDir = Split-Path $G.DetectedZipPath -Parent
        $G.txtPath.Text = Join-Path $zipDir "openclaw"
        Update-PathInfo
    }
})
$G.rbSourceGitHub.Add_Checked({ Update-PathInfo })
$G.rbSourceMirror.Add_Checked({ Update-PathInfo })

# ================================================================
#  Installation (background runspace)
# ================================================================
function Start-Installation {
    $st = $G.InstState
    $st.Progress = 0; $st.Status = "Starting..."; $st.Error = ""; $st.Done = $false; $st.Success = $false
    $st.LogLines.Clear(); $st.LogIdx = 0
    $G.installLog.Text = ""

    # Determine source type
    $sourceType = if ($G.rbSourceLocal.IsChecked) { "local" }
                  elseif ($G.rbSourceGitHub.IsChecked) { "github" }
                  else { "mirror" }
    $installerRoot = $global:RootDir
    $cfg = @{
        InstallPath = $G.txtPath.Text; Port = $G.txtPort.Text
        Bind = $(if ($G.rbLoopback.IsChecked) {"loopback"} else {"lan"})
        AutoStart = [bool]$G.chkAutoStart.IsChecked
        SkipBuild = [bool]$G.chkSkipBuild.IsChecked
        SysPath = $env:Path; UserProfile = $env:USERPROFILE
        SourceType = $sourceType
        ZipPath = $G.DetectedZipPath
        InstallerRoot = $installerRoot
    }

    $rs = [runspacefactory]::CreateRunspace()
    $rs.ApartmentState = "STA"; $rs.Open()
    $rs.SessionStateProxy.SetVariable("state", $st)
    $rs.SessionStateProxy.SetVariable("cfg", $cfg)

    $ps = [powershell]::Create(); $ps.Runspace = $rs
    $null = $ps.AddScript({
        $env:Path = $cfg.SysPath
        function Log($m)          { $null = $state.LogLines.Add($m) }
        function Status($m, $pct) { $state.Status = $m; if ($null -ne $pct) { $state.Progress = $pct }; Log("[STEP] $m") }
        function Exec($label, $cmd, $dir) {
            Log("  > $cmd")
            $psi = New-Object System.Diagnostics.ProcessStartInfo
            $psi.FileName = "cmd.exe"; $psi.Arguments = "/c $cmd"
            $psi.WorkingDirectory = $dir; $psi.UseShellExecute = $false
            $psi.RedirectStandardOutput = $true; $psi.RedirectStandardError = $true; $psi.CreateNoWindow = $true
            # Pass modified PATH to child process (Git Bash before WSL)
            $psi.EnvironmentVariables["Path"] = $env:Path
            $proc = [System.Diagnostics.Process]::Start($psi)
            $stdout = $proc.StandardOutput.ReadToEnd(); $stderr = $proc.StandardError.ReadToEnd()
            $proc.WaitForExit()
            if ($stdout.Trim()) { foreach ($l in ($stdout -split "`n" | Select-Object -Last 10)) { $t=$l.Trim(); if($t){Log("  $t")} } }
            if ($proc.ExitCode -ne 0) { if ($stderr.Trim()) { Log("  [err] $($stderr.Substring(0,[Math]::Min($stderr.Length,300)).Trim())") }; throw "$label failed (exit $($proc.ExitCode))" }
        }
        try {
            $root = $cfg.InstallPath

            # On Windows, ensure Git Bash is in PATH before WSL bash.
            # The build script (canvas:a2ui:bundle) requires real bash, not WSL.
            $gitCmd = Get-Command git -ErrorAction SilentlyContinue
            if ($gitCmd) {
                $gitDir = Split-Path (Split-Path $gitCmd.Source -Parent) -Parent
                $gitBash = Join-Path $gitDir "bin"
                if (Test-Path (Join-Path $gitBash "bash.exe")) {
                    $env:Path = "$gitBash;$($env:Path)"
                    Log("  Git Bash added to PATH: $gitBash")
                }
            }

            Status "Checking project source..." 2
            $hasPkg = Test-Path (Join-Path $root "package.json")
            if (-not $hasPkg) {
                if (-not (Test-Path $root)) { New-Item -ItemType Directory -Path $root -Force | Out-Null }
                if ($cfg.SourceType -eq "local") {
                    # Check if we have a zip file to extract
                    if ($cfg.ZipPath -and (Test-Path $cfg.ZipPath)) {
                        Status "Extracting ZIP file..." 3
                        Log("  Extracting: $($cfg.ZipPath)")
                        $tempExtract = Join-Path ([System.IO.Path]::GetTempPath()) "openclaw-extract-$([guid]::NewGuid().ToString().Substring(0,8))"
                        Expand-Archive -Path $cfg.ZipPath -DestinationPath $tempExtract -Force
                        # Find the extracted folder (usually openclaw-main or openclaw-master)
                        $extracted = Get-ChildItem -Path $tempExtract -Directory | Select-Object -First 1
                        if ($extracted -and (Test-Path (Join-Path $extracted.FullName "package.json"))) {
                            # Move contents to target directory
                            if (Test-Path $root) { Remove-Item $root -Recurse -Force }
                            Move-Item -Path $extracted.FullName -Destination $root -Force
                            Log("  Extracted to: $root")
                        } else {
                            Remove-Item $tempExtract -Recurse -Force -EA SilentlyContinue
                            throw "ZIP file does not contain a valid OpenClaw project"
                        }
                        Remove-Item $tempExtract -Recurse -Force -EA SilentlyContinue
                    } else {
                        throw "Local source selected but no project found at $root"
                    }
                } else {
                    # Clone from network (mirror or github)
                    $cloneUrl = if ($cfg.SourceType -eq "mirror") {
                        "https://ghproxy.com/https://github.com/openclaw/openclaw.git"
                    } else {
                        "https://github.com/openclaw/openclaw.git"
                    }
                    $srcLabel = if ($cfg.SourceType -eq "mirror") { "GitHub Mirror (ghproxy.com)" } else { "GitHub" }
                    Status "Cloning from $srcLabel..." 3
                    Log("  Source: $srcLabel")
                    Log("  URL: $cloneUrl")
                    Exec "Git clone" "git clone `"$cloneUrl`" `"$root`"" $cfg.UserProfile
                }
            } else {
                Log("  Using existing local project.")
            }
            Log("  Source ready."); $state.Progress = 6
            Status "Creating config directories..." 7
            $oc = Join-Path $cfg.UserProfile ".openclaw"
            foreach ($sd in @("logs","identity","agents\main\agent","agents\main\sessions","workspace","bin")) {
                $d = Join-Path $oc $sd; if (-not (Test-Path $d)) { New-Item -ItemType Directory -Path $d -Force | Out-Null }
            }
            if (-not $cfg.SkipBuild) {
                # Fix prepare script for Windows (avoid garbled output from Unix commands)
                $pkgPath = Join-Path $root "package.json"
                if (Test-Path $pkgPath) {
                    $pkgContent = [IO.File]::ReadAllText($pkgPath, [Text.Encoding]::UTF8)
                    # Remove BOM if present
                    $pkgContent = $pkgContent.TrimStart([char]0xFEFF)
                    $oldPrepare = '"prepare": "command -v git >/dev/null 2>&1 && git rev-parse --is-inside-work-tree >/dev/null 2>&1 && git config core.hooksPath git-hooks || exit 0"'
                    $newPrepare = '"prepare": "exit 0"'
                    if ($pkgContent.Contains($oldPrepare)) {
                        $pkgContent = $pkgContent.Replace($oldPrepare, $newPrepare)
                        # Write without BOM
                        $utf8NoBom = New-Object System.Text.UTF8Encoding $false
                        [IO.File]::WriteAllText($pkgPath, $pkgContent, $utf8NoBom)
                        Log("  Fixed prepare script for Windows compatibility.")
                    }
                }
                Status "Installing dependencies (several minutes)..." 10
                # Configure pnpm store to be inside project directory (avoid polluting drive root)
                $npmrcPath = Join-Path $root ".npmrc"
                $storeDir = Join-Path $root ".pnpm-store"
                $npmrcContent = "store-dir=$storeDir`n"
                if (Test-Path $npmrcPath) {
                    $existing = [IO.File]::ReadAllText($npmrcPath)
                    if ($existing -notmatch "store-dir") {
                        $npmrcContent = $existing.TrimEnd() + "`nstore-dir=$storeDir`n"
                        [IO.File]::WriteAllText($npmrcPath, $npmrcContent)
                        Log("  Configured pnpm store: $storeDir")
                    }
                } else {
                    [IO.File]::WriteAllText($npmrcPath, $npmrcContent)
                    Log("  Configured pnpm store: $storeDir")
                }
                # Use npmmirror.com registry for faster downloads in China when using mirror source
                $pnpmCmd = if ($cfg.SourceType -eq "mirror") {
                    Log("  Using npmmirror.com registry for faster downloads...")
                    "pnpm install --registry=https://registry.npmmirror.com"
                } else { "pnpm install" }
                Exec "pnpm install" $pnpmCmd $root; $state.Progress = 40; Log("  Deps installed.")
                Status "Building project..." 42
                Exec "pnpm build" "pnpm build" $root; $state.Progress = 70; Log("  Built.")
                Status "Building UI..." 72
                Exec "pnpm ui:build" "pnpm ui:build" $root; $state.Progress = 85; Log("  UI built.")
            } else { Status "Skipping build..." 85; Log("  Build skipped.") }
            Status "Creating CLI wrapper..." 87
            $bin = Join-Path $cfg.UserProfile ".openclaw\bin"
            [IO.File]::WriteAllText((Join-Path $bin "openclaw.cmd"), "@echo off`r`nnode `"$root\openclaw.mjs`" %*")
            [IO.File]::WriteAllText((Join-Path $bin "openclaw.ps1"), "& node `"$root\openclaw.mjs`" @args")
            $up = [Environment]::GetEnvironmentVariable("Path","User")
            if ($up -notlike "*$bin*") { [Environment]::SetEnvironmentVariable("Path","$up;$bin","User"); Log("  Added $bin to PATH.") }
            Log("  CLI wrapper created.")
            # Create initial openclaw.json with gateway auth so complete page can show token/password
            $cfgPath = Join-Path $cfg.UserProfile ".openclaw\openclaw.json"
            if (-not (Test-Path $cfgPath)) {
                $gwToken = -join ((1..48) | ForEach-Object { "{0:x2}" -f (Get-Random -Maximum 256) })
                $gwPassword = -join ((48..57) + (65..90) + (97..122) | Get-Random -Count 12 | ForEach-Object { [char]$_ })
                $initialConfig = @{
                    meta = @{ lastTouchedVersion = "deploy"; lastTouchedAt = (Get-Date -Format "o") }
                    gateway = @{
                        port = [int]$cfg.Port
                        mode = "local"
                        bind = $cfg.Bind
                        auth = @{ mode = "token"; token = $gwToken; password = $gwPassword }
                        tailscale = @{ mode = "off"; resetOnExit = $false }
                        nodes = @{ denyCommands = @() }
                    }
                }
                $json = $initialConfig | ConvertTo-Json -Depth 10
                $utf8NoBom = New-Object System.Text.UTF8Encoding $false
                [IO.File]::WriteAllText($cfgPath, $json, $utf8NoBom)
                Log("  Initial config created with gateway token and password.")
            }
            Status "Creating helper scripts..." 90
            $wd = Join-Path $root "scripts\windows"
            if (-not (Test-Path $wd)) { New-Item -ItemType Directory -Path $wd -Force | Out-Null }
            $er = $root -replace '\\','\\'; $pt = $cfg.Port; $bd = $cfg.Bind

            $startContent = (@'
$ErrorActionPreference="Stop"; $R="__R__"; $P=__P__; $B="__B__"
if($args.Count -ge 1){$P=$args[0]}; if($args.Count -ge 2){$B=$args[1]}
$ld=Join-Path $env:USERPROFILE ".openclaw\logs"; if(!(Test-Path $ld)){mkdir $ld -Force|Out-Null}
$lf=Join-Path $ld "gateway.log"; $ef=Join-Path $ld "gateway-error.log"; $pf=Join-Path $ld "gateway.pid"
if(Test-Path $pf){$ep=(gc $pf -EA SilentlyContinue).Trim(); if($ep){$pp=Get-Process -Id $ep -EA SilentlyContinue
if($pp -and $pp.ProcessName -eq "node"){Write-Host "Already running (PID $ep)";exit 0}}}
Write-Host "Starting gateway on port $P ($B)..."
$p=Start-Process node -ArgumentList "$R\openclaw.mjs","gateway","run","--port","$P","--bind","$B","--force" -WorkingDirectory $R -WindowStyle Hidden -RedirectStandardOutput $lf -RedirectStandardError $ef -PassThru
sc $pf $p.Id -Encoding ASCII; Write-Host "Started (PID $($p.Id)). Log: $lf"
'@)
            $startContent = $startContent -replace '__R__',$er
            $startContent = $startContent -replace '__P__',$pt
            $startContent = $startContent -replace '__B__',$bd
            [IO.File]::WriteAllText((Join-Path $wd "start-gateway.ps1"), $startContent)

            $stopContent = @'
$pf=Join-Path $env:USERPROFILE ".openclaw\logs\gateway.pid"
if(!(Test-Path $pf)){Write-Host "Not running.";exit 0}
$r=(gc $pf -EA SilentlyContinue).Trim(); if($r){$p=Get-Process -Id $r -EA SilentlyContinue
if($p){Stop-Process -Id $r -Force;sleep 1;Write-Host "Stopped."}else{Write-Host "Not running."}}
ri $pf -Force -EA SilentlyContinue
'@
            [IO.File]::WriteAllText((Join-Path $wd "stop-gateway.ps1"), $stopContent)

            $restartContent = @'
$d=Split-Path -Parent $MyInvocation.MyCommand.Path; & "$d\stop-gateway.ps1"; sleep 2; & "$d\start-gateway.ps1" @args
'@
            [IO.File]::WriteAllText((Join-Path $wd "restart-gateway.ps1"), $restartContent)
            # Copy config manager script from installer source so "Open Config Manager" finds it at install path
            $instRoot = $cfg.InstallerRoot
            if ($instRoot -and (Test-Path $instRoot)) {
                $srcManagePs1 = Join-Path $instRoot "scripts\manage-config.ps1"
                $srcManageBat = Join-Path $instRoot "manage-config.bat"
                $scriptsDir = Join-Path $root "scripts"
                if (-not (Test-Path $scriptsDir)) { New-Item -ItemType Directory -Path $scriptsDir -Force | Out-Null }
                if (Test-Path $srcManagePs1) {
                    Copy-Item -Path $srcManagePs1 -Destination (Join-Path $scriptsDir "manage-config.ps1") -Force
                    Log("  Copied manage-config.ps1 to install path.")
                }
                if (Test-Path $srcManageBat) {
                    Copy-Item -Path $srcManageBat -Destination (Join-Path $root "manage-config.bat") -Force
                    Log("  Copied manage-config.bat to install path.")
                }
            }
            Log("  Helper scripts created.")
            if ($cfg.AutoStart) {
                Status "Setting up auto-start..." 94
                try {
                    $tn="OpenClaw Gateway"; $sp=Join-Path $wd "start-gateway.ps1"
                    $ex=Get-ScheduledTask -TaskName $tn -EA SilentlyContinue; if($ex){Unregister-ScheduledTask -TaskName $tn -Confirm:$false}
                    $a=New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-ExecutionPolicy Bypass -WindowStyle Hidden -File `"$sp`""
                    $t=New-ScheduledTaskTrigger -AtLogOn -User $env:USERNAME
                    $s=New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable
                    Register-ScheduledTask -TaskName $tn -Action $a -Trigger $t -Settings $s -Description "OpenClaw auto-start" -RunLevel Limited | Out-Null
                    Log("  Scheduled Task registered.")
                } catch { Log("  [WARN] Task registration failed: $($_.Exception.Message)") }
            }
            if ($cfg.Bind -ne "loopback") {
                Status "Adding firewall rule..." 96
                try { $rn="OpenClaw Gateway (TCP $pt)"; if(!(Get-NetFirewallRule -DisplayName $rn -EA SilentlyContinue)){New-NetFirewallRule -DisplayName $rn -Direction Inbound -Protocol TCP -LocalPort ([int]$pt) -Action Allow|Out-Null; Log("  Firewall rule added.")} } catch { Log("  [WARN] Firewall: $($_.Exception.Message)") }
            }
            Status "Done!" 100; $state.Success = $true
        } catch { $state.Error = $_.Exception.Message; Log(""); Log("ERROR: $($_.Exception.Message)"); $state.Success = $false }
        $state.Done = $true
    })
    $null = $ps.BeginInvoke()

    # Poll progress with a DispatcherTimer — references $G directly
    $timer = New-Object System.Windows.Threading.DispatcherTimer
    $timer.Interval = [TimeSpan]::FromMilliseconds(200)
    $timer.Add_Tick({
        $s = $global:G.InstState
        if ($null -eq $s) { return }
        $global:G.installStatus.Text  = $s.Status
        $global:G.installProgress.Value = $s.Progress
        while ($s.LogIdx -lt $s.LogLines.Count) {
            $global:G.installLog.AppendText([string]$s.LogLines[$s.LogIdx] + "`r`n")
            $s.LogIdx++
        }
        if ($s.LogLines.Count -gt 0) { $global:G.installLog.ScrollToEnd() }
        if ($s.Done) {
            $this.Stop()
            $global:G.btnCancel.IsEnabled = $true
            if ($s.Success) {
                $global:G.completeSummary.Text = "Project:  $($global:G.txtPath.Text)"
                Show-Page 5
            } else {
                $global:G.completeTitle.Text = "Installation Failed"
                $global:G.completeTitle.Foreground = [Windows.Media.Brushes]::Red
                $global:G.completeSummary.Text = "Error: $($s.Error)"
                Show-Page 5
            }
        }
    })
    $timer.Start()
}

# ================================================================
#  Event Handlers (all use $global:G)
# ================================================================
$G.btnNext.Add_Click({
    switch ($global:G.CurPage) {
        0 { Show-Page 1 }
        1 { if ($global:G.PrereqOK) { Show-Page 2 } }
        2 { Show-Page 3 }
        3 { Show-Page 4; Start-Installation }
        5 { $global:G.Window.Close() }
    }
})
$G.btnBack.Add_Click({
    switch ($global:G.CurPage) {
        1 { Show-Page 0 }
        2 { Show-Page 1 }
        3 { Show-Page 2 }
    }
})
$G.btnCancel.Add_Click({
    $r = [System.Windows.MessageBox]::Show("Cancel installation?","Cancel",
        [System.Windows.MessageBoxButton]::YesNo,[System.Windows.MessageBoxImage]::Question)
    if ($r -eq [System.Windows.MessageBoxResult]::Yes) { $global:G.Window.Close() }
})
$G.btnRecheck.Add_Click({ Run-PrereqCheck })
$G.btnInstallMissing.Add_Click({ Install-MissingPrereqs })
$G.btnBrowse.Add_Click({
    $dlg = New-Object System.Windows.Forms.FolderBrowserDialog
    $dlg.Description = "Select OpenClaw installation directory"
    $dlg.SelectedPath = $global:G.txtPath.Text
    if ($dlg.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
        $global:G.txtPath.Text = $dlg.SelectedPath
        Update-PathInfo
    }
})
$G.txtPath.Add_TextChanged({ Update-PathInfo })
$G.btnOpenConfigManager.Add_Click({
    $rt = $global:G.txtPath.Text
    $managerScript = Join-Path $rt "scripts\manage-config.ps1"
    if (Test-Path $managerScript) {
        Start-Process powershell -ArgumentList "-STA -ExecutionPolicy Bypass -NoProfile -File `"$managerScript`""
    } else {
        [System.Windows.MessageBox]::Show("Config manager not found: $managerScript", "Error")
    }
})

# ================================================================
#  Launch
# ================================================================
Show-Page 0
$null = $G.Window.ShowDialog()

# Cleanup
$global:G = $null
