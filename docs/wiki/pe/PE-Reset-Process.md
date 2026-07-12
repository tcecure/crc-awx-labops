# Physical Protection (PE) — Reset Process

Run **Reset - PE Family (AWX template 30)** with `pods` or `pod_id`. The reset:

1. Removes `C:\CyberLab\PodNN\PE-Artifacts\`.
2. Removes `C:\CyberLab\PodNN\.families\PE.seeded`.
3. Leaves AC, IA, SI, SC, and the other new family untouched.
4. Does not delete shared template files used by other pods.

After reset, the next verifier reports every PE lab incomplete because its readiness marker and evidence are absent.
