# CMMC Level 1 Media Protection (MP) Labs — Student Completion Guide

This guide provides step-by-step instructions for completing all 3 Media Protection labs. Each lab presents a real-world scenario involving removable media that contains Federal Contract Information (FCI): classifying it, sanitizing it for reuse, and deciding the correct disposition for end-of-life equipment.

---

## Table of Contents

1. [Before You Begin](#before-you-begin)
2. [How to Connect to the Lab Environment](#how-to-connect-to-the-lab-environment)
3. [How to Open Your Lab Artifacts](#how-to-open-your-lab-artifacts)
4. [Understanding Your Pod](#understanding-your-pod)
5. [Working With the Lab Media (VHDX Files)](#working-with-the-lab-media-vhdx-files)
6. [Module 1: Media Protection (Labs M1-L1 – M1-L3)](#module-1-media-protection)
7. [Quick Reference: Where to Find Things](#quick-reference-where-to-find-things)
8. [Tips and Common Mistakes](#tips-and-common-mistakes)
9. [Lab Completion Checklist](#lab-completion-checklist)

---

## Before You Begin

### What You Need

- Your **Pod number** (your instructor will assign this, e.g., Pod01, Pod05, Pod12)
- Your **Guacamole login credentials** (your instructor will provide your username and password)
- A computer with a web browser (Chrome, Firefox, or Edge) — no special software needed

### What You Will Be Doing

In these labs you will work with **simulated removable media**. Each "USB drive" is a virtual disk file (`.vhdx`) in your pod folder, and a contents listing published next to it shows everything on that drive. You will inspect what is on the media, decide whether it contains FCI, sanitize media so it can be safely reused, and complete the paperwork (logs, certificates, worksheets) that an assessor would ask to see.

**The key lesson of this family:** deleting files is not sanitization — media must be classified, sanitized by an approved method, and documented before it is reused or disposed of.

### CMMC Context

These labs align with **CMMC Level 1 Media Protection (MP)** requirements:
- **MP.L1-3.8.3** — Sanitize or destroy information system media containing Federal Contract Information before disposal or release for reuse

They also reinforce **ACS-POL-MP-001** (the company media handling policy referenced in your artifacts) and the media inventory/classification practices that support it.

---

## How to Connect to the Lab Environment

You will connect to the lab through **Apache Guacamole** — a web-based remote desktop gateway. There is nothing to install; everything runs in your web browser.

### Step 1: Open the Guacamole Gateway

1. Open your web browser (Chrome, Firefox, or Edge)
2. Go to: **https://crc.guac.01.tcecure.com/#/**
3. You will see a login screen

### Step 2: Log In with Your Student Credentials

1. Enter your **Username** — this matches your pod number:
   - Pod 01 → `student01`
   - Pod 05 → `student05`
   - Pod 12 → `student12`
   - *(and so on — the number matches your assigned pod)*
2. Enter your **Password** (provided by your instructor)
3. Click **Login**

### Step 3: Connect to the Domain Controller

| Connection Name | What It Is |
|---|---|
| **PODXX-DC** | Domain Controller — **use this for all MP labs** |

This is the only connection you get: every MP lab is done on this desktop.

1. Click on **PODXX-DC** (where XX is your pod number, e.g., **POD03-DC**)
2. The remote desktop session opens directly in your browser — no extra login is needed
3. Wait a few seconds for the Windows Server desktop to appear

> **Tip:** Press **Ctrl+Alt+Shift** to open the Guacamole side menu (to return Home or switch connections).

### Step 4: Check Your Lab Progress

**Option 1:** Click the "Check Your Progress — Pod XX" banner at the top of the Guacamole interface.

**Option 2:** Go directly to **https://training.status.tcecure.com/pod/XX** (replace XX with your pod number).

---

## How to Open Your Lab Artifacts

1. Open **File Explorer** on the server desktop (folder icon on the taskbar, or **Windows + E**)
2. Navigate to: **C:\CyberLab\PodXX\MP-Artifacts\\** (e.g., `C:\CyberLab\Pod03\MP-Artifacts\`)

**Alternative method using PowerShell:**
1. Press **Windows key + R**, type `powershell`, press Enter
2. Run: `explorer "C:\CyberLab\Pod03\MP-Artifacts"` (replace `03` with your pod number)

### What You Will See

| File | What It Is |
|---|---|
| `MP-Lab-Instructions.txt` | Short summary of all three labs |
| `PXX-FCI-USB.vhdx` | Simulated USB drive that contains contract data |
| `PXX-Employee-Handbook.vhdx` | Simulated USB drive with general company documents |
| `PXX-FCI-USB-Contents.txt`, `PXX-Employee-Handbook-Contents.txt` | Full contents listing of each drive, including hidden items — read these instead of mounting |
| `MediaInventory.xlsx` | Media inventory spreadsheet |
| `MediaClassificationWorksheet.docx` | Worksheet you fill in for M1-L1 |
| `MediaClassificationResponses.csv` | **Your graded answer file** for M1-L1 |
| `MediaDisposalPolicy.pdf` | Policy reference (ACS-POL-MP-001) |
| `MediaSanitizationLog.csv` | **Graded answer file** for M1-L2 |
| `MediaSanitizationCertificate.csv` | **Graded answer file** for M1-L2 |
| `MP-M1-L2_SeedMetadata.json` | Do **not** edit or delete |
| `LaptopAssetRecord.csv`, `ChainOfCustody.csv`, `VendorDestructionCertificate.txt` | Evidence for M1-L3 |
| `MP-M1-L3_DispositionWorksheet.csv` | **Graded answer file** for M1-L3 |
| `_LAB_READY_MP-M1-*.txt` | Markers confirming the lab was seeded |

> **Important:** Do not delete the original evidence files or the `_LAB_READY_` / `SeedMetadata` files. Fill in the CSV answer files in place (the checker reads those exact file names).

### Editing the CSV Answer Files

The graded answer files are CSVs with the header row and blank cells already in place. Either:
- Open them with **Notepad** (right-click → *Open with* → *Notepad*) and type your values between the commas, or
- Open them with **Excel**, fill the cells, then **Save as CSV** (keep the same file name and `.csv` type)

Do not rename the columns, and do not add extra header rows.

---

## Understanding Your Pod

Everything in your pod is prefixed with your pod number so your work stays separate from other students. If you are **Pod 03**, your prefix is **P03**:

- Artifacts folder: `C:\CyberLab\Pod03\MP-Artifacts\`
- FCI media: `P03-FCI-USB.vhdx` (media ID `P03-FCI-USB`)
- General media: `P03-Employee-Handbook.vhdx`
- End-of-life laptop: `P03-LAP-017`, drive serial `SN-P03-88421`
- Vendor destruction certificate: `VDC-P03-2026-017`

Throughout this guide, replace **XX** with your pod number and **PXX** with your pod prefix.

---

## Working With the Lab Media (VHDX Files)

A `.vhdx` file behaves like a physical USB drive. Mounting one is an
administrator operation on Windows, and on this shared server student accounts
are deliberately not administrators — so for this cohort **you do not mount the
media yourself**. Each drive image ships with a full contents listing that was
captured from the mounted media, and you classify and document from that.

### Read what is on a drive

1. In File Explorer, open `C:\CyberLab\PodXX\MP-Artifacts\`
2. Open the listing next to the drive image:
   - `PXX-FCI-USB-Contents.txt`
   - `PXX-Employee-Handbook-Contents.txt`
3. Each listing shows the volume label and **every** file and folder on that
   drive — including hidden items — with sizes

Or in PowerShell:

```powershell
Get-Content C:\CyberLab\PodXX\MP-Artifacts\PXX-FCI-USB-Contents.txt
```

> **If you try to mount a `.vhdx`** you will get *"A required privilege is not
> held by the client"*, or Windows will ask for administrator credentials that
> your account does not have. That is expected — use the contents listing
> instead. Nothing is broken and no lab credit depends on mounting.

---

## Module 1: Media Protection

### Lab M1-L1: Classify the Media

**Difficulty:** Beginner | **Time:** 25 minutes | **Type:** Media inspection + worksheet

#### Scenario
Two USB drives were found in an unlocked desk drawer at ACS Consulting. Before either one can be reused, stored, or thrown away, you must determine whether it holds Federal Contract Information. FCI is information provided by or generated for the government under a contract that is **not** intended for public release.

#### What You Need
- `PXX-FCI-USB.vhdx`
- `PXX-Employee-Handbook.vhdx`
- `MediaInventory.xlsx`, `MediaClassificationWorksheet.docx`, `MediaDisposalPolicy.pdf`
- Answer file: `MediaClassificationResponses.csv`

#### Steps

1. **Read the policy first:**
   - Open `MediaDisposalPolicy.pdf` and note how the policy defines FCI and what handling it requires

2. **Inspect the first drive:**
   - Open `PXX-FCI-USB-Contents.txt`
   - Read every folder listed: `Contracts`, `Purchase Orders`, `Drawings`, `Invoices`, `General Office`, and the hidden `Hidden Archive` and `Temp` folders
   - Look for file names referencing the federal contract `FA-2026-PXX`
   - Note that some FCI is in hidden folders or a temp file. Media is classified by the **most sensitive** thing on it, so one contract file is enough to make the whole drive FCI

3. **Inspect the second drive:**
   - Open `PXX-Employee-Handbook-Contents.txt`
   - Review `Policies\Employee-Handbook.txt`, `Benefits\Benefits-Guide.txt`, `General Office\Holiday-Calendar.txt`
   - These are internal general business documents — no contract data, no government deliverables

4. **Complete the worksheet:**
   - Open `MediaClassificationWorksheet.docx` and record, for each drive, what you found and why it does or does not meet the FCI definition
   - Cross-check `MediaInventory.xlsx` so your media IDs match the inventory

5. **Record your graded answers in `MediaClassificationResponses.csv`:**

   | Column | What to enter |
   |---|---|
   | `Media` | Already filled in — leave as is |
   | `Classification` | `FCI` for the FCI drive, `Non-FCI` for the handbook drive |
   | `Evidence` | A specific sentence naming the file(s) that justify your classification (must be more than a few words) |

   Example of a completed row (use your own findings):

   ```
   PXX-FCI-USB.vhdx,FCI,Contracts\Federal-Services-Contract-2026.txt and Invoices\INV-2026-031.txt reference federal contract FA-2026-PXX
   PXX-Employee-Handbook.vhdx,Non-FCI,Only general internal documents: employee handbook, benefits guide, holiday calendar
   ```

#### Completion Criteria
- [ ] `PXX-FCI-USB.vhdx` is classified as `FCI`
- [ ] `PXX-Employee-Handbook.vhdx` is classified as `Non-FCI`
- [ ] Both rows have specific written evidence (a short phrase is not enough)
- [ ] Worksheet, inventory, policy and both `.vhdx` files are still present in the folder

#### Why This Matters
You cannot protect FCI you have not identified. Media classification is the first step of MP.L1-3.8.3 — it decides which drives need sanitization or destruction later.

---

### Lab M1-L2: Sanitize Media for Reuse

**Difficulty:** Intermediate | **Time:** 25 minutes | **Type:** Sanitization records

> **This cohort:** re-creating and formatting a volume requires administrator
> rights on this shared server, so the disk-management step is performed by the
> instructor and is not graded. Read step 3 so you know how it is done, then
> complete the log and certificate in step 5 — that is what is graded. When pods
> move to their own servers you will perform the sanitization yourself.

#### Scenario
`PXX-FCI-USB` is being reassigned to a non-federal project team. Before release for reuse it must be sanitized in accordance with **ACS-POL-MP-001**. A previous employee "sanitized" a drive by selecting the files and pressing Delete — the data was recovered by an auditor two weeks later. You will do it properly.

#### What You Need
- `PXX-FCI-USB-Contents.txt` (what is on the media today)
- Answer files: `MediaSanitizationLog.csv`, `MediaSanitizationCertificate.csv`

#### Steps

1. **Understand what "sanitize" means:**
   - **Clear** — overwrite the media so data cannot be recovered with standard tools
   - **Purge** — a stronger method (e.g., degauss or cryptographic erase) that defeats laboratory recovery
   - **Destroy** — physically render the media unusable (used when media will not be reused)
   - Deleting files, emptying the Recycle Bin, and quick-deleting a folder are **none** of these

2. **Confirm what is on the media before it is sanitized (evidence for your log):**
   - Open `PXX-FCI-USB-Contents.txt` and note the current volume label (`PXX-FCI-MEDIA`) and the folders present

3. **How the volume is re-created** (reference for this cohort — administrator step, do not attempt): the volume is deleted and a new one created and fully formatted, not merely emptied.

   **Option A — Disk Management (GUI):**
   - Press **Windows + R**, type `diskmgmt.msc`, press Enter
   - **Action → Attach VHD**, browse to `C:\CyberLab\PodXX\MP-Artifacts\PXX-FCI-USB.vhdx`, click OK
   - Find the attached disk at the bottom of the window (it will be about 96 MB)
   - Right-click its partition → **Delete Volume** → Yes
   - Right-click the resulting unallocated space → **New Simple Volume** → Next
   - Use the full size → assign any drive letter → **Format this volume**:
     - File system: **NTFS**
     - Volume label: **PXX-SANITIZED** (exactly this, with your pod prefix)
     - **Uncheck** "Perform a quick format" (a full format overwrites the data area)
   - Finish and wait for the format to complete
   - Right-click the disk (left-hand grey box) → **Detach VHD**

   **Option B — PowerShell:**

   ```powershell
   $vhd = "C:\CyberLab\PodXX\MP-Artifacts\PXX-FCI-USB.vhdx"

   Mount-DiskImage -ImagePath $vhd
   $disk = Get-DiskImage -ImagePath $vhd | Get-Disk

   # Remove the old volume and create a brand-new one
   Clear-Disk -Number $disk.Number -RemoveData -Confirm:$false
   Initialize-Disk -Number $disk.Number -PartitionStyle MBR -ErrorAction SilentlyContinue
   $part = New-Partition -DiskNumber $disk.Number -UseMaximumSize -AssignDriveLetter
   Format-Volume -Partition $part -FileSystem NTFS -NewFileSystemLabel "PXX-SANITIZED" -Full -Confirm:$false

   # Confirm the volume is empty
   Get-ChildItem -Path "$($part.DriveLetter):\" -Force

   Dismount-DiskImage -ImagePath $vhd
   ```

   *(Replace `PodXX` / `PXX` with your pod values. `-Full` performs the overwriting format.)*

4. **Validation** (performed with the sanitization): the label reads `PXX-SANITIZED` and the volume is empty apart from `System Volume Information` and `$RECYCLE.BIN`.

5. **Complete `MediaSanitizationLog.csv` and `MediaSanitizationCertificate.csv`.** Both files use the same columns and both must be filled in:

   | Column | What to enter |
   |---|---|
   | `MediaId` | Leave as `PXX-FCI-USB` |
   | `Method` | `Clear` or `Purge` (the method used on this media) |
   | `Result` | `Pass` (replace `Pending`) |
   | `Disposition` | `Reuse` |
   | `SanitizedBy` | Your name |
   | `Date` | The date the sanitization was performed, e.g., `2026-06-10` |

#### Completion Criteria
- [ ] Sanitization **log** and **certificate** both record `Clear` or `Purge`, `Pass`, `Reuse`, a `SanitizedBy` name, and a valid date
- [ ] `MP-M1-L2_SeedMetadata.json` is still present and unmodified

#### Why This Matters
MP.L1-3.8.3 requires sanitization **before** media is released for reuse. Deleted files remain recoverable, so an assessor tests the media and the records — which is exactly what this lab does.

---

### Lab M1-L3: Decide the Disposition

**Difficulty:** Intermediate | **Time:** 25 minutes | **Type:** Document analysis + worksheet

#### Scenario
Laptop `PXX-LAP-017` from the Federal Programs group has failed diagnostics and reached end of life. Its drive held FCI. Facilities has already sent it out with a chain-of-custody record, and the vendor returned a certificate. Your job is to record the correct disposition decision and prove that the paperwork lines up.

#### What You Need
- `LaptopAssetRecord.csv`
- `ChainOfCustody.csv`
- `VendorDestructionCertificate.txt`
- Answer file: `MP-M1-L3_DispositionWorksheet.csv`

#### Steps

1. **Read the asset record** (`LaptopAssetRecord.csv`):
   - Asset `PXX-LAP-017`, owner Federal Programs, status **End of life**
   - `ContainsFCI` = **Yes**
   - `DriveSerial` = `SN-PXX-88421`
   - `Serviceability` = **Failed diagnostics**

2. **Read the chain of custody** (`ChainOfCustody.csv`):
   - Record `COC-PXX-017` shows the drive released by Jordan Lee to an approved destruction vendor for the purpose of **Destruction**
   - Confirm the drive serial matches the asset record

3. **Read the vendor certificate** (`VendorDestructionCertificate.txt`):
   - Certificate `VDC-PXX-2026-017`, method **Physical shredding**, status **DESTROYED**, witnessed
   - Confirm the asset ID and drive serial match

4. **Reason through the decision:**
   - **Reuse** is wrong — the drive failed diagnostics and cannot be reliably sanitized or trusted
   - **Return to inventory** is wrong — the asset is end of life and still contains FCI
   - **Destroy** is correct — FCI media that will not be reused must be destroyed, and the custody record and vendor certificate already document destruction

5. **Complete `MP-M1-L3_DispositionWorksheet.csv`:**

   | Column | What to enter |
   |---|---|
   | `AssetId` | Leave as `PXX-LAP-017` |
   | `Decision` | `Destroy` |
   | `DriveSerial` | `SN-PXX-88421` (must match the asset and custody records) |
   | `CertificateId` | `VDC-PXX-2026-017` (must match the vendor certificate) |
   | `Rationale` | At least a full sentence (20+ characters) explaining *why* destruction is required — cite the failed drive, the FCI content, and the vendor certificate |

   Example rationale:

   ```
   Drive failed diagnostics and cannot be reliably sanitized; the asset is end of life and held FCI, so destruction was performed and documented on certificate VDC-PXX-2026-017.
   ```

#### Completion Criteria
- [ ] `Decision` is `Destroy`
- [ ] `DriveSerial` and `CertificateId` match the supporting records exactly
- [ ] `Rationale` is a complete justification, not a single word
- [ ] Asset record, chain of custody and vendor certificate are all still present

#### Why This Matters
MP.L1-3.8.3 gives you two valid outcomes for FCI media: sanitize it or destroy it. Choosing correctly — and being able to show matching custody and certificate records — is what turns a decision into audit evidence.

---

## Quick Reference: Where to Find Things

| Task | Where to Go |
|---|---|
| Open the artifacts folder | `C:\CyberLab\PodXX\MP-Artifacts\` |
| Read what is on simulated media | Open `PXX-<name>-Contents.txt` in the artifacts folder |
| Open PowerShell | **Windows + R** → `powershell` |
| Check your lab progress | https://training.status.tcecure.com/pod/XX |

### Media Handling Terms

| Term | Meaning |
|---|---|
| **FCI** | Federal Contract Information — provided by or generated for the government under a contract, not for public release |
| **Clear** | Overwrite the media so standard recovery tools cannot retrieve the data |
| **Purge** | Stronger sanitization (degauss, cryptographic erase) that defeats laboratory recovery |
| **Destroy** | Physically render media unusable (shred, incinerate, disintegrate) |
| **Chain of custody** | Documented record of who held the media, when, and why |

---

## Tips and Common Mistakes

| Mistake | Solution |
|---|---|
| Deleting files and calling it sanitization | Delete the **volume** and create a new one, then full-format it |
| Filling in only the sanitization log | The **certificate** must be completed with the same values |
| Leaving `Result` as `Pending` | Change it to `Pass` |
| One-word evidence or rationale | The checker requires real explanatory text |
| Editing or deleting `MP-M1-L2_SeedMetadata.json` | Leave it alone |
| Renaming the answer CSVs | Keep the exact file names; the checker looks for them |
| Missing hidden FCI in M1-L1 | The contents listing includes hidden items — read `Hidden Archive` and `Temp` |

### Getting Unstuck

- **Asked for administrator credentials when opening a `.vhdx`?** Expected — cancel the prompt and read the `-Contents.txt` listing instead
- **Verification still failing?** Re-read the exact wording of the failure reason on your progress page and check the answer CSVs against the tables above
- **Missing artifacts?** Ask your instructor to reseed the MP family for your pod

---

## Lab Completion Checklist

| Lab | Name | Status |
|---|---|---|
| M1-L1 | Classify the Media | ☐ |
| M1-L2 | Sanitize Media for Reuse | ☐ |
| M1-L3 | Decide the Disposition | ☐ |

**After completing each lab:**
1. Confirm your answer CSVs are saved in `C:\CyberLab\PodXX\MP-Artifacts\` with their original names
2. Confirm all seeded evidence files are still present
3. Check your status at https://training.status.tcecure.com/pod/XX

---

*This guide was created for the Digital Resilience Community Clinic (DRCC) Cyber Range.*
*CMMC Level 1 — Media Protection (MP) Module*
