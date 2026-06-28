# apply-sc-lab.ps1
# Deploys SC lab artifacts to DC01 for document-based labs
# and creates lab markers for all 12 SC labs
# SC labs primarily run on pfSense (PodXX-GW) but DC01 holds:
#   - Lab completion markers
#   - Evidence templates for document-based labs
#   - Compliance checklists

param(
    [Parameter(Mandatory=$true)]
    [ValidateRange(1,20)]
    [int]$PodId,

    [Parameter(Mandatory=$false)]
    [string]$LabId = "ALL",

    [Parameter(Mandatory=$false)]
    [string]$TemplatesPath = "C:\CyberLab\_Templates\SC"
)

$podName    = "Pod{0:D2}" -f $PodId
$prefix     = "P{0:D2}" -f $PodId
$podPadded  = "{0:D2}" -f $PodId
$gwIp       = "10.51.$PodId.1"
$artifactDir = "C:\CyberLab\$podName\SC-Artifacts"

if (-not (Test-Path $artifactDir)) {
    New-Item -Path $artifactDir -ItemType Directory -Force | Out-Null
}

function Deploy-Template {
    param(
        [string]$TemplateName,
        [string]$OutputName
    )
    $srcJ2 = Join-Path $TemplatesPath "$TemplateName.j2"
    $srcPlain = Join-Path $TemplatesPath $TemplateName
    if (Test-Path $srcJ2) {
        $content = Get-Content -Path $srcJ2 -Raw
        $content = $content -replace '\{\{\s*prefix\s*\}\}', $prefix
        $content = $content -replace '\{\{\s*pod_id_padded\s*\}\}', $podPadded
        $content = $content -replace '\{\{\s*gw_ip\s*\}\}', $gwIp
        $content = $content -replace '\{\{\s*pod_name\s*\}\}', $podName
        $content = $content -replace '\{\{\s*ansible_date_time\.date\s*\|\s*default\([^)]*\)\s*\}\}', (Get-Date -Format 'yyyy-MM-dd')
        $content = $content -replace '\{\{\s*ansible_date_time\.date\s*\}\}', (Get-Date -Format 'yyyy-MM-dd')
        $dst = Join-Path $artifactDir $OutputName
        Set-Content -Path $dst -Value $content -NoNewline
        Write-Host "[DEPLOYED] $OutputName"
    } elseif (Test-Path $srcPlain) {
        Copy-Item -Path $srcPlain -Destination (Join-Path $artifactDir $OutputName) -Force
        Write-Host "[DEPLOYED] $OutputName"
    } else {
        Write-Host "[WARN] Template not found: $TemplateName"
    }
}

function Set-LabMarker {
    param([string]$Lab)
    $marker = Join-Path $artifactDir "_LAB_READY_SC-$Lab.txt"
    $ts = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Set-Content -Path $marker -Value "SC Lab $Lab seeded for $podName at $ts`nGateway: $gwIp`nWeb UI: http://$gwIp"
    Write-Host "[MARKER] _LAB_READY_SC-$Lab.txt"
}

# ========================================================================
# MODULE 1: Foundations of the Digital Perimeter
# ========================================================================

function Seed-M1-L1 {
    # Understanding Trust Boundaries - boundary diagram worksheet
    Deploy-Template "SC_Trust_Boundary_Worksheet.txt" "SC-M1-L1_Boundary_Worksheet.txt"
    Deploy-Template "SC_Network_Topology.txt" "SC-M1-L1_Network_Topology.txt"
    Set-LabMarker "M1-L1"
}

function Seed-M1-L2 {
    # Deny By Default Firewall
    Deploy-Template "SC_DenyByDefault_Instructions.txt" "SC-M1-L2_Lab_Instructions.txt"
    Set-LabMarker "M1-L2"
}

function Seed-M1-L3 {
    # Monitor, Control, Protect
    Deploy-Template "SC_MonitorControlProtect_Worksheet.txt" "SC-M1-L3_Worksheet.txt"
    Set-LabMarker "M1-L3"
}

# ========================================================================
# MODULE 2: External and Internal Boundaries
# ========================================================================

function Seed-M2-L1 {
    # Draw Organizational Boundary - diagram exercise
    Deploy-Template "SC_OrgBoundary_Worksheet.txt" "SC-M2-L1_Boundary_Worksheet.txt"
    Deploy-Template "SC_Network_Topology.txt" "SC-M2-L1_Network_Reference.txt"
    Set-LabMarker "M2-L1"
}

