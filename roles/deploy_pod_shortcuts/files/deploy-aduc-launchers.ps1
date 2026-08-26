[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][int]$PodId,
    [string]$DomainFqdn = 'acs-p01.local'
)

$ErrorActionPreference = 'Stop'

$pod = 'Pod{0:d2}' -f $PodId
$prefix = 'P{0:d2}' -f $PodId
$toolsDir = 'C:\CyberLab\Tools'
$podDir = Join-Path 'C:\CyberLab\PodShortcuts' $pod

New-Item -ItemType Directory -Path $toolsDir -Force | Out-Null
New-Item -ItemType Directory -Path $podDir -Force | Out-Null

# Shared launcher. Two things matter here and both are defect fixes:
#   * __COMPAT_LAYER=RunAsInvoker keeps mmc.exe from requesting elevation, which a
#     delegated pod account cannot satisfy (it gets a UAC credential prompt instead of ADUC).
#   * MMC restores %APPDATA%\Microsoft\MMC\dsa on every launch, so a student who last
#     closed ADUC on an empty node (for example Saved Queries) reopens to a blank console.
#     Clearing the cached view makes the console always open on the domain.
$sharedCmd = @'
@echo off
setlocal
set __COMPAT_LAYER=RunAsInvoker
if exist "%APPDATA%\Microsoft\MMC\dsa" del /q "%APPDATA%\Microsoft\MMC\dsa"
start "" mmc.exe "%SystemRoot%\system32\dsa.msc"
'@
$sharedCmdPath = Join-Path $toolsDir 'Open-ADUC.cmd'
Set-Content -Path $sharedCmdPath -Value $sharedCmd -Encoding ASCII

$acl = Get-Acl $toolsDir
$acl.SetAccessRuleProtection($false, $true)
$acl.AddAccessRule((New-Object System.Security.AccessControl.FileSystemAccessRule(
    'Authenticated Users', 'ReadAndExecute', 'ContainerInherit,ObjectInherit', 'None', 'Allow')))
Set-Acl -Path $toolsDir -AclObject $acl

$podPs1Path = Join-Path $podDir "Open-$pod-ADUC.ps1"
$podPs1 = @"
# Open Active Directory Users and Computers scoped to the $pod OU.
`$env:__COMPAT_LAYER = 'RunAsInvoker'
`$cached = Join-Path `$env:APPDATA 'Microsoft\MMC\dsa'
if (Test-Path `$cached) { Remove-Item `$cached -Force -ErrorAction SilentlyContinue }
Start-Process -FilePath "`$env:SystemRoot\system32\mmc.exe" -ArgumentList "```"`$env:SystemRoot\system32\dsa.msc```""
Start-Sleep -Seconds 3
Write-Host ''
Write-Host '============================================' -ForegroundColor Cyan
Write-Host '  Welcome to $pod Lab Environment' -ForegroundColor Green
Write-Host '============================================' -ForegroundColor Cyan
Write-Host ''
Write-Host 'Your OU path:' -ForegroundColor Yellow
Write-Host '  OU=$pod,OU=Students,DC=$($DomainFqdn -replace '\.', ',DC=')' -ForegroundColor White
Write-Host ''
Write-Host 'Navigate in ADUC to:' -ForegroundColor Yellow
Write-Host '  $DomainFqdn > Students > $pod' -ForegroundColor White
Write-Host ''
Write-Host 'Your users are prefixed with: $prefix-' -ForegroundColor Yellow
Write-Host 'Your groups are prefixed with: $prefix-SG-' -ForegroundColor Yellow
Write-Host ''
Write-Host 'You can ONLY modify objects inside your $pod OU.' -ForegroundColor Red
Write-Host '============================================' -ForegroundColor Cyan
"@
Set-Content -Path $podPs1Path -Value $podPs1 -Encoding ASCII

$podBatPath = Join-Path $podDir "Open-$pod-ADUC.bat"
$podBat = @"
@echo off
title $pod - Active Directory Lab
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$podPs1Path"
pause
"@
Set-Content -Path $podBatPath -Value $podBat -Encoding ASCII

$sh = New-Object -ComObject WScript.Shell

# Pod launcher shortcut points at the pod batch file, never at mmc.exe directly:
# a direct mmc.exe shortcut cannot set the compatibility layer and prompts for elevation.
$podLnk = $sh.CreateShortcut((Join-Path $podDir "$pod - Active Directory.lnk"))
$podLnk.TargetPath = $podBatPath
$podLnk.Arguments = ''
$podLnk.WorkingDirectory = $podDir
$podLnk.IconLocation = "$env:SystemRoot\system32\dsadmin.dll,0"
$podLnk.Description = "Open Active Directory Users and Computers for $pod"
$podLnk.WindowStyle = 7
$podLnk.Save()

$publicLnkPath = 'C:\Users\Public\Desktop\Active Directory Users and Computers.lnk'
$publicLnk = $sh.CreateShortcut($publicLnkPath)
$publicLnk.TargetPath = $sharedCmdPath
$publicLnk.Arguments = ''
$publicLnk.WorkingDirectory = $toolsDir
$publicLnk.IconLocation = "$env:SystemRoot\system32\dsadmin.dll,0"
$publicLnk.Description = 'Open ADUC with your own pod permissions (no admin prompt)'
$publicLnk.WindowStyle = 7
$publicLnk.Save()

Write-Output "$pod shared=$([bool](Test-Path $sharedCmdPath)) pod_ps1=$([bool](Test-Path $podPs1Path)) pod_bat=$([bool](Test-Path $podBatPath)) public_lnk=$([bool](Test-Path $publicLnkPath))"
