param(
  [Parameter(Mandatory=$true)]
  [ValidateSet(
    "L1.1","L1.2","L1.3",
    "L2.1","L2.2","L2.3",
    "L3.1","L3.2","L3.3",
    "L4.1","L4.2","L4.3",
    "ALL"
  )]
  [string]$LabId,
  [Parameter(Mandatory=$true)]
  [ValidateRange(1,20)]
  [int]$PodId,
  [string]$SeedPassword = $env:SEED_USER_PASSWORD
)

Import-Module ActiveDirectory
$domainDN = (Get-ADDomain).DistinguishedName
$podName = "Pod{0:D2}" -f $PodId
$prefix = "P{0:D2}" -f $PodId
$podOU = "OU=$podName,OU=Students,$domainDN"
$ouPodUsers = "OU=Users,$podOU"
$ouPodResources = "OU=Resources,$podOU"
$ouStaff = "OU=Staff,$ouPodUsers"
$ouAdmins = "OU=Admins,$ouPodUsers"

function Ensure-OU($name, $path) {
  $dn = "OU=$name,$path"
  try { Get-ADOrganizationalUnit -Identity $dn -ErrorAction Stop | Out-Null }
  catch { New-ADOrganizationalUnit -Name $name -Path $path -ProtectedFromAccidentalDeletion $false | Out-Null }
  return $dn
}

function Ensure-User($sam, $display, $path, $groups) {
  if (-not (Get-ADUser -Filter "SamAccountName -eq '$sam'" -ErrorAction SilentlyContinue)) {
    $pw = ConvertTo-SecureString $SeedPassword -AsPlainText -Force
    New-ADUser -SamAccountName $sam -UserPrincipalName "$sam@$((Get-ADDomain).DNSRoot)" `
      -Name $display -DisplayName $display -Path $path -AccountPassword $pw `
      -Enabled $true -PasswordNeverExpires $false -ChangePasswordAtLogon $false | Out-Null
  }
  foreach ($g in $groups) { Add-ADGroupMember -Identity $g -Members $sam -ErrorAction SilentlyContinue }
}

