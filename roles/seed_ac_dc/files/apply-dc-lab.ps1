param(
  [Parameter(Mandatory=$true)]
  [ValidateSet(
    "L1.1","L1.2","L1.3",
    "L2.1","L2.2","L2.3",
    "L3.1","L3.3",
    "L4.1",
    "ALL"
  )]
  [string]$LabId,
  [string]$SeedPassword = $env:SEED_USER_PASSWORD
)

Import-Module ActiveDirectory
$domainDN = (Get-ADDomain).DistinguishedName
$ouACS = "OU=ACS,$domainDN"
$ouStaff = "OU=Staff,OU=Users,$ouACS"
$ouAdmins = "OU=Admins,OU=Users,$ouACS"

function Ensure-OU($name, $path) {
  $dn = "OU=$name,$path"
  try { Get-ADOrganizationalUnit -Identity $dn -ErrorAction Stop | Out-Null }
  catch { New-ADOrganizationalUnit -Name $name -Path $path | Out-Null }
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
      Ensure-User "ex.employee" "Former Employee" $ouStaff @("SG-ACS-Finance","SG-ACS-All-Staff")
      Enable-ADAccount "ex.employee" -ErrorAction SilentlyContinue
      Set-ADUser "ex.employee" -Description "L1.1: Terminated user still enabled with Finance access" -ErrorAction SilentlyContinue
      Write-Host "  L1.1 seeded: ex.employee enabled + Finance"
    }

    "L1.2" {
      Add-ADGroupMember -Identity "SG-ACS-Finance" -Members "hr.user1" -ErrorAction SilentlyContinue
      Set-ADUser "hr.user1" -Description "L1.2: HR user mistakenly in Finance group" -ErrorAction SilentlyContinue
      Write-Host "  L1.2 seeded: hr.user1 added to Finance"
    }

    "L1.3" {
      Add-ADGroupMember -Identity "Domain Admins" -Members "it.helpdesk" -ErrorAction SilentlyContinue
      Set-ADUser "it.helpdesk" -Description "L1.3: Helpdesk incorrectly in Domain Admins" -ErrorAction SilentlyContinue
      Write-Host "  L1.3 seeded: it.helpdesk added to Domain Admins"
    }

    "L2.1" {
      Set-ADUser "ceo.acs" -Description "L2.1: HR approved new.user1 - account not yet created" -ErrorAction SilentlyContinue
      Write-Host "  L2.1 seeded: new.user1 absent (joiner scenario)"
    }

    "L2.2" {
      Add-ADGroupMember -Identity "SG-ACS-Sales" -Members "consult.user1" -ErrorAction SilentlyContinue
      Add-ADGroupMember -Identity "SG-ACS-Consulting" -Members "consult.user1" -ErrorAction SilentlyContinue
      Set-ADUser "consult.user1" -Description "L2.2: Mover - old Consulting access not removed after role change" -ErrorAction SilentlyContinue
      Write-Host "  L2.2 seeded: consult.user1 in both Consulting + Sales"
    }

    "L2.3" {
      $ouTerm = Ensure-OU "Terminated" ("OU=Users,$ouACS")
      Enable-ADAccount "fin.user1" -ErrorAction SilentlyContinue
      Add-ADGroupMember -Identity "SG-ACS-Finance" -Members "fin.user1" -ErrorAction SilentlyContinue
      Set-ADUser "fin.user1" -Description "L2.3: Leaver - should be disabled, de-grouped, moved to Terminated OU" -ErrorAction SilentlyContinue
      Write-Host "  L2.3 seeded: fin.user1 still enabled with groups"
    }

    "L3.1" {
      $ouExec = "OU=Executive,OU=Departments,$ouACS"
      $u = Get-ADUser "sales.user1" -ErrorAction SilentlyContinue
      if ($u) { Move-ADObject $u.DistinguishedName -TargetPath $ouExec -ErrorAction SilentlyContinue }
      Set-ADUser "sales.user1" -Description "L3.1: User in wrong OU - move to correct department OU" -ErrorAction SilentlyContinue
      Write-Host "  L3.1 seeded: sales.user1 moved to Executive OU"
    }

    "L3.3" {
      Set-ADUser "it.helpdesk" -Description "L3.3: Delegate password reset for Staff OU (no Domain Admin)" -ErrorAction SilentlyContinue
      Write-Host "  L3.3 seeded: delegation scenario marked"
    }

    "L4.1" {
      Ensure-User "contractor.user1" "Contractor User" $ouStaff @("SG-ACS-All-Staff")
      Enable-ADAccount "contractor.user1" -ErrorAction SilentlyContinue
      Set-ADUser "contractor.user1" -Description "L4.1: Contractor access should be disabled/expired per policy" -ErrorAction SilentlyContinue
      Write-Host "  L4.1 seeded: contractor.user1 enabled with no expiry"
    }
  }
}

if ($LabId -eq "ALL") {
  $allLabs = @("L1.1","L1.2","L1.3","L2.1","L2.2","L2.3","L3.1","L3.3","L4.1")
  foreach ($lab in $allLabs) { Apply-Lab $lab }
  Write-Host "All DC labs seeded on $((Get-ADDomain).DNSRoot)"
} else {
  Apply-Lab $LabId
  Write-Host "Lab $LabId seeded on $((Get-ADDomain).DNSRoot)"
}
