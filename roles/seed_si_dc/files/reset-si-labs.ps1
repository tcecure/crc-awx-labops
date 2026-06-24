# reset-si-labs.ps1
# Removes all SI lab artifacts for a given pod
# Does NOT touch AC or IA artifacts
# Does NOT remove PXX-d.chen (shared with IA)

param(
    [Parameter(Mandatory=$true)]
    [ValidateRange(1,20)]
    [int]$PodId
)

$podName    = "Pod{0:D2}" -f $PodId
$prefix     = "P{0:D2}" -f $PodId
$artifactDir = "C:\CyberLab\$podName\SI-Artifacts"

Write-Host "======================================================"
Write-Host " SI LAB RESET - $podName - $prefix"
Write-Host "======================================================"

# Remove SI-Artifacts directory contents (keep the directory itself)
if (Test-Path $artifactDir) {
    $items = Get-ChildItem -Path $artifactDir -Recurse
    $count = ($items | Measure-Object).Count
    Remove-Item -Path "$artifactDir\*" -Recurse -Force
    Write-Host "[CLEANED] $artifactDir - $count items removed"
} else {
    Write-Host "[SKIP] $artifactDir - does not exist"
}

# Remove SI templates directory if it exists
$templateDir = "C:\CyberLab\_Templates\SI"
if (Test-Path $templateDir) {
    Remove-Item -Path "$templateDir\*" -Recurse -Force
    Write-Host "[CLEANED] SI templates dir"
}

# NOTE: We do NOT delete PXX-d.chen from AD because it's shared with IA.
# If IA is also being reset, that family's reset script handles it.
Write-Host "[PRESERVED] $prefix-d.chen - shared with IA family"

Write-Host "`n======================================================"
Write-Host " SI RESET COMPLETE - $podName"
Write-Host " AC/IA artifacts: UNTOUCHED"
Write-Host " d.chen account: PRESERVED"
Write-Host "======================================================"
