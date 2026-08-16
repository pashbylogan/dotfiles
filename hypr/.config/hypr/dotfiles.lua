-- Personal Quattro Hyprland overlay. The hypr.* module name is reloadable by
-- Omarchy's bootstrap, so these deltas reapply after every config reload.
-- [D-DELTA-STORAGE][F-HYPR-SEAM]

hl.config({
  input = {
    -- Preserve Omarchy's detected layout while replacing only its options.
    -- [D-CAPS-CTRL]
    kb_options = "compose:caps,ctrl:nocaps",
  },

  general = {
    gaps_in = 2,
    gaps_out = 4,
    -- Restated so the stock no-gaps toggle cannot leave borders disabled.
    border_size = 2,
  },

  decoration = {
    rounding = 8,
    -- Quattro disables both effects by default; spell out the effective v3
    -- values so the appearance does not depend on upstream defaults.
    shadow = {
      enabled = true,
      range = 2,
      render_power = 3,
      color = "rgba(1a1a1aee)",
    },
    blur = {
      enabled = true,
      size = 8,
      passes = 2,
      special = true,
      brightness = 0.72,
      contrast = 0.75,
    },
  },

  misc = {
    focus_on_activate = false,
  },
})

-- App placement remains a personal choice; unmatched rules are harmless when
-- an optional app is absent. [D-WORKSPACE-RULES]
o.window("(Alacritty|com.mitchellh.ghostty|kitty|foot)", { workspace = "1" })
o.window("brave-origin", { workspace = "2" })
o.window("(Slack|slack|obsidian)", { workspace = "3" })
o.window("jetbrains-idea", { workspace = "5" })
o.window("(Spotify|spotify)", { workspace = "10" })

-- Float only Slack's huddle preview. Float is static, so match the initial
-- title explicitly. [D-SLACK-HUDDLE-FLOAT]
o.window(
  { class = "(Slack|slack)", initial_title = "^Slack - Huddle Preview$" },
  { float = true }
)

-- Quattro's terminal tag also covers org.omarchy.* and TUI.*. Match emulator
-- classes directly to preserve the narrower personal opacity choice.
-- [D-LOOKNFEEL]
o.window(
  "(Alacritty|kitty|com.mitchellh.ghostty|foot|org\\.codeberg\\.dnkl\\.foot|wezterm)",
  { opacity = "0.86 override 0.78 override" }
)

-- Keep the personal HJKL mapping even where Quattro chose other actions.
-- [D-HJKL-DECLINED]
-- Only unbind real Quattro conflicts before restoring the personal mapping.
-- SUPER+J/K/L were toggle-split/keybindings/layout, SUPER+SPACE was the root
-- menu, SUPER+SHIFT+S was Maps, and SUPER+ALT+SPACE was the Apps menu.
-- [D-KEYBIND-OVERRIDES]
for _, keys in ipairs({
  "SUPER + J",
  "SUPER + K",
  "SUPER + L",
  "SUPER + SPACE",
  "SUPER + SHIFT + S",
  "SUPER + ALT + SPACE",
}) do
  hl.unbind(keys)
end

o.bind("SUPER + D", "Omarchy menu", "omarchy-menu toggle")
o.bind("SUPER + SPACE", "Apps menu", "omarchy-menu toggle apps")
o.bind("SUPER + I", "Show keybindings", "omarchy-menu-keybindings")
o.bind("SUPER + E", "Toggle workspace layout", "omarchy-hyprland-workspace-layout-toggle")

o.bind("SUPER + H", "Focus on left window", hl.dsp.focus({ direction = "l" }))
o.bind("SUPER + J", "Focus on below window", hl.dsp.focus({ direction = "d" }))
o.bind("SUPER + K", "Focus on above window", hl.dsp.focus({ direction = "u" }))
o.bind("SUPER + L", "Focus on right window", hl.dsp.focus({ direction = "r" }))

o.bind("SUPER + SHIFT + H", "Swap window to the left", hl.dsp.window.swap({ direction = "l" }))
o.bind("SUPER + SHIFT + J", "Swap window down", hl.dsp.window.swap({ direction = "d" }))
o.bind("SUPER + SHIFT + K", "Swap window up", hl.dsp.window.swap({ direction = "u" }))
o.bind("SUPER + SHIFT + L", "Swap window to the right", hl.dsp.window.swap({ direction = "r" }))

o.bind(
  "SUPER + SHIFT + PERIOD",
  "Move workspace to next monitor",
  hl.dsp.workspace.move({ monitor = "+1" })
)

-- Fallback while the keyboard's PRINT key emits no Linux input event.
-- [D-SCREENSHOT-FALLBACK]
o.bind("SUPER + SHIFT + S", "Screenshot", "omarchy-capture-screenshot")

-- Kinesis Calc sends F14 (evdev 184; X keycode 192). [D-KINESIS-REMAP]
o.bind(
  "code:192",
  "Clipboard history",
  "omarchy-shell shell toggle omarchy.clipboard"
)

-- Known displays. eDP-1 deliberately remains governed by Quattro's internal
-- monitor/lid toggles. [D-MONITORS]
hl.monitor({
  output = "desc:Acer Technologies XV272U 0x01822E61",
  mode = "2560x1440@144",
  position = "0x0",
  scale = 1.333333,
})
hl.monitor({
  output = "desc:Acer Technologies XV272U V 332506A1C3LIJ",
  mode = "2560x1440@144",
  position = "1920x0",
  scale = 1.333333,
})
hl.monitor({
  output = "desc:Dell Inc. DELL U2719DC GGBR4N2",
  mode = "2560x1440@59.95",
  position = "0x0",
  scale = 1.25,
})
