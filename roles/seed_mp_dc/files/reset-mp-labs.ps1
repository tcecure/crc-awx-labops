param(
    [Parameter(Mandatory=$true)]
    [ValidateRange(1,20)]
    [int]$PodId
)

$podName = "Pod{0:D2}" -f $PodId
$podRoot = "C:\CyberLab\$podName"
$artifactDir = Join-Path $podRoot "MP-Artifacts"
$familyMarker = Join-Path $podRoot ".families\MP.seeded"

if (Test-Path $artifactDir) {
    Get-ChildItem -Path $artifactDir -Filter '*.vhdx' -ErrorAction SilentlyContinue | ForEach-Object {
        Dismount-DiskImage -ImagePath $_.FullName -ErrorAction SilentlyContinue
    }
    Remove-Item -Path $artifactDir -Recurse -Force
    Write-Host "[REMOVED] $artifactDir"
} else {
    Write-Host "[SKIP] $artifactDir does not exist"
}

Remove-Item -Path $familyMarker -Force -ErrorAction SilentlyContinue
Write-Host "[COMPLETE] MP reset finished for $podName; other family artifacts were not changed"
