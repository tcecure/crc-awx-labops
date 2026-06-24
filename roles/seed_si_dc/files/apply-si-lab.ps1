# apply-si-lab.ps1
# Seeds all 12 SI lab scenarios for a given pod
# All artifacts are text-based files deployed to C:\CyberLab\PodXX\SI-Artifacts\
# LabId can be ALL (default) or specific like M1-L1

param(
    [Parameter(Mandatory=$true)]
    [ValidateRange(1,20)]
    [int]$PodId,

    [Parameter(Mandatory=$false)]
    [string]$LabId = "ALL",

    [Parameter(Mandatory=$false)]
    [string]$TemplatesPath = "C:\CyberLab\_Templates\SI"
)

$podName    = "Pod{0:D2}" -f $PodId
$prefix     = "P{0:D2}" -f $PodId
$podPadded  = "{0:D2}" -f $PodId
$artifactDir = "C:\CyberLab\$podName\SI-Artifacts"

# Ensure artifact directory exists
if (-not (Test-Path $artifactDir)) {
    New-Item -Path $artifactDir -ItemType Directory -Force | Out-Null
}

function Deploy-Template {
    param(
        [string]$TemplateName,
        [string]$OutputName
    )
    $src = Join-Path $TemplatesPath $TemplateName
    $dst = Join-Path $artifactDir $OutputName
    if (Test-Path $src) {
        Copy-Item -Path $src -Destination $dst -Force
        Write-Host "[DEPLOYED] $OutputName"
    } else {
        Write-Host "[WARN] Template not found: $TemplateName"
    }
}

function Set-LabMarker {
    param([string]$Lab)
    $marker = Join-Path $artifactDir "_LAB_READY_SI-$Lab.txt"
    $ts = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Set-Content -Path $marker -Value "SI Lab $Lab seeded for $podName at $ts"
    Write-Host "[MARKER] _LAB_READY_SI-$Lab.txt"
}

# ========================================================================
# MODULE 1 — Flaw Remediation Foundations
# ========================================================================

function Seed-M1-L1 {
    # Understanding System Flaws — 5 example flaws for classification
    Deploy-Template "SI_Flaw_Examples.txt" "SI-M1-L1_Flaw_Examples.txt"
    Deploy-Template "SI_Flaw_Identification_Worksheet.txt" "SI-M1-L1_Worksheet.txt"
    Deploy-Template "SI_Remediation_Timeline_Policy.txt" "ACS-POL-SI-002_Remediation_Timeline.txt"
    Set-LabMarker "M1-L1"
}

function Seed-M1-L2 {
    # Active vs Passive Flaw Identification — 3 source documents
    Deploy-Template "SI_CISA_Advisory_Sample.txt" "SI-M1-L2_CISA_Advisory.txt"
    Deploy-Template "SI_Vendor_Alert_Sample.txt" "SI-M1-L2_Vendor_Alert.txt"
    Deploy-Template "SI_Blog_Rumor_Sample.txt" "SI-M1-L2_Blog_Post.txt"
    Deploy-Template "SI_Source_Classification_Worksheet.txt" "SI-M1-L2_Worksheet.txt"
    Set-LabMarker "M1-L2"
}

function Seed-M1-L3 {
    # Window of Exposure Calculation — CSV with 8 findings
    Deploy-Template "SI_Exposure_Calculation.csv" "SI-M1-L3_Exposure_Data.csv"
    Deploy-Template "SI_Window_of_Exposure_Timeline.txt" "SI-M1-L3_Timeline_Reference.txt"
    Deploy-Template "SI_Remediation_Timeline_Policy.txt" "ACS-POL-SI-002_Remediation_Timeline.txt"
    Deploy-Template "SI_Risk_Timeline_Reference.txt" "SI-M1-L3_Quick_Reference.txt"
    Set-LabMarker "M1-L3"
}

# ========================================================================
# MODULE 2 — Vulnerability Assessment and Patch Verification
# ========================================================================

function Seed-M2-L1 {
    # Read a Vulnerability Scan — Realistic Nessus report
    Deploy-Template "SI_Nessus_Report.txt" "SI-M2-L1_Nessus_Scan.txt"
    Deploy-Template "SI_Remediation_Timeline_Policy.txt" "ACS-POL-SI-002_Remediation_Timeline.txt"
    Set-LabMarker "M2-L1"
}

function Seed-M2-L2 {
    # Patch Verification — patch log with failures
    Deploy-Template "SI_Patch_Log.csv" "SI-M2-L2_Patch_History.csv"
    Deploy-Template "SI_Failed_Update_Evidence.txt" "SI-M2-L2_Event_Log.txt"
    Set-LabMarker "M2-L2"
}

function Seed-M2-L3 {
    # Remediation Reporting — student creates report and ticket
    Deploy-Template "SI_Vulnerability_Report_Form.txt" "SI-M2-L3_Report_Form.txt"
    Deploy-Template "SI_Remediation_Ticket_Template.txt" "SI-M2-L3_Ticket_Template.txt"
    Deploy-Template "SI_Nessus_Report.txt" "SI-M2-L3_Nessus_Reference.txt"
    Deploy-Template "SI_Risk_Timeline_Reference.txt" "SI-M2-L3_Timeline_Reference.txt"
    Set-LabMarker "M2-L3"
}

