
;; Added by Package.el.  This must come before configurations of
;; installed packages.  Don't delete this line.  If you don't want it,
;; just comment it out by adding a semicolon to the start of the line.
;; You may delete these explanatory comments.
(package-initialize)

(load "~/.emacs.d/package")

;; Leader key (should be BEFORE evil)
(require-package 'evil-leader)
(global-evil-leader-mode)
(evil-leader/set-leader ",")

;; Native settings
;; Keybindings

;; Tabs
(global-set-key (kbd "M-t") 'elscreen-create)
(global-set-key (kbd "M-w") 'elscreen-kill)
(global-set-key (kbd "M-W") 'elscreen-kill-others)
(global-set-key (kbd "M-S-<left>") 'elscreen-previous)
(global-set-key (kbd "M-S-<right>") 'elscreen-next)

;; Buffers
;; TODO: Manage special buffers, per window, sort/order them on demand
(global-set-key (kbd "M-c") 'kill-this-buffer)
(global-set-key (kbd "M-<left>") 'previous-buffer)
(global-set-key (kbd "M-<right>") 'next-buffer)

;; Windows
(global-set-key (kbd "M-RET") 'split-window-right)
(global-set-key (kbd "M-<backspace>") 'delete-window)
(global-set-key (kbd "M-f") 'delete-other-windows)
(global-set-key (kbd "M-<down>") 'previous-multiframe-window)
(global-set-key (kbd "M-<up>") 'next-multiframe-window)
;(global-set-key (kbd "M-S-RET") 'split-window-below)

(evil-leader/set-key "f" 'speedbar-get-focus)

(with-eval-after-load 'evil-maps
    (define-key evil-normal-state-map (kbd "M-/") 'comment-line)
    (define-key evil-visual-state-map (kbd "M-/") 'comment-dwim)
)

;; Internal functions
(define-key global-map (kbd "RET") 'newline-and-indent)

;; Hide/Show stuff
(add-hook 'prog-mode-hook 'hs-minor-mode)

;; Highlight current line
(global-hl-line-mode t)

;; Disable the menu bar
(menu-bar-mode -1)

;; Disable the scroll bar
(scroll-bar-mode -1)

;; Save position in file
(save-place-mode t)

;; Save minibuffer history
(savehist-mode t)

;; Disable backups
(setq make-backup-files nil)

;; IComplete for the modeline
(icomplete-mode t)

;; Start maximized
(custom-set-variables
 ;; custom-set-variables was added by Custom.
 ;; If you edit it by hand, you could mess it up, so be careful.
 ;; Your init file should contain only one such instance.
 ;; If there is more than one, they won't work right.
 '(flycheck-display-errors-function (function flycheck-pos-tip-error-messages))
 '(initial-frame-alist (quote ((fullscreen . maximized))))
 '(package-selected-packages
   (quote
    (evil-escape powerline molokai-theme linum-relative imenu-list git-gutter-fringe+ flycheck fill-column-indicator evil-surround evil-smartparens evil-mc evil-matchit evil-leader elscreen dtrt-indent company-tern company-quickhelp company-jedi company-irony company-go))))


;; Package Settings
;; Evil Mode
(require-package 'evil)
(evil-mode t)

;; Molokai
(require-package 'molokai-theme)
(add-to-list 'custom-theme-load-path "~/.emacs.d/molokai-overrides-theme.el")
(load-theme 'molokai t)
(load-theme 'molokai-overrides t)
(setq molokai-theme-kit t)
(setq font-lock-maximum-decoration t)
(setq custom-safe-themes t)

;; Git Helpers

;; Git Gutter
(require-package 'git-gutter+)
(require-package 'git-gutter-fringe+)
(global-git-gutter+-mode)
(git-gutter-fr+-minimal)


;; Buffer/View Helpers

;; ELScreen
(require-package 'elscreen)
(elscreen-start)

;; Tag Bar
(require-package 'imenu-list)

;; Relative line numbers
(require-package 'linum-relative)
(linum-on)
(linum-relative-mode t)

;; Powerline
(require-package 'powerline)
(powerline-center-theme)

;(require-package 'airline-themes)
;(load-theme 'airline-badwolf)


;; Editing Helpers

;; Indentation
(require-package 'dtrt-indent)
(dtrt-indent-mode t)

;; Emacs Code Browser
;; (require-package 'ecb)

;; Evil Escape everything
(require-package 'evil-escape)
(evil-escape-mode t)

;; Advanced blocks
(require-package 'evil-matchit)
(global-evil-matchit-mode t)

;; Undo Tree
;(require-package 'undo-tree)
;(global-undo-tree-mode)

;; Multiple cursors
;; TODO: Escape this
(require-package 'evil-mc)
(global-evil-mc-mode t)
(global-set-key (kbd "C-n") 'evil-mc-make-and-goto-next-match)
(global-set-key (kbd "C-p") 'evil-mc-make-and-goto-prev-match)
(global-set-key (kbd "C-x") 'evil-mc-skip-and-goto-next-match)
(add-hook 'evil-mc-mode
  (local-set-key [escape] 'evil-mc-undo-all-cursors))

;; SmartParens
(require-package 'evil-smartparens)
(require 'smartparens-config)
(add-hook 'prog-mode-hook #'smartparens-mode)
(add-hook 'smartparens-enabled-hook #'evil-smartparens-mode)

;; Change surroundings
(require-package 'evil-surround)
(global-evil-surround-mode t)

;; Column rule
; TODO: Incompatibility with company mode
;(require-package 'fill-column-indicator)
;(setq-default fill-column 80)
;(add-hook 'prog-mode-hook 'fci-mode)

;; Highlight Characters
; TODO: Fix only trailing
; TODO: Fix character indicators
(load "~/.emacs.d/highlight-chars")
(require 'highlight-chars)
(hc-toggle-highlight-tabs)
(hc-toggle-highlight-trailing-whitespace)
;(font-lock-add-keywords nil `(("[\240\040\t]+$" (0 'hc-trailing-whitespace ,hc-font-lock-override))) 'APPEND)
(setq hc-trailing-whitespace '((t (:strike-through))))
(setq hc-tab '((t (:background "#888888"))))


;; Autocompletion

;; Company auto-completion
(require-package 'company)
(setq company-tooltip-limit 20)
(setq company-idle-delay 0)
(setq company-echo-delay 0)
(setq company-auto-complete t)

(add-hook 'after-init-hook 'global-company-mode)
;(add-hook 'company-completion-started-hook '(fci-mode -1))
;(add-hook 'company-completion-finished-hook '(fci-mode 1))
;(add-hook 'company-completion-cancelled-hook '(fci-mode 1))

;; Company Quickhelp
(require-package 'company-quickhelp)
(company-quickhelp-mode)
(setq company-quickhelp-delay 0)

;; Company Languages

(add-to-list 'company-backends 'company-capf)

(require-package 'company-go)       ; Go. Needs go get -u github.com/nsf/gocode
(setq company-go-gocode-command "~/go/bin/gocode")
(add-to-list 'company-backends 'company-go)

(require-package 'jedi-core)
(require-package 'company-jedi)     ; Python. Needs M-x jedi:install-server
(add-to-list 'company-backends 'company-jedi)

(require-package 'company-irony)    ; C/C++/ObjC/ObjC++
(add-to-list 'company-backends 'company-irony)

(require-package 'company-tern)     ; JS
(add-to-list 'company-backends 'company-tern)

;(require-package 'company-web-html) ; HTML
;(add-to-list 'company-backends 'company-web-html)

;(require-package 'company-web-jade) ; Jade
;(add-to-list 'company-backends 'company-web-jade)

;(require-package 'company-web-slim) ; Slim
;(add-to-list 'company-backends 'company-web-slim)

;(require-package 'php-extras)       ; PHP
;(add-to-list 'company-backends 'php-extras)


;; Linting, debugging & building

;; Flycheck syntax checker
(require-package 'flycheck)
(add-hook 'after-init-hook #'global-flycheck-mode)
(after 'flycheck
  (setq flycheck-check-syntax-automatically '(save mode-enabled))
  (setq flycheck-checkers (delq 'emacs-lisp-checkdoc flycheck-checkers))
  (setq flycheck-checkers (delq 'html-tidy flycheck-checkers))
  (setq flycheck-standard-error-navigation nil))
(global-flycheck-mode t)

;; flycheck errors on a tooltip (doesnt work on console)
(when (display-graphic-p (selected-frame))
  (eval-after-load 'flycheck
    '(custom-set-variables
      '(flycheck-display-errors-function #'flycheck-pos-tip-error-messages))))


;; Syntax
(custom-set-faces
 ;; custom-set-faces was added by Custom.
 ;; If you edit it by hand, you could mess it up, so be careful.
 ;; Your init file should contain only one such instance.
 ;; If there is more than one, they won't work right.
 '(default ((t (:inherit nil :stipple nil :background "#1B1D1E" :foreground "#F8F8F2" :inverse-video nil :box nil :strike-through nil :overline nil :underline nil :slant normal :weight normal :height 145 :width normal :foundry "nil" :family "Iosevka")))))
