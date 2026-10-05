param(
    [Parameter(Mandatory=$true)]
    [ValidateRange(1,20)]
    [int]$PodId,

    [Parameter(Mandatory=$false)]
    [ValidateSet("ALL", "M5-L1")]
    [string]$LabId = "ALL",

    [Parameter(Mandatory=$false)]
    [string]$TemplatesPath = "C:\CyberLab\_Templates\SC-CyDeploy",

    [Parameter(Mandatory=$false)]
    [ValidateSet(0,1)]
    [int]$ForceReseed = 0
)

$podName = "Pod{0:D2}" -f $PodId
$prefix = "P{0:D2}" -f $PodId
$podPadded = "{0:D2}" -f $PodId
$podRoot = "C:\CyberLab\$podName"
$scArtifactDir = Join-Path $podRoot "SC-Artifacts"
$artifactDir = Join-Path $scArtifactDir "CyDeploy"
$responseDir = Join-Path $artifactDir "StudentResponses"
$familyMarker = Join-Path $podRoot ".families\SC-CYDEPLOY.seeded"

if ((Test-Path $familyMarker) -and -not $ForceReseed) {
    Write-Host "[SKIP] SC CyDeploy is already seeded for $podName. Reset SC CyDeploy or use ForceReseed to seed again."
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
    $marker = Join-Path $artifactDir "_LAB_READY_SC-$Lab.txt"
    Set-Content -Path $marker -Value "SC Lab $Lab (CyDeploy) seeded for $podName at $(Get-Date -Format o)"
    Write-Host "[MARKER] _LAB_READY_SC-$Lab.txt"
}

function Seed-M5-L1 {
    Deploy-Template 'SC-M5-L1_Firewall_Change_Request.docx' "${prefix}_Firewall_Change_Request.docx"
    Deploy-Template 'SC-M5-L1_Required_Communication_Matrix.csv' "${prefix}_Required_Communication_Matrix.csv"
    Deploy-Template 'SC-M5-L1_Dependency_Worksheet.docx' "${prefix}_Dependency_Worksheet.docx"
    Deploy-Template 'SC-M5-L1_Change_Validation_Report.docx' "${prefix}_Change_Validation_Report.docx"
    Deploy-Template 'SC-M5-L1_Firewall_Scenario.txt' "${prefix}_Firewall_Scenario.txt"
    Deploy-ResponseTemplate 'SC-M5-L1_Response_Template.json' 'SC-M5-L1.json'
    Set-LabMarker 'M5-L1'
}

switch ($LabId) {
    "M5-L1" { Seed-M5-L1 }
    "ALL" { Seed-M5-L1 }
}

New-Item -ItemType Directory -Force -Path (Split-Path $familyMarker -Parent) | Out-Null
Set-Content -Path $familyMarker -Value (Get-Date -Format o)
Write-Host "[COMPLETE] SC CyDeploy seeding finished for $podName ($LabId); no gateway configuration and no other SC artifacts were changed"
