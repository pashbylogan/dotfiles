"""Stateless adapter contracts; never dispatch into the running desktop.

[D-GLOBAL-WORKSPACES]
"""

from pathlib import Path
import os
import shutil
import subprocess
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[2]
ADAPTER = ROOT / "hypr/.config/default/hypr/monitor-workspaces.lua"
LUA = shutil.which("lua") or shutil.which("lua5.4")
OMARCHY = Path("/usr/share/omarchy")


@unittest.skipUnless(LUA, "Lua is required for adapter contract tests")
class GlobalWorkspaceTests(unittest.TestCase):
    def run_contract(self, body):
        # No io, os, require, events or compositor state is exposed to the module.
        script = r'''
local loading = true
local function dispatcher(kind)
  return function(args)
    assert(not loading, "load-time dispatcher call")
    return { kind = kind, args = args }
  end
end
local env = {
  tostring = tostring,
  o = {},
  hl = { dsp = {
    focus = dispatcher("focus"),
    window = { move = dispatcher("window.move") },
    workspace = { move = dispatcher("workspace.move") },
  } },
}
setmetatable(env, { __index = function(_, key)
  error("adapter accessed unexpected global: " .. key)
end })
local M = assert(loadfile(arg[1], "t", env))()
loading = false
assert(env.o.workspaces == M)
local count = 0
for _ in pairs(M) do count = count + 1 end
assert(count == 4, "only four compatibility methods are needed")
'''
        result = subprocess.run(
            [LUA, "-", str(ADAPTER)], input=script + body,
            text=True, capture_output=True, timeout=10,
        )
        self.assertEqual(result.returncode, 0, result.stderr)

    def test_focus_uses_global_id_and_ignores_widget_monitor(self):
        self.run_contract('''
for _, id in ipairs({1, 2, 10, 11, 38}) do
  local d = M.focus(id, "DP-2")
  assert(d.kind == "focus" and d.args.workspace == tostring(id))
  assert(d.args.monitor == nil)
end
''')

    def test_window_move_preserves_follow_choice(self):
        self.run_contract('''
for _, follow in ipairs({true, false}) do
  local d = M.move_window(10, follow)
  assert(d.kind == "window.move" and d.args.workspace == "10")
  assert(d.args.follow == follow)
end
assert(M.move_window(1).args.follow == nil)
''')

    def test_directional_moves_use_native_dispatchers(self):
        self.run_contract('''
for _, direction in ipairs({"l", "r", "u", "d"}) do
  local workspace = M.move_to_monitor(direction)
  local window = M.move_window_to_monitor(direction)
  assert(workspace.kind == "workspace.move")
  assert(window.kind == "window.move")
  assert(workspace.args.monitor == direction)
  assert(window.args.monitor == direction)
end
''')

    def test_installer_refuses_first_deployment_in_live_session(self):
        with tempfile.TemporaryDirectory(prefix="t3-task-") as tmp:
            env = dict(os.environ, HOME=tmp, HYPRLAND_INSTANCE_SIGNATURE="test-session")
            result = subprocess.run(
                ["bash", str(ROOT / "install")], env=env,
                text=True, capture_output=True, timeout=10,
            )
            self.assertNotEqual(result.returncode, 0)
            self.assertIn("requires logout first", result.stderr)
            self.assertEqual(list(Path(tmp).iterdir()), [])

    @unittest.skipUnless(shutil.which("stow"), "Stow is required for deployment test")
    def test_stow_deploys_user_shadow_without_packaged_edits(self):
        with tempfile.TemporaryDirectory(prefix="t3-task-") as tmp:
            result = subprocess.run(
                ["stow", "--dir", str(ROOT), "--target", tmp, "--no-folding", "hypr"],
                text=True, capture_output=True, timeout=10,
            )
            self.assertEqual(result.returncode, 0, result.stderr)
            target = Path(tmp) / ".config/default/hypr/monitor-workspaces.lua"
            self.assertTrue(target.is_symlink())
            self.assertEqual(target.resolve(), ADAPTER)

    @unittest.skipUnless(
        shutil.which("Hyprland") and (OMARCHY / "default/hypr/bootstrap.lua").exists(),
        "installed Hyprland/Omarchy required for native config-only validation",
    )
    def test_native_config_and_stock_tiling_bindings(self):
        with tempfile.TemporaryDirectory(prefix="t3-task-") as tmp:
            home = Path(tmp)
            shadow = home / ".config/default/hypr/monitor-workspaces.lua"
            shadow.parent.mkdir(parents=True)
            shadow.symlink_to(ADAPTER)
            runtime = home / "runtime"
            runtime.mkdir(mode=0o700)
            config = home / ".config/hypr/hyprland.lua"
            config.parent.mkdir(parents=True)
            config.write_text('''
dofile("/usr/share/omarchy/default/hypr/bootstrap.lua")
require("default.hypr.helpers")
assert(package.searchpath("default.hypr.monitor-workspaces", package.path) ==
  os.getenv("HOME") .. "/.config/default/hypr/monitor-workspaces.lua")
local M = require("default.hypr.monitor-workspaces")
assert(M == o.workspaces)
require("default.hypr.bindings.tiling")
-- Construct dispatchers only; never execute them or contact a compositor.
for _, n in ipairs({1, 10, 11, 38}) do
  M.focus(n, "DP-2")
  M.move_window(n, true)
  M.move_window(n, false)
end
for _, direction in ipairs({"l", "r", "u", "d"}) do
  M.move_to_monitor(direction)
  M.move_window_to_monitor(direction)
end
''')
            env = {
                "PATH": os.environ.get("PATH", "/usr/bin:/bin"),
                "HOME": tmp,
                "XDG_CONFIG_HOME": str(home / ".config"),
                "XDG_STATE_HOME": str(home / ".local/state"),
                "XDG_RUNTIME_DIR": str(runtime),
                "OMARCHY_PATH": str(OMARCHY),
                "LANG": "C.UTF-8",
            }
            # Use the installed menu's own read-only Lua scanner, not a replica.
            menu = (OMARCHY / "bin/omarchy-menu-keybindings").read_text()
            scanner = menu.split("<<'LUA'\n", 1)[1].split("\nLUA\n", 1)[0]
            scan = subprocess.run(
                [LUA, "-E", "-"], input=scanner, env=env, cwd=tmp,
                text=True, capture_output=True, timeout=15,
            )
            self.assertEqual(scan.returncode, 0, scan.stderr)
            self.assertNotIn("lua bind scan failed", scan.stderr)
            records = [line.split("\t", 4) for line in scan.stdout.splitlines()]
            workspace_records = [record for record in records if len(record) == 5 and (
                record[1].startswith(("Switch to workspace ", "Move window to workspace ",
                                      "Move window silently to workspace ")) or
                (record[1].startswith(("Move workspace to ", "Move window to ")) and
                 record[1].endswith(" monitor"))
            )]
            self.assertEqual(len(workspace_records), 38, scan.stdout)
            with config.open("a") as stream:
                for record in workspace_records:
                    self.assertEqual(record[3], "lua", record)
                    self.assertTrue(record[4].startswith("hl.dsp."), record)
                    # Validate replay's dispatcher expression without executing it.
                    stream.write("assert(" + record[4] + ")\n")
            result = subprocess.run(
                ["Hyprland", "--verify-config", "--config", str(config)],
                env=env, cwd=tmp, text=True, capture_output=True, timeout=30,
            )
            self.assertEqual(result.returncode, 0, (result.stdout + result.stderr)[-12000:])


if __name__ == "__main__":
    unittest.main()
