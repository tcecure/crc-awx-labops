param(
  [Parameter(Mandatory=$true)]
  [ValidateSet(
    "M1-L1","M1-L2","M1-L3",
    "M2-L1","M2-L2","M2-L3",
    "M3-L1","M3-L2","M3-L3",
    "M4-L1","M4-L2","M4-L3",
    "ALL"
  )]
  [string]$LabId,
  [Parameter(Mandatory=$true)]
  [ValidateRange(1,20)]
  [int]$PodId,
  [string]$SeedPassword = $env:SEED_USER_PASSWORD
)

Import-Module ActiveDirectory

$domainDN  = (Get-ADDomain).DistinguishedName
$dnsRoot   = (Get-ADDomain).DNSRoot
$netBIOS   = (Get-ADDomain).NetBIOSName
$podName   = "Pod{0:D2}" -f $PodId
$prefix    = "P{0:D2}" -f $PodId
$podOU     = "OU=$podName,OU=Students,$domainDN"
$ouPodUsers     = "OU=Users,$podOU"
$ouPodResources = "OU=Resources,$podOU"
$ouStaff   = "OU=Staff,$ouPodUsers"
$ouAdmins  = "OU=Admins,$ouPodUsers"
$ouSales   = "OU=Sales,OU=Departments,$ouPodResources"
$pw        = ConvertTo-SecureString $SeedPassword -AsPlainText -Force

# Per-pod file paths
$podRoot      = "C:\CyberLab\$podName"
$iaArtifacts  = "$podRoot\IA-Artifacts"
$vault        = "$iaArtifacts\Vault"
$labArtifacts = "$podRoot\LabArtifacts"
$labScripts   = "$labArtifacts\Scripts"
$labScans     = "$labArtifacts\Scans"

function Ensure-OU($name, $path) {
  $dn = "OU=$name,$path"
  try { Get-ADOrganizationalUnit -Identity $dn -ErrorAction Stop | Out-Null }
  catch { New-ADOrganizationalUnit -Name $name -Path $path -ProtectedFromAccidentalDeletion $false | Out-Null }
  return $dn
}

function Ensure-User($sam, $display, $path, $groups, [hashtable]$extra = @{}) {
  if (-not (Get-ADUser -Filter "SamAccountName -eq '$sam'" -ErrorAction SilentlyContinue)) {
    $params = @{
      SamAccountName        = $sam
      UserPrincipalName     = "$sam@$dnsRoot"
      Name                  = $display
      DisplayName           = $display
      Path                  = $path
      AccountPassword       = $pw
      Enabled               = $true
      PasswordNeverExpires  = $false
      ChangePasswordAtLogon = $false
    }
    foreach ($k in $extra.Keys) { $params[$k] = $extra[$k] }
    New-ADUser @params | Out-Null
    Write-Host "  Created $sam"
  } else {
    Enable-ADAccount $sam -ErrorAction SilentlyContinue
    Write-Host "  $sam already exists, ensured enabled"
  }
  foreach ($g in $groups) {
    Add-ADGroupMember -Identity $g -Members $sam -ErrorAction SilentlyContinue
  }
}

function Remove-IfExists($sam) {
  $u = Get-ADUser -Filter "SamAccountName -eq '$sam'" -ErrorAction SilentlyContinue
  if ($u) {
    Remove-ADUser -Identity $u -Confirm:$false
    Write-Host "  Removed $sam"
  }
}

