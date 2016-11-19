from libqtile.config import Key, Drag, Click
from libqtile.command import lazy

def conf(groups=None, mod=None):
    keys = [
        Key([mod], "Up", lazy.group.next_window()),
        Key([mod], "Down", lazy.group.prev_window()),
        Key([mod], "Right", lazy.screen.next_group()),
        Key([mod], "Left", lazy.screen.prev_group()),
        Key([mod], "period", lazy.next_screen()),
        Key([mod], "comma", lazy.prev_screen()),

        Key([mod, "shift"], "Up", lazy.layout.increase_ratio()),
        Key([mod, "shift"], "Down", lazy.layout.decrease_ratio()),
        Key([mod], "equal", lazy.layout.increase_nmaster()),
        Key([mod], "minus", lazy.layout.decrease_nmaster()),
        Key([mod, "shift"], "Return", lazy.layout.shift()),

        Key([mod], "b", lazy.hide_show_bar()),
        Key([mod], "f", lazy.window.toggle_fullscreen()),
        Key([mod], "s", lazy.group.setlayout("max")),
        Key([mod], "t", lazy.group.setlayout("mastertile")),
        Key([mod], "space", lazy.next_layout()),

        Key([mod], "c", lazy.window.kill()),
        Key([mod], "r", lazy.spawncmd()),
        Key([mod], "x", lazy.execute("xautolock", "-locknow")),
        Key([mod], "Return", lazy.spawn("termite")),


        Key([mod, "shift"], "q", lazy.restart()),
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
