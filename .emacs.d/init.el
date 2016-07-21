;(add-to-list 'load-path (expand-file-name "configs" user-emacs-directory))

;; Emacs specific
(setq auto-save-default nil) ;Do not autosave
(setq make-backup-files nil) ;Do not keep backups
(setq show-paren-delay 0) ;Do not delay in show-paren
(setq vc-follow-symlinks t) ;Just follow the symlinks in vc dirs
(setq-default indent-tabs-mode t) ;Use tabs
(setq-default mode-line-format nil) ;Disable mode line
(setq-default tab-always-indent t)
(setq-default tab-width 4)
(setq-default c-basic-offset 4)
(setq-default lua-basic-offset 4)
(setq-default html-basic-offset 4)
(setq-default lua-indent-level 4)
(add-hook 'prog-mode-hook #'hs-minor-mode)
(add-hook 'html-mode-hook
	(lambda ()
		;; Default indentation is usually 2 spaces, changing to 4.
		(set (make-local-variable 'sgml-basic-offset) 4)
	)
)
(setq frame-title-format
	  '("emacs - " (buffer-file-name "%f"
									 (dired-directory dired-directory "%b")
									 )
		)
	  )

(electric-pair-mode) ;Auto pairing
(menu-bar-mode -1) ;Disable the menu bar
(show-paren-mode t)

;; Package manager
(require 'package)
(push '("gnu" . "http://elpa.gnu.org/packages/") package-archives)
;(push '("marmalade" . "http://marmalade-repo.org/packages/") package-archives)
(push '("melpa-stable" . "http://melpa.milkbox.net/packages/") package-archives)
(push '("org" . "http://orgmode.org/elpa/") package-archives)
(package-initialize)

;; Bindings
(global-set-key (kbd "M-c") 'kill-this-buffer)
(global-set-key (kbd "M-<left>") 'previous-buffer)
(global-set-key (kbd "M-<right>") 'next-buffer)

(global-set-key (kbd "M-S-c") 'delete-window)
(global-set-key (kbd "M-RET") 'split-window-right)
(global-set-key (kbd "M-S-RET") 'split-window-below)
(global-set-key (kbd "M-<down>") 'previous-multiframe-window)
(global-set-key (kbd "M-<up>") 'next-multiframe-window)

;; Evil
(require 'evil)
(evil-mode t)

;; Theme
(require 'color-theme)
(setq font-lock-maximum-decoration t) ;Do maximum decoration
(color-theme-molokai)

;; Relative line numbers
(require 'linum-relative)
(global-linum-mode t)

;; Column rule
(require 'fill-column-indicator)
(setq-default fill-column 80)
(add-hook 'after-change-major-mode-hook 'fci-mode)

;; Auto complete
(require 'auto-complete)
(global-auto-complete-mode t)

;; SSH
(require 'ssh)
(add-hook 'ssh-mode-hook
	(lambda ()
		(setq ssh-directory-tracking-mode t)
		(shell-dirtrack-mode t)
		(setq dirtrackp nil)))

;; Web mode
(require 'web-mode)
(add-to-list 'auto-mode-alist '("\\.html\\'" . web-mode))

;; Spell checking
;;(dolist (hook '(text-mode-hook))
;;  (add-hook hook (lambda () (flyspell-mode 1))))
;;(dolist (hook '(change-log-mode-hook log-edit-mode-hook))
;;  (add-hook hook (lambda () (flyspell-mode -1))))

;; Syntax cheking
;(add-hook 'find-file-hook 'flymake-find-file-hook)

;; TODO: Whitespace
;; (setq-default show-trailing-whitespace nil) ;Disable mode line
;; (require 'whitespace)

;; SQLite support
(require 'sql)
(defalias 'sql-get-login 'ignore)