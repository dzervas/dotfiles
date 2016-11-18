from libqtile import hook

# Arrange windows in groups according to their class
@hook.subscribe.client_new
def grouper(window):
    windowtype = window.window.get_wm_class()[0]
    windows = {
            'Termite': 'Term',

            'Chromium': 'Browser',
            'Firefox': 'Browser',

            'Linphone': 'Mail',
            'Mumble': 'Mail',
            'Skype': 'Mail',
            'Telegram': 'Mail',
            'Thunderbird': 'Mail',

            'jetbrains-studio': 'Dev',
            'Eclipse': 'Dev',
            'Pronterface.py': 'Dev',
            'Slic3r': 'Dev',

            'MPlayer': 'Mail',
            'Steam': 'Media',
            'Wine': 'Media',
            }

    # if the window is in our map
    if windowtype in windows.keys():
        try:
            window.togroup(windows[windowtype][0])
            windows[windowtype].pop(0)
        except IndexError:
            pass

# Make dialogs floating
@hook.subscribe.client_new
def dialogs(window):
    if(window.window.get_wm_type() == 'dialog'
        or window.window.get_wm_transient_for()):
        window.floating = True

# Restart on xrandr screen change
@hook.subscribe.screen_change
def xrandr_restart(qtile, ev):
    qtile.cmd_restart()