function Apply-Lab($id) {
  switch ($id) {

    "L1.1" {
      Ensure-User "$prefix-ex.employee" "$podName Former Employee" $ouStaff @("$prefix-SG-ACS-Finance","$prefix-SG-ACS-All-Staff")
      Enable-ADAccount "$prefix-ex.employee" -ErrorAction SilentlyContinue
      Set-ADUser "$prefix-ex.employee" -Description "L1.1: Terminated user still enabled with Finance access" -ErrorAction SilentlyContinue
      Write-Host "  L1.1 seeded: $prefix-ex.employee enabled + Finance"
    }

    "L1.2" {
      Add-ADGroupMember -Identity "$prefix-SG-ACS-Finance" -Members "$prefix-hr.user1" -ErrorAction SilentlyContinue
      Set-ADUser "$prefix-hr.user1" -Description "L1.2: HR user mistakenly in Finance group" -ErrorAction SilentlyContinue
      Write-Host "  L1.2 seeded: $prefix-hr.user1 added to Finance"
    }

    "L1.3" {
      Add-ADGroupMember -Identity "$prefix-SG-ACS-IT-Admins" -Members "$prefix-it.helpdesk" -ErrorAction SilentlyContinue
      Set-ADUser "$prefix-it.helpdesk" -Description "L1.3: Helpdesk incorrectly given IT-Admins privileges" -ErrorAction SilentlyContinue
      Write-Host "  L1.3 seeded: $prefix-it.helpdesk added to IT-Admins"
    }

    "L2.1" {
      Set-ADUser "$prefix-ceo.acs" -Description "L2.1: HR approved new.user1 - account not yet created" -ErrorAction SilentlyContinue
      Write-Host "  L2.1 seeded: new.user1 absent (joiner scenario)"
    }

    "L2.2" {
      Add-ADGroupMember -Identity "$prefix-SG-ACS-Sales" -Members "$prefix-consult.user1" -ErrorAction SilentlyContinue
      Add-ADGroupMember -Identity "$prefix-SG-ACS-Consulting" -Members "$prefix-consult.user1" -ErrorAction SilentlyContinue
      Set-ADUser "$prefix-consult.user1" -Description "L2.2: Mover - old Consulting access not removed after role change" -ErrorAction SilentlyContinue
      Write-Host "  L2.2 seeded: $prefix-consult.user1 in both Consulting + Sales"
    }

    "L2.3" {
      $ouTerm = Ensure-OU "Terminated" $ouPodUsers
      Enable-ADAccount "$prefix-fin.user1" -ErrorAction SilentlyContinue
      Add-ADGroupMember -Identity "$prefix-SG-ACS-Finance" -Members "$prefix-fin.user1" -ErrorAction SilentlyContinue
      Set-ADUser "$prefix-fin.user1" -Description "L2.3: Leaver - should be disabled, de-grouped, moved to Terminated OU" -ErrorAction SilentlyContinue
      Write-Host "  L2.3 seeded: $prefix-fin.user1 still enabled with groups"
    }

    "L3.1" {
      $ouExec = "OU=Executive,OU=Departments,$ouPodResources"
      $u = Get-ADUser "$prefix-sales.user1" -ErrorAction SilentlyContinue
      if ($u) { Move-ADObject $u.DistinguishedName -TargetPath $ouExec -ErrorAction SilentlyContinue }
      Set-ADUser "$prefix-sales.user1" -Description "L3.1: User in wrong OU - move to correct department OU" -ErrorAction SilentlyContinue
      Write-Host "  L3.1 seeded: $prefix-sales.user1 moved to Executive OU"
    }

    "L3.3" {
      Set-ADUser "$prefix-it.helpdesk" -Description "L3.3: Delegate password reset for Staff OU (no IT-Admins)" -ErrorAction SilentlyContinue
      Write-Host "  L3.3 seeded: delegation scenario marked"
    }

    "L4.1" {
      Ensure-User "$prefix-contractor.user1" "$podName Contractor User" $ouStaff @("$prefix-SG-ACS-All-Staff")
      Enable-ADAccount "$prefix-contractor.user1" -ErrorAction SilentlyContinue
      Set-ADUser "$prefix-contractor.user1" -Description "L4.1: Contractor access should be disabled/expired per policy" -ErrorAction SilentlyContinue
      Write-Host "  L4.1 seeded: $prefix-contractor.user1 enabled with no expiry"
    }

    # --- Converted from workstation labs (now run on DC) ---

    "L3.2" {
      # Add pod All-Staff group to pod IT-Admins (simulates over-permissioned group nesting)
      Add-ADGroupMember -Identity "$prefix-SG-ACS-IT-Admins" -Members "$prefix-SG-ACS-All-Staff" -ErrorAction SilentlyContinue
      Write-Host "  L3.2 seeded: $prefix-SG-ACS-All-Staff nested in IT-Admins"
    }

    "L4.2" {
      # Per-pod evidence folder under C:\CyberLab\PodXX
      $podLab = "C:\CyberLab\$podName"
      New-Item -ItemType Directory -Path $podLab -Force | Out-Null
      Remove-Item -Recurse -Force "$podLab\Lab4-2" -ErrorAction SilentlyContinue
      New-Item -ItemType Directory -Path "$podLab\Lab4-2" -Force | Out-Null
      Write-Host "  L4.2 seeded: Lab4-2 evidence folder created (empty) under $podLab"
    }

    "L4.3" {
      # Per-pod evidence folder under C:\CyberLab\PodXX
      $podLab = "C:\CyberLab\$podName"
      New-Item -ItemType Directory -Path $podLab -Force | Out-Null
      Remove-Item -Recurse -Force "$podLab\Lab4-3" -ErrorAction SilentlyContinue
      New-Item -ItemType Directory -Path "$podLab\Lab4-3" -Force | Out-Null
      Set-Content -Path "$podLab\Lab4-3\enabled_users.csv" -Value "placeholder"
      Write-Host "  L4.3 seeded: Lab4-3 evidence folder created (incomplete files) under $podLab"
    }
  }
}

if ($LabId -eq "ALL") {
  $allLabs = @("L1.1","L1.2","L1.3","L2.1","L2.2","L2.3","L3.1","L3.2","L3.3","L4.1","L4.2","L4.3")
  foreach ($lab in $allLabs) { Apply-Lab $lab }
  Write-Host "All labs seeded for $podName on $((Get-ADDomain).DNSRoot) (shared DC mode)"
} else {
  Apply-Lab $LabId
  Write-Host "Lab $LabId seeded for $podName on $((Get-ADDomain).DNSRoot)"
}
