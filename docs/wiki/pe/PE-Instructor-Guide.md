# Physical Protection (PE) — Instructor Guide

## Seed

Run **Seed - PE Family (AWX template 28)**. The survey accepts `7`, `7,9,12`, or blank for all pods. A family already marked as seeded is skipped unless `force_reseed=true`; use Reset before deliberately reseeding student work.

## Verify

Run **Verify - PE Family (AWX template 29)**. Verification is read-only to student evidence (MP mounts the media image read-only for inspection) and returns `completed` plus a human-readable `reason` for every declared lab on all 20 pods.

## Reset

Run **Reset - PE Family (AWX template 30)** with one pod or an explicit pod list. Reset removes only `C:\CyberLab\PodNN\PE-Artifacts\` and `PE.seeded`.

## Grading

Do not edit student response files to force completion. Use the tracker reason, source evidence, and lab validation rules to coach the student.
