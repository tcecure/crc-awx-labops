param(
  [string]$SeedPassword = $env:SEED_USER_PASSWORD
)

Import-Module ActiveDirectory

$domainDN = (Get-ADDomain).DistinguishedName

$ouACS = "OU=ACS,$domainDN"
try { Get-ADOrganizationalUnit -Identity $ouACS -ErrorAction Stop | Out-Null }
catch { New-ADOrganizationalUnit -Name "ACS" -Path $domainDN | Out-Null }

function Ensure-OU($name, $path) {
  $dn = "OU=$name,$path"
  try { Get-ADOrganizationalUnit -Identity $dn -ErrorAction Stop | Out-Null }
  catch { New-ADOrganizationalUnit -Name $name -Path $path | Out-Null }
  return $dn
}

$ouDepartments  = Ensure-OU "Departments" $ouACS
$ouUsers        = Ensure-OU "Users" $ouACS
$ouGroups       = Ensure-OU "Groups" $ouACS
$ouComputers    = Ensure-OU "Computers" $ouACS

$ouExec         = Ensure-OU "Executive"  $ouDepartments
$ouIT           = Ensure-OU "IT"         $ouDepartments
$ouFinance      = Ensure-OU "Finance"    $ouDepartments
$ouHR           = Ensure-OU "HR"         $ouDepartments
$ouConsulting   = Ensure-OU "Consulting" $ouDepartments
$ouSales        = Ensure-OU "Sales"      $ouDepartments

$ouAdmins       = Ensure-OU "Admins" $ouUsers
$ouStaff        = Ensure-OU "Staff"  $ouUsers

$ouSecGroups    = Ensure-OU "Security"      $ouGroups
$ouDistGroups   = Ensure-OU "Distribution"  $ouGroups

$ouWorkstations = Ensure-OU "Workstations" $ouComputers
$ouServers      = Ensure-OU "Servers"      $ouComputers

$groups = @(
  "SG-ACS-Executive",
  "SG-ACS-IT",
  "SG-ACS-Finance",
  "SG-ACS-HR",
  "SG-ACS-Consulting",
  "SG-ACS-Sales",
  "SG-ACS-IT-Admins",
  "SG-ACS-Helpdesk",
  "SG-ACS-All-Staff",
  "SG-ACS-Workstation-Admins"
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

Ensure-User "ceo.acs"        "ACS CEO"         $ouStaff  @("SG-ACS-Executive","SG-ACS-All-Staff")
Ensure-User "it.admin"       "ACS IT Admin"    $ouAdmins @("SG-ACS-IT","SG-ACS-IT-Admins","Domain Admins")
Ensure-User "it.helpdesk"    "ACS Helpdesk"    $ouAdmins @("SG-ACS-IT","SG-ACS-Helpdesk")
Ensure-User "fin.user1"      "ACS Finance 1"   $ouStaff  @("SG-ACS-Finance","SG-ACS-All-Staff")
Ensure-User "hr.user1"       "ACS HR 1"        $ouStaff  @("SG-ACS-HR","SG-ACS-All-Staff")
Ensure-User "consult.user1"  "ACS Consultant"  $ouStaff  @("SG-ACS-Consulting","SG-ACS-All-Staff")
Ensure-User "sales.user1"    "ACS Sales 1"     $ouStaff  @("SG-ACS-Sales","SG-ACS-All-Staff")

Get-ADComputer -Filter * | ForEach-Object {
  if ($_.Name -like "DC01-*") {
    Move-ADObject -Identity $_.DistinguishedName -TargetPath $ouServers -ErrorAction SilentlyContinue
  }
  elseif ($_.Name -like "WS01-*") {
    Move-ADObject -Identity $_.DistinguishedName -TargetPath $ouWorkstations -ErrorAction SilentlyContinue
  }
}

Write-Host "ACS baseline seed complete on $((Get-ADDomain).DNSRoot)"
