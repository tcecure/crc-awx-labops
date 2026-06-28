# reset-sc-labs.ps1
# Removes all SC lab artifacts and markers from DC01 for a given pod

param(
    [Parameter(Mandatory=$true)]
    [ValidateRange(1,20)]
    [int]$PodId
)

$podName = "Pod{0:D2}" -f $PodId
$artifactDir = "C:\CyberLab\$podName\SC-Artifacts"

Write-Host "=== SC RESET (DC) - $podName ==="

if (Test-Path $artifactDir) {
    # Remove all lab files and markers
    Get-ChildItem $artifactDir -Recurse | Remove-Item -Force -Recurse
    Write-Host "[CLEANED] $artifactDir contents removed"
} else {
    Write-Host "[SKIP] $artifactDir does not exist"
}

Write-Host "[SC-RESET-DC] $podName DC cleanup complete"
