param(
  [Parameter(Mandatory=$true)]
  [ValidateRange(1,20)]
  [int]$PodId
)

<#
.SYNOPSIS
  Resets all AC lab artifacts for a given pod on the shared DC.
  Removes lab-created users, undoes group membership changes, restores OU placement,
  clears evidence folders, and resets user descriptions back to baseline.
  After running this, the pod is ready to be re-seeded for the next lab family.
#>

Import-Module ActiveDirectory
$domainDN  = (Get-ADDomain).DistinguishedName
$podName   = "Pod{0:D2}" -f $PodId
$prefix    = "P{0:D2}" -f $PodId
$podOU     = "OU=$podName,OU=Students,$domainDN"
$ouPodUsers     = "OU=Users,$podOU"
$ouPodResources = "OU=Resources,$podOU"
$ouStaff   = "OU=Staff,$ouPodUsers"
$ouAdmins  = "OU=Admins,$ouPodUsers"

Write-Host "=== Resetting AC labs for $podName ($prefix) ==="

# -------------------------------------------------------
# 1. Remove lab-created users (L1.1: ex.employee, L4.1: contractor.user1, L2.1: new.user1)
# -------------------------------------------------------
$labUsers = @("$prefix-ex.employee", "$prefix-contractor.user1", "$prefix-new.user1")
foreach ($sam in $labUsers) {
  $u = Get-ADUser -Filter "SamAccountName -eq '$sam'" -ErrorAction SilentlyContinue
  if ($u) {
    Remove-ADUser $u -Confirm:$false -ErrorAction SilentlyContinue
    Write-Host "  Removed lab user: $sam"
  }
}

# -------------------------------------------------------
# 2. Undo group membership changes from lab scenarios
# -------------------------------------------------------

# L1.2: Remove hr.user1 from Finance group (should only be in HR)
Remove-ADGroupMember -Identity "$prefix-SG-ACS-Finance" -Members "$prefix-hr.user1" -Confirm:$false -ErrorAction SilentlyContinue
Write-Host "  L1.2 reset: removed $prefix-hr.user1 from Finance"

# L1.3: Remove it.helpdesk from IT-Admins (should only be in Helpdesk)
Remove-ADGroupMember -Identity "$prefix-SG-ACS-IT-Admins" -Members "$prefix-it.helpdesk" -Confirm:$false -ErrorAction SilentlyContinue
Write-Host "  L1.3 reset: removed $prefix-it.helpdesk from IT-Admins"

# L2.2: Remove consult.user1 from Sales (should only be in Consulting)
Remove-ADGroupMember -Identity "$prefix-SG-ACS-Sales" -Members "$prefix-consult.user1" -Confirm:$false -ErrorAction SilentlyContinue
Write-Host "  L2.2 reset: removed $prefix-consult.user1 from Sales"

# L3.2: Remove All-Staff from IT-Admins (undo group nesting)
Remove-ADGroupMember -Identity "$prefix-SG-ACS-IT-Admins" -Members "$prefix-SG-ACS-All-Staff" -Confirm:$false -ErrorAction SilentlyContinue
Write-Host "  L3.2 reset: removed $prefix-SG-ACS-All-Staff from IT-Admins"

# -------------------------------------------------------
# 3. Restore user states modified by lab scenarios
# -------------------------------------------------------

# L2.3: Re-enable fin.user1 (leaver scenario may have been remediated by student)
# Just ensure the user is in correct baseline state
$finUser = Get-ADUser -Filter "SamAccountName -eq '$prefix-fin.user1'" -ErrorAction SilentlyContinue
if ($finUser) {
  Enable-ADAccount $finUser -ErrorAction SilentlyContinue
  # Ensure back in Finance group (baseline membership)
  Add-ADGroupMember -Identity "$prefix-SG-ACS-Finance" -Members "$prefix-fin.user1" -ErrorAction SilentlyContinue
  # Move back to Staff OU if student moved it to Terminated
  if ($finUser.DistinguishedName -notlike "*$ouStaff*") {
    Move-ADObject $finUser.DistinguishedName -TargetPath $ouStaff -ErrorAction SilentlyContinue
    Write-Host "  L2.3 reset: moved $prefix-fin.user1 back to Staff OU"
  }
}

# L3.1: Move sales.user1 back to Staff OU (was moved to Executive OU)
$salesUser = Get-ADUser -Filter "SamAccountName -eq '$prefix-sales.user1'" -ErrorAction SilentlyContinue
if ($salesUser -and $salesUser.DistinguishedName -notlike "*$ouStaff*") {
  Move-ADObject $salesUser.DistinguishedName -TargetPath $ouStaff -ErrorAction SilentlyContinue
  Write-Host "  L3.1 reset: moved $prefix-sales.user1 back to Staff OU"
}

# -------------------------------------------------------
# 4. Clear all user descriptions (set by lab scenarios)
# -------------------------------------------------------
$baselineUsers = @(
  "$prefix-ceo.acs", "$prefix-it.admin", "$prefix-it.helpdesk",
  "$prefix-fin.user1", "$prefix-hr.user1", "$prefix-consult.user1",
  "$prefix-sales.user1"
)
foreach ($sam in $baselineUsers) {
  Set-ADUser $sam -Description "" -ErrorAction SilentlyContinue
}
Write-Host "  Cleared descriptions on all baseline users"

# -------------------------------------------------------
# 5. Remove Terminated OU if created by L2.3
# -------------------------------------------------------
$ouTerm = "OU=Terminated,$ouPodUsers"
try {
  # Move any users out of Terminated OU back to Staff first
  Get-ADUser -SearchBase $ouTerm -Filter * -ErrorAction Stop | ForEach-Object {
    Move-ADObject $_.DistinguishedName -TargetPath $ouStaff -ErrorAction SilentlyContinue
  }
  Set-ADOrganizationalUnit -Identity $ouTerm -ProtectedFromAccidentalDeletion $false -ErrorAction SilentlyContinue
  Remove-ADOrganizationalUnit -Identity $ouTerm -Confirm:$false -ErrorAction SilentlyContinue
  Write-Host "  Removed Terminated OU"
} catch {
  # OU doesn't exist, that's fine
}

# -------------------------------------------------------
# 6. Clean up evidence folders (L4.2, L4.3)
# -------------------------------------------------------
$podLab = "C:\CyberLab\$podName"
if (Test-Path $podLab) {
  Remove-Item -Recurse -Force "$podLab\Lab4-2" -ErrorAction SilentlyContinue
  Remove-Item -Recurse -Force "$podLab\Lab4-3" -ErrorAction SilentlyContinue
  Write-Host "  Cleaned evidence folders under $podLab"
}

Write-Host "=== AC lab reset complete for $podName ==="