function Drop-Marker($labTag) {
  $ts = Get-Date -Format "o"
  Set-Content -Path "$podRoot\_LAB_READY_$labTag.txt" `
    -Value "Lab $labTag seeded at $ts. Students must remediate to PASS.`r`n"
}

# ── Lab seeds ────────────────────────────────────────────────────────

function Apply-Lab($id) {
  switch ($id) {

    # ── Module 1: User Identification ──────────────────────────────

    "M1-L1" {
      # Shared reception account — student must disable + create individual accounts
      Ensure-User "$prefix-frontdesk" "$podName Front Desk" $ouStaff @("$prefix-SG-ACS-All-Staff") @{PasswordNeverExpires=$true}
      Remove-IfExists "$prefix-k.omalley"
      Remove-IfExists "$prefix-temp.agency01"
      Remove-Item -Path "$podRoot\M1-L1.txt" -Force -ErrorAction SilentlyContinue
      Drop-Marker "IA-M1-L1"
      Write-Host "  M1-L1 seeded: $prefix-frontdesk enabled (shared account)"
    }

    "M1-L2" {
      # Zombie account — tom.davis still enabled in Sales after termination
      $null = Ensure-OU "Terminated" $ouPodUsers
      Ensure-User "$prefix-tom.davis" "$podName Tom Davis" $ouSales @("$prefix-SG-ACS-Sales") @{GivenName="Tom";Surname="Davis";PasswordNeverExpires=$true}
      Enable-ADAccount "$prefix-tom.davis" -ErrorAction SilentlyContinue
      Drop-Marker "IA-M1-L2"
      Write-Host "  M1-L2 seeded: $prefix-tom.davis enabled in Sales"
    }

    "M1-L3" {
      # Generic accounts present — student must disable and inventory
      $generics = @(
        @{Sam="$prefix-admin"; Name="$podName Admin Account";  Display="Admin"},
        @{Sam="$prefix-user1"; Name="$podName User1 Account";  Display="User1"},
        @{Sam="$prefix-test";  Name="$podName Test Account";   Display="Test"}
      )
      foreach ($g in $generics) {
        Ensure-User $g.Sam $g.Name $ouPodUsers @() @{PasswordNeverExpires=$true}
      }
      Remove-Item -Path "$iaArtifacts\Authorized_User_Inventory.csv" -Force -ErrorAction SilentlyContinue
      Drop-Marker "IA-M1-L3"
      Write-Host "  M1-L3 seeded: generic accounts ($prefix-admin, $prefix-user1, $prefix-test)"
    }

    # ── Module 2: Non-Person Entity Identification ─────────────────

    "M2-L1" {
      # Scheduled task runs as human account s.jenkins
      Remove-IfExists "$prefix-svc_backup"
      Ensure-User "$prefix-s.jenkins" "$podName Steve Jenkins" $ouStaff @("$prefix-SG-ACS-All-Staff") @{GivenName="Steve";Surname="Jenkins";PasswordNeverExpires=$true}

      $taskName = "$podName ACS Nightly Backup"
      Unregister-ScheduledTask -TaskName $taskName -Confirm:$false -ErrorAction SilentlyContinue
      # Use schtasks.exe for reliable task creation on DCs
      schtasks.exe /Create /TN $taskName /SC DAILY /ST 02:00 `
        /TR "powershell.exe -ExecutionPolicy Bypass -Command Write-Output 'Backup started'" `
        /RU "$netBIOS\$prefix-s.jenkins" /RP $SeedPassword /RL HIGHEST /F | Out-Null
      Drop-Marker "IA-M2-L1"
      Write-Host "  M2-L1 seeded: task '$taskName' running as $prefix-s.jenkins"
    }

    "M2-L2" {
      # Rogue device artifact — student must update device list + create config record
      $deviceCsv = @"
Hostname,MAC Address,IP Address,Status,Department,Last Verified
DC01-P01,00-15-5D-01-01-10,10.50.1.10,AUTHORIZED,IT,2026-01-15
WS01-P01,00-15-5D-01-01-20,10.50.1.20,AUTHORIZED,General,2026-01-15
PRINT-P01,00-15-5D-01-01-30,10.50.1.30,AUTHORIZED,Facilities,2026-01-15
"@
      Set-Content -Path "$iaArtifacts\Authorized_Device_List.csv" -Value $deviceCsv
      Set-Content -Path "$labArtifacts\rogue_mac.txt" -Value "AA-BB-CC-11-22-33`r`n"
      Remove-Item -Path "$iaArtifacts\Device_Config_Record.csv" -Force -ErrorAction SilentlyContinue
      Drop-Marker "IA-M2-L2"
      Write-Host "  M2-L2 seeded: device list + rogue MAC hint deployed"
    }

    "M2-L3" {
      # Service accounts with empty descriptions — student must document
      $svcAccounts = @(
        @{Sam="$prefix-svc_backup"; Name="$podName svc_backup"; Display="svc_backup"},
        @{Sam="$prefix-svc_web";    Name="$podName svc_web";    Display="svc_web"},
        @{Sam="$prefix-svc_print";  Name="$podName svc_print";  Display="svc_print"}
      )
      foreach ($svc in $svcAccounts) {
        Ensure-User $svc.Sam $svc.Name $ouPodUsers @() @{PasswordNeverExpires=$true}
        Set-ADUser $svc.Sam -Description "" -ErrorAction SilentlyContinue
      }
      Remove-Item -Path "$iaArtifacts\Service_Account_Matrix.csv" -Force -ErrorAction SilentlyContinue
      Drop-Marker "IA-M2-L3"
      Write-Host "  M2-L3 seeded: service accounts with empty descriptions"
    }

    # ── Module 3: User Authentication Management ───────────────────

    "M3-L1" {
      # Password policy report missing — evidence-only lab
      Remove-Item -Path "$iaArtifacts\PasswordPolicy_Report.html" -Force -ErrorAction SilentlyContinue
      Remove-Item -Path "$podRoot\M3-L1.txt" -Force -ErrorAction SilentlyContinue
      Drop-Marker "IA-M3-L1"
      Write-Host "  M3-L1 seeded: evidence files cleared"
    }

    "M3-L2" {
      # Weak password policy (domain-wide — affects all pods)
      # Set weak password policy via AD cmdlets (domain-level)
      Set-ADDefaultDomainPasswordPolicy -Identity $dnsRoot `
        -MinPasswordLength 6 `
        -ComplexityEnabled $false `
        -LockoutThreshold 0 `
        -PasswordHistoryCount 0 `
        -MaxPasswordAge (New-TimeSpan -Days 90) `
        -MinPasswordAge (New-TimeSpan -Days 0) `
        -ErrorAction SilentlyContinue
      Drop-Marker "IA-M3-L2"
      Write-Host "  M3-L2 seeded: weak password policy applied (domain-wide)"
    }

    "M3-L3" {
      # Must-change flag not set on d.chen
      Ensure-User "$prefix-d.chen" "$podName David Chen" $ouStaff @("$prefix-SG-ACS-All-Staff") @{GivenName="David";Surname="Chen"}
      Set-ADUser "$prefix-d.chen" -ChangePasswordAtLogon $false -ErrorAction SilentlyContinue
      Set-ADUser "$prefix-d.chen" -Replace @{pwdLastSet = -1} -ErrorAction SilentlyContinue
      Drop-Marker "IA-M3-L3"
      Write-Host "  M3-L3 seeded: $prefix-d.chen with must-change=false"
    }

    # ── Module 4: Defaults & Process Authentication ────────────────

    "M4-L1" {
      # Hardening standard missing default-password clause
      $hardening = @"
ACS Corporation - System Hardening Standard
Document Version: 1.2
Last Updated: 2026-01-10
Domain: acs-p01.local

1. OPERATING SYSTEM HARDENING
   - All servers must run supported OS versions
   - Automatic updates must be enabled
   - Unnecessary services must be disabled

2. NETWORK SECURITY
   - Firewalls must be enabled on all endpoints
   - Only required ports shall be open
   - SNMP must use complex community strings

3. ACCOUNT SECURITY
   - All accounts must have unique passwords
   - Service accounts must use managed passwords
   - Inactive accounts must be disabled after 30 days

4. LOGGING AND MONITORING
   - All authentication events must be logged
   - Logs must be retained for 90 days minimum
   - Failed login attempts must trigger alerts after 5 failures

5. PHYSICAL SECURITY
   - Server rooms must use badge access
   - Visitor access must be logged

NOTE: This document is incomplete. Additional hardening requirements
may need to be added per CMMC Level 1 controls.
"@
      Set-Content -Path "$iaArtifacts\Hardening_Standard.txt" -Value $hardening
      Remove-Item -Path "$podRoot\M4-L1.txt" -Force -ErrorAction SilentlyContinue
      Drop-Marker "IA-M4-L1"
      Write-Host "  M4-L1 seeded: hardening standard deployed (missing default-password clause)"
    }

    "M4-L2" {
      # SNMP scan report with 'public' community string finding
      $scanReport = @"
OpenVAS Scan Report - ACS Corporation $podName
Scan Date: 2026-01-20
Target Range: 10.50.1.0/24
Scanner: OpenVAS 22.4

=== FINDINGS ===

[HIGH] CVE-2024-XXXX - SNMP community string is public
  Host: 10.50.1.30 (PRINT-P01)
  Port: 161/udp
  Description: The SNMP agent on this device is configured with the
  default community string "public". This allows any network user to
  read device configuration, interface statistics, and routing tables.
  Remediation: Change the SNMP community string to a complex value
  and restrict SNMP access to management stations only.

[MEDIUM] SSL Certificate Expiring Soon
  Host: 10.50.1.10 (DC01-P01)
  Port: 443/tcp
  Description: The SSL certificate expires within 60 days.
  Remediation: Renew the certificate before expiration.

[INFO] Host Discovery
  Hosts found: 3 (DC01-P01, WS01-P01, PRINT-P01)

=== END OF REPORT ===
"@
      Set-Content -Path "$labScans\openvas_scan_report.txt" -Value $scanReport
      Remove-Item -Path "$iaArtifacts\Device_Config_Record.csv" -Force -ErrorAction SilentlyContinue
      Drop-Marker "IA-M4-L2"
      Write-Host "  M4-L2 seeded: SNMP scan report deployed"
    }

    "M4-L3" {
      # Script with hardcoded password123
      $script = @"
#!/usr/bin/env python3
# db_connect.py - ACS Database Connection Script
# Pod: $podName | Domain: acs-p01.local
# WARNING: This script contains hardcoded credentials

import pyodbc

DB_SERVER = "10.50.1.10"
DB_NAME = "ACS_Inventory"
DB_USER = "svc_web"
DB_PASSWORD = "password123"

def connect():
    conn_str = (
        f"DRIVER={{ODBC Driver 17 for SQL Server}};"
        f"SERVER={DB_SERVER};"
        f"DATABASE={DB_NAME};"
        f"UID={DB_USER};"
        f"PWD={DB_PASSWORD};"
    )
    return pyodbc.connect(conn_str)

def get_inventory():
    conn = connect()
    cursor = conn.cursor()
    cursor.execute("SELECT * FROM dbo.Assets")
    rows = cursor.fetchall()
    conn.close()
    return rows

if __name__ == "__main__":
    items = get_inventory()
    for item in items:
        print(item)
"@
      Set-Content -Path "$labScripts\db_connect.py" -Value $script
      Remove-Item -Path "$vault\Vault_Entries.txt" -Force -ErrorAction SilentlyContinue
      Remove-Item -Path "$podRoot\M4-L3.txt" -Force -ErrorAction SilentlyContinue
      Drop-Marker "IA-M4-L3"
      Write-Host "  M4-L3 seeded: db_connect.py with hardcoded password deployed"
    }
  }
}

# ── Execute ──────────────────────────────────────────────────────────

if ($LabId -eq "ALL") {
  # Order: M2-L3 before M2-L1 so svc_backup removal is the final state
  $allLabs = @("M1-L1","M1-L2","M1-L3","M2-L2","M2-L3","M2-L1","M3-L1","M3-L2","M3-L3","M4-L1","M4-L2","M4-L3")
  foreach ($lab in $allLabs) { Apply-Lab $lab }
  Write-Host "All IA labs seeded for $podName on $dnsRoot (shared DC mode)"
} else {
  Apply-Lab $LabId
  Write-Host "IA lab $LabId seeded for $podName on $dnsRoot"
}
