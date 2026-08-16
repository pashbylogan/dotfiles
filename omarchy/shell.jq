# Personal Quickshell layout delta. The installer supplies Quattro's normalized
# shell.json shape before evaluating this filter.
# [D-QUICKSHELL-DELTAS][D-DELTA-STORAGE]

# Modules this filter owns. dotfiles.memory is purged but never re-added: it was
# a custom RAM widget, retired because Quattro's native power panel already
# reports memory via omarchy-system-stats. Listing it here is what converges an
# existing bar off it on the next install.
def purge: map(select(.id | IN("omarchy.workspaces", "pashbyl.workspaces", "dotfiles.memory") | not));

.bar.layout.left |= purge
| .bar.layout.center |= purge
| .bar.layout.right |= purge
# Workspaces sit just after the menu, falling back to the lane edge when
# Quattro's anchor module is absent.
| .bar.layout.left |= (
    (map(.id) | index("omarchy.menu")) as $menu
    | if $menu == null
      then [{ "id": "pashbyl.workspaces" }] + .
      else .[:$menu + 1] + [{ "id": "pashbyl.workspaces" }] + .[$menu + 1:]
      end
  )
