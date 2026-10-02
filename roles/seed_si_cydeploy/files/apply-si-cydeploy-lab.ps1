param(
    [Parameter(Mandatory=$true)]
    [ValidateRange(1,20)]
    [int]$PodId,

    [Parameter(Mandatory=$false)]
    [ValidateSet("ALL", "M5-L1", "M5-L2", "M5-L3")]
    [string]$LabId = "ALL",

    [Parameter(Mandatory=$false)]
    [string]$TemplatesPath = "C:\CyberLab\_Templates\SI-CyDeploy",

    [Parameter(Mandatory=$false)]
    [ValidateSet(0,1)]
    [int]$ForceReseed = 0
)

$podName = "Pod{0:D2}" -f $PodId
$prefix = "P{0:D2}" -f $PodId
$podPadded = "{0:D2}" -f $PodId
$podRoot = "C:\CyberLab\$podName"
$siArtifactDir = Join-Path $podRoot "SI-Artifacts"
$artifactDir = Join-Path $siArtifactDir "CyDeploy"
$responseDir = Join-Path $artifactDir "StudentResponses"
$familyMarker = Join-Path $podRoot ".families\SI-CYDEPLOY.seeded"

if ((Test-Path $familyMarker) -and -not $ForceReseed) {
    Write-Host "[SKIP] SI CyDeploy is already seeded for $podName. Reset SI CyDeploy or use ForceReseed to seed again."
    exit 0
}

New-Item -Path $artifactDir -ItemType Directory -Force | Out-Null
New-Item -Path $responseDir -ItemType Directory -Force | Out-Null

function Deploy-Template {
    param([string]$TemplateName, [string]$OutputName)

    $srcJ2 = Join-Path $TemplatesPath "$TemplateName.j2"
    $srcPlain = Join-Path $TemplatesPath $TemplateName
    $destination = Join-Path $artifactDir $OutputName
    if (Test-Path $srcJ2) {
        $content = Get-Content -Path $srcJ2 -Raw
        $content = $content -replace '\{\{\s*prefix\s*\}\}', $prefix
        $content = $content -replace '\{\{\s*pod_id_padded\s*\}\}', $podPadded
        $content = $content -replace '\{\{\s*pod_id\s*\}\}', $PodId
        Set-Content -Path $destination -Value $content -NoNewline
    } elseif (Test-Path $srcPlain) {
        Copy-Item -Path $srcPlain -Destination $destination -Force
    } else {
        throw "Template not found: $TemplateName"
    }
    Write-Host "[DEPLOYED] $OutputName"
}

function Deploy-ResponseTemplate {
    param([string]$TemplateName, [string]$OutputName)

    $destination = Join-Path $responseDir $OutputName
    if (Test-Path $destination) {
        Write-Host "[KEEP] $OutputName already exists; student work was not overwritten"
        return
    }
    $source = Join-Path $TemplatesPath "$TemplateName.j2"
    if (-not (Test-Path $source)) { throw "Template not found: $TemplateName" }
    $content = Get-Content -Path $source -Raw
    $content = $content -replace '\{\{\s*prefix\s*\}\}', $prefix
    $content = $content -replace '\{\{\s*pod_id_padded\s*\}\}', $podPadded
    $content = $content -replace '\{\{\s*pod_id\s*\}\}', $PodId
    Set-Content -Path $destination -Value $content -NoNewline
    Write-Host "[DEPLOYED] StudentResponses\$OutputName"
}

function Set-LabMarker {
    param([string]$Lab)
    $marker = Join-Path $artifactDir "_LAB_READY_SI-$Lab.txt"
    Set-Content -Path $marker -Value "SI Lab $Lab (CyDeploy) seeded for $podName at $(Get-Date -Format o)"
    Write-Host "[MARKER] _LAB_READY_SI-$Lab.txt"
}

function Seed-M5-L1 {
    Deploy-Template 'SI-M5-L1_Expected_Asset_Inventory.csv' "${prefix}_Expected_Asset_Inventory.csv"
    Deploy-Template 'SI-M5-L1_CyDeploy_Discovery_Worksheet.docx' "${prefix}_CyDeploy_Discovery_Worksheet.docx"
    Deploy-Template 'SI-M5-L1_Discovery_Scenario.txt' "${prefix}_Discovery_Scenario.txt"
    Deploy-ResponseTemplate 'SI-M5-L1_Response_Template.json' 'SI-M5-L1.json'
    Set-LabMarker 'M5-L1'
}

function Seed-M5-L2 {
    Deploy-Template 'SI-M5-L2_CyDeploy_Findings_Worksheet.docx' "${prefix}_CyDeploy_Findings_Worksheet.docx"
    Deploy-Template 'SI-M5-L2_Approved_Software_List.csv' "${prefix}_Approved_Software_List.csv"
    Deploy-Template 'SI-M5-L2_Configuration_Baseline.pdf' "${prefix}_Configuration_Baseline.pdf"
    Deploy-Template 'SI-M5-L2_Exception_Register.csv' "${prefix}_Exception_Register.csv"
    Deploy-Template 'SI-M5-L2_Observed_Conditions.txt' "${prefix}_Observed_Conditions.txt"
    Deploy-ResponseTemplate 'SI-M5-L2_Response_Template.json' 'SI-M5-L2.json'
    Set-LabMarker 'M5-L2'
}

function Seed-M5-L3 {
    Deploy-Template 'SI-M5-L3_Change_Request.docx' "${prefix}_Change_Request.docx"
    Deploy-Template 'SI-M5-L3_Baseline_Worksheet.docx' "${prefix}_Baseline_Worksheet.docx"
    Deploy-Template 'SI-M5-L3_Change_Validation_Report.docx' "${prefix}_Change_Validation_Report.docx"
    Deploy-Template 'SI-M5-L3_Change_Scenario.txt' "${prefix}_Change_Scenario.txt"
    Deploy-ResponseTemplate 'SI-M5-L3_Response_Template.json' 'SI-M5-L3.json'
    Set-LabMarker 'M5-L3'
}

switch ($LabId) {
    "M5-L1" { Seed-M5-L1 }
    "M5-L2" { Seed-M5-L2 }
    "M5-L3" { Seed-M5-L3 }
    "ALL" {
        Seed-M5-L1
        Seed-M5-L2
        Seed-M5-L3
    }
}

New-Item -ItemType Directory -Force -Path (Split-Path $familyMarker -Parent) | Out-Null
Set-Content -Path $familyMarker -Value (Get-Date -Format o)
Write-Host "[COMPLETE] SI CyDeploy seeding finished for $podName ($LabId); no other SI artifacts were changed"
