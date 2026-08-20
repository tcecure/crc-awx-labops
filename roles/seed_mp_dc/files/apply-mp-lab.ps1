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
    [ValidateSet(0,1)]
    [int]$ForceReseed = 0
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

    $volume = Get-Volume -DriveLetter $drive -ErrorAction Stop
    $volumeUniqueId = [string]$volume.UniqueId
    if ([string]::IsNullOrWhiteSpace($volumeUniqueId)) { throw "Could not read the seeded volume unique ID" }
    Invoke-DiskPartScript @(
        "select vdisk file=`"$Path`"",
        "detach vdisk"
    )
    return $volumeUniqueId
}

function Write-MediaListing {
    param([string]$Path)

    # Students on the shared DC cannot mount a VHDX (that needs local admin), so
    # the seed publishes a read-only listing of each image next to it. Contents
    # match what File Explorer would show with hidden items enabled.
    $listing = [System.IO.Path]::ChangeExtension($Path, $null).TrimEnd('.') + "-Contents.txt"
    $mountedHere = $false
    try {
        $image = Get-DiskImage -ImagePath $Path -ErrorAction Stop
        if (-not $image.Attached) {
            Mount-DiskImage -ImagePath $Path -Access ReadOnly -ErrorAction Stop | Out-Null
            $mountedHere = $true
        }
        $volume = Get-DiskImage -ImagePath $Path | Get-Disk | Get-Partition | Get-Volume |
            Where-Object FileSystem | Select-Object -First 1
        if (-not $volume) { throw "no formatted volume found" }
        $lines = @(
            "Media file  : $(Split-Path $Path -Leaf)"
            "Volume label: $($volume.FileSystemLabel)"
            "Listed at   : $(Get-Date -Format o)"
            ""
            "All files and folders, including hidden items:"
            ""
        )
        $lines += Get-ChildItem -LiteralPath $volume.Path -Recurse -Force |
            Sort-Object FullName |
            ForEach-Object {
                $relative = $_.FullName.Substring($volume.Path.Length)
                if ($_.PSIsContainer) { "[DIR ] $relative" }
                else { "[FILE] $relative  ($($_.Length) bytes)" }
            }
        Set-Content -Path $listing -Value $lines
        Write-Host "[DEPLOYED] $(Split-Path $listing -Leaf)"
    } catch {
        Write-Host "[WARN] could not write media listing for $(Split-Path $Path -Leaf): $($_.Exception.Message)"
    } finally {
        if ($mountedHere) { Dismount-DiskImage -ImagePath $Path -ErrorAction SilentlyContinue | Out-Null }
    }
}

function Ensure-FciMedia {
    $path = Join-Path $artifactDir "$prefix-FCI-USB.vhdx"
    $metadata = Join-Path $artifactDir "MP-M1-L2_SeedMetadata.json"
    if (-not (Test-Path $path) -or -not (Test-Path $metadata)) {
        if ((Test-Path $path) -and -not (Test-Path $metadata)) { Remove-Item -LiteralPath $path -Force }
        $volumeUniqueId = New-LabVhdx -Path $path -Label "$prefix-FCI-MEDIA" -ContentType FCI
        @{ MediaId = "$prefix-FCI-USB"; OriginalVolumeUniqueId = $volumeUniqueId; SeededAt = (Get-Date -Format o) } |
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
    Write-MediaListing -Path (Join-Path $artifactDir "$prefix-FCI-USB.vhdx")
    Write-MediaListing -Path $handbookPath
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
