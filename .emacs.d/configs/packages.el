(require 'package)
(push '("gnu" . "http://elpa.gnu.org/packages/"), package-archives)
(push '("marmalade" . "http://marmalade-repo.org/packages/"), package-archives)
(push '("melpa" . "http://melpa.milkbox.net/packages/"), package-archives)
(push '("org" . "http://orgmode.org/elpa/"), package-archives)
(package-initialize)

(provide 'packages)
