# Colors
c.colors.webpage.preferred_color_scheme = "dark"
c.colors.statusbar.passthrough.bg = c.colors.statusbar.normal.bg
c.colors.statusbar.passthrough.fg = c.colors.statusbar.normal.fg

# View settings
c.statusbar.show = "always"
c.tabs.show = "multiple"
c.window.title_format = "{{emoji}} {perc}{current_title}"

# Defaults
c.content.cookies.accept = "no-3rdparty"
config.set("input.mode_override", "passthrough")
config.set("content.notifications.enabled", True, "{{url}}")

# Custom adblock filters (if any)
custom_adblock = ["file://{{adblock}}"] if len("{{adblock}}") > 0 else []
c.content.blocking.method = "both"
config.set("content.blocking.adblock.lists", custom_adblock + [
	# Default EasyList filters
	"https://easylist.to/easylist/easylist.txt",
	"https://easylist.to/easylist/easyprivacy.txt",

	# uBlock Origin filters
	"https://github.com/uBlockOrigin/uAssets/raw/master/filters/filters.txt",
	"https://github.com/uBlockOrigin/uAssets/raw/master/filters/privacy.txt",
	"https://github.com/uBlockOrigin/uAssets/raw/master/filters/quick-fixes.txt",
])

# Spell checking
config.set("spellcheck.languages", ["en-US", "el-GR"])

# Keybindings
config.bind("<Ctrl-r>", "reload", mode="passthrough")
config.bind("<Ctrl-Shift-i>", "devtools", mode="passthrough")
