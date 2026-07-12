# Media Protection (MP) — Reset Process

Run **Reset - MP Family (AWX template 27)** with `pods` or `pod_id`. The reset:

1. Removes `C:\CyberLab\PodNN\MP-Artifacts\`.
2. Removes `C:\CyberLab\PodNN\.families\MP.seeded`.
3. Leaves AC, IA, SI, SC, and the other new family untouched.
4. Does not delete shared template files used by other pods.

After reset, the next verifier reports every MP lab incomplete because its readiness marker and evidence are absent.
