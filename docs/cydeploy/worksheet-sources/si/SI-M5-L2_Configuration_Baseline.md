% ACS Configuration Baseline (Extract)
% Cyber Lab Reference Document — CMMC Level 1
% Advanced Cyber Solutions (ACS)

## Purpose

This extract of the ACS configuration baseline is provided so that analysts can decide whether an observed condition is expected, a finding, or a formally approved deviation. It is a lab reference document.

## BL-1 Software installation

1. Only software on the ACS Approved Software List may be installed on ACS systems.
2. Software that is present but not on the approved list is a finding unless a current entry exists in the ACS exception register.
3. Software whose publisher cannot be verified, or that has no recorded owner, must be treated as Needs Investigation until ownership is established. It must not be silently accepted.

## BL-2 Software currency

1. Software must run a vendor-supported version.
2. File transfer and remote access software that is no longer supported by its vendor is a finding regardless of who installed it.

## BL-3 Services

1. Only services required for a documented business or operational purpose may run.
2. Remote management services that are not required for the system's documented role must be disabled. Remote Registry is not required on ACS systems and must remain disabled.
3. Endpoint protection services are required and must remain enabled and current.

## BL-4 Endpoint protection

1. Microsoft Windows Defender Antivirus must be enabled with real-time protection on.
2. Definitions must be current.
3. Defender being enabled and current is the expected baseline state, not a finding.

## BL-5 Exceptions

1. A deviation from this baseline is only an Approved Exception when a current, unexpired entry exists in the ACS exception register, approved by the CISO, with a documented justification.
2. An expired exception reverts to a finding.
3. An exception must never be assumed. If it is not written down, it does not exist.

## BL-6 Evidence

1. Every classification an analyst records must cite the reference used: the approved software list, the exception register, or this baseline.
2. Tool output alone is not a finding. A finding is tool output evaluated against this baseline.
