<#
Ensures student accounts can use the shared domain controller for their own pod:
  1. Grants "Allow log on through Remote Desktop Services" to Remote Desktop Users.
  2. Ensures a PodNN-Admins domain-local group exists, delegated GenericAll on OU=PodNN.
  3. Adds studentNN to PodNN-Admins.
  4. Grants PodNN-Admins Modify on C:\CyberLab\PodNN.
Idempotent: reports what it changed and makes no change when already correct.
#>
[CmdletBinding()]
param(
  [int]$PodCount = 20,
  [string]$DomainDn = 'DC=acs-p01,DC=local',
  [string]$NetbiosDomain = 'ACS-P01'
)

$ErrorActionPreference = 'Stop'
Import-Module ActiveDirectory

# --- 1. RDS logon right for Remote Desktop Users (S-1-5-32-555) ---
$work = Join-Path $env:WINDIR 'Temp\student_access'
New-Item -ItemType Directory -Force -Path $work | Out-Null
secedit /export /areas USER_RIGHTS /cfg "$work\cur.inf" | Out-Null
$right = (Get-Content "$work\cur.inf") | Where-Object { $_ -match '^SeRemoteInteractiveLogonRight' }
if ($right -notmatch 'S-1-5-32-555') {
  @('[Unicode]', 'Unicode=yes', '[Version]', 'signature="$CHICAGO$"', 'Revision=1',
    '[Privilege Rights]', 'SeRemoteInteractiveLogonRight = *S-1-5-32-544,*S-1-5-32-555') |
    Set-Content -Path "$work\fix.inf" -Encoding Unicode
  secedit /configure /db "$work\fix.sdb" /cfg "$work\fix.inf" /areas USER_RIGHTS /quiet
  Write-Host 'CHANGED: granted RDS logon right to Remote Desktop Users'
} else {
  Write-Host 'OK: Remote Desktop Users already hold the RDS logon right'
}

# --- 2-4. Per-pod delegation ---
foreach ($n in 1..$PodCount) {
  $pod = 'Pod{0:D2}' -f $n
  $podDn = "OU=$pod,OU=Students,$DomainDn"
  if (-not (Test-Path "AD:$podDn")) { Write-Host "SKIP ${pod}: no OU"; continue }

  $groupsOu = "OU=Groups,$podDn"
  if (-not (Test-Path "AD:$groupsOu")) {
    New-ADOrganizationalUnit -Name 'Groups' -Path $podDn -ProtectedFromAccidentalDeletion $false
    Write-Host "CHANGED ${pod}: created Groups OU"
  }

  $gName = "$pod-Admins"
  $g = Get-ADGroup -LDAPFilter "(name=$gName)" -ErrorAction SilentlyContinue
  if (-not $g) {
    $g = New-ADGroup -Name $gName -GroupScope DomainLocal -GroupCategory Security -Path $groupsOu `
      -Description "$pod student delegated admins" -PassThru
    Write-Host "CHANGED ${pod}: created $gName"
  }

  $acl = Get-Acl "AD:$podDn"
  $delegated = $acl.Access | Where-Object {
    $_.IdentityReference -like "*$gName" -and $_.ActiveDirectoryRights -match 'GenericAll'
  }
  if (-not $delegated) {
    $sid = New-Object System.Security.Principal.SecurityIdentifier $g.SID
    $ace = New-Object System.DirectoryServices.ActiveDirectoryAccessRule(
      $sid,
      [System.DirectoryServices.ActiveDirectoryRights]::GenericAll,
      [System.Security.AccessControl.AccessControlType]::Allow,
      [System.DirectoryServices.ActiveDirectorySecurityInheritance]::All)
    $acl.AddAccessRule($ace)
    Set-Acl -Path "AD:$podDn" -AclObject $acl
    Write-Host "CHANGED ${pod}: delegated GenericAll on $podDn to $gName"
  }

  $student = 'student{0:D2}' -f $n
  if (Get-ADUser -LDAPFilter "(sAMAccountName=$student)" -ErrorAction SilentlyContinue) {
    $members = Get-ADGroupMember $gName | Select-Object -ExpandProperty SamAccountName
    if ($members -notcontains $student) {
      Add-ADGroupMember -Identity $gName -Members $student
      Write-Host "CHANGED ${pod}: added $student to $gName"
    }
  } else {
    Write-Host "WARN ${pod}: user $student does not exist"
  }

  $path = "C:\CyberLab\$pod"
  if (Test-Path $path) {
    $identity = "$NetbiosDomain\$gName"
    $facl = Get-Acl $path
    $hasNtfs = $facl.Access | Where-Object {
      $_.IdentityReference.Value -eq $identity -and $_.FileSystemRights -match 'Modify|FullControl'
    }
    if (-not $hasNtfs) {
      $rule = New-Object System.Security.AccessControl.FileSystemAccessRule(
        $identity,
        [System.Security.AccessControl.FileSystemRights]::Modify,
        [System.Security.AccessControl.InheritanceFlags]'ContainerInherit,ObjectInherit',
        [System.Security.AccessControl.PropagationFlags]::None,
        [System.Security.AccessControl.AccessControlType]::Allow)
      $facl.AddAccessRule($rule)
      Set-Acl -Path $path -AclObject $facl
      Write-Host "CHANGED ${pod}: granted Modify on $path to $identity"
    }
  }
}

# --- Guard rail: students must never hold the DC shutdown right ---
$da = Get-ADGroupMember 'Domain Admins' -Recursive | Select-Object -ExpandProperty SamAccountName
$studentDa = $da | Where-Object { $_ -match '^student\d\d$' }
if ($studentDa) {
  Write-Host "WARN: student accounts in Domain Admins (can shut down the shared DC): $($studentDa -join ',')"
} else {
  Write-Host 'OK: no student accounts in Domain Admins'
}
