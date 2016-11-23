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
        Key([mod], "Tab", lazy.screen.togglegroup()),

        Key([mod], "c", lazy.window.kill()),
        Key([mod], "r", lazy.spawncmd()),
        Key([mod], "x", lazy.spawn("xautolock -locknow")),
        Key([mod], "Return", lazy.spawn("termite")),

        Key([], "XF86KbdBrightnessUp", lazy.spawn("kbdlight up 10")),
        Key([], "XF86KbdBrightnessDown", lazy.spawn("kbdlight down 10")),
        Key(["shift"], "XF86KbdBrightnessUp", lazy.spawn("kbdlight max")),
        Key(["shift"], "XF86KbdBrightnessDown", lazy.spawn("kbdlight set 0")),

        Key([], "XF86MonBrightnessUp", lazy.spawn("xbacklight +5")),
        Key([], "XF86MonBrightnessDown", lazy.spawn("xbacklight -5")),
        Key(["shift"], "XF86MonBrightnessUp", lazy.spawn("xbacklight =100")),
        Key(["shift"], "XF86MonBrightnessDown", lazy.spawn("xbacklight =0")),

        Key([], "XF86AudioRaiseVolume", lazy.spawn(
            "pactl set-sink-volume @DEFAULT_SINK@ +5%")),
        Key([], "XF86AudioLowerVolume", lazy.spawn(
            "pactl set-sink-volume @DEFAULT_SINK@ -5%")),
        Key([], "XF86AudioMute", lazy.spawn(
            "pactl set-sink-mute @DEFAULT_SINK@ 1")),
        Key(["shift"], "XF86AudioMute", lazy.spawn(
            "pactl set-sink-mute @DEFAULT_SINK@ 0")),

        Key([], "XF86AudioNext", lazy.spawn("mpc next")),
        Key([], "XF86AudioPrev", lazy.spawn("mpc prev")),
        Key([], "XF86AudioPlay", lazy.spawn("mpc toggle")),
        Key([], "XF86AudioPause", lazy.spawn("mpc toggle")),

        # Key([], "XF86LaunchA", ),
        # Key([], "XF86LaunchB", ),

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
