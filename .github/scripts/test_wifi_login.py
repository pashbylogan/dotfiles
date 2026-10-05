"""Offline regression tests for the stowed portal helper. [D-WIFI-LOGIN]"""

import contextlib
from email.message import Message
import io
from pathlib import Path
import subprocess
import types
import unittest
from unittest.mock import patch
from urllib.error import HTTPError, URLError


SCRIPT = Path(__file__).resolve().parents[2] / "bin/.local/bin/wifi-login"
SOURCE = SCRIPT.read_text().split("<<'PY'\n", 1)[1].rsplit("\nPY", 1)[0]
helper = types.ModuleType("wifi_login")
exec(compile(SOURCE, str(SCRIPT), "exec"), helper.__dict__)


class RedirectTests(unittest.TestCase):
    base = "http://probe.example/check"

    def redirect(self, body="", status=200, headers=None):
        return helper.redirect_url(self.base, status, headers or {}, body)

    def test_http_redirect(self):
        url = "https://portal.example/auth?key=abc&x=1"
        self.assertEqual(self.redirect(status=307, headers={"Location": url}), url)

    def test_ac_style_javascript(self):
        url = "https://hotel.example:8001/index.php?zone=guest&redirurl=https%3A%2F%2Fexample.com"
        self.assertEqual(
            self.redirect(f'<script>document.location.href="{url}";</script>'), url
        )

    def test_other_literal_navigation(self):
        for body in [
            "window.location='/login';",
            "location.replace('/login')",
            "location.assign('/login')",
        ]:
            with self.subTest(body=body):
                self.assertEqual(self.redirect(body), "http://probe.example/login")

    def test_meta_refresh(self):
        self.assertEqual(
            self.redirect(
                '<meta content="0; URL=/login?a=1&amp;b=2" http-equiv="Refresh">'
            ),
            "http://probe.example/login?a=1&b=2",
        )

    def test_no_redirect(self):
        self.assertIsNone(self.redirect("NetworkManager is online"))
        self.assertIsNone(self.redirect("location.href = computeURL();"))
        self.assertIsNone(self.redirect(status=302, headers={"Location": self.base}))

    def test_reject_unsafe_targets(self):
        for target in [
            "javascript:alert(1)",
            "file:///etc/passwd",
            "https:///missing-host",
            "https://user:pass@portal.example/",
            "https://portal.example/a b",
            "https://portal.example/a\nb",
            "https://portal.example/a\tb",
        ]:
            with self.subTest(target=target), self.assertRaises(ValueError):
                self.redirect(status=302, headers={"Location": target})

    def test_discover_handles_http_redirect_without_following(self):
        headers = Message()
        headers["Location"] = "https://portal.example/login"
        response = HTTPError(self.base, 307, "redirect", headers, io.BytesIO(b""))
        with patch.object(helper, "build_opener") as build:
            build.return_value.open.side_effect = response
            self.assertEqual(helper.discover(), "https://portal.example/login")
        build.return_value.open.assert_called_once()
        self.assertEqual(build.return_value.open.call_args.kwargs["timeout"], 8)

    def test_probe_errors_are_bounded_and_reported(self):
        with patch.object(helper, "build_opener") as build:
            build.return_value.open.side_effect = OSError("unreachable")
            with contextlib.redirect_stderr(io.StringIO()), self.assertRaises(ValueError):
                helper.discover()
        self.assertEqual(build.return_value.open.call_count, 2)

    def test_url_error_falls_back_to_javascript_probe(self):
        response = io.BytesIO(b'location.href="https://portal.example/login";')
        response.code = 200
        response.headers = {}
        with patch.object(helper, "build_opener") as build:
            build.return_value.open.side_effect = [URLError("DNS failed"), response]
            with contextlib.redirect_stderr(io.StringIO()):
                self.assertEqual(helper.discover(), "https://portal.example/login")
        self.assertEqual(build.return_value.open.call_count, 2)
        self.assertEqual(
            build.return_value.open.call_args.args, ("http://neverssl.com/",)
        )

    def test_urljoin_cannot_hide_controls(self):
        for target in ["\nhttps://portal.example/", "https://portal.example/?a=1&#9;b=2"]:
            with self.subTest(target=target), self.assertRaises(ValueError):
                self.redirect(status=302, headers={"Location": target})

    def run_main(self, state, args=(), url="https://portal.example/login"):
        result = subprocess.CompletedProcess([], 0, state + "\n", "")
        out = io.StringIO()
        with (
            patch.object(helper.sys, "argv", ["wifi-login", *args]),
            patch.object(helper.shutil, "which", return_value="present"),
            patch.object(helper.subprocess, "run", return_value=result) as run,
            patch.object(helper, "discover", return_value=url) as discover,
            contextlib.redirect_stdout(out),
        ):
            helper.main()
        return out.getvalue(), run, discover

    def test_no_browser_on_full_connectivity(self):
        _, run, discover = self.run_main("full")
        discover.assert_not_called()
        self.assertEqual(run.call_count, 1)

    def test_omarchy_launcher_keeps_url_one_argument(self):
        url = "https://portal.example/login?a=1&b=2"
        _, run, _ = self.run_main("portal", url=url)
        self.assertEqual(
            run.call_args.args[0], ["omarchy", "launch", "browser", url]
        )

    def test_print_does_not_launch(self):
        out, run, _ = self.run_main("portal", args=("--print",))
        self.assertEqual(out, "https://portal.example/login\n")
        self.assertEqual(run.call_count, 1)

    def test_no_network_fails_without_probing(self):
        with contextlib.redirect_stderr(io.StringIO()), self.assertRaises(SystemExit) as exc:
            self.run_main("none")
        self.assertEqual(exc.exception.code, 1)


if __name__ == "__main__":
    unittest.main()
