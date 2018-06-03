
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
(global-set-key (kbd "M-<left>") 'bs-cycle-previous)
(global-set-key (kbd "M-<right>") 'bs-cycle-next)

;; Windows
(global-set-key (kbd "M-RET") 'split-window-right)
(global-set-key (kbd "M-<backspace>") 'delete-window)
(global-set-key (kbd "M-f") 'delete-other-windows)
(global-set-key (kbd "M-<down>") 'previous-multiframe-window)
(global-set-key (kbd "M-<up>") 'next-multiframe-window)
;(global-set-key (kbd "M-S-RET") 'split-window-below)

(global-set-key (kbd "C-f") 'list-matching-lines)

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

;; Disable the tool bar
(tool-bar-mode -1)

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


;; Package Settings
;; Evil Mode
(require-package 'evil)
(evil-mode t)

;; Molokai
(require-package 'molokai-theme)
(add-to-list 'custom-theme-load-path "~/.emacs.d/molokai-overrides-theme.el")
(load-theme 'molokai t)
(load-theme 'molokai-overrides t)
(setq font-lock-maximum-decoration t)
(setq custom-safe-themes t)

;; Git Helpers

;; Git Gutter
(require-package 'git-gutter+)
(require-package 'git-gutter-fringe+)
(global-git-gutter+-mode)
(git-gutter-fr+-minimal)


;; Buffer/View Helpers

;; ElScreen
(require-package 'elscreen)
(elscreen-start)

;; Relative line numbers
(require-package 'linum-relative)
(linum-relative-mode t)

;; Powerline
(require-package 'powerline)
(powerline-center-theme)

;; Multi-Term
(require-package 'multi-term)


;; Editing Helpers

;; Indentation
(require-package 'dtrt-indent)
(dtrt-indent-mode t)

;; Emacs Code Browser
;; (require-package 'ecb)

;; Evil Escape everything
(require-package 'evil-escape)

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


;; Start maximized
(custom-set-variables
 ;; custom-set-variables was added by Custom.
 ;; If you edit it by hand, you could mess it up, so be careful.
 ;; Your init file should contain only one such instance.
 ;; If there is more than one, they won't work right.
 '(align-c++-modes (quote (c++-mode c-mode java-mode js-mode php-mode)))
 '(align-open-comment-modes
   (quote
	(emacs-lisp-mode lisp-interaction-mode lisp-mode scheme-mode c++-mode c-mode java-mode perl-mode cperl-mode python-mode makefile-mode go-mode js-mode web-mode php-mode)))
 '(align-text-modes (quote (text-mode outline-mode markdown-mode org-mode)))
 '(auto-insert-mode t)
 '(auto-revert-check-vc-info t)
 '(bs-cycle-configuration-name "files")
 '(comment-inline-offset 2)
 '(comment-style (quote aligned))
 '(company-auto-complete t)
 '(company-auto-complete-chars (quote ignore))
 '(company-dabbrev-code-modes
   (quote
	(prog-mode batch-file-mode csharp-mode css-mode erlang-mode haskell-mode jde-mode lua-mode python-mode go-mode js-mode php-mode web-mode)))
 '(company-files-exclusions \.git)
 '(company-go-begin-after-member-access nil)
 '(company-go-show-annotation t)
 '(company-idle-delay 0)
 '(company-quickhelp-delay 0)
 '(company-quickhelp-use-propertized-text t)
 '(company-search-regexp-function (quote company-search-flex-regexp))
 '(company-selection-wrap-around t)
 '(company-show-numbers t)
 '(company-tooltip-align-annotations t)
 '(company-tooltip-idle-delay 0)
 '(compilation-ask-about-save nil)
 '(create-lockfiles nil)
 '(display-raw-bytes-as-hex t)
 '(dtrt-indent-global-mode t)
 '(dtrt-indent-ignore-single-chars-flag t)
 '(dtrt-indent-mode t nil (dtrt-indent))
 '(ede-auto-add-method (quote multi-ask))
 '(electric-pair-inhibit-predicate (quote electric-pair-conservative-inhibit))
 '(electric-pair-mode t)
 '(evil-disable-insert-state-bindings nil)
 '(evil-escape-mode t)
 '(evil-ex-interactive-search-highlight (quote selected-window))
 '(evil-indent-convert-tabs nil)
 '(evil-jumps-cross-buffers nil)
 '(evil-magic (quote very-magic))
 '(evil-search-module (quote evil-search))
 '(evil-symbol-word-search t)
 '(evil-want-Y-yank-to-eol t)
 '(evil-want-fine-undo t)
 '(fill-column 80)
 '(flycheck-display-errors-function (function flycheck-pos-tip-error-messages))
 '(global-auto-revert-mode t)
 '(global-ede-mode t)
 '(global-evil-surround-mode t)
 '(global-hl-line-mode t)
 '(global-hl-line-sticky-flag t)
 '(global-linum-mode t)
 '(global-semantic-highlight-edits-mode t)
 '(global-semantic-highlight-func-mode t)
 '(global-semantic-idle-breadcrumbs-mode t nil (semantic/idle))
 '(global-semantic-idle-completions-mode t nil (semantic/idle))
 '(global-semantic-idle-local-symbol-highlight-mode t nil (semantic/idle))
 '(global-semantic-idle-summary-mode t)
 '(global-semantic-stickyfunc-mode t)
 '(global-undo-tree-mode t)
 '(godoc-use-completing-read t)
 '(grep-command "rg")
 '(help-at-pt-display-when-idle (quote never) nil (help-at-pt))
 '(imenu-auto-rescan t)
 '(imenu-list-auto-resize t)
 '(imenu-list-focus-after-activation t)
 '(imenu-max-item-length 30)
 '(imenu-max-items 50)
 '(imenu-use-popup-menu t)
 '(initial-buffer-choice (quote remember-notes))
 '(initial-frame-alist (quote ((fullscreen . maximized))))
 '(isearch-allow-scroll t)
 '(js-chain-indent t)
 '(linum-format (quote linum-relative))
 '(linum-relative-backend (quote display-line-numbers-mode))
 '(linum-relative-current-symbol "")
 '(package-selected-packages
   (quote
	(evil-escape powerline molokai-theme linum-relative imenu-list git-gutter-fringe+ flycheck fill-column-indicator evil-surround evil-smartparens evil-mc evil-matchit evil-leader elscreen dtrt-indent company-tern company-quickhelp company-jedi company-irony company-go)))
 '(plstore-select-keys nil)
 '(prog-mode-hook
   (quote
	(flyspell-prog-mode prettify-symbols-mode hs-minor-mode)))
 '(scalable-fonts-allowed t)
 '(search-default-mode t)
 '(search-exit-option nil)
 '(semantic-complete-inline-analyzer-displayor-class (quote semantic-displayor-tooltip))
 '(semantic-mode t)
 '(semanticdb-project-roots (quote ("~/Lab")))
 '(show-paren-delay 0)
 '(show-paren-mode t)
 '(show-paren-style (quote mixed))
 '(show-paren-when-point-in-periphery t)
 '(show-paren-when-point-inside-paren t)
 '(tab-always-indent nil)
 '(tab-width 4)
 '(tooltip-mode t)
 '(tramp-adb-connect-if-not-connected t nil (tramp))
 '(word-wrap t)
 '(words-include-escapes t))

(custom-set-faces
 ;; custom-set-faces was added by Custom.
 ;; If you edit it by hand, you could mess it up, so be careful.
 ;; Your init file should contain only one such instance.
 ;; If there is more than one, they won't work right.
 '(default ((t (:inherit nil :stipple nil :background "#1B1D1E" :foreground "#F8F8F2" :inverse-video nil :box nil :strike-through nil :overline nil :underline nil :slant normal :weight normal :height 145 :width normal :foundry "nil" :family "Iosevka"))))
 '(hc-tab ((t (:underline (:color "dim gray" :style wave)))))
 '(hc-trailing-whitespace ((t (:strike-through "dim gray")))))
