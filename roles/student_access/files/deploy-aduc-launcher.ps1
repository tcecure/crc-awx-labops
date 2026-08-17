$ErrorActionPreference = 'Stop'

$toolsDir = 'C:\CyberLab\Tools'
New-Item -ItemType Directory -Path $toolsDir -Force | Out-Null

$cmd = @'
@echo off
rem Launches Active Directory Users and Computers without UAC elevation so
rem delegated pod accounts can use it with their own permissions.
set __COMPAT_LAYER=RunAsInvoker
start "" mmc.exe "%SystemRoot%\system32\dsa.msc"
'@
$cmdPath = Join-Path $toolsDir 'Open-ADUC.cmd'
Set-Content -Path $cmdPath -Value $cmd -Encoding ASCII

$acl = Get-Acl $toolsDir
$acl.SetAccessRuleProtection($false, $true)
$rule = New-Object System.Security.AccessControl.FileSystemAccessRule(
  'Authenticated Users', 'ReadAndExecute', 'ContainerInherit,ObjectInherit', 'None', 'Allow')
$acl.AddAccessRule($rule)
Set-Acl -Path $toolsDir -AclObject $acl

$lnkPath = 'C:\Users\Public\Desktop\Active Directory Users and Computers.lnk'
$sh = New-Object -ComObject WScript.Shell
$lnk = $sh.CreateShortcut($lnkPath)
$lnk.TargetPath = $cmdPath
$lnk.WorkingDirectory = $toolsDir
$lnk.IconLocation = "$env:SystemRoot\system32\dsadmin.dll,0"
$lnk.Description = 'Open ADUC with your own pod permissions (no admin prompt)'
$lnk.WindowStyle = 7
$lnk.Save()

Write-Output "cmd=$([bool](Test-Path $cmdPath))"
Write-Output "lnk=$([bool](Test-Path $lnkPath))"
Get-Content $cmdPath
