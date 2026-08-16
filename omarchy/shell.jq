# Personal Quickshell layout delta. The installer supplies Quattro's normalized
# shell.json shape before evaluating this filter.
# [D-QUICKSHELL-DELTAS][D-DELTA-STORAGE]

# Every module this filter owns. Clearing all three from every lane first is what
# makes a re-run a fixed point instead of accumulating duplicates.
def purge: map(select(.id | IN("omarchy.workspaces", "pashbyl.workspaces", "dotfiles.memory") | not));

{
  "id": "dotfiles.memory",
  "type": "command",
  "exec": "~/.config/omarchy/bar/scripts/memory-status",
  "interval": 5
} as $memory
| .bar.layout.left |= purge
| .bar.layout.center |= purge
| .bar.layout.right |= purge
# Workspaces sit just after the menu, memory just before the power button; both
# fall back to the lane edge when Quattro's anchor module is absent.
| .bar.layout.left |= (
    (map(.id) | index("omarchy.menu")) as $menu
    | if $menu == null
      then [{ "id": "pashbyl.workspaces" }] + .
      else .[:$menu + 1] + [{ "id": "pashbyl.workspaces" }] + .[$menu + 1:]
      end
  )
| .bar.layout.right |= (
    (map(.id) | index("omarchy.power")) as $power
    | if $power == null
      then . + [$memory]
      else .[:$power] + [$memory] + .[$power:]
      end
  )
