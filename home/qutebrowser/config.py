c.colors.webpage.preferred_color_scheme = "dark"
c.statusbar.show = "always"
c.tabs.show = "multiple"
c.window.title_format = "{{emoji}} {perc}{current_title}"

config.set("content.notifications.enabled", True, "{{url}}")
config.set("content.blocking.adblock.lists", [
	# Default EasyList filters
	"https://easylist.to/easylist/easylist.txt",
	"https://easylist.to/easylist/easyprivacy.txt",

	# uBlock Origin filters
	"https://github.com/uBlockOrigin/uAssets/raw/master/filters/filters.txt",
	"https://github.com/uBlockOrigin/uAssets/raw/master/filters/privacy.txt",
	"https://github.com/uBlockOrigin/uAssets/raw/master/filters/quick-fixes.txt",
])
