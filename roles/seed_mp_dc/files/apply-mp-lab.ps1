param(
    [Parameter(Mandatory=$true)]
    [ValidateRange(1,20)]
    [int]$PodId,

    [Parameter(Mandatory=$false)]
    [ValidateSet("ALL", "M1-L1", "M1-L2", "M1-L3")]
    [string]$LabId = "ALL",

    [Parameter(Mandatory=$false)]
    [string]$TemplatesPath = "C:\CyberLab\_Templates\MP",

    [Parameter(Mandatory=$false)]
    [bool]$ForceReseed = $false
)

$podName = "Pod{0:D2}" -f $PodId
$prefix = "P{0:D2}" -f $PodId
$podPadded = "{0:D2}" -f $PodId
$podRoot = "C:\CyberLab\$podName"
$artifactDir = Join-Path $podRoot "MP-Artifacts"
$familyMarker = Join-Path $podRoot ".families\MP.seeded"

if ((Test-Path $familyMarker) -and -not $ForceReseed) {
    Write-Host "[SKIP] MP is already seeded for $podName. Reset MP or use ForceReseed to seed again."
    exit 0
}

New-Item -Path $artifactDir -ItemType Directory -Force | Out-Null

function Deploy-Template {
    param([string]$TemplateName, [string]$OutputName)

    $srcJ2 = Join-Path $TemplatesPath "$TemplateName.j2"
    $srcPlain = Join-Path $TemplatesPath $TemplateName
    $destination = Join-Path $artifactDir $OutputName
    if (Test-Path $srcJ2) {
        $content = Get-Content -Path $srcJ2 -Raw
        $content = $content -replace '\{\{\s*prefix\s*\}\}', $prefix
        $content = $content -replace '\{\{\s*pod_id_padded\s*\}\}', $podPadded
        Set-Content -Path $destination -Value $content -NoNewline
    } elseif (Test-Path $srcPlain) {
        Copy-Item -Path $srcPlain -Destination $destination -Force
    } else {
        throw "Template not found: $TemplateName"
    }
    Write-Host "[DEPLOYED] $OutputName"
}

function Set-LabMarker {
    param([string]$Lab)
    $marker = Join-Path $artifactDir "_LAB_READY_MP-$Lab.txt"
    Set-Content -Path $marker -Value "MP Lab $Lab seeded for $podName at $(Get-Date -Format o)"
}

