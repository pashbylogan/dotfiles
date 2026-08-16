# Personal Quickshell layout delta. The installer supplies Quattro's normalized
# shell.json shape before evaluating this filter.
# [D-QUICKSHELL-DELTAS][D-DELTA-STORAGE]

def is_workspace:
  .id == "omarchy.workspaces" or .id == "pashbyl.workspaces";

(.bar.layout.left | map(select(is_workspace | not))) as $left
| ($left | map(.id) | index("omarchy.menu")) as $menu
| .bar.layout.left = (
    if $menu == null
    then [{ "id": "pashbyl.workspaces" }] + $left
    else $left[:$menu + 1] + [{ "id": "pashbyl.workspaces" }] + $left[$menu + 1:]
    end
  )
| .bar.layout.center |= map(select(is_workspace | not))
| .bar.layout.right |= map(select(is_workspace | not))
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
