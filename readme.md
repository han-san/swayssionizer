# swayssionizer

Inspired by
[tmux-sessionizer](https://github.com/ThePrimeagen/tmux-sessionizer), this
script launches a terminal "session" or switches focus to the session if it is
already running.

The script assumes you're using [sway](https://swaywm.org/), 
[kitty](https://sw.kovidgoyal.net/kitty/), and
[tofi](https://github.com/philj56/tofi). Switching from tofi to another menu program
is easy, switching to a different terminal less so.

## Usage

```sh
swayssionizer [session index] # The index being 0-3.
```

Ideally you probably want to bind the command to some shortcut, e.g.
```
bindsym Mod4+Control+p         exec swayssionizer

bindsym Mod4+Control+j         exec swayssionizer 0
bindsym Mod4+Control+k         exec swayssionizer 1
bindsym Mod4+Control+l         exec swayssionizer 2
bindsym Mod4+Control+Semicolon exec swayssionizer 3
```
