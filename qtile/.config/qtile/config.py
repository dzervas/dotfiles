from libqtile.config import Screen, Group, Match
from libqtile.command import lazy
from libqtile import layout, bar, widget
import events
import keybindings
from layouts import MasterTile

border_color = "232526"
mod = "mod4"

groups = [
    Group("Term", matches=[
        Match(wm_class=["Termite"]),
        ]),
    Group("Browser", matches=[
        Match(wm_class=["Firefox"]),
        Match(wm_class=["Chromium"]),
        ]),
    Group("Mail", matches=[
        Match(wm_class=["Linphone"]),
        Match(wm_class=["Mumble"]),
        Match(wm_class=["Skype"]),
        Match(wm_class=["Telegram"]),
        Match(wm_class=["Thunderbird"]),
        ]),
    Group("Dev", matches=[
        Match(wm_class=["jetbrains-studio"]),
        Match(wm_class=["Eclipse"]),
        Match(wm_class=["Pronterface.py"]),
        Match(wm_class=["Slic3r"]),
        ]),
    Group("Media", matches=[
        Match(wm_class=["MPlayer"]),
        Match(wm_class=["Steam"]),
        Match(wm_class=["Wine"]),
        ]),
    Group("Other")
]

(keys, mouse) = keybindings.conf(mod=mod, groups=groups)

layouts = [
    layout.Max(),
    MasterTile(ratio=0.5, border_focus=border_color)
]

widget_defaults = dict(
    font="Inconsolatas",
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
                widget.Mpd(do_color_progress=True, padding=3),
                widget.ThermalSensor(padding=3),
                widget.Battery(charge_char="⚡", discharge_char="", padding=3),
                widget.Systray(),
                widget.Clock(format="%a %d %I:%M"),
            ],
            30,
        ),
    ),
]

follow_mouse_focus = True
bring_front_click = True
cursor_warp = False
floating_layout = layout.Floating(border_focus=border_color)
auto_fullscreen = True
focus_on_window_activation = "smart"

wmname = "LG3D"