function Get-FreeDriveLetter {
    foreach ($letter in @('R','Q','P','O','N','M')) {
        if (-not (Test-Path "${letter}:\")) { return $letter }
    }
    throw "No free drive letter is available for MP media creation"
}

function Invoke-DiskPartScript {
    param([string[]]$Commands)
    $scriptPath = Join-Path $env:TEMP ("mp-diskpart-{0}.txt" -f ([guid]::NewGuid().ToString('N')))
    try {
        Set-Content -Path $scriptPath -Value ($Commands -join "`r`n")
        $output = diskpart.exe /s $scriptPath 2>&1 | Out-String
        if ($LASTEXITCODE -ne 0 -or $output -match 'DiskPart has encountered an error') {
            throw "DiskPart failed: $output"
        }
    } finally {
        Remove-Item -Path $scriptPath -Force -ErrorAction SilentlyContinue
    }
}

function New-LabVhdx {
    param(
        [string]$Path,
        [string]$Label,
        [ValidateSet('FCI','General')]
        [string]$ContentType
    )

    if (Test-Path $Path) {
        Dismount-DiskImage -ImagePath $Path -ErrorAction SilentlyContinue
        Remove-Item -Path $Path -Force
    }

    $drive = Get-FreeDriveLetter
    Invoke-DiskPartScript @(
        "create vdisk file=`"$Path`" maximum=96 type=expandable",
        "select vdisk file=`"$Path`"",
        "attach vdisk",
        "create partition primary",
        "format fs=ntfs label=`"$Label`" quick",
        "assign letter=$drive"
    )

    $root = "${drive}:\"
    if (-not (Test-Path $root)) { throw "VHDX was created but drive $drive was not mounted" }

    if ($ContentType -eq 'FCI') {
        foreach ($folder in @('Contracts','Purchase Orders','Drawings','Invoices','General Office','Hidden Archive','Temp')) {
            New-Item -Path (Join-Path $root $folder) -ItemType Directory -Force | Out-Null
        }
        Set-Content -Path (Join-Path $root 'Contracts\Federal-Services-Contract-2026.txt') -Value "Federal services contract, contract number FA-2026-$prefix, performance and delivery terms."
        Set-Content -Path (Join-Path $root 'Purchase Orders\PO-1048.txt') -Value "Purchase order supporting federal contract FA-2026-$prefix."
        Set-Content -Path (Join-Path $root 'Drawings\Facility-Network-Drawing.txt') -Value "Network drawing delivered under federal contract FA-2026-$prefix."
        Set-Content -Path (Join-Path $root 'Invoices\INV-2026-031.txt') -Value "Invoice for services performed under federal contract FA-2026-$prefix."
        Set-Content -Path (Join-Path $root 'General Office\Meeting-Agenda.txt') -Value "General weekly staff meeting agenda."
        Set-Content -Path (Join-Path $root 'Hidden Archive\Archived-Contract-Notes.txt') -Value "Archived FCI contract notes."
        Set-Content -Path (Join-Path $root 'Temp\~contract-review.tmp') -Value "Temporary working copy for federal contract review."
        Set-Content -Path (Join-Path $root 'Deleted-Contract-Draft.txt') -Value "Deleted draft data that remains recoverable until media sanitization."
        Remove-Item -Path (Join-Path $root 'Deleted-Contract-Draft.txt') -Force
        attrib.exe +h (Join-Path $root 'Hidden Archive') | Out-Null
        attrib.exe +h (Join-Path $root 'Temp\~contract-review.tmp') | Out-Null
    } else {
        foreach ($folder in @('Policies','Benefits','General Office')) {
            New-Item -Path (Join-Path $root $folder) -ItemType Directory -Force | Out-Null
        }
        Set-Content -Path (Join-Path $root 'Policies\Employee-Handbook.txt') -Value "General employee handbook: conduct, leave, and workplace expectations."
        Set-Content -Path (Join-Path $root 'Benefits\Benefits-Guide.txt') -Value "General benefits enrollment guide."
        Set-Content -Path (Join-Path $root 'General Office\Holiday-Calendar.txt') -Value "Company holiday calendar."
    }

    $volumeInfo = fsutil.exe fsinfo volumeinfo $root 2>&1 | Out-String
    $match = [regex]::Match($volumeInfo, 'Volume Serial Number\s*:\s*(\S+)', 'IgnoreCase')
    if (-not $match.Success) { throw "Could not read the seeded volume serial number" }
    $serial = $match.Groups[1].Value
    Invoke-DiskPartScript @(
        "select vdisk file=`"$Path`"",
        "detach vdisk"
    )
    return $serial
}

function Ensure-FciMedia {
    $path = Join-Path $artifactDir "$prefix-FCI-USB.vhdx"
    $metadata = Join-Path $artifactDir "MP-M1-L2_SeedMetadata.json"
    if (-not (Test-Path $path) -or -not (Test-Path $metadata)) {
        $serial = New-LabVhdx -Path $path -Label "$prefix-FCI-MEDIA" -ContentType FCI
        @{ MediaId = "$prefix-FCI-USB"; OriginalVolumeSerial = $serial; SeededAt = (Get-Date -Format o) } |
            ConvertTo-Json | Set-Content -Path $metadata
    }
}

function Seed-M1-L1 {
    Ensure-FciMedia
    $handbookPath = Join-Path $artifactDir "$prefix-Employee-Handbook.vhdx"
    if (-not (Test-Path $handbookPath)) {
        New-LabVhdx -Path $handbookPath -Label "$prefix-HANDBOOK" -ContentType General | Out-Null
    }
    Deploy-Template "MediaInventory.xlsx" "MediaInventory.xlsx"
    Deploy-Template "MediaClassificationWorksheet.docx" "MediaClassificationWorksheet.docx"
    Deploy-Template "MediaClassificationResponses.csv" "MediaClassificationResponses.csv"
    Deploy-Template "MediaDisposalPolicy.pdf" "MediaDisposalPolicy.pdf"
    Set-LabMarker "M1-L1"
}

function Seed-M1-L2 {
    Ensure-FciMedia
    Deploy-Template "MediaSanitizationLog.csv" "MediaSanitizationLog.csv"
    Deploy-Template "MediaSanitizationCertificate.csv" "MediaSanitizationCertificate.csv"
    Set-LabMarker "M1-L2"
}

function Seed-M1-L3 {
    Deploy-Template "LaptopAssetRecord.csv" "LaptopAssetRecord.csv"
    Deploy-Template "ChainOfCustody.csv" "ChainOfCustody.csv"
    Deploy-Template "VendorDestructionCertificate.txt" "VendorDestructionCertificate.txt"
    Deploy-Template "MP-M1-L3_DispositionWorksheet.csv" "MP-M1-L3_DispositionWorksheet.csv"
    Set-LabMarker "M1-L3"
}

Deploy-Template "MP-Lab-Instructions.txt" "MP-Lab-Instructions.txt"

switch ($LabId) {
    'M1-L1' { Seed-M1-L1 }
    'M1-L2' { Seed-M1-L2 }
    'M1-L3' { Seed-M1-L3 }
    'ALL' {
        Seed-M1-L1
        Seed-M1-L2
        Seed-M1-L3
    }
}

Write-Host "[COMPLETE] MP seed finished for $podName"
