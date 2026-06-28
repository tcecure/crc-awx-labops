# install-putty.ps1
# Downloads and installs PuTTY system-wide, then creates per-pod saved sessions
# for each student profile on DC01 and DC02.
#
# Usage: powershell -ExecutionPolicy Bypass -File install-putty.ps1 -PodCount 20

param(
    [int]$PodCount = 20
)

$ErrorActionPreference = "Stop"

# ---- 1. Install PuTTY system-wide ----
$puttyUrl = "https://the.earth.li/~sgtatham/putty/latest/w64/putty-64bit-0.82-installer.msi"
$msiPath = "$env:TEMP\putty-installer.msi"
$installDir = "C:\Program Files\PuTTY"

if (Test-Path "$installDir\putty.exe") {
    Write-Host "PuTTY already installed at $installDir"
} else {
    Write-Host "Downloading PuTTY MSI..."
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    try {
        Invoke-WebRequest -Uri $puttyUrl -OutFile $msiPath -UseBasicParsing
        Write-Host "Installing PuTTY..."
        Start-Process msiexec.exe -ArgumentList "/i `"$msiPath`" /qn /norestart INSTALLDIR=`"$installDir`"" -Wait -NoNewWindow
        Write-Host "PuTTY installed successfully"
    } catch {
        Write-Host "Download failed, trying alternate URL..."
        $altUrl = "https://the.earth.li/~sgtatham/putty/0.82/w64/putty-64bit-0.82-installer.msi"
        Invoke-WebRequest -Uri $altUrl -OutFile $msiPath -UseBasicParsing
        Start-Process msiexec.exe -ArgumentList "/i `"$msiPath`" /qn /norestart INSTALLDIR=`"$installDir`"" -Wait -NoNewWindow
        Write-Host "PuTTY installed successfully (alternate URL)"
    }
    # Add to system PATH if not already there
    $systemPath = [Environment]::GetEnvironmentVariable("Path", "Machine")
    if ($systemPath -notlike "*PuTTY*") {
        [Environment]::SetEnvironmentVariable("Path", "$systemPath;$installDir", "Machine")
        Write-Host "Added PuTTY to system PATH"
    }
}

# ---- 2. Create per-pod saved sessions in Default profile ----
# These sessions will be available to all users who log into the machine.
# We use HKLM\SOFTWARE\SimonTatham\PuTTY\Sessions for machine-wide sessions.

$regBase = "HKLM:\SOFTWARE\SimonTatham\PuTTY\Sessions"
if (-not (Test-Path "HKLM:\SOFTWARE\SimonTatham")) {
    New-Item -Path "HKLM:\SOFTWARE\SimonTatham" -Force | Out-Null
}
if (-not (Test-Path "HKLM:\SOFTWARE\SimonTatham\PuTTY")) {
    New-Item -Path "HKLM:\SOFTWARE\SimonTatham\PuTTY" -Force | Out-Null
}
if (-not (Test-Path $regBase)) {
    New-Item -Path $regBase -Force | Out-Null
}

for ($i = 1; $i -le $PodCount; $i++) {
    $padded = "{0:D2}" -f $i
    $sessionName = "Pod${padded}-GW"
    $gwIp = "10.51.${i}.1"
    $sessionPath = "$regBase\$sessionName"
    
    if (Test-Path $sessionPath) {
        Write-Host "Session $sessionName already exists, updating..."
    } else {
        New-Item -Path $sessionPath -Force | Out-Null
    }
    
    # Core connection settings
    Set-ItemProperty -Path $sessionPath -Name "HostName" -Value $gwIp
    Set-ItemProperty -Path $sessionPath -Name "PortNumber" -Value 22 -Type DWord
    Set-ItemProperty -Path $sessionPath -Name "Protocol" -Value "ssh"
    Set-ItemProperty -Path $sessionPath -Name "UserName" -Value "admin"
    
    # Terminal settings
    Set-ItemProperty -Path $sessionPath -Name "TermWidth" -Value 120 -Type DWord
    Set-ItemProperty -Path $sessionPath -Name "TermHeight" -Value 40 -Type DWord
    Set-ItemProperty -Path $sessionPath -Name "ScrollbackLines" -Value 2000 -Type DWord
    
    # Auto-accept host key (lab environment only)
    Set-ItemProperty -Path $sessionPath -Name "SSHManualHostKeys" -Value ""
    
    Write-Host "Created session: $sessionName -> $gwIp (admin@$gwIp:22)"
}

