param(
    [Parameter(Mandatory=$true)]
    [ValidateRange(1,20)]
    [int]$PodId,

    [ValidateSet('M5-L1','ALL')]
    [string]$LabId = 'ALL'
)

$podName = "Pod{0:D2}" -f $PodId
$podRoot = "C:\CyberLab\$podName"
$artifactDir = Join-Path $podRoot "SC-Artifacts\CyDeploy"
$familyMarker = Join-Path $podRoot ".families\SC-CYDEPLOY.seeded"

$prefix = "P{0:D2}" -f $PodId

# SC-M5-L1 is the only lab in this family, so 'M5-L1' and 'ALL' reset the same
# state. The parameter exists so the AWX templates and the SI family share one
# calling convention; add a per-lab branch here when a second SC CyDeploy lab is
# introduced, rather than letting 'ALL' quietly become wrong.
Write-Host "[SCOPE] resetting SC CyDeploy lab(s): $LabId"

# Remove every CyDeploy firewall rule on this pod server: the seeded permissive
# rule and any rule the student created while working the lab. Nothing outside
# the P<NN>-CYDEPLOY- namespace is touched, so the host's own baseline rules and
# the other SC labs are left exactly as they were.
$rules = @(Get-NetFirewallRule -ErrorAction SilentlyContinue |
    Where-Object { $_.DisplayName -like "$prefix-CYDEPLOY-*" -or $_.Name -like "$prefix-CYDEPLOY-*" })
foreach ($rule in $rules) {
    Remove-NetFirewallRule -Name $rule.Name -ErrorAction SilentlyContinue
    Write-Host "[REMOVED] firewall rule $($rule.DisplayName)"
}
if ($rules.Count -eq 0) {
    Write-Host "[SKIP] no $prefix-CYDEPLOY-* firewall rules present"
}

if (Test-Path $artifactDir) {
    Remove-Item -Path $artifactDir -Recurse -Force
    Write-Host "[REMOVED] $artifactDir"
} else {
    Write-Host "[SKIP] $artifactDir does not exist"
}

Remove-Item -Path $familyMarker -Force -ErrorAction SilentlyContinue
Write-Host "[COMPLETE] SC CyDeploy reset finished for $podName; CyDeploy firewall rules removed from this pod server and the core SC labs were not touched"
