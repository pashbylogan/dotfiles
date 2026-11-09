-- Use native global IDs without Omarchy's monitor-block reconciliation. [D-GLOBAL-WORKSPACES]
local M = {}

function M.focus(n)
  return hl.dsp.focus({ workspace = tostring(n) })
end

function M.move_window(n, follow)
  return hl.dsp.window.move({ workspace = tostring(n), follow = follow })
end

function M.move_to_monitor(direction)
  return hl.dsp.workspace.move({ monitor = direction })
end

function M.move_window_to_monitor(direction)
  return hl.dsp.window.move({ monitor = direction })
end

o.workspaces = M
return M
