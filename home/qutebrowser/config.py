c.tabs.show = "multiple"
c.statusbar.show = "always"
c.window.title_format = "{perc}{current_title}"
config.set("colors.webpage.darkmode.enabled", True)
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
