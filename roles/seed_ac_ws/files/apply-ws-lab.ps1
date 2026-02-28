param(
  [Parameter(Mandatory=$true)]
  [ValidateSet("L3.2","L4.2","L4.3","ALL")]
  [string]$LabId
)

$evidenceRoot = "C:\LabEvidence"
New-Item -ItemType Directory -Path $evidenceRoot -Force | Out-Null

function Apply-Lab($id) {
  switch ($id) {

    "L3.2" {
      $domain = (Get-WmiObject Win32_ComputerSystem).Domain
      $group = "$domain\SG-ACS-All-Staff"
      net localgroup Administrators "$group" /add 2>$null
      Write-Host "  L3.2 seeded: SG-ACS-All-Staff added to local Administrators"
    }

    "L4.2" {
      Remove-Item -Recurse -Force "$evidenceRoot\Lab4-2" -ErrorAction SilentlyContinue
      New-Item -ItemType Directory -Path "$evidenceRoot\Lab4-2" -Force | Out-Null
      Write-Host "  L4.2 seeded: Lab4-2 evidence folder created (empty)"
    }

    "L4.3" {
      Remove-Item -Recurse -Force "$evidenceRoot\Lab4-3" -ErrorAction SilentlyContinue
      New-Item -ItemType Directory -Path "$evidenceRoot\Lab4-3" -Force | Out-Null
      Set-Content -Path "$evidenceRoot\Lab4-3\enabled_users.csv" -Value "placeholder"
      Write-Host "  L4.3 seeded: Lab4-3 evidence folder created (incomplete files)"
    }
  }
}

if ($LabId -eq "ALL") {
  $allLabs = @("L3.2","L4.2","L4.3")
  foreach ($lab in $allLabs) { Apply-Lab $lab }
  Write-Host "All WS labs seeded on $env:COMPUTERNAME"
} else {
  Apply-Lab $LabId
  Write-Host "Lab $LabId seeded on $env:COMPUTERNAME"
}
