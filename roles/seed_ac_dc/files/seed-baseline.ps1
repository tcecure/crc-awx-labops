param(
  [Parameter(Mandatory=$true)]
  [ValidateRange(1,10)]
  [int]$PodId,
  [string]$SeedPassword = $env:SEED_USER_PASSWORD
)

Import-Module ActiveDirectory

$domainDN = (Get-ADDomain).DistinguishedName
$podName = "Pod{0:D2}" -f $PodId
$podOU = "OU=$podName,OU=Students,$domainDN"

# Verify pod OU exists (created during Phase 2 OU build)
try { Get-ADOrganizationalUnit -Identity $podOU -ErrorAction Stop | Out-Null }
catch { throw "Pod OU not found: $podOU. Run Phase 2 OU build first." }

function Ensure-OU($name, $path) {
  $dn = "OU=$name,$path"
  try { Get-ADOrganizationalUnit -Identity $dn -ErrorAction Stop | Out-Null }
  catch { New-ADOrganizationalUnit -Name $name -Path $path -ProtectedFromAccidentalDeletion $false | Out-Null }
  return $dn
}

# Build sub-OU structure under the pod OU
# OU=PodXX,OU=Students already has Users, Groups, Resources, Policies from Phase 2
# Add departmental sub-OUs under Resources for lab scenarios
$ouPodUsers     = "OU=Users,$podOU"
$ouPodGroups    = "OU=Groups,$podOU"
$ouPodResources = "OU=Resources,$podOU"

# Department sub-OUs under Resources (for lab scenarios)
$ouDepartments  = Ensure-OU "Departments" $ouPodResources
$ouExec         = Ensure-OU "Executive"   $ouDepartments
$ouIT           = Ensure-OU "IT"          $ouDepartments
$ouFinance      = Ensure-OU "Finance"     $ouDepartments
$ouHR           = Ensure-OU "HR"          $ouDepartments
$ouConsulting   = Ensure-OU "Consulting"  $ouDepartments
$ouSales        = Ensure-OU "Sales"       $ouDepartments

# User sub-OUs
$ouAdmins       = Ensure-OU "Admins" $ouPodUsers
$ouStaff        = Ensure-OU "Staff"  $ouPodUsers

# Group sub-OUs
$ouSecGroups    = Ensure-OU "Security"     $ouPodGroups
$ouDistGroups   = Ensure-OU "Distribution" $ouPodGroups

# Computer sub-OUs
$ouComputers    = Ensure-OU "Computers"    $ouPodResources
$ouWorkstations = Ensure-OU "Workstations" $ouComputers
$ouServers      = Ensure-OU "Servers"      $ouComputers

# Per-pod security groups (prefixed with pod name for isolation)
$prefix = "P{0:D2}" -f $PodId
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

$pw = ConvertTo-SecureString $SeedPassword -AsPlainText -Force

function Ensure-User($sam, $display, $path, $memberOf) {
  if (-not (Get-ADUser -Filter "SamAccountName -eq '$sam'" -ErrorAction SilentlyContinue)) {
    New-ADUser `
      -SamAccountName $sam `
      -UserPrincipalName "$sam@$((Get-ADDomain).DNSRoot)" `
      -Name $display `
      -DisplayName $display `
      -Path $path `
      -AccountPassword $pw `
      -Enabled $true `
      -PasswordNeverExpires $false `
      -ChangePasswordAtLogon $false | Out-Null
  }
  foreach ($grp in $memberOf) {
    Add-ADGroupMember -Identity $grp -Members $sam -ErrorAction SilentlyContinue
  }
}

# Per-pod users (prefixed with pod number for isolation)
Ensure-User "$prefix-ceo.acs"        "$podName ACS CEO"         $ouStaff  @("$prefix-SG-ACS-Executive","$prefix-SG-ACS-All-Staff")
Ensure-User "$prefix-it.admin"       "$podName ACS IT Admin"    $ouAdmins @("$prefix-SG-ACS-IT","$prefix-SG-ACS-IT-Admins")
Ensure-User "$prefix-it.helpdesk"    "$podName ACS Helpdesk"    $ouAdmins @("$prefix-SG-ACS-IT","$prefix-SG-ACS-Helpdesk")
Ensure-User "$prefix-fin.user1"      "$podName ACS Finance 1"   $ouStaff  @("$prefix-SG-ACS-Finance","$prefix-SG-ACS-All-Staff")
Ensure-User "$prefix-hr.user1"       "$podName ACS HR 1"        $ouStaff  @("$prefix-SG-ACS-HR","$prefix-SG-ACS-All-Staff")
Ensure-User "$prefix-consult.user1"  "$podName ACS Consultant"  $ouStaff  @("$prefix-SG-ACS-Consulting","$prefix-SG-ACS-All-Staff")
Ensure-User "$prefix-sales.user1"    "$podName ACS Sales 1"     $ouStaff  @("$prefix-SG-ACS-Sales","$prefix-SG-ACS-All-Staff")

Write-Host "$podName baseline seed complete on $((Get-ADDomain).DNSRoot)"
