from libqtile.config import Screen, Group
from libqtile.command import lazy
from libqtile import layout, bar, widget
import events
import keybindings
from layouts import MasterTile

mod = "mod4"

groups = [
     Group('Term'),
     Group('Browser'),
     Group('Mail'),
     Group('Dev'),
     Group('Media'),
     Group('Other')
]

(keys, mouse) = keybindings.conf(mod=mod, groups=groups)

layouts = [
    layout.Max(),
    MasterTile(ratio=0.5, border_focus="232526")
]

widget_defaults = dict(
    font='Inconsolatas',
    fontsize=22,
    padding=1,
)

screens = [
    Screen(
        top=bar.Bar(
            [
                widget.GroupBox(),
                widget.Prompt(),
                widget.WindowName(),
                widget.Systray(),
                widget.Clock(format='%a %d %I:%M'),
            ],
            30,
        ),
    ),
]

dgroups_key_binder = None
dgroups_app_rules = []
main = None
follow_mouse_focus = True
bring_front_click = True
cursor_warp = False
floating_layout = layout.Floating()
auto_fullscreen = True
focus_on_window_activation = "smart"

wmname = "LG3D"
