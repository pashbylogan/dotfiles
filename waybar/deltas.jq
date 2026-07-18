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

# 2. Memory module. Merge so future upstream keys survive; CSS spacing lives in
#    the style.css managed block. [D-WAYBAR-DELTAS]
| .memory = ((.memory // {}) + {
    "interval": 5,
    "format": "",
    "tooltip-format": "RAM {used:0.1f}G / {total:0.1f}G  ({percentage}%)"
  })

# 3. Add "memory" only if absent from every modules-* group; prefer
#    modules-right after cpu / before battery, and guard malformed inputs.
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
