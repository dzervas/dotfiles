from libqtile.config import Screen, Group, Drag, Click
from libqtile.command import lazy
from libqtile import layout, bar, widget
import keybindings
import events

mod = "mod4"

groups = [
     Group('Term'),
     Group('Browser'),
     Group('Mail'),
     Group('Dev'),
     Group('Media'),
     Group('Other')
]

keys = keybindings.conf(mod=mod, groups=groups)

layouts = [
    layout.Max(),
    layout.Tile(border_width=1)
]

widget_defaults = dict(
    font='Inconsolatas',
    fontsize=20,
    padding=5,
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

# Drag floating layouts.
mouse = [
    Drag([mod], "Button1", lazy.window.set_position_floating(),
        start=lazy.window.get_position()),
    Drag([mod], "Button3", lazy.window.set_size_floating(),
        start=lazy.window.get_size()),
    Click([mod], "Button2", lazy.window.toggle_floating())
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
