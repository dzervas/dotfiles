-- Standard awesome library
local gears = require("gears")
local awful = require("awful")
awful.rules = require("awful.rules")
require("awful.autofocus")
-- Widget and layout library
local wibox = require("wibox")
-- Theme handling library
local beautiful = require("beautiful")
-- Notification library
local naughty = require("naughty")
local menubar = require("menubar")
local vicious = require("vicious")

-- {{{ Error handling
-- Check if awesome encountered an error during startup and fell back to
-- another config (This code will only ever execute for the fallback config)
if awesome.startup_errors then
	naughty.notify({preset = naughty.config.presets.critical, title = "Oops, there were errors during startup!", text = awesome.startup_errors})
end

-- Handle runtime errors after startup
do
	local in_error = false
	awesome.connect_signal("debug::error", function (err)
		-- Make sure we don't go into an endless error loop
		if in_error then return end
		in_error = true

		naughty.notify({preset = naughty.config.presets.critical, title = "Error!", text = err})
		in_error = false
	end)
end
-- }}}

-- {{{ Variable definitions
-- Themes define colours, icons, and wallpapers
--beautiful.init("/usr/share/awesome/themes/default/theme.lua")
beautiful.init("/home/ttouch/.config/awesome/powerarrowf/theme.lua")
font = "Monaco 14"

-- User settings
scstep = 10
kbstep = 10
terminal = "termite"
volcard = 0
volstep = 5
editor = "vim"

-- {{ These are the power arrow dividers/separators }} --
arr1 = wibox.widget.imagebox()
arr1:set_image(beautiful.arr1)
arr2 = wibox.widget.imagebox()
arr2:set_image(beautiful.arr2)
arr3 = wibox.widget.imagebox()
arr3:set_image(beautiful.arr3)
arr4 = wibox.widget.imagebox()
arr4:set_image(beautiful.arr4)
arr5 = wibox.widget.imagebox()
arr5:set_image(beautiful.arr5)
arr6 = wibox.widget.imagebox()
arr6:set_image(beautiful.arr6)
arr7 = wibox.widget.imagebox()
arr7:set_image(beautiful.arr7)
arr8 = wibox.widget.imagebox()
arr8:set_image(beautiful.arr8)
arr9 = wibox.widget.imagebox()
arr9:set_image(beautiful.arr9)

-- Default modkey.
-- Usually, Mod4 is the key with a logo between Control and Alt.
-- If you do not like this or do not have such a key,
-- I suggest you to remap Mod4 to another key using xmodmap or other tools.
-- However, you can use another modifier like Mod1, but it may interact with others.
modkey = "Mod4"

makesloppy = true

-- Table of layouts to cover with awful.layout.inc, order matters.
local layouts = {
	awful.layout.suit.tile,
--	awful.layout.suit.tile.left,
--	awful.layout.suit.tile.bottom,
--	awful.layout.suit.tile.top,
	awful.layout.suit.floating,
	awful.layout.suit.max,
	awful.layout.suit.max.fullscreen,
--	awful.layout.suit.magnifier
}

kbdcfg = {}
kbdcfg.cmd = "setxkbmap"
kbdcfg.layout = { "us", "gr"}
kbdcfg.current = 1
kbdcfg.switch = function ()
	if kbdcfg.current == #(kbdcfg.layout) then
		kbdcfg.current = kbdcfg.current - 1
	else
		kbdcfg.current = kbdcfg.current + 1
	end

	local t = " " .. kbdcfg.layout[kbdcfg.current] .. " "
	os.execute( kbdcfg.cmd .. t )
end
-- }}}

-- {{{ Wallpaper
if beautiful.wallpaper then
	for s = 1, screen.count() do
		gears.wallpaper.maximized(beautiful.wallpaper, s, true)
	end
end
-- }}}

