# Kinesis Advantage360 (SmartSet) — ergonomic layout for Omarchy

This directory versions the SmartSet **Profile 1** layout for the Kinesis
Advantage360 (KB360), tuned for Omarchy's SUPER-centric Hyprland keybinds.
Reference-only — not stowed (it backs up keyboard firmware config, nothing is
symlinked into `~`). [D-KINESIS-REMAP]

- `layout1.txt` — byte-exact backup of the keyboard's `layouts/layout1.txt`
  (CRLF line endings; re-flashable as-is).

## What changed (base layer, thumb clusters only — everything else is untouched)

| Physical key (keycap) | Position token | Now sends |
| --------------------- | -------------- | --------- |
| left bottom ("Left Alt") | `END` | **Super** — `[end]>[lwin]` |
| right bottom ("Right Alt") | `PGDN` | **Super** — `[pgdn]>[rwin]` |
| right inner-top ("Right Win") | `RWIN` | **Alt** — `[rwin]>[ralt]` |
| left interior ("Home") | `HOME` | **Tab** — `[home]>[tab]` |
| right interior ("Calc") | `PGUP` | **F14** — `[pgup]>[f14]` |

Result: **Super on both bottom thumb keys**, so any `SUPER` chord can be formed
with whichever hand is free; Alt stays thumb-reachable on the right; `Home→Tab`
makes `SUPER+Tab` (workspace cycle) and `ALT+Tab` (window cycle) thumb gestures;
and `Calc` opens the clipboard manager. Shift/Ctrl remain on the thumbs as
before, and `Caps` is left unchanged. Delete is still available on the `fn`
layer (`<function1>` keeps `[home]>[del]`).

## The Calc → clipboard binding

`Calc` sends **F14** (evdev 184). Hyprland binds it **by keycode** in
`hypr/.config/dotfiles/hypr.conf`:

```
bindd = , code:192, Clipboard history, exec, omarchy-launch-walker -m clipboard
```

X keycode `192` = evdev `184` + 8. Binding by keycode is required because F13+
keysyms map unreliably through xkb, so a plain `, F14` keysym bind silently
never matches even though `hyprctl binds` lists it. [D-KINESIS-REMAP]

## Re-applying after an edit

1. On a programmable profile (Profile 0 is read-only), connect the v-Drive:
   hold **SmartSet** + tap the **v-Drive key** (right module, middle button).
2. Edit `layouts/layout1.txt` on the mounted drive — plain text, keep CRLF, one
   remap per line (`[position]>[action]`), `*` at line start disables a line.
3. `sync` and eject the drive: `udisksctl unmount -b /dev/sda`.
4. Apply: hold **SmartSet** + tap the **Refresh key** (bottom button); LEDs flash.
5. Disconnect: **SmartSet** + **v-Drive key**.

To restore this exact layout, copy `layout1.txt` from here onto the drive's
`layouts/layout1.txt` and Refresh. Token names live in Appendix A of the
[SmartSet Direct Programming Guide](https://kinesis-ergo.com/support/kb360/#manuals).
