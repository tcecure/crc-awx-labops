# AWX Lab Seeding Guide

This guide walks you through how to **seed**, **verify**, and **reset** the CMMC Access Control (AC) labs using the AWX web interface. No command-line experience is needed — everything is done by clicking buttons in AWX.

---

## Table of Contents

1. [What is Lab Seeding?](#what-is-lab-seeding)
2. [Before You Begin](#before-you-begin)
3. [Step 1: Log Into AWX](#step-1-log-into-awx)
4. [Step 2: Seed the AC Labs](#step-2-seed-the-ac-labs)
5. [Step 3: Verify the Labs Were Seeded Correctly](#step-3-verify-the-labs-were-seeded-correctly)
6. [Step 4: Reset Labs When Finished (Switching to Next Lab Family)](#step-4-reset-labs-when-finished)
7. [Understanding the AWX Templates](#understanding-the-awx-templates)
8. [Troubleshooting](#troubleshooting)
9. [Frequently Asked Questions](#frequently-asked-questions)

---

## What is Lab Seeding?

"Seeding" means setting up the lab environment so students can begin their exercises. When you run the seeding process, it automatically:

- Creates practice user accounts on the domain controller (e.g., `P01-hr.user1`, `P01-fin.user1`)
- Creates security groups (e.g., `P01-SG-ACS-Finance`, `P01-SG-ACS-HR`)
- Sets up organizational units (folders) for each pod (Pod01 through Pod20)
- Introduces intentional misconfigurations that students must find and fix during their labs

Each **pod** is an isolated workspace for one student or student team. All 20 pods share the same domain controllers (dc01 and dc02) but are separated by organizational units so students cannot see or affect each other's work.

---

## Before You Begin

Make sure the following are true before you start:

- **AWX is running** — The AWX server should be accessible at its web address
- **Domain controllers are online** — dc01 (10.50.1.10) and dc02 (10.50.1.11) must be powered on and reachable
- **You have the AWX login credentials** — You will need the admin username and password

---

## Step 1: Log Into AWX

1. Open your web browser (Chrome, Firefox, or Edge)
2. Navigate to the AWX web address:
   ```
   http://<awx-server-address>:8088
   ```
3. You will see the AWX login screen
4. Enter your credentials:
   - **Username:** `admin`
   - **Password:** *(ask your system administrator if you don't have this)*
5. Click **Log In**

You should now see the AWX Dashboard.

---

## Step 2: Seed the AC Labs

This step creates all the user accounts, groups, and lab scenarios that students need.

### 2a. Navigate to Templates

1. On the left sidebar, look under **Resources**
2. Click **Templates**
3. You will see a list of available job templates

### 2b. Launch the Seed Job

1. Find the template called **"Seed CMMC AC Labs"**
2. On the right side of that row, click the **rocket icon** (the Launch button)

   ![Launch button is the rocket icon on the right side of the template row](images/launch-icon.png)

3. A prompt will appear asking you to review or change **Extra Variables**. You will see something like:
   ```yaml
   pod_count: 10
   seed_user_password: <password>
   ```
4. **Change the values as needed:**
   - `pod_count` — How many student pods to set up. Change this to `20` if you want all 20 pods seeded. If you only need 10 pods, leave it at `10`.
   - `seed_user_password` — The password that will be set on all lab user accounts. Students will use this password to log in as the practice users. **Choose a password and type it here** (e.g., `CyberLab2026!`).

5. Click the **Launch** button at the bottom of the prompt

### 2c. Watch the Job Run

1. AWX will automatically take you to the **Job Output** screen
2. You will see a live log of what is happening:
   - First, it copies the setup scripts to the domain controller
   - Then it creates the baseline structure for each pod (Pod01, Pod02, etc.)
   - Finally, it applies all 12 lab scenarios to each pod
3. **Wait for the job to finish.** This may take several minutes depending on how many pods you are seeding.
4. When the job is done, you will see one of these statuses:
   - **Successful** (green) — Everything worked. Labs are ready for students.
   - **Failed** (red) — Something went wrong. See the [Troubleshooting](#troubleshooting) section below.

---

## Step 3: Verify the Labs Were Seeded Correctly

After seeding, you should verify that all labs were created properly.

### 3a. Launch the Verify Job

1. Go back to **Templates** (left sidebar → Resources → Templates)
2. Find **"Verify CMMC AC Labs"**
3. Click the **rocket icon** to launch it
4. When prompted for Extra Variables, set `pod_count` to the same number you used for seeding (e.g., `20`)
5. Click **Launch**

### 3b. Read the Results

1. The job will check each lab for each pod and report whether it is **Complete** (C) or **Incomplete** (I)
2. In the job output, look for a summary table or matrix showing the results
3. **What you want to see:** All labs should show as **Complete** (C) for every pod
4. If any labs show as **Incomplete** (I), you may need to re-run the seed for those specific pods, or check the [Troubleshooting](#troubleshooting) section

---

## Step 4: Reset Labs When Finished

When the current lab session is over (for example, students have finished the AC labs and you need to prepare for the next lab family like IA), you need to **reset** the environment.

### What Does Reset Do?

The reset process **removes** all the AC lab artifacts that were created during seeding:
- Deletes lab-created user accounts (e.g., ex.employee, contractor.user1)
- Removes users from groups they were added to during lab scenarios
- Moves users back to their correct organizational units
- Clears any evidence folders that were created
- Resets user descriptions

**Important:** The reset does **NOT** delete the baseline organizational unit structure. The pod OUs (Pod01–Pod20) and the original structure remain intact. This means you can immediately re-seed for the next lab family after resetting.

### 4a. Launch the Reset Job

1. Go to **Templates** (left sidebar → Resources → Templates)
2. Find **"Reset AC Labs (AD-Level)"**
3. Click the **rocket icon** to launch it
4. When prompted, set `pod_count` to the number of pods you want to reset (typically `20` for all pods)
5. Click **Launch**

### 4b. Wait for Completion

1. Watch the job output — it will show progress for each pod
2. Wait for the **Successful** status
3. Once complete, the environment is clean and ready to be seeded again for the next lab family

---

## Understanding the AWX Templates

Here is a summary of all the templates available and when to use each one:

| Template Name | When to Use It | What It Does |
|---|---|---|
| **Seed CMMC AC Labs** | Before a new AC lab session begins | Creates all user accounts, groups, and 12 lab scenarios for each pod |
| **Verify CMMC AC Labs** | After seeding, to confirm everything is set up | Checks every lab in every pod and reports Complete/Incomplete status |
| **Reset AC Labs (AD-Level)** | After students finish AC labs, before switching to next family | Removes all AC lab artifacts while keeping baseline structure |
| **Reset to Baseline (AD-Level)** | Same as above — full baseline reset | Removes all lab artifacts and prepares for next lab family |

### Typical Workflow

```
1. Seed CMMC AC Labs     →  Set up labs for students
2. Verify CMMC AC Labs   →  Confirm everything is ready
3. (Students do their labs)
4. Reset AC Labs         →  Clean up after AC labs
5. (Seed next family, e.g., IA labs)
```

---

## Troubleshooting

### The seed job failed

1. Click on the failed job to see the output
2. Scroll through the output to find the error message (look for red text or lines starting with "FAILED")
3. Common causes:
   - **Domain controller is not reachable** — Make sure dc01 (10.50.1.10) is powered on and connected to the network
   - **WinRM connection refused** — The Windows Remote Management service may not be running on the domain controller. Contact your system administrator.
   - **Authentication failed** — The WinRM credential in AWX may have the wrong password. Contact your system administrator to update the "CRC WinRM Verifier" credential.

### The verify job shows Incomplete for some labs

1. This usually means the seed did not fully complete for those pods
2. Try re-running the **Seed CMMC AC Labs** job with the same settings
3. If the problem persists, contact your system administrator

### I accidentally ran the wrong template

- If you ran **Reset** by accident, simply re-run the **Seed** template to set everything back up
- If you ran **Seed** when labs were already seeded, this is usually harmless — the scripts are designed to handle re-runs

### The job is stuck or taking too long

- Seeding 20 pods typically takes 5–15 minutes
- If a job has been running for more than 30 minutes, something may be wrong
- You can click the **Cancel** button (red X) on the job output page to stop it
- Check that the domain controllers are online and try again

---

## Frequently Asked Questions

**Q: How many pods can I seed at once?**
A: Up to 20 pods. Set the `pod_count` variable to the number you need.

**Q: Do I need to reset before seeding?**
A: No. If this is a fresh environment (never been seeded before), you can go straight to seeding. You only need to reset when switching from one lab family to another (e.g., AC to IA).

**Q: Can I seed just a few pods for testing?**
A: Yes. Set `pod_count` to a smaller number like `1` or `5` to seed only those pods.

**Q: What password should I set for seed_user_password?**
A: Choose a password that meets your organization's requirements. This will be the password for all lab user accounts that students will use during exercises. Make sure to communicate this password to students.

**Q: Can students from one pod see another pod's data?**
A: No. Each pod is isolated using organizational units (OUs). Pod01 students can only see Pod01 users and groups. They cannot access Pod02's resources.

**Q: What happens if I reset while students are still working?**
A: The reset will immediately remove all lab artifacts. Students will lose their in-progress work. **Always confirm that all students have finished before running a reset.**

**Q: How do I switch from AC labs to IA labs?**
A: Run the **Reset AC Labs** template first to clean up, then seed the IA labs using the appropriate IA seed template.
