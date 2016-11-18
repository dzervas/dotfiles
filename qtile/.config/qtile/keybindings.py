from libqtile.config import Key, Drag, Click
from libqtile.command import lazy

def conf(groups=None, mod=None):
    keys = [
        Key([mod], "Up", lazy.group.next_window()),
        Key([mod], "Down", lazy.group.prev_window()),
        Key([mod], "Right", lazy.screen.next_group()),
        Key([mod], "Left", lazy.screen.prev_group()),

        Key([mod, "shift"], "Up", lazy.layout.shuffle_up()),
        Key([mod, "shift"], "Down", lazy.layout.shuffle_down()),

        Key([mod], "s", lazy.group.setlayout("max")),
        Key([mod], "t", lazy.group.setlayout("mastertile")),

        Key([mod], "f", lazy.window.enable_floating()),
        Key([mod], "Return", lazy.spawn("termite")),

        Key([mod, "shift"], "Return", lazy.layout.shift()),

        # Toggle between different layouts as defined below
        Key([mod], "space", lazy.layout.next()),
        Key([mod], "c", lazy.window.kill()),

        Key([mod, "shift"], "q", lazy.restart()),
        Key([mod], "r", lazy.spawncmd()),
    ]

    mouse = [
        Drag([mod], "Button1", lazy.window.set_position_floating(),
            start=lazy.window.get_position()),
        Drag([mod], "Button3", lazy.window.set_size_floating(),
            start=lazy.window.get_size()),
        Click([mod], "Button2", lazy.window.toggle_floating())
    ]

    for index, grp in enumerate(groups):
        keys.append(Key([mod], str(index+1), lazy.group[grp.name].toscreen()))

        keys.append(Key([mod, "shift"], str(index+1), lazy.window.togroup(grp.name)))

    return (keys, mouse)
