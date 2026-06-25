param(
  [Parameter(Mandatory=$true)]
  [ValidateRange(1,20)]
  [int]$PodId,
  [string]$SeedPassword = $env:SEED_USER_PASSWORD
)

Import-Module ActiveDirectory

$domainDN = (Get-ADDomain).DistinguishedName
$podName  = "Pod{0:D2}" -f $PodId
$prefix   = "P{0:D2}" -f $PodId
$podOU    = "OU=$podName,OU=Students,$domainDN"

# Verify pod OU exists (created during Phase 2 OU build)
try { Get-ADOrganizationalUnit -Identity $podOU -ErrorAction Stop | Out-Null }
catch { throw "Pod OU not found: $podOU. Run Phase 2 OU build first." }

function Ensure-OU($name, $path) {
  $dn = "OU=$name,$path"
  try { Get-ADOrganizationalUnit -Identity $dn -ErrorAction Stop | Out-Null }
  catch { New-ADOrganizationalUnit -Name $name -Path $path -ProtectedFromAccidentalDeletion $false | Out-Null }
  return $dn
}

# Sub-OU structure (mirrors AC baseline — idempotent if AC already ran)
$ouPodUsers     = "OU=Users,$podOU"
$ouPodGroups    = "OU=Groups,$podOU"
$ouPodResources = "OU=Resources,$podOU"

$ouDepartments  = Ensure-OU "Departments" $ouPodResources
$null           = Ensure-OU "Executive"   $ouDepartments
$null           = Ensure-OU "IT"          $ouDepartments
$null           = Ensure-OU "Finance"     $ouDepartments
$null           = Ensure-OU "HR"          $ouDepartments
$null           = Ensure-OU "Consulting"  $ouDepartments
$ouSales        = Ensure-OU "Sales"       $ouDepartments

$ouAdmins       = Ensure-OU "Admins"      $ouPodUsers
$ouStaff        = Ensure-OU "Staff"       $ouPodUsers
$null           = Ensure-OU "Terminated"  $ouPodUsers

$ouSecGroups    = Ensure-OU "Security"     $ouPodGroups
$null           = Ensure-OU "Distribution" $ouPodGroups

# Security groups (idempotent — AC baseline may have created these already)
$groups = @(
  "$prefix-SG-ACS-Executive",
  "$prefix-SG-ACS-IT",
  "$prefix-SG-ACS-Finance",
  "$prefix-SG-ACS-HR",
  "$prefix-SG-ACS-Consulting",
  "$prefix-SG-ACS-Sales",
  "$prefix-SG-ACS-IT-Admins",
  "$prefix-SG-ACS-Helpdesk",
  "$prefix-SG-ACS-All-Staff",
  "$prefix-SG-ACS-Workstation-Admins"
)
foreach ($g in $groups) {
  if (-not (Get-ADGroup -Filter "Name -eq '$g'" -ErrorAction SilentlyContinue)) {
    New-ADGroup -Name $g -SamAccountName $g -GroupScope Global -GroupCategory Security -Path $ouSecGroups | Out-Null
  }
}

# Per-pod evidence directories for IA labs
$podRoot = "C:\CyberLab\$podName"
foreach ($d in @(
  $podRoot,
  "$podRoot\IA-Artifacts",
  "$podRoot\IA-Artifacts\Vault",
  "$podRoot\LabArtifacts",
  "$podRoot\LabArtifacts\Scripts",
  "$podRoot\LabArtifacts\Scans"
)) {
  New-Item -ItemType Directory -Path $d -Force | Out-Null
}

Write-Host "$podName IA baseline complete on $((Get-ADDomain).DNSRoot)"
