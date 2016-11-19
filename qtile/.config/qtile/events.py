from libqtile import hook

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