function Seed-M2-L2 {
    # Secure the DMZ
    Deploy-Template "SC_DMZ_Instructions.txt" "SC-M2-L2_Lab_Instructions.txt"
    Set-LabMarker "M2-L2"
}

function Seed-M2-L3 {
    # Internal Segmentation (VLANs)
    Deploy-Template "SC_VLAN_Segmentation_Plan.txt" "SC-M2-L3_Segmentation_Plan.txt"
    Set-LabMarker "M2-L3"
}

# ========================================================================
# MODULE 3: Firewall Rules
# ========================================================================

function Seed-M3-L1 {
    # Firewall Rule Audit
    Deploy-Template "SC_RuleAudit_Worksheet.txt" "SC-M3-L1_Audit_Worksheet.txt"
    Set-LabMarker "M3-L1"
}

function Seed-M3-L2 {
    # Rule Ordering Challenge
    Deploy-Template "SC_RuleOrdering_Instructions.txt" "SC-M3-L2_Lab_Instructions.txt"
    Set-LabMarker "M3-L2"
}

function Seed-M3-L3 {
    # Least Privilege Access
    Deploy-Template "SC_LeastPrivilege_Instructions.txt" "SC-M3-L3_Lab_Instructions.txt"
    Set-LabMarker "M3-L3"
}

# ========================================================================
# MODULE 4: Monitoring and Validation
# ========================================================================

function Seed-M4-L1 {
    # Firewall Log Investigation
    Deploy-Template "SC_LogInvestigation_Worksheet.txt" "SC-M4-L1_Investigation_Worksheet.txt"
    Set-LabMarker "M4-L1"
}

function Seed-M4-L2 {
    # Verify SC Compliance
    Deploy-Template "SC_Compliance_Checklist.txt" "SC-M4-L2_Compliance_Checklist.txt"
    Set-LabMarker "M4-L2"
}

function Seed-M4-L3 {
    # Final Capstone
    Deploy-Template "SC_Capstone_Instructions.txt" "SC-M4-L3_Capstone_Instructions.txt"
    Deploy-Template "SC_Compliance_Checklist.txt" "SC-M4-L3_Compliance_Checklist.txt"
    Set-LabMarker "M4-L3"
}

# ========================================================================
# EXECUTION
# ========================================================================

function Apply-Lab {
    param([string]$Lab)
    switch ($Lab) {
        "M1-L1" { Seed-M1-L1 }
        "M1-L2" { Seed-M1-L2 }
        "M1-L3" { Seed-M1-L3 }
        "M2-L1" { Seed-M2-L1 }
        "M2-L2" { Seed-M2-L2 }
        "M2-L3" { Seed-M2-L3 }
        "M3-L1" { Seed-M3-L1 }
        "M3-L2" { Seed-M3-L2 }
        "M3-L3" { Seed-M3-L3 }
        "M4-L1" { Seed-M4-L1 }
        "M4-L2" { Seed-M4-L2 }
        "M4-L3" { Seed-M4-L3 }
        default { Write-Host "[ERROR] Unknown LabId: $Lab"; exit 1 }
    }
}

Write-Host "======================================================"
Write-Host " SC DC LAB SEEDING - $podName ($prefix)"
Write-Host " Gateway: $gwIp | Web UI: http://$gwIp"
Write-Host "======================================================"

if ($LabId -eq "ALL") {
    $allLabs = @("M1-L1","M1-L2","M1-L3","M2-L1","M2-L2","M2-L3","M3-L1","M3-L2","M3-L3","M4-L1","M4-L2","M4-L3")
    foreach ($lab in $allLabs) {
        Write-Host "`n--- Seeding $lab ---"
        Apply-Lab $lab
    }
} else {
    Write-Host "`n--- Seeding $LabId ---"
    Apply-Lab $LabId
}

Write-Host "`n======================================================"
Write-Host " SC DC SEEDING COMPLETE - $podName"
$markerCount = (Get-ChildItem $artifactDir -Filter "_LAB_READY_SC-*.txt" | Measure-Object).Count
Write-Host " Lab markers present: $markerCount / 12"
Write-Host "======================================================"
