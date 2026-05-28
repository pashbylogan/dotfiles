# Personal waybar deltas applied idempotently by ./install. Each filter must
# be a no-op on already-patched input so re-runs converge. [D-WAYBAR-DELTAS]
# Background + omarchy mutation patterns: [F-WAYBAR-MIGRATIONS]

# Refuse to operate on a corrupted file rather than overwriting recoverable
# content with a 2-key stub. (Hits when config.jsonc is `null`, `[]`, etc.)
if type != "object" then
  error("waybar config root must be an object, got \(type) — refusing to apply deltas")
else . end

# 1. Drop the fixed 1-5 workspace pin so the bar grows i3-style.
| del(.["hyprland/workspaces"]."persistent-workspaces")

# 2. Memory module. Merge (not assignment) so any future omarchy upstream
#    keys (states, format-alt, …) survive our overlay; ours win on conflict.
#    Spacing comes from the #memory rule we install into style.css, so the
#    format string stays minimal — matches the omarchy cpu format idiom.
| .memory = ((.memory // {}) + {
    "interval": 5,
    "format": "",
    "tooltip-format": "RAM {used:0.1f}G / {total:0.1f}G  ({percentage}%)",
    "on-click": "omarchy-launch-or-focus-tui btop"
  })

# 3. Ensure "memory" appears in some modules-* group. If omarchy ever moves
#    it to modules-left/center/right, no-op here (no duplicates). Otherwise
#    insert into modules-right after cpu / before battery / at the end.
#    Type-guarded so a malformed modules-right doesn't crash apply_jq_deltas.
| if [ (.["modules-left"]   // []),
       (.["modules-center"] // []),
       (.["modules-right"]  // []) ]
     | flatten
     | index("memory") != null
  then .
  elif (.["modules-right"] | type) != "array"
  then .
  else .["modules-right"] |= (
    if index("cpu") != null
      then (.[: index("cpu") + 1] + ["memory"] + .[index("cpu") + 1 :])
    elif index("battery") != null
      then (.[: index("battery")] + ["memory"] + .[index("battery") :])
    else . + ["memory"]
    end
  )
  end
