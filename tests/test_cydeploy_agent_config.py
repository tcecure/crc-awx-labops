"""Configuration guarantees for the CyDefense agent install.

The supplied agent cannot confine itself: its licence check always returns true
and its command pipe accepts network scans and volume imaging from any
interactive user (docs/cydeploy/CYDEPLOY-AGENT-FINDINGS.md). Everything that
keeps it inside one pod therefore lives in this repository, so these tests lock
it in: the artifact is checksum-pinned, the agent is installed offline with
insights and the imaging helper off, its binaries are denied every outbound
path, and the rules that do the denying are outside the namespace a student lab
is allowed to delete.
"""

from __future__ import annotations

from pathlib import Path

import pytest
import yaml

REPO = Path(__file__).resolve().parents[1]
ROLE = REPO / "roles" / "cydeploy_community"
DEFAULTS = ROLE / "defaults" / "main.yml"
INSTALL_TASKS = ROLE / "tasks" / "main.yml"
GUARD_TASKS = ROLE / "tasks" / "egress_guard.yml"
UNINSTALL_TASKS = ROLE / "tasks" / "uninstall.yml"
POD_VARS = REPO / "vars" / "cydeploy-pods.yml"
FINDINGS = REPO / "docs" / "cydeploy" / "CYDEPLOY-AGENT-FINDINGS.md"

APPROVED_SHA256 = "1648363b29d502eb978c0ae805a91fcc11e9c73f627097adfc84c79edd232fb9"
PRODUCT_CODE = "{00BDA44B-2F36-464E-BCF9-99E5BD743CA1}"


@pytest.fixture(scope="module")
def defaults() -> dict:
    return yaml.safe_load(DEFAULTS.read_text())


@pytest.fixture(scope="module")
def pod_vars() -> dict:
    return yaml.safe_load(POD_VARS.read_text())


def test_installation_is_off_by_default(defaults: dict) -> None:
    assert defaults["cydeploy_install_enabled"] is False


def test_artifact_is_pinned_in_both_places(defaults: dict, pod_vars: dict) -> None:
    # The preflight role reads these before cydeploy_community is included, so a
    # role default alone cannot gate the run; both copies must agree.
    for source in (defaults, pod_vars):
        assert source["cydeploy_installer_sha256"] == APPROVED_SHA256
        assert source["cydeploy_product_code"] == PRODUCT_CODE
        assert source["cydeploy_version"] == "1.0.16226.849"


def test_agent_is_installed_offline_with_telemetry_off(defaults: dict) -> None:
    assert defaults["cydeploy_online_mode"] == 0
    assert "localhost" in defaults["cydeploy_api_url"]
    assert defaults["cydeploy_insights_enabled"] is False
    assert defaults["cydeploy_imaging_helper_enabled"] is False
    assert defaults["cydeploy_guard_egress"] is True


def test_install_applies_offline_properties_and_corrects_insights() -> None:
    body = INSTALL_TASKS.read_text()

    assert "ONLINE_MODE={{ cydeploy_online_mode }}" in body
    assert "APIURL={{ cydeploy_api_url }}" in body
    # The MSI ships Insights=1, so the registry value must be written explicitly
    # rather than left at the installer default.
    assert "name: Insights" in body
    assert "name: Online" in body
    assert "AllowInvalidServerCert" in body


def test_service_is_configured_before_it_is_started() -> None:
    body = INSTALL_TASKS.read_text()
    tasks = yaml.safe_load(body)
    names = [
        task["name"]
        for block in tasks
        for task in block.get("block", [block])
    ]

    stop = names.index("Stop the CyDefense service while its configuration is corrected")
    config = names.index("Apply the pod-local agent configuration")
    guard = names.index("Keep the CyDeploy agent binaries off every network")
    start = names.index("Start the CyDefense service with the corrected configuration")

    assert stop < config < guard < start, (
        "the agent must be configured and fenced before it is allowed to run"
    )


def test_install_asserts_the_applied_configuration() -> None:
    body = INSTALL_TASKS.read_text()

    assert "cydeploy_applied.result.service_state == 'Running'" in body
    assert "cydeploy_applied.result.online | int == cydeploy_online_mode | int" in body
    assert "cydeploy_applied.result.insights | int" in body
    assert "cydeploy_applied.result.guard_rules | int > 0" in body


def test_install_refuses_an_unpinned_or_mismatched_installer() -> None:
    body = INSTALL_TASKS.read_text()

    assert "cydeploy_installer_sha256 | default('') | trim) == ''" in body
    assert (
        "cydeploy_installer_stat.stat.checksum | lower != cydeploy_installer_sha256 | lower"
        in body
    )


def test_guard_blocks_every_agent_binary_outbound() -> None:
    tasks = yaml.safe_load(GUARD_TASKS.read_text())
    assert tasks, "the egress guard must do something"

    for task in tasks:
        rule = task["community.windows.win_firewall_rule"]
        assert rule["direction"] == "out"
        assert rule["action"] == "block"
        assert rule["enabled"] is True
        assert rule["profiles"] == "domain,private,public"

        programs = task["vars"]["cydeploy_guard_programs"]
        assert set(programs) == {"service", "tray", "imaging"}
        assert all(path.endswith(".exe") for path in programs.values())

    protocols = {task["community.windows.win_firewall_rule"]["protocol"] for task in tasks}
    assert {"any", "icmpv4"} <= protocols, (
        "the scanner finds hosts with ICMP echo, so ICMP must be denied by "
        "protocol as well as by the catch-all rule"
    )