# ========================================================================
# MODULE 3 — Malware Protection Status
# ========================================================================

function Seed-M3-L1 {
    # Verify AV Installation and Coverage — inventory with mixed status
    Deploy-Template "SI_AV_Coverage_Inventory.csv" "SI-M3-L1_AV_Inventory.csv"
    Deploy-Template "SI_Endpoint_Status_Report.csv" "SI-M3-L1_Endpoint_Status.csv"
    Deploy-Template "SI_Malware_Protection_Policy.txt" "ACS-POL-SI-003_Malware_Protection.txt"
    Set-LabMarker "M3-L1"
}

function Seed-M3-L2 {
    # Review Malware Scan Logs — scan history with good events
    Deploy-Template "SI_Scan_History_Report.csv" "SI-M3-L2_Scan_History.csv"
    Deploy-Template "SI_Defender_Event_Log.txt" "SI-M3-L2_Event_Log.txt"
    Set-LabMarker "M3-L2"
}

function Seed-M3-L3 {
    # Old Definitions Check — definition status showing outdated systems
    Deploy-Template "SI_Definition_Status_Report.csv" "SI-M3-L3_Definition_Status.csv"
    Deploy-Template "SI_AV_Coverage_Inventory.csv" "SI-M3-L3_Coverage_Reference.csv"
    Deploy-Template "SI_Malware_Protection_Policy.txt" "ACS-POL-SI-003_Malware_Protection.txt"
    Set-LabMarker "M3-L3"
}

# ========================================================================
# MODULE 4 — GPO Enforcement and Rogue Developer
# ========================================================================

function Seed-M4-L1 {
    # Defender GPO Review — staged GPO report
    Deploy-Template "SI_GPO_Report_Defender_Policy.txt" "SI-M4-L1_GPO_Report.txt"
    Deploy-Template "SI_Malware_Protection_Policy.txt" "ACS-POL-SI-003_Malware_Protection.txt"
    Set-LabMarker "M4-L1"
}

function Seed-M4-L2 {
    # Event Viewer: Disabled Protection — event log showing tampering
    Deploy-Template "SI_RogueDeveloper_EventLog.txt" "SI-M4-L2_Security_Events.txt"
    Deploy-Template "SI_Malware_Protection_Policy.txt" "ACS-POL-SI-003_Malware_Protection.txt"
    Set-LabMarker "M4-L2"
}

function Seed-M4-L3 {
    # Rogue Developer Scenario — full incident investigation
    Deploy-Template "SI_RogueDeveloper_EventLog.txt" "SI-M4-L3_Event_Evidence.txt"
    Deploy-Template "SI_RogueDeveloper_Interview.txt" "SI-M4-L3_Interview_Transcript.txt"
    Deploy-Template "SI_Exclusion_Request_Form.txt" "SI-M4-L3_Exclusion_Form.txt"
    Deploy-Template "SI_Malware_Protection_Policy.txt" "ACS-POL-SI-003_Malware_Protection.txt"
    Deploy-Template "SI_GPO_Report_Defender_Policy.txt" "SI-M4-L3_GPO_Reference.txt"
    Set-LabMarker "M4-L3"
}

# ========================================================================
# EXECUTION
# ========================================================================

$labs = @{
    "M1-L1" = { Seed-M1-L1 }
    "M1-L2" = { Seed-M1-L2 }
    "M1-L3" = { Seed-M1-L3 }
    "M2-L1" = { Seed-M2-L1 }
    "M2-L2" = { Seed-M2-L2 }
    "M2-L3" = { Seed-M2-L3 }
    "M3-L1" = { Seed-M3-L1 }
    "M3-L2" = { Seed-M3-L2 }
    "M3-L3" = { Seed-M3-L3 }
    "M4-L1" = { Seed-M4-L1 }
    "M4-L2" = { Seed-M4-L2 }
    "M4-L3" = { Seed-M4-L3 }
}

Write-Host "======================================================"
Write-Host " SI LAB SEEDING — $podName ($prefix)"
Write-Host "======================================================"

if ($LabId -eq "ALL") {
    foreach ($lab in ($labs.Keys | Sort-Object)) {
        Write-Host "`n--- Seeding $lab ---"
        & $labs[$lab]
    }
} else {
    if ($labs.ContainsKey($LabId)) {
        Write-Host "`n--- Seeding $LabId ---"
        & $labs[$LabId]
    } else {
        Write-Host "[ERROR] Unknown LabId: $LabId. Valid: M1-L1..M4-L3 or ALL"
        exit 1
    }
}

Write-Host "`n======================================================"
Write-Host " SI SEEDING COMPLETE — $podName"
$markerCount = (Get-ChildItem $artifactDir -Filter "_LAB_READY_SI-*.txt" | Measure-Object).Count
Write-Host " Lab markers present: $markerCount / 12"
Write-Host "======================================================"
