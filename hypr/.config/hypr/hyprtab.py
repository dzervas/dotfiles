#!/usr/bin/env python3
import json
from hyprpy import Hyprland

h = Hyprland()
clients_json = h.command_socket.send_command("clients", flags=["-j"])
active_workspace_windows = h.get_active_workspace().windows

if len(active_workspace_windows) <= 1:
    h.command_socket.send_command("dispatch", args=["togglegroup"])

active_workspace_windows_addr = list(map(lambda w: w.address, active_workspace_windows))

all_window_data = json.loads(clients_json)
window_data = list(filter(lambda w: w["address"] in active_workspace_windows_addr, all_window_data))

grouped_windows = list(filter(lambda w: len(w["grouped"]) > 0, window_data))
active_window = h.get_active_window()

if len(grouped_windows) > 0:
    print("Found group")

    if active_window.address not in map(lambda w: w["address"], grouped_windows):
        h.command_socket.send_command("dispatch", args=["focuswindow", f"address:{grouped_windows[0]['address']}"])

    h.command_socket.send_command("dispatch", args=["togglegroup"])
else:
    print("No group found, creating")

    h.command_socket.send_command("dispatch", args=["togglegroup"])

    #  left = True
    for window in active_workspace_windows:
        if window.address == active_window.address:
            #  left = False
            print("Changing direction")
            continue

        print("Moving window", window.title)

        h.command_socket.send_command("dispatch", args=["focuswindow", f"address:{window.address}"])

        #  h.command_socket.send_command("dispatch", args=["moveintogroup", "left" if left else "right"])

        h.command_socket.send_command("dispatch", args=["moveintogroup", "l"])
        h.command_socket.send_command("dispatch", args=["moveintogroup", "r"])
        h.command_socket.send_command("dispatch", args=["moveintogroup", "u"])
        h.command_socket.send_command("dispatch", args=["moveintogroup", "d"])

    h.command_socket.send_command("dispatch", args=["focuswindow", f"address:{active_window.address}"])