def test_guard_namespace_is_outside_the_student_lab_namespace(defaults: dict) -> None:
    prefix = defaults["cydeploy_guard_rule_prefix"]

    # SC-M5-L1 seeds P<NN>-CYDEPLOY-* rules and its reset deletes everything in
    # that namespace. The guard must not be deletable by a student exercise.
    assert not prefix.startswith("P")
    assert "CYDEPLOY-GUARD" in prefix

    reset = (REPO / "roles" / "seed_sc_cydeploy" / "files" / "reset-sc-cydeploy-labs.ps1").read_text()
    assert prefix not in reset, (
        "the SC-M5-L1 reset must not match the CyDeploy egress guard rules"
    )


def test_removal_uses_the_product_code_and_clears_agent_state() -> None:
    body = UNINSTALL_TASKS.read_text()

    assert 'product_id: "{{ cydeploy_product_code }}"' in body
    assert "state: absent" in body
    for path in (
        r"C:\ProgramData\CyDefense",
        r"C:\ProgramData\CyDeploy.AgentEnrollment",
    ):
        assert path in body, f"removal must clear {path}"
    assert "Remove the CyDeploy egress guard rules" in body
    assert "HKLM:\\SOFTWARE\\CyDefense" in body


def test_findings_document_records_the_isolation_decision() -> None:
    body = FINDINGS.read_text()

    assert APPROVED_SHA256 in body
    assert PRODUCT_CODE in body
    for claim in (
        "HasLicenseFeature",
        "BUILTIN\\Users",
        "scan_network",
        "cvelistv5",
        "CRC-CYDEPLOY-GUARD",
        # Learning mode records the student's screen and keystrokes and is not
        # gated by the Insights flag; only ONLINE_MODE=0 keeps it unreachable.
        "startLearning",
        "EnsureInsightUploaderRunning",
        # The on-premise server is the offline topology, and is explicitly out of
        # scope for pods and domain controllers.
        "CyDeployWebSetup-1.0.16226.940.msi",
    ):
        assert claim in body, f"the findings document must address {claim}"


# --- Permanence -------------------------------------------------------------
#
# CyDeploy stays on a pod once installed. The pod server is still a Windows box
# a student has administrative rights on, and it can be rebuilt or rolled back,
# so permanence is three properties: the routine restore point contains the
# agent, there is an idempotent way to re-assert it, and uninstalling takes a
# deliberate act.

INSTALL_PLAY = REPO / "playbooks" / "cydeploy" / "install.yml"
ENSURE_PLAY = REPO / "playbooks" / "cydeploy" / "ensure.yml"
REMOVE_PLAY = REPO / "playbooks" / "cydeploy" / "remove.yml"
SI_RESET = REPO / "roles" / "seed_si_cydeploy" / "files" / "reset-si-cydeploy-labs.ps1"
SC_RESET = REPO / "roles" / "seed_sc_cydeploy" / "files" / "reset-sc-cydeploy-labs.ps1"


def test_install_snapshots_the_pod_with_the_agent_present(pod_vars: dict) -> None:
    assert pod_vars["cydeploy_installed_snapshot_name"] == "cydeploy-installed"
    assert pod_vars["cydeploy_installed_snapshot_name"] != pod_vars["cydeploy_snapshot_name"]
    assert pod_vars["cydeploy_post_install_snapshot"] is True

    body = INSTALL_PLAY.read_text()
    install = body.index("name: cydeploy_community")
    snapshot = body.index("cydeploy_installed_snapshot_name")
    assert install < snapshot, (
        "the agent-present snapshot must be taken after the install, otherwise "
        "it is just another pre-install baseline"
    )
    assert "qm" in body and "snapshot" in body


def test_an_idempotent_play_can_re_assert_the_agent() -> None:
    body = ENSURE_PLAY.read_text()

    assert "cydeploy_targets | mandatory" in body
    assert "name: cydeploy_preflight" in body, (
        "drift repair must not be allowed to run on a pod a student is using"
    )
    assert "name: cydeploy_community" in body, (
        "repair must reuse the install role rather than keep a second copy of "
        "the approved configuration"
    )


def test_uninstall_requires_a_deliberate_approval() -> None:
    body = REMOVE_PLAY.read_text()

    assert "cydeploy_removal_approved" in body
    gate = body.index("cydeploy_removal_approved")
    preflight = body.index("name: cydeploy_preflight")
    assert gate < preflight, "the removal gate must be the first thing the play does"

    pod_vars = yaml.safe_load(POD_VARS.read_text())
    assert pod_vars["cydeploy_removal_approved"] is False


@pytest.mark.parametrize("script", (SI_RESET, SC_RESET), ids=("si", "sc"))
def test_lab_resets_leave_the_agent_installed(script: Path) -> None:
    body = script.read_text()

    for survivor in (
        "CyDefenseService",
        "CRC-CYDEPLOY-GUARD",
        r"C:\CyberLab\_Tools\CyDeploy",
        r"C:\Program Files\CyDeploy",
        "msiexec",
    ):
        assert survivor not in body, (
            f"{script.name} must not touch {survivor}; a lab reset clears the "
            "student's artifacts, not the agent"
        )
