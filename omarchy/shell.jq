# Personal Quickshell layout delta. The installer supplies Quattro's normalized
# shell.json shape before evaluating this filter.
# [D-WAYBAR-DELTAS][D-DELTA-STORAGE]

def replace_workspace:
  if .id == "omarchy.workspaces" then .id = "pashbyl.workspaces" else . end;

.bar.layout.left |= map(replace_workspace)
| .bar.layout.center |= map(replace_workspace)
| .bar.layout.right |= map(replace_workspace)
| if ([.bar.layout.left[], .bar.layout.center[], .bar.layout.right[]]
      | map(.id) | index("pashbyl.workspaces")) == null
  then .bar.layout.left += [{ "id": "pashbyl.workspaces" }]
  else .
  end
| .bar.layout.left |= map(select(.id != "dotfiles.memory"))
| .bar.layout.center |= map(select(.id != "dotfiles.memory"))
| .bar.layout.right |= map(select(.id != "dotfiles.memory"))
| .bar.layout.right |= (
    (map(.id) | index("omarchy.power")) as $power
    | if $power == null
      then . + [{
        "id": "dotfiles.memory",
        "type": "command",
        "exec": "~/.config/omarchy/bar/scripts/memory-status",
        "interval": 5
      }]
      else .[:$power] + [{
        "id": "dotfiles.memory",
        "type": "command",
        "exec": "~/.config/omarchy/bar/scripts/memory-status",
        "interval": 5
      }] + .[$power:]
      end
  )