-- {{{ Tags
tags = {}
for s = 1, screen.count() do
	-- Each screen has its own tag table.
	if screen.count() == 1 then
		tags[s] = awful.tag({"T", "B", "I", "M", "D", "T"}, s, layouts[1])
	elseif screen.count() == 2 then
		if s == 2 then
			tags[s] = awful.tag({"Browser", "Dev", "Tmp"}, s, layouts[1])
		else
			tags[s] = awful.tag({"Term", "IM", "Media", "Tmp"}, s, layouts[1])
		end
	else
		tags[s] = awful.tag({ 1, 2, 3, 4, 5, 6, 7, 8, 9 }, s, layouts[1])
	end
end

order = {}
if screen.count() == 2 then
	order["browser"] = tags[2][1]
	order["dev"] = tags[2][2]
	order["im"] = tags[2][1]
	order["media"] = tags[2][3]
	order["term"] = tags[1][1]
else
	order["browser"] = tags[1][2]
	order["dev"] = tags[1][5]
	order["im"] = tags[1][3]
	order["media"] = tags[1][4]
	order["term"] = tags[1][1]
end
-- }}}

-- {{{ Wibox
-- Create a textclock widget
--mytextclock = awful.widget.textclock()
--{{-- Time and Date Widget }} --
tdwidget = wibox.widget.textbox()
local strf = '<span font="' .. font .. '" color="#EEEEEE" background="#777E76">  %b %d %I:%M </span>'
vicious.register(tdwidget, vicious.widgets.date, strf, 20)

clockicon = wibox.widget.imagebox()
clockicon:set_image(beautiful.clock)

--{{ Net Widget }} --
netwidget = wibox.widget.textbox()
vicious.register(netwidget, vicious.widgets.net, function(widget, args)
    local interface = ""
    if args["{wlp3s0 carrier}"] == 1 then
        interface = "wlp3s0"
    elseif args["{enp0s25 carrier}"] == 1 then
        interface = "enp0s25"
    else
        return ""
    end
    return '<span background="#C2C2A4"> <span color="#FFFFFF">'..args["{"..interface.." down_kb}"]..'kbps'..'</span></span>' end, 10)

---{{---| Wifi Signal Widget |-------
neticon = wibox.widget.imagebox()
vicious.register(neticon, vicious.widgets.wifi, function(widget, args)
    local sigstrength = tonumber(args["{link}"])
    if sigstrength > 69 then
        neticon:set_image(beautiful.nethigh)
    elseif sigstrength > 40 and sigstrength < 70 then
        neticon:set_image(beautiful.netmedium)
    else
        neticon:set_image(beautiful.netlow)
    end
end, 120, 'wlp3s0')


--{{ Battery Widget }} --
baticon = wibox.widget.imagebox()
baticon:set_image(beautiful.baticon)

batwidget = wibox.widget.textbox()
vicious.register( batwidget, vicious.widgets.bat, '<span background="#92B0A0"><span color="#FFFFFF"> Pwr: $1$2% </span></span>', 30, "BAT0" )


----{{--| Volume / volume icon |----------
volume = wibox.widget.textbox()
vicious.register(volume, vicious.widgets.volume,
 
'<span background="#D0785D"> <span color="#EEEEEE"> Vol:$1 </span></span>', 0.3, "Master")
volumeicon = wibox.widget.imagebox()
vicious.register(volumeicon, vicious.widgets.volume, function(widget, args)
    local paraone = tonumber(args[1])

    if args[2] == "♩" or paraone == 0 then
        volumeicon:set_image(beautiful.mute)
    elseif paraone >= 67 and paraone <= 100 then
        volumeicon:set_image(beautiful.volhi)
    elseif paraone >= 33 and paraone <= 66 then
        volumeicon:set_image(beautiful.volmed)
    else
        volumeicon:set_image(beautiful.vollow)
    end

end, 0.3, "Master")

--{{--| Mail widget |---------
mailicon = wibox.widget.imagebox()

vicious.register(mailicon, vicious.widgets.gmail, function(widget, args)
    local newMail = tonumber(args["{count}"])
    if newMail > 0 then
        mailicon:set_image(beautiful.mail)
    else
        mailicon:set_image(beautiful.mailopen)
    end
end, 15)

-- to make GMail pop up when pressed:
mailicon:buttons(awful.util.table.join(awful.button({ }, 1,
function () awful.util.spawn("thunderbird") end)))

-- Create a wibox for each screen and add it
mywibox = {}
mypromptbox = {}
mylayoutbox = {}
mytaglist = {}
mytaglist.buttons = awful.util.table.join(
	awful.button({}, 1, awful.tag.viewonly),
	awful.button({modkey}, 1, awful.client.movetotag),
	awful.button({}, 3, awful.tag.viewtoggle),
	awful.button({modkey}, 3, awful.client.toggletag),
	awful.button({}, 4, function(t) awful.tag.viewnext(awful.tag.getscreen(t)) end),
	awful.button({}, 5, function(t) awful.tag.viewprev(awful.tag.getscreen(t)) end)
)
mytasklist = {}
mytasklist.buttons = awful.util.table.join(
	awful.button({}, 1, function (c)
		client.focus = c
		c:raise()
	end)
)

for s = 1, screen.count() do
	-- Create a promptbox for each screen
	mypromptbox[s] = awful.widget.prompt()
	-- Create an imagebox widget which will contains an icon indicating which layout we're using.
	-- We need one layoutbox per screen.
	mylayoutbox[s] = awful.widget.layoutbox(s)
	mylayoutbox[s]:buttons(awful.util.table.join(
		awful.button({}, 1, function () awful.layout.inc(layouts, 1) end),
		awful.button({}, 3, function () awful.layout.inc(layouts, -1) end),
		awful.button({}, 4, function () awful.layout.inc(layouts, 1) end),
		awful.button({}, 5, function () awful.layout.inc(layouts, -1) end)))
	-- Create a taglist widget
	mytaglist[s] = awful.widget.taglist(s, awful.widget.taglist.filter.all, mytaglist.buttons)

	-- Create a tasklist widget
	mytasklist[s] = awful.widget.tasklist(s, awful.widget.tasklist.filter.currenttags, mytasklist.buttons)

	-- Create the wibox
	mywibox[s] = awful.wibox({position = "top", height = "24", screen = s})

	-- Widgets that are aligned to the left
	local left_layout = wibox.layout.fixed.horizontal()
	left_layout:add(mytaglist[s])
	left_layout:add(mylayoutbox[s])
	left_layout:add(mypromptbox[s])

	-- Widgets that are aligned to the right
	local right_layout = wibox.layout.fixed.horizontal()
	right_layout:add(wibox.widget.systray())
	right_layout:add(mailicon)
	right_layout:add(volumeicon)
	right_layout:add(volume)
	right_layout:add(baticon)
	right_layout:add(batwidget)
	right_layout:add(neticon)
	right_layout:add(netwidget)
	right_layout:add(clockicon)
	right_layout:add(tdwidget)

	-- Now bring it all together (with the tasklist in the middle)
	local layout = wibox.layout.align.horizontal()
	layout:set_left(left_layout)
	layout:set_middle(mytasklist[s])
	layout:set_right(right_layout)

	mywibox[s]:set_widget(layout)
end
-- }}}

-- {{{ Mouse bindings
root.buttons(awful.util.table.join(
	awful.button({}, 4, awful.tag.viewnext),
	awful.button({}, 5, awful.tag.viewprev)
))
-- }}}

-- {{{ Key bindings
globalkeys = awful.util.table.join(
	awful.key({modkey,}, "Left", awful.tag.viewprev),
	awful.key({modkey,}, "Right", awful.tag.viewnext),
	awful.key({modkey,}, "Tab", awful.tag.history.restore),
	awful.key({modkey,}, "Up", function ()
		awful.client.focus.byidx( 1)
		if client.focus then client.focus:raise() end
	end),
	awful.key({ modkey, }, "Down", function ()
		awful.client.focus.byidx(-1)
		if client.focus then
			client.focus:raise()
		end
	end),

	-- Layout manipulation
	awful.key({modkey, "Shift"}, "Up", function () awful.client.swap.byidx(1) end),
	awful.key({modkey, "Shift"}, "Down", function () awful.client.swap.byidx(-1) end),
	awful.key({modkey,}, ",", function () awful.screen.focus_relative(1) end),
	awful.key({modkey,}, ".", function () awful.screen.focus_relative(-1) end),
	awful.key({modkey,}, "space", function () awful.layout.inc(layouts, 1) end),
	awful.key({modkey, "Shift"}, "space", function () awful.layout.inc(layouts, -1) end),
	awful.key({modkey, "Shift"}, "Right", function () awful.tag.incmwfact( 0.05) end),
	awful.key({modkey, "Shift"}, "Left", function () awful.tag.incmwfact(-0.05) end),

	-- Standard program
	awful.key({modkey,}, "Return", function () awful.util.spawn(terminal) end),
	awful.key({modkey, "Shift" }, "Esc", awesome.quit),
	awful.key({modkey, "Shift" }, "q", awesome.restart),

	-- Prompt
	awful.key({modkey,}, "r", function () mypromptbox[mouse.screen]:run() end),
	awful.key({modkey,}, "x", function ()
		awful.prompt.run({ prompt = "Run Lua code: " },
		mypromptbox[mouse.screen].widget,
		awful.util.eval, nil,
		awful.util.getdir("cache") .. "/history_eval")
	end),

	-- Menubar
	awful.key({ modkey }, "p", function() menubar.show() end),

	-- Change keyboard layout
	awful.key({"Mod1"}, "Shift_L", function () kbdcfg.switch() end),

	-- Media keys
	awful.key({}, "XF86MonBrightnessDown", function ()
		awful.util.spawn("xbacklight -dec " .. scstep)
	end),
	awful.key({}, "XF86MonBrightnessUp", function ()
		awful.util.spawn("xbacklight -inc " .. scstep)
	end),
	awful.key({}, "XF86LaunchA", function () awful.layout.set(awful.layout.suit.float) end),
	awful.key({}, "XF86LaunchB", function () awful.layout.set(awful.layout.suit.tile) end),
	awful.key({}, "XF86KbdBrightnessDown", function ()
		awful.util.spawn("kbdlight down " .. kbstep)
	end),
	awful.key({}, "XF86KbdBrightnessUp", function ()
		awful.util.spawn("kbdlight up " .. kbstep)
	end),
	awful.key({}, "XF86AudioPrev", function () awful.util.spawn("mpc prev") end),
	awful.key({}, "XF86AudioPlay", function () awful.util.spawn("mpc toggle") end),
	awful.key({}, "XF86AudioNext", function () awful.util.spawn("mpc prev") end),
	awful.key({}, "XF86AudioMute", function ()
		awful.util.spawn("pactl set-sink-mute " .. volcard .. " 1")
	end),
	awful.key({}, "XF86AudioLowerVolume", function ()
		awful.util.spawn("pactl set-sink-mute " .. volcard .. " 0")
		awful.util.spawn("pactl set-sink-volume " .. volcard .. " -" .. volstep .. "%")
	end),
	awful.key({}, "XF86AudioRaiseVolume", function ()
		awful.util.spawn("pactl set-sink-mute " .. volcard .. " 0")
		awful.util.spawn("pactl set-sink-volume " .. volcard .. " +" .. volstep .. "%")
	end),
	awful.key({}, "", function ()  end)
)

clientkeys = awful.util.table.join(
		awful.key({ modkey}, "f", function (c) c.fullscreen = not c.fullscreen end),
		awful.key({ modkey}, "c", function (c) c:kill() end),
		awful.key({ modkey, "Shift"}, "space", awful.client.floating.toggle),
		awful.key({ modkey, "Shift"}, "Return", function (c) c:swap(awful.client.getmaster()) end),
		awful.key({ modkey}, "o", awful.client.movetoscreen),
		awful.key({ modkey}, "t", function (c) c.ontop = not c.ontop end),
		awful.key({ modkey}, "m", function (c) awful.layout.set(awful.layout.suit.max) end)
)

-- Compute the maximum number of digit we need, limited to 9
keynumber = 0
for s = 1, screen.count() do
	keynumber = math.min(9, math.max(#tags[s], keynumber))
end

-- Bind all key numbers to tags.
-- Be careful: we use keycodes to make it works on any keyboard layout.
-- This should map on the top row of your keyboard, usually 1 to 9.
for i = 1, keynumber do
	globalkeys = awful.util.table.join(globalkeys,
		awful.key({ modkey }, "#" .. i + 9, function ()
			local screen = mouse.screen
			if tags[screen][i] then
				awful.tag.viewonly(tags[screen][i])
			end
		end),
		awful.key({ modkey, "Control" }, "#" .. i + 9, function ()
			local screen = mouse.screen
			if tags[screen][i] then
				awful.tag.viewtoggle(tags[screen][i])
			end
		end),
		awful.key({ modkey, "Shift" }, "#" .. i + 9, function ()
			if client.focus and tags[client.focus.screen][i] then
				awful.client.movetotag(tags[client.focus.screen][i])
			end
		end),
		awful.key({ modkey, "Control", "Shift" }, "#" .. i + 9, function ()
			if client.focus and tags[client.focus.screen][i] then
				awful.client.toggletag(tags[client.focus.screen][i])
			end
		end)
	)
end

clientbuttons = awful.util.table.join(
	awful.button({ }, 1, function (c) client.focus = c; c:raise() end),
	awful.button({ modkey }, 1, awful.mouse.client.move),
	awful.button({ modkey }, 3, awful.mouse.client.resize))

-- Set keys
root.keys(globalkeys)
-- }}}

-- {{{ Rules
awful.rules.rules = {
	-- All clients will match this rule.
	{rule = {}, properties = {
			border_width = beautiful.border_width,
			border_color = beautiful.border_normal,
			focus = awful.client.focus.filter,
			keys = clientkeys,
			buttons = clientbuttons
		}
	},

	{rule = {class = "pinentry"}, properties = {floating = true}},
	{rule = {class = "gimp"}, properties = {floating = true}},

	{rule = {class = "Firefox"}, properties = {tag = order["browser"]}},

	{rule = {class = "Mumble"}, properties = {tag = order["im"]}},
	{rule = {class = "Skype"}, properties = {tag = order["im"]}},
	{rule = {class = "Telegram"}, properties = {tag = order["im"]}},
	{rule = {class = "Thunderbird"}, properties = {tag = order["im"]}},
	{rule = {class = "ViberPC"}, properties = {tag = order["im"]}},

	{rule = {class = "MPlayer"}, properties = {tag = order["media"]}},
	{rule = {class = "PlayOnLinux"}, properties = {tag = order["media"]}},

	{rule = {instance = "Terminal"}, properties = {tag = order["term"]}},
	{rule = {instance = "Termite"}, properties = {tag = order["term"]}},
}
-- }}}

awful.util.spawn("thunderbird")
awful.util.spawn("firefox")
awful.util.spawn(terminal)
awful.util.spawn("pasystray")
awful.util.spawn("wpa_gui -t")

-- {{{ Signals
-- Signal function to execute when a new client appears.
client.connect_signal("manage", function (c, startup)
		-- Enable sloppy focus
		c:connect_signal("mouse::enter", function(c)
				if awful.layout.get(c.screen) ~= awful.layout.suit.magnifier and awful.client.focus.filter(c) and makesloppy then
						client.focus = c
				end
		end)

		if not startup then
				-- Set the windows at the slave,
				-- i.e. put it at the end of others instead of setting it master.
				-- awful.client.setslave(c)

				-- Put windows in a smart way, only if they does not set an initial position.
				if not c.size_hints.user_position and not c.size_hints.program_position then
						awful.placement.no_overlap(c)
						awful.placement.no_offscreen(c)
				end
		end

		local titlebars_enabled = false
		if titlebars_enabled and (c.type == "normal" or c.type == "dialog") then
				-- Widgets that are aligned to the left
				local left_layout = wibox.layout.fixed.horizontal()
				left_layout:add(awful.titlebar.widget.iconwidget(c))

				-- Widgets that are aligned to the right
				local right_layout = wibox.layout.fixed.horizontal()
				right_layout:add(awful.titlebar.widget.floatingbutton(c))
				right_layout:add(awful.titlebar.widget.maximizedbutton(c))
				right_layout:add(awful.titlebar.widget.stickybutton(c))
				right_layout:add(awful.titlebar.widget.ontopbutton(c))
				right_layout:add(awful.titlebar.widget.closebutton(c))

				-- The title goes in the middle
				local title = awful.titlebar.widget.titlewidget(c)
				title:buttons(awful.util.table.join(
								awful.button({ }, 1, function()
										client.focus = c
										c:raise()
										awful.mouse.client.move(c)
								end),
								awful.button({ }, 3, function()
										client.focus = c
										c:raise()
										awful.mouse.client.resize(c)
								end)
								))

				-- Now bring it all together
				local layout = wibox.layout.align.horizontal()
				layout:set_left(left_layout)
				layout:set_right(right_layout)
				layout:set_middle(title)

				awful.titlebar(c):set_widget(layout)
		end
end)

beautiful.border_focus = "#000000"
beautiful.border_normal = "#000000"

client.connect_signal("focus", function(c) c.border_color = beautiful.border_focus end)
client.connect_signal("unfocus", function(c) c.border_color = beautiful.border_normal end)
-- }}}
