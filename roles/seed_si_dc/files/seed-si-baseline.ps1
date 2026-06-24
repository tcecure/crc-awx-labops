# seed-si-baseline.ps1
# Creates SI lab baseline structure for a given pod
# Ensures pod OU exists and creates SI-Artifacts directory

param(
    [Parameter(Mandatory=$true)]
    [ValidateRange(1,20)]
    [int]$PodId
)

Import-Module ActiveDirectory

$podName    = "Pod{0:D2}" -f $PodId
$prefix     = "P{0:D2}" -f $PodId
$domainDN   = "DC=acs-p01,DC=local"
$studentsOU = "OU=Students,$domainDN"
$podOU      = "OU=$podName,$studentsOU"
$usersOU    = "OU=Users,$podOU"
$deptOU     = "OU=Departments,$podOU"
$resOU      = "OU=Resources,$podOU"

# Ensure pod OU structure exists (idempotent)
foreach ($ou in @($studentsOU, $podOU, $usersOU, $deptOU, $resOU)) {
    if (-not [adsi]::Exists("LDAP://$ou")) {
        $parentDN = ($ou -split ',', 2)[1]
        $ouName   = (($ou -split ',')[0]) -replace 'OU=',''
        New-ADOrganizationalUnit -Name $ouName -Path $parentDN -ProtectedFromAccidentalDeletion $false
        Write-Host "[CREATED] $ou"
    }
}

# Create SI-Artifacts directory per pod
$artifactPath = "C:\CyberLab\$podName\SI-Artifacts"
if (-not (Test-Path $artifactPath)) {
    New-Item -Path $artifactPath -ItemType Directory -Force | Out-Null
    Write-Host "[CREATED] $artifactPath"
} else {
    Write-Host "[EXISTS] $artifactPath"
}

# Ensure PXX-d.chen exists (shared with IA - create only if missing)
$dchenSam = "$prefix-d.chen"
try {
    Get-ADUser -Identity $dchenSam -ErrorAction Stop | Out-Null
    Write-Host "[EXISTS] $dchenSam (shared with IA)"
} catch {
    New-ADUser -Name "$prefix-d.chen" `
        -SamAccountName $dchenSam `
        -UserPrincipalName "$dchenSam@acs-p01.local" `
        -GivenName "David" -Surname "Chen" `
        -DisplayName "$prefix - David Chen" `
        -Description "Software Developer - Build Tools Team" `
        -Path $usersOU `
        -AccountPassword (ConvertTo-SecureString "Welcome!2026" -AsPlainText -Force) `
        -Enabled $true `
        -PasswordNeverExpires $true
    Write-Host "[CREATED] $dchenSam in $usersOU"
}

Write-Host "`n[SI-BASELINE] Pod $podName baseline complete."
