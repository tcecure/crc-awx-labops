"""Safety rules for the CyDeploy lab automation.

CyDeploy runs against pods that are *not* in use. These tests lock in the two
properties that keep it off an active student's pod: every CyDeploy playbook
takes its hosts from a mandatory variable (never a pod range, never a group of
all pods), and the protected and approved pod lists never overlap.
"""

from __future__ import annotations

import re
from pathlib import Path

import pytest
import yaml

REPO = Path(__file__).resolve().parents[1]
PLAYBOOK_DIRS = (
    REPO / "playbooks" / "cydeploy",
    REPO / "playbooks" / "si" / "cydeploy",
    REPO / "playbooks" / "sc" / "cydeploy",
)
POD_VARS = REPO / "vars" / "cydeploy-pods.yml"
INVENTORY = REPO / "inventories" / "prod.ini"


def cydeploy_playbooks() -> list[Path]:
    found: list[Path] = []
    for directory in PLAYBOOK_DIRS:
        found.extend(sorted(directory.glob("*.yml")))
    assert found, "no CyDeploy playbooks found"
    return found


@pytest.fixture(scope="module")
def pod_vars() -> dict:
    return yaml.safe_load(POD_VARS.read_text())


@pytest.mark.parametrize("playbook", cydeploy_playbooks(), ids=lambda p: p.name)
def test_targets_are_mandatory_and_never_all_pods(playbook: Path) -> None:
    plays = yaml.safe_load(playbook.read_text())

    for play in plays:
        hosts = str(play["hosts"])

        if hosts == "localhost":
            continue

        assert "cydeploy_targets | mandatory" in hosts, (
            f"{playbook.name} play '{play['name']}' must take its hosts from "
            f"cydeploy_targets | mandatory, got {hosts!r}"
        )
        assert "default" not in hosts, (
            f"{playbook.name} play '{play['name']}' gives cydeploy_targets a "
            "default; a forgotten target must fail, not select pods"
        )


@pytest.mark.parametrize("playbook", cydeploy_playbooks(), ids=lambda p: p.name)
def test_no_pod_range_fallback(playbook: Path) -> None:
    body = playbook.read_text()

    assert "range(1," not in body, (
        f"{playbook.name} builds a pod range; CyDeploy must act only on the "
        "hosts an operator named explicitly"
    )
    for play in yaml.safe_load(body):
        assert str(play["hosts"]) != "crc_pod_servers", (
            f"{playbook.name} targets the whole pod-server group"
        )


@pytest.mark.parametrize("playbook", cydeploy_playbooks(), ids=lambda p: p.name)
def test_mutating_playbooks_run_preflight(playbook: Path) -> None:
    body = playbook.read_text()

    assert "name: cydeploy_preflight" in body, (
        f"{playbook.name} must include the cydeploy_preflight role before it "
        "touches a pod"
    )


def test_protected_and_approved_pods_do_not_overlap(pod_vars: dict) -> None:
    protected = set(pod_vars["protected_pods"])
    approved = set(pod_vars["approved_cydeploy_pods"])

    assert protected, "protected_pods must not be empty"
    assert approved, "approved_cydeploy_pods must not be empty"
    assert not protected & approved, (
        f"pods are both protected and approved: {sorted(protected & approved)}"
    )


def test_approved_pods_are_not_in_the_protected_inventory_group(pod_vars: dict) -> None:
    text = INVENTORY.read_text()
    group = re.search(
        r"^\[cydeploy_protected_active_pods\]\n((?:[^\[\n].*\n)*)",
        text,
        re.MULTILINE,
    )
    assert group, "cydeploy_protected_active_pods group missing from the inventory"

    protected_hosts = {line.strip() for line in group.group(1).splitlines() if line.strip()}
    approved_hosts = {
        f"{pod.lower()}-srv".replace("pod", "pod") for pod in pod_vars["approved_cydeploy_pods"]
    }

    assert not protected_hosts & approved_hosts, (
        "a pod in the protected inventory group is also approved for CyDeploy: "
        f"{sorted(protected_hosts & approved_hosts)}"
    )
