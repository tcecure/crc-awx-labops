param(
    [Parameter(Mandatory=$true)]
    [ValidateRange(1,20)]
    [int]$PodId,

    [Parameter(Mandatory=$false)]
    [ValidateSet("ALL", "M1-L1", "M1-L2", "M2-L1", "M2-L2", "M3-L1", "M3-L2")]
    [string]$LabId = "ALL",

    [Parameter(Mandatory=$false)]
    [string]$TemplatesPath = "C:\CyberLab\_Templates\PE",

    [Parameter(Mandatory=$false)]
    [bool]$ForceReseed = $false
)

$podName = "Pod{0:D2}" -f $PodId
$prefix = "P{0:D2}" -f $PodId
$podPadded = "{0:D2}" -f $PodId
$podRoot = "C:\CyberLab\$podName"
$artifactDir = Join-Path $podRoot "PE-Artifacts"
$familyMarker = Join-Path $podRoot ".families\PE.seeded"

if ((Test-Path $familyMarker) -and -not $ForceReseed) {
    Write-Host "[SKIP] PE is already seeded for $podName. Reset PE or use ForceReseed to seed again."
    exit 0
}

New-Item -Path $artifactDir -ItemType Directory -Force | Out-Null

function Deploy-Template {
    param([string]$TemplateName, [string]$OutputName)
    $source = Join-Path $TemplatesPath "$TemplateName.j2"
    if (-not (Test-Path $source)) { throw "Template not found: $TemplateName" }
    $content = Get-Content -Path $source -Raw
    $content = $content -replace '\{\{\s*prefix\s*\}\}', $prefix
    $content = $content -replace '\{\{\s*pod_id_padded\s*\}\}', $podPadded
    Set-Content -Path (Join-Path $artifactDir $OutputName) -Value $content -NoNewline
    Write-Host "[DEPLOYED] $OutputName"
}

function Set-LabMarker {
    param([string]$Lab)
    Set-Content -Path (Join-Path $artifactDir "_LAB_READY_PE-$Lab.txt") -Value "PE Lab $Lab seeded for $podName at $(Get-Date -Format o)"
}

function Seed-M1-L1 {
    Deploy-Template 'PE-M1-L1_EmployeeRoster.csv' 'PE-M1-L1_EmployeeRoster.csv'
    Deploy-Template 'PE-M1-L1_BadgeRoster.csv' 'PE-M1-L1_BadgeRoster.csv'
    Deploy-Template 'PE-M1-L1_ServerRoomAccessList.csv' 'PE-M1-L1_ServerRoomAccessList.csv'
    Deploy-Template 'PE-M1-L1_AccessReview.csv' 'PE-M1-L1_AccessReview.csv'
    Set-LabMarker 'M1-L1'
}

function Seed-M1-L2 {
    Deploy-Template 'PE-M1-L1_EmployeeRoster.csv' 'PE-M1-L2_EmployeeRoster.csv'
    Deploy-Template 'PE-M1-L1_ServerRoomAccessList.csv' 'PE-M1-L2_ServerRoomAccessList.csv'
    Deploy-Template 'PE-M1-L2_BadgeLog.csv' 'PE-M1-L2_BadgeLog.csv'
    Deploy-Template 'PE-M1-L2_ServerRoomLog.csv' 'PE-M1-L2_ServerRoomLog.csv'
    Deploy-Template 'PE-M1-L2_AccessDecision.csv' 'PE-M1-L2_AccessDecision.csv'
    Set-LabMarker 'M1-L2'
}

function Seed-M2-L1 {
    Deploy-Template 'PE-M2-L1_VisitorLog.csv' 'PE-M2-L1_VisitorLog.csv'
    Deploy-Template 'PE-M2-L1_RepairTicket.txt' 'PE-M2-L1_RepairTicket.txt'
    Deploy-Template 'PE-M2-L1_CameraObservation.txt' 'PE-M2-L1_CameraObservation.txt'
    Deploy-Template 'PE-M2-L1_EscortPolicy.txt' 'PE-M2-L1_EscortPolicy.txt'
    Deploy-Template 'PE-M2-L1_EscortReview.csv' 'PE-M2-L1_EscortReview.csv'
    Set-LabMarker 'M2-L1'
}

function Seed-M2-L2 {
    Deploy-Template 'PE-M2-L2_TemporaryBadgeInventory.csv' 'PE-M2-L2_TemporaryBadgeInventory.csv'
    Deploy-Template 'PE-M2-L2_VisitorLog.csv' 'PE-M2-L2_VisitorLog.csv'
    Set-LabMarker 'M2-L2'
}

function Seed-M3-L1 {
    Deploy-Template 'PE-M3-L1_BadgeControllerExport.csv' 'PE-M3-L1_BadgeControllerExport.csv'
    Deploy-Template 'PE-M3-L1_VisitorSignInSheet.csv' 'PE-M3-L1_VisitorSignInSheet.csv'
    Deploy-Template 'PE-M3-L1_AlarmLog.csv' 'PE-M3-L1_AlarmLog.csv'
    Deploy-Template 'PE-M3-L1_DiscrepancyReview.csv' 'PE-M3-L1_DiscrepancyReview.csv'
    Set-LabMarker 'M3-L1'
}

function Seed-M3-L2 {
    Deploy-Template 'PE-M3-L2_LostBadgeReport.txt' 'PE-M3-L2_LostBadgeReport.txt'
    Deploy-Template 'PE-M3-L2_BadgeInventory.csv' 'PE-M3-L2_BadgeInventory.csv'
    Deploy-Template 'PE-M3-L2_AccessEventsAfterLoss.csv' 'PE-M3-L2_AccessEventsAfterLoss.csv'
    Deploy-Template 'PE-M3-L2_IncidentReport.csv' 'PE-M3-L2_IncidentReport.csv'
    Set-LabMarker 'M3-L2'
}

Deploy-Template 'PE-Lab-Instructions.txt' 'PE-Lab-Instructions.txt'

switch ($LabId) {
    'M1-L1' { Seed-M1-L1 }
    'M1-L2' { Seed-M1-L2 }
    'M2-L1' { Seed-M2-L1 }
    'M2-L2' { Seed-M2-L2 }
    'M3-L1' { Seed-M3-L1 }
    'M3-L2' { Seed-M3-L2 }
    'ALL' {
        Seed-M1-L1
        Seed-M1-L2
        Seed-M2-L1
        Seed-M2-L2
        Seed-M3-L1
        Seed-M3-L2
    }
}

Write-Host "[COMPLETE] PE seed finished for $podName"
