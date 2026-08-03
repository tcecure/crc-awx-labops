param(
    [Parameter(Mandatory=$true)]
    [ValidateRange(1,20)]
    [int]$PodId,

    [Parameter(Mandatory=$true)]
    [ValidatePattern('^student\d{2}$')]
    [string]$StudentAccount
)

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName Microsoft.VisualBasic
Add-Type -AssemblyName System.Windows.Forms

$podName = 'Pod{0:d2}' -f $PodId
$certificateDir = "C:\CyberLab\$podName\Certificates"
$profilePath = Join-Path $certificateDir 'CertificateProfile.json'

New-Item -ItemType Directory -Force -Path $certificateDir | Out-Null

$currentName = ''
if (Test-Path $profilePath) {
    try {
        $currentName = [string](Get-Content $profilePath -Raw | ConvertFrom-Json).DisplayName
    }
    catch {
        $currentName = ''
    }
}

while ($true) {
    $displayName = [Microsoft.VisualBasic.Interaction]::InputBox(
        "Enter your full name exactly as it should appear on your DRCC CMMC Level 1 completion certificate.`r`n`r`nUse letters, spaces, apostrophes, periods, and hyphens only.",
        'DRCC Certificate Name',
        $currentName
    ).Trim()

    if ([string]::IsNullOrWhiteSpace($displayName)) {
        [System.Windows.Forms.MessageBox]::Show(
            'No name was saved. You can run Request My Certificate again later.',
            'DRCC Certificate Name',
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Information
        ) | Out-Null
        exit 0
    }

    $supportedEncoding = $true
    try {
        $windowsEncoding = [System.Text.Encoding]::GetEncoding(
            1252,
            [System.Text.EncoderFallback]::ExceptionFallback,
            [System.Text.DecoderFallback]::ExceptionFallback
        )
        $null = $windowsEncoding.GetBytes($displayName)
    }
    catch {
        $supportedEncoding = $false
    }

    if ($displayName.Length -lt 2 -or $displayName.Length -gt 80 -or $displayName -notmatch "^[\p{L}\p{M} .'-]+$" -or -not $supportedEncoding) {
        [System.Windows.Forms.MessageBox]::Show(
            'Enter a name between 2 and 80 characters using the Latin alphabet, spaces, apostrophes, periods, and hyphens.',
            'Invalid Certificate Name',
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Warning
        ) | Out-Null
        $currentName = $displayName
        continue
    }

    $confirmation = [System.Windows.Forms.MessageBox]::Show(
        "Your CMMC Level 1 completion certificate will display:`r`n`r`n$displayName`r`n`r`nIs this correct?",
        'Confirm Certificate Name',
        [System.Windows.Forms.MessageBoxButtons]::YesNo,
        [System.Windows.Forms.MessageBoxIcon]::Question
    )
    if ($confirmation -eq [System.Windows.Forms.DialogResult]::Yes) {
        break
    }
    $currentName = $displayName
}

$profile = [ordered]@{
    SchemaVersion = 1
    DisplayName = $displayName
    StudentAccount = $StudentAccount
    Pod = $podName
    NameSource = 'student_supplied'
    SubmittedAt = (Get-Date).ToUniversalTime().ToString('o')
}
$profileJson = $profile | ConvertTo-Json
[System.IO.File]::WriteAllText($profilePath, $profileJson, (New-Object System.Text.UTF8Encoding($false)))

[System.Windows.Forms.MessageBox]::Show(
    "Your certificate name has been saved as:`r`n`r`n$displayName`r`n`r`nYour CMMC Level 1 certificate will be generated automatically after all 57 labs are verified complete. If it was already issued, contact your instructor to request a corrected copy.",
    'DRCC Certificate Profile Saved',
    [System.Windows.Forms.MessageBoxButtons]::OK,
    [System.Windows.Forms.MessageBoxIcon]::Information
) | Out-Null
