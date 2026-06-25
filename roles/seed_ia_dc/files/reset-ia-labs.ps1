param(
  [Parameter(Mandatory=$true)]
  [ValidateRange(1,20)]
  [int]$PodId
)

Import-Module ActiveDirectory

$domainDN = (Get-ADDomain).DistinguishedName
$podName  = "Pod{0:D2}" -f $PodId
$prefix   = "P{0:D2}" -f $PodId
$podOU    = "OU=$podName,OU=Students,$domainDN"
$podRoot  = "C:\CyberLab\$podName"

# ── Remove IA-created AD users ──────────────────────────────────────
$iaUsers = @(
  "$prefix-frontdesk",
  "$prefix-k.omalley",
  "$prefix-temp.agency01",
  "$prefix-tom.davis",
  "$prefix-admin",
  "$prefix-user1",
  "$prefix-test",
  "$prefix-s.jenkins",
  "$prefix-svc_backup",
  "$prefix-svc_web",
  "$prefix-svc_print",
  "$prefix-d.chen"
)

foreach ($sam in $iaUsers) {
  $u = Get-ADUser -Filter "SamAccountName -eq '$sam'" -ErrorAction SilentlyContinue
  if ($u) {
    Remove-ADUser -Identity $u -Confirm:$false
    Write-Host "  Removed user $sam"
  }
}

# ── Remove scheduled task ────────────────────────────────────────────
$taskName = "$podName ACS Nightly Backup"
Unregister-ScheduledTask -TaskName $taskName -Confirm:$false -ErrorAction SilentlyContinue
Write-Host "  Removed scheduled task: $taskName"

# ── Clean per-pod IA file artifacts ──────────────────────────────────
$filesToRemove = @(
  "$podRoot\M1-L1.txt",
  "$podRoot\M3-L1.txt",
  "$podRoot\M3-L3.txt",
  "$podRoot\M4-L1.txt",
  "$podRoot\M4-L3.txt",
  "$podRoot\IA-Artifacts\Authorized_Device_List.csv",
  "$podRoot\IA-Artifacts\Authorized_User_Inventory.csv",
  "$podRoot\IA-Artifacts\Device_Config_Record.csv",
  "$podRoot\IA-Artifacts\Hardening_Standard.txt",
  "$podRoot\IA-Artifacts\PasswordPolicy_Report.html",
  "$podRoot\IA-Artifacts\Service_Account_Matrix.csv",
  "$podRoot\IA-Artifacts\Vault\Vault_Entries.txt",
  "$podRoot\LabArtifacts\rogue_mac.txt",
  "$podRoot\LabArtifacts\Scripts\db_connect.py",
  "$podRoot\LabArtifacts\Scans\openvas_scan_report.txt"
)
foreach ($f in $filesToRemove) {
  Remove-Item -Path $f -Force -ErrorAction SilentlyContinue
}

# Remove lab-ready markers
Get-ChildItem -Path $podRoot -Filter "_LAB_READY_IA-*.txt" -ErrorAction SilentlyContinue |
  Remove-Item -Force -ErrorAction SilentlyContinue

Write-Host "$podName IA labs reset complete"
