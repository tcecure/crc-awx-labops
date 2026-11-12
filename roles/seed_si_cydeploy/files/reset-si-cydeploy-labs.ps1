param(
    [Parameter(Mandatory=$true)]
    [ValidateRange(1,20)]
    [int]$PodId,

    [ValidateSet('M5-L1','M5-L2','M5-L3','ALL')]
    [string]$LabId = 'ALL'
)

$podName = "Pod{0:D2}" -f $PodId
$prefix = "P{0:D2}" -f $PodId
$podRoot = "C:\CyberLab\$podName"
$artifactDir = Join-Path $podRoot "SI-Artifacts\CyDeploy"
$responseDir = Join-Path $artifactDir "StudentResponses"
$familyMarker = Join-Path $podRoot ".families\SI-CYDEPLOY.seeded"

# Files each lab owns, so a single-lab reset leaves the other two labs and the
# student work in them intact.
$labFiles = @{
    'M5-L1' = @(
        "${prefix}_Expected_Asset_Inventory.csv",
        "${prefix}_CyDeploy_Discovery_Worksheet.docx",
        "${prefix}_Discovery_Scenario.txt",
        '_LAB_READY_SI-M5-L1.txt'
    )
    'M5-L2' = @(
        "${prefix}_CyDeploy_Findings_Worksheet.docx",
        "${prefix}_Approved_Software_List.csv",
        "${prefix}_Configuration_Baseline.pdf",
        "${prefix}_Exception_Register.csv",
        "${prefix}_Observed_Conditions.txt",
        '_LAB_READY_SI-M5-L2.txt'
    )
    'M5-L3' = @(
        "${prefix}_Change_Request.docx",
        "${prefix}_Baseline_Worksheet.docx",
        "${prefix}_Change_Validation_Report.docx",
        "${prefix}_Change_Scenario.txt",
        '_LAB_READY_SI-M5-L3.txt'
    )
}

function Restore-ChangeTargetService {
    # SI-M5-L3 leaves the Print Spooler stopped and disabled. Reset puts the
    # documented baseline back so the next run starts from running/automatic.
    $service = Get-Service -Name 'Spooler' -ErrorAction SilentlyContinue
    if (-not $service) {
        Write-Host '[SKIP] Spooler service not present'
        return
    }
    Set-Service -Name 'Spooler' -StartupType Automatic
    if ($service.Status -ne 'Running') { Start-Service -Name 'Spooler' }
    Write-Host '[RESTORED] Spooler running and automatic (SI-M5-L3 baseline)'
}

function Reset-Lab {
    param([string]$Lab)

    foreach ($name in $labFiles[$Lab]) {
        $path = Join-Path $artifactDir $name
        if (Test-Path $path) {
            Remove-Item -Path $path -Force
            Write-Host "[REMOVED] $name"
        }
    }

    $response = Join-Path $responseDir "SI-$Lab.json"
    if (Test-Path $response) {
        Remove-Item -Path $response -Force
        Write-Host "[REMOVED] StudentResponses\SI-$Lab.json"
    }

    if ($Lab -eq 'M5-L3') { Restore-ChangeTargetService }
}

if ($LabId -eq 'ALL') {
    Restore-ChangeTargetService

    if (Test-Path $artifactDir) {
        Remove-Item -Path $artifactDir -Recurse -Force
        Write-Host "[REMOVED] $artifactDir"
    } else {
        Write-Host "[SKIP] $artifactDir does not exist"
    }

    Remove-Item -Path $familyMarker -Force -ErrorAction SilentlyContinue
} else {
    if (-not (Test-Path $artifactDir)) {
        Write-Host "[SKIP] $artifactDir does not exist"
    } else {
        Reset-Lab $LabId
    }
}

Write-Host "[COMPLETE] SI CyDeploy reset finished for $podName ($LabId); the core SI labs and all other family artifacts were not changed"
