(require 'package)

(add-to-list 'package-archives '("org" . "http://orgmode.org/elpa/"))
(add-to-list 'package-archives '("melpa" . "http://melpa.org/packages/"))
;; (add-to-list 'package-archives '("melpa-stable" . "http://stable.melpa.org/packages/"))

(setq package-enable-at-startup nil)

(defun require-package (&rest packages)
  (mapcar
    (lambda (package)
      (if (package-installed-p package)
        nil
        (if (y-or-n-p (format "Package %s is missing. Install it? " package))
	  (package-install package)
	  require package)
	)
      )
    packages)
  )
  (or (file-exists-p package-user-dir) (package-refresh-contents))
(package-initialize)

;; Native settings
;; Keybindings
(global-set-key (kbd "M-c") 'kill-this-buffer)
(global-set-key (kbd "M-f") 'speedbar-get-focus)
(global-set-key (kbd "M-l") 'flycheck-list-errors)
;; (global-set-key (kbd "C-n") 'evil-mc-make-and-goto-next-match)
;; (global-set-key (kbd "C-p") 'evil-mc-make-and-goto-prev-match)
;; (global-set-key (kbd "C-S-n") 'evil-mc-skip-and-goto-next-match)
;; (global-set-key (kbd "C-S-p") 'evil-mc-skip-and-goto-prev-match)
(global-set-key (kbd "M-<left>") 'previous-buffer)
(global-set-key (kbd "M-<right>") 'next-buffer)

(global-set-key (kbd "M-S-c") 'delete-window)
(global-set-key (kbd "M-RET") 'split-window-right)
(global-set-key (kbd "M-S-RET") 'split-window-below)
(global-set-key (kbd "M-<down>") 'previous-multiframe-window)
(global-set-key (kbd "M-<up>") 'next-multiframe-window)

(with-eval-after-load 'evil-maps
    (define-key evil-normal-state-map "//" 'comment-dwim)
    (define-key evil-visual-state-map "//" 'comment-dwim)
)

;; Internal functions
(define-key global-map (kbd "RET") 'newline-and-indent)

(add-hook 'prog-mode-hook 'hs-minor-mode)

(global-hl-line-mode t)      ;; Highlight current line
(menu-bar-mode -1)	     ;; Disable the menu bar
(save-place-mode 1)          ;; Save position in file
(savehist-mode 1)            ;; Save minibuffer history

(setq make-backup-files nil) ;; Disable backups

;; Package Settings
;; Molokai
(load-theme 'molokai t)
(setq molokai-theme-kit t)
(setq font-lock-maximum-decoration t)
(setq custom-safe-themes t)

;; Evil Mode
(require-package 'evil)
(evil-mode t)

;; Advanced blocks
(require-package 'evil-matchit)
(global-evil-matchit-mode 1)

;; Relative line numbers
(require-package 'linum-relative)
(global-linum-mode t)
(linum-relative-mode t)

;; Column rule
(require-package 'fill-column-indicator)
(setq-default fill-column 80)
(add-hook 'after-change-major-mode-hook 'fci-mode)

;; Emacs Code Browser
;; (require-package 'ecb)

;; Powerline
(require-package 'powerline)
(powerline-center-theme)

;; (require-package 'airline-themes)
;; (load-theme 'airline-molokai t)

;; SmartParens
(require-package 'evil-smartparens)
(require 'smartparens-config)
(add-hook 'prog-mode-hook #'smartparens-mode)
(add-hook 'smartparens-enabled-hook #'evil-smartparens-mode)

;; Flycheck syntax checker
(add-hook 'after-init-hook #'global-flycheck-mode)
(setq-default flycheck-disabled-checkers '(emacs-lisp-checkdoc))

;; Company auto-completion
(add-hook 'after-init-hook 'global-company-mode)
(add-hook 'python-mode-hook
  (with-eval-after-load 'company
    (add-to-list 'company-backends 'company-jedi)))

;; Evil-MC Multi-cursors
;; (global-evil-mc-mode  1)

(custom-set-variables
 ;; custom-set-variables was added by Custom.
 ;; If you edit it by hand, you could mess it up, so be careful.
 ;; Your init file should contain only one such instance.
 ;; If there is more than one, they won't work right.
 '(package-selected-packages
   (quote
    (evil-mc company company-jedi molokai-theme linum-relative flycheck fill-column-indicator evil-visual-mark-mode evil-smartparens evil-matchit ecb airline-themes))))
(custom-set-faces
 ;; custom-set-faces was added by Custom.
 ;; If you edit it by hand, you could mess it up, so be careful.
 ;; Your init file should contain only one such instance.
 ;; If there is more than one, they won't work right.
 )
