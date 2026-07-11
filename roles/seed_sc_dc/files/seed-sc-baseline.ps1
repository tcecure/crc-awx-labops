# seed-sc-baseline.ps1
# Creates SC lab baseline structure on DC01 for a given pod
# Deploys artifact templates and lab markers

param(
    [Parameter(Mandatory=$true)]
    [ValidateRange(1,20)]
    [int]$PodId
)

$podName    = "Pod{0:D2}" -f $PodId
$prefix     = "P{0:D2}" -f $PodId
$domainDN   = "DC=acs-p01,DC=local"
$studentsOU = "OU=Students,$domainDN"
$podOU      = "OU=$podName,$studentsOU"

# Ensure pod OU exists (shared with AC/IA/SI)
if (-not [adsi]::Exists("LDAP://$studentsOU")) {
    New-ADOrganizationalUnit -Name "Students" -Path $domainDN -ProtectedFromAccidentalDeletion $false
    Write-Host "[CREATED] $studentsOU"
}
if (-not [adsi]::Exists("LDAP://$podOU")) {
    New-ADOrganizationalUnit -Name $podName -Path $studentsOU -ProtectedFromAccidentalDeletion $false
    Write-Host "[CREATED] $podOU"
}

# Create SC-Artifacts directory
$artifactPath = "C:\CyberLab\$podName\SC-Artifacts"
if (-not (Test-Path $artifactPath)) {
    New-Item -Path $artifactPath -ItemType Directory -Force | Out-Null
    Write-Host "[CREATED] $artifactPath"
} else {
    Write-Host "[EXISTS] $artifactPath"
}

Write-Host "`n[SC-BASELINE] Pod $podName DC baseline complete."
