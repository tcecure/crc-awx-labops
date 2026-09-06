import importlib.util
import json
import os
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
ENV_KEYS = ("CRC_TARGET_MODE", "CRC_HELD_BACK_PODS")


def load_advance(**env):
    previous = {key: os.environ.get(key) for key in ENV_KEYS}
    for key in ENV_KEYS:
        os.environ.pop(key, None)
    os.environ.update({key: value for key, value in env.items() if value is not None})
    try:
        spec = importlib.util.spec_from_file_location(
            "advance_families_case", ROOT / "scripts" / "advance_families.py"
        )
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)
        return module
    finally:
        for key, value in previous.items():
            if value is None:
                os.environ.pop(key, None)
            else:
                os.environ[key] = value


class TargetModeTests(unittest.TestCase):
    def test_member_server_is_the_default(self):
        self.assertEqual(load_advance().TARGET_MODE, "member_server")

    def test_unknown_mode_falls_back_to_member_server(self):
        self.assertEqual(load_advance(CRC_TARGET_MODE="nonsense").TARGET_MODE, "member_server")

    def test_scheduled_templates_are_the_same_in_both_models(self):
        for mode in ("member_server", "shared_dc"):
            advance = load_advance(CRC_TARGET_MODE=mode)
            self.assertEqual(
                advance.VERIFY_TEMPLATES,
                {"AC": 13, "IA": 16, "SI": 19, "SC": 22, "MP": 28, "PE": 31},
            )
            self.assertEqual(
                advance.SEED_TEMPLATES,
                {"AC": 12, "IA": 15, "SI": 18, "SC": 21, "MP": 27, "PE": 30},
            )


class SeedLaunchTests(unittest.TestCase):
    def _capture(self, advance, family, pod):
        captured = {}

        def fake_req(url, token, method="GET", body=None):
            captured["url"] = url
            captured["body"] = body
            return 201, {"id": 999}

        advance._req = fake_req
        self.assertEqual(advance.launch_seed("http://awx", "token", family, pod), (201, 999))
        return captured

    def test_host_scoped_seed_is_limited_to_the_pod_session_host(self):
        captured = self._capture(load_advance(), "MP", 5)
        self.assertTrue(captured["url"].endswith("/job_templates/27/launch/"))
        self.assertEqual(captured["body"]["limit"], "pod05-srv")
        self.assertEqual(json.loads(captured["body"]["extra_vars"]), {"pods": "5"})

    def test_directory_seed_keeps_its_template_limit(self):
        captured = self._capture(load_advance(), "AC", 5)
        self.assertNotIn("limit", captured["body"])

    def test_shared_dc_mode_never_limits_to_a_pod_session_host(self):
        captured = self._capture(load_advance(CRC_TARGET_MODE="shared_dc"), "MP", 5)
        self.assertNotIn("limit", captured["body"])


class HeldBackPodTests(unittest.TestCase):
    def test_pods_are_parsed_from_the_environment(self):
        advance = load_advance(CRC_HELD_BACK_PODS="7, 11")
        self.assertEqual(advance.HELD_BACK_PODS, {7, 11})

    def test_no_held_back_pods_by_default(self):
        self.assertEqual(load_advance().HELD_BACK_PODS, set())

    def test_pod_number_reads_tracker_pod_keys(self):
        advance = load_advance()
        self.assertEqual(advance.pod_number("pod07"), 7)
        self.assertEqual(advance.pod_number("nonsense"), 0)


if __name__ == "__main__":
    unittest.main()