# ---- 3. Also create sessions in Default User profile (for new user logins) ----
# Load the default user hive
$defaultHive = "C:\Users\Default\NTUSER.DAT"
$hiveMounted = $false

if (Test-Path $defaultHive) {
    try {
        reg load "HKU\DefaultUser" $defaultHive 2>$null
        $hiveMounted = $true
        $userRegBase = "Registry::HKU\DefaultUser\SOFTWARE\SimonTatham\PuTTY\Sessions"
        
        # Create registry path
        $parts = @("HKU\DefaultUser\SOFTWARE\SimonTatham",
                    "HKU\DefaultUser\SOFTWARE\SimonTatham\PuTTY",
                    "HKU\DefaultUser\SOFTWARE\SimonTatham\PuTTY\Sessions")
        foreach ($p in $parts) {
            if (-not (Test-Path "Registry::$p")) {
                New-Item -Path "Registry::$p" -Force | Out-Null
            }
        }
        
        for ($i = 1; $i -le $PodCount; $i++) {
            $padded = "{0:D2}" -f $i
            $sessionName = "Pod${padded}-GW"
            $gwIp = "10.51.${i}.1"
            $sessionPath = "$userRegBase\$sessionName"
            
            if (-not (Test-Path $sessionPath)) {
                New-Item -Path $sessionPath -Force | Out-Null
            }
            Set-ItemProperty -Path $sessionPath -Name "HostName" -Value $gwIp
            Set-ItemProperty -Path $sessionPath -Name "PortNumber" -Value 22 -Type DWord
            Set-ItemProperty -Path $sessionPath -Name "Protocol" -Value "ssh"
            Set-ItemProperty -Path $sessionPath -Name "UserName" -Value "admin"
            Set-ItemProperty -Path $sessionPath -Name "TermWidth" -Value 120 -Type DWord
            Set-ItemProperty -Path $sessionPath -Name "TermHeight" -Value 40 -Type DWord
            Set-ItemProperty -Path $sessionPath -Name "ScrollbackLines" -Value 2000 -Type DWord
        }
        Write-Host "Created sessions in Default User profile"
    } catch {
        Write-Host "Warning: Could not write to Default User profile: $_"
    } finally {
        if ($hiveMounted) {
            [gc]::Collect()
            Start-Sleep -Seconds 1
            reg unload "HKU\DefaultUser" 2>$null
        }
    }
}

# ---- 4. Create desktop shortcut for easy access ----
$shortcutPath = "C:\Users\Public\Desktop\PuTTY.lnk"
if (-not (Test-Path $shortcutPath) -and (Test-Path "$installDir\putty.exe")) {
    $WshShell = New-Object -ComObject WScript.Shell
    $Shortcut = $WshShell.CreateShortcut($shortcutPath)
    $Shortcut.TargetPath = "$installDir\putty.exe"
    $Shortcut.Description = "PuTTY SSH Client - Connect to Pod Gateway"
    $Shortcut.Save()
    Write-Host "Created PuTTY desktop shortcut"
}

Write-Host ""
Write-Host "=== PuTTY Installation Complete ==="
Write-Host "Installed: $installDir\putty.exe"
Write-Host "Sessions: $PodCount saved sessions (Pod01-GW through Pod${PodCount}-GW)"
Write-Host "Students open PuTTY and double-click their pod session to connect."
