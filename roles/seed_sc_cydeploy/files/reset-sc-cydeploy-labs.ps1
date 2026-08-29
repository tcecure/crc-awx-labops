param(
    [Parameter(Mandatory=$true)]
    [ValidateRange(1,20)]
    [int]$PodId
)

$podName = "Pod{0:D2}" -f $PodId
$podRoot = "C:\CyberLab\$podName"
$artifactDir = Join-Path $podRoot "SC-Artifacts\CyDeploy"
$familyMarker = Join-Path $podRoot ".families\SC-CYDEPLOY.seeded"

if (Test-Path $artifactDir) {
    Remove-Item -Path $artifactDir -Recurse -Force
    Write-Host "[REMOVED] $artifactDir"
} else {
    Write-Host "[SKIP] $artifactDir does not exist"
}

Remove-Item -Path $familyMarker -Force -ErrorAction SilentlyContinue
Write-Host "[COMPLETE] SC CyDeploy reset finished for $podName; no gateway rules were changed and the core SC labs were not touched"
