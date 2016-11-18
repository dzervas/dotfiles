from libqtile.config import Key
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
        Key([mod], "t", lazy.group.setlayout("tile")),

        Key([mod], "f", lazy.window.enable_floating()),
        Key([mod], "Return", lazy.spawn("termite")),

        # Toggle between different layouts as defined below
        Key([mod], "space", lazy.layout.next()),
        Key([mod], "c", lazy.window.kill()),

        Key([mod, "shift"], "q", lazy.restart()),
        Key([mod], "r", lazy.spawncmd()),
    ]

    for index, grp in enumerate(groups):
        # mod1 + letter of group = switch to group
        keys.append(
            Key([mod], str(index+1), lazy.group[grp.name].toscreen())
        )

        # mod1 + shift + letter of group = switch to & move focused window to group
        keys.append(
            Key([mod, "shift"], str(index+1), lazy.window.togroup(grp.name))
        )

    return keys
