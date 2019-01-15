
;; Added by Package.el.  This must come before configurations of
;; installed packages.  Don't delete this line.  If you don't want it,
;; just comment it out by adding a semicolon to the start of the line.
;; You may delete these explanatory comments.
(package-initialize)

(load "~/.emacs.d/package")

;; Leader key (should be BEFORE evil)
(require-package 'evil-leader)
(global-evil-leader-mode)
(evil-leader/set-leader "<SPC>")

;; Native settings
(require-package 'realgud)

;; Functions
(defun move-line-up ()
  "Move up the current line."
  (interactive)
  (transpose-lines 1)
  (forward-line -2)
  (indent-according-to-mode))

(defun move-line-down ()
  "Move down the current line."
  (interactive)
  (forward-line 1)
  (transpose-lines 1)
  (forward-line -1)
  (indent-according-to-mode))

(defun speedbar-cycle (dir)
  "Go to the next speedbar mode"
  (interactive)
  (let ((modes
		 (mapcar (lambda (x)
				   (nth 0 x)) speedbar-initial-expansion-mode-alist)))
	(let
		((new-mode (nth
					(+ dir (cl-position speedbar-initial-expansion-list-name modes :test 'equal))
					modes)))
	 (if new-mode
	     (speedbar-change-initial-expansion-list new-mode)
	   nil))))

(defun realgud-populate-common-fn-keys-evil (&optional map)
  (define-key map [f5]    'realgud:cmd-continue)
  (define-key map [S-f5]  'realgud:cmd-quit)
  ;; (define-key map [f9]    'realgud-toggle-source-breakpoint)
  (define-key map [f9]    'realgud:cmd-break)
  ;; (define-key map [C-f9]  'realgud-toggle-source-breakpoint-enabled)
  (define-key map [f10]   'realgud:cmd-next)
  (define-key map [f11]   'realgud:cmd-step)
  (define-key map [S-f11] 'realgud:cmd-finish)
  ;; (define-key map [M-down]    'realgud-track-hist-newer)
  ;; (define-key map [A-down]    'realgud-track-hist-newer)
  ;; (define-key map [M-kp-2]    'realgud-track-hist-newer)
  ;; (define-key map [M-up]      'realgud-track-hist-older)
  ;; (define-key map [A-up]      'realgud-track-hist-older)
  ;; (define-key map [M-kp-8]    'realgud-track-hist-older)
  ;; (define-key map [M-kp-up]   'realgud-track-hist-older)
  ;; (define-key map [M-kp-down] 'realgud-track-hist-newer)
  ;; (define-key map [M-print]   'realgud-track-hist-older)
  ;; (define-key map [M-S-down]  'realgud-track-hist-newest)
  ;; (define-key map [M-S-up]    'realgud-track-hist-oldest)
  (define-key map "\C-c " 'realgud:cmd-break)
  )

(defun debug-enable ()
  (interactive)
  (tool-bar-mode 1)
  (if realgud-debug-command
	(funcall realgud-debug-command)
	(print "No debug command is set!")
	  ;; (
	  ;;  (funcall realgud-debug-command)
	  ;;  (tool-bar-mode 1)
	  ;;  )
	)
  )

(defun debug-disable ()
  (interactive)
  (realgud:cmd-quit)
  (tool-bar-mode 0))

(defun debug-toggle ()
  (interactive)
  (if realgud-cmdbuf-info (debug-disable) (debug-enable)))


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
(global-set-key (kbd "M-<left>") 'bs-cycle-previous)
(global-set-key (kbd "M-<right>") 'bs-cycle-next)

(evil-leader/set-key "b" 'sr-speedbar-toggle)

;; Windows
(global-set-key (kbd "M-RET") 'split-window-right)
(global-set-key (kbd "M-<backspace>") 'delete-window)
(global-set-key (kbd "M-f") 'delete-other-windows)
(global-set-key (kbd "M-C") 'delete-window)
(global-set-key (kbd "M-<down>") 'previous-multiframe-window)
(global-set-key (kbd "M-<up>") 'next-multiframe-window)
;(global-set-key (kbd "M-S-RET") 'split-window-below)

;; Editing & Navigation
;; (global-set-key '[(M-mouse-1)] 'semantic-ia-fast-mouse-jump)
(global-set-key (kbd "C-l") 'evil-ex-nohighlight)
(global-set-key (kbd "M-/") 'comment-line)
(global-set-key (kbd "C-]") 'semantic-ia-fast-jump)
(global-set-key (kbd "C-<down>") 'move-line-down)
(global-set-key (kbd "C-<up>") 'move-line-up)

(evil-leader/set-key "f" 'list-matching-lines)


(with-eval-after-load 'evil-maps
    (define-key evil-visual-state-map (kbd "M-/") 'comment-dwim))

;; Internal functions
(define-key global-map (kbd "RET") 'newline-and-indent)

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

;; _ is part of word
(modify-syntax-entry ?_ "w")


;; Package Settings
;; Evil Mode
(require-package 'evil)
(evil-mode t)
;; (require-package 'evil-collection)
;; (evil-collection-init)

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

;; Projectile
(require-package 'projectile)
(require-package 'projectile-speedbar)
(projectile-mode t)
(evil-leader/set-key "p" 'projectile-speedbar-open-current-buffer-in-tree)


;; Buffer/View Helpers

;; Column rule (hooks @prog-mode)
(load "~/.emacs.d/column-marker")
(require 'column-marker)

;; ElScreen
(require-package 'elscreen)
(elscreen-start)

;; SrSpeedBar - Speedbar in-frame
(load "~/.emacs.d/sr-speedbar")
(require 'sr-speedbar)
(require 'semantic/sb)

;; Highlight Characters
(load "~/.emacs.d/highlight-chars")
(require 'highlight-chars)
(hc-toggle-highlight-tabs)
(hc-toggle-highlight-trailing-whitespace)

;; Relative line numbers
(require-package 'linum-relative)
(linum-relative-mode t)

;; Multi-Term
(require-package 'multi-term)

;; Powerline
(require-package 'powerline)
(powerline-center-theme)

;; Replace for occur-mode
(load "~/.emacs.d/replace+")
(require 'replace+)


;; Editing Helpers

;; Indentation
(require-package 'dtrt-indent)
(dtrt-indent-mode t)

;; Evil Escape everything
(require-package 'evil-escape)

;; Advanced blocks
(require-package 'evil-matchit)
(global-evil-matchit-mode t)

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
;; Enable JavaScript completion between <script>...</script> etc.
(advice-add 'company-tern :before
            #'(lambda (&rest _)
                (if (equal major-mode 'web-mode)
                    (let ((web-mode-cur-language
                           (web-mode-language-at-pos)))
                      (if (or (string= web-mode-cur-language "javascript")
                              (string= web-mode-cur-language "jsx"))
                          (unless tern-mode (tern-mode))
                        (if tern-mode (tern-mode -1)))))))

(require-package 'company-web)
(require-package 'ac-html-angular)
(require-package 'ac-html-csswatcher)
(require 'company-web-html) ; HTML
(add-to-list 'company-backends 'company-web-html)

(require 'company-web-jade) ; Jade
(add-to-list 'company-backends 'company-web-jade)

(require 'company-web-slim) ; Slim
(add-to-list 'company-backends 'company-web-slim)

;(require-package 'php-extras)       ; PHP
;(add-to-list 'company-backends 'php-extras)


;; Linting, debugging & building

;; Flycheck syntax checker
(require-package 'flycheck)
(require-package 'flycheck-pos-tip)
(after 'flycheck
  (setq flycheck-check-syntax-automatically '(save mode-enabled))
  (setq flycheck-checkers (delq 'emacs-lisp-checkdoc flycheck-checkers))
  (setq flycheck-checkers (delq 'html-tidy flycheck-checkers))
  (setq flycheck-standard-error-navigation nil)
  (flycheck-pos-tip-mode))
(evil-leader/set-key "e" 'flycheck-list-errors)

;; RealGUD
(defvar-local realgud-debug-command nil "RealGUD debug commmand for current major mode")
(add-hook 'prog-mode-hook (lambda nil (setq-local realgud-debug-command 'realgud:gdb)))

(add-hook 'go-mode-hook (lambda nil (setq-local realgud-debug-command 'realgud:gub)))
(add-hook 'java-mode-hook (lambda nil (setq-local realgud-debug-command 'realgud:jdb)))
(add-hook 'javascript-mode-hook (lambda nil (setq-local realgud-debug-command 'realgud:trepanjs)))
;; (add-hook 'javascript-mode-hook (lambda nil (setq-local realgud-debug-command 'realgud:node-debug)))
(add-hook 'makefile-mode-hook (lambda nil (setq-local realgud-debug-command 'realgud:remake)))
(add-hook 'perl-mode-hook (lambda nil (setq-local realgud-debug-command 'realgud:trepan.pl)))
;; (add-hook 'perl-mode-hook (lambda nil (setq-local realgud-debug-command 'realgud:perldb)))
(add-hook 'python-mode-hook (lambda nil (setq-local realgud-debug-command 'realgud:ipdb)))
;; (add-hook 'python-mode-hook (lambda nil (setq-local realgud-debug-command 'realgud:pdb)))
;; (add-hook 'python-mode-hook (lambda nil (setq-local realgud-debug-command 'realgud:pydb)))
;; (add-hook 'python-mode-hook (lambda nil (setq-local realgud-debug-command 'realgud:trepan2)))
;; (add-hook 'python-mode-hook (lambda nil (setq-local realgud-debug-command 'realgud:trepan3k)))
(add-hook 'ruby-mode-hook (lambda nil (setq-local realgud-debug-command 'realgud:trepan)))
;; (add-hook 'ruby-mode-hook (lambda nil (setq-local realgud-debug-command 'realgud:rdebug)))
(add-hook 'sh-mode-hook (lambda nil (setq-local realgud-debug-command 'realgud:bashdb)))
(add-hook 'sh-mode-hook (lambda nil (setq-local realgud-debug-command 'realgud:bashdb)))

;; (evil-leader/set-key "g" 'debug-toggle)
(evil-leader/set-key "g" 'debug-enable)
(evil-leader/set-key "G" 'debug-disable)




;; Syntax

;; Arduino
(require-package 'arduino-mode)
(require-package 'platformio-mode)

;; CoffeeScript
(require-package 'coffee-mode)

;; Docker things
(require-package 'docker-compose-mode)
(require-package 'dockerfile-mode)

;; Jinja2
(require-package 'jinja2-mode)

;; Markdown
(require-package 'markdown-mode)

;; Python
(require-package 'virtualenvwrapper)
;; (add-hook 'python-mode-hook #'auto-virtualenvwrapper-activate)

;; (require-package 'elpy)
;; (elpy-enable)

;; Swift
(require-package 'swift-mode)


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
 '(auth-source-gpg-encrypt-to (quote ("dzervas@census-labs.com")))
 '(auto-insert-mode t)
 '(auto-revert-check-vc-info t)
 '(bs-configurations
   (quote
	(("all" nil nil nil nil nil)
	 ("files" nil nil nil bs-visits-non-file bs-sort-buffer-interns-are-last)
	 ("same-mm" nil nil nil
	  (lambda
		(buf)
		(let
			((original-mm major-mode))
		  (with-current-buffer buf
			(not
			 (eq major-mode original-mm)))))
	  bs-sort-interns-are-last))))
 '(bs-cycle-configuration-name "same-mm")
 '(comment-inline-offset 2)
 '(company-auto-complete t)
 '(company-auto-complete-chars (quote ignore))
 '(company-backends
   (quote
	(company-tern company-irony company-jedi company-go company-bbdb company-eclim company-semantic company-clang company-xcode company-cmake company-capf company-css company-files
				  (company-dabbrev-code company-gtags company-etags company-keywords)
				  company-oddmuse company-dabbrev)))
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
 '(erc-autojoin-channels-alist (quote (("token.census" "#census"))))
 '(erc-email-userid "dzervas")
 '(erc-modules
   (quote
	(autojoin button completion fill irccontrols list match menu move-to-prompt netsplit networks noncommands notifications readonly ring smiley stamp spelling track)))
 '(erc-nick "dzervas")
 '(erc-nick-uniquifier "_")
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
 '(gnus-secondary-select-methods
   (quote
	((nnimap "dzervas@census-labs.com"
			 (nnimap-address mail\.webfaction\.com)
			 (nnimap-server-port 993)
			 (nnimap-authinfo-file "~/.authinfo.gpg")
			 (nnimap-stream ssl)))))
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
	(docker-compose-mode dockerfile-mode jinja2-mode coffee-mode projectile evil-escape powerline molokai-theme linum-relative imenu-list git-gutter-fringe+ flycheck fill-column-indicator evil-surround evil-smartparens evil-mc evil-matchit evil-leader elscreen dtrt-indent company-tern company-quickhelp company-jedi company-irony company-go)))
 '(plstore-select-keys nil)
 '(prog-mode-hook
   (quote
	(flyspell-prog-mode flycheck-mode prettify-symbols-mode hs-minor-mode
						(lambda nil
						  (interactive)
						  (column-marker-1 80)))))
 '(projectile-mode t nil (projectile))
 '(projectile-mode-line (quote (:eval (format " [%s]" (projectile-project-name)))))
 '(projectile-other-file-alist
   (quote
	(("cpp" "h" "hpp" "ipp")
	 ("ipp" "h" "hpp" "cpp")
	 ("hpp" "h" "ipp" "cpp" "cc")
	 ("cxx" "h" "hxx" "ixx")
	 ("ixx" "h" "hxx" "cxx")
	 ("hxx" "h" "ixx" "cxx")
	 ("c" "h")
	 ("m" "h")
	 ("mm" "h")
	 ("h" "c" "cc" "cpp" "ipp" "hpp" "cxx" "ixx" "hxx" "m" "mm")
	 ("cc" "h" "hh" "hpp")
	 ("hh" "cc")
	 ("vert" "frag")
	 ("frag" "vert")
	 (nil "lock" "gpg")
	 ("lock" "")
	 ("gpg" "")
	 ("java" . "smali"))))
 '(realgud-populate-common-fn-keys-function (quote realgud-populate-common-fn-keys-none))
 '(realgud-safe-mode nil)
 '(replace-w-completion-flag t)
 '(scalable-fonts-allowed t)
 '(search-default-mode t)
 '(search-exit-option nil)
 '(semantic-complete-inline-analyzer-displayor-class (quote semantic-displayor-tooltip))
 '(semantic-mode t)
 '(semanticdb-project-roots (quote ("~/Lab")))
 '(send-mail-function (quote smtpmail-send-it))
 '(show-paren-delay 0)
 '(show-paren-mode t)
 '(show-paren-style (quote mixed))
 '(show-paren-when-point-in-periphery t)
 '(show-paren-when-point-inside-paren t)
 '(speedbar-mode-hook
   (quote
	((lambda nil
	   (local-set-key
		(kbd "M-<left>")
		(lambda nil
		  (interactive)
		  (speedbar-cycle -1))))
	 (lambda nil
	   (local-set-key
		(kbd "M-<right>")
		(lambda nil
		  (interactive)
		  (speedbar-cycle 1)))))))
 '(tab-always-indent nil)
 '(tab-width 4)
 '(term-mode-hook
   (quote
	((lambda nil
	   (linum-mode -1))
	 (lambda nil
	   (setq-local global-hl-line-mode nil)))))
 '(text-mode-hook (quote (turn-on-flyspell text-mode-hook-identify)))
 '(tooltip-mode t)
 '(tramp-adb-connect-if-not-connected t nil (tramp))
 '(word-wrap t)
 '(words-include-escapes t))

(custom-set-faces
 ;; custom-set-faces was added by Custom.
 ;; If you edit it by hand, you could mess it up, so be careful.
 ;; Your init file should contain only one such instance.
 ;; If there is more than one, they won't work right.
 '(default ((t (:inherit nil :stipple nil :background "#1B1D1E" :foreground "#F8F8F2" :inverse-video nil :box nil :strike-through nil :overline nil :underline nil :slant normal :weight normal :height 120 :width normal :foundry "CYEL" :family "Iosevka"))))
 '(hc-tab ((t (:underline (:color "dim gray" :style wave)))))
 '(hc-trailing-whitespace ((t (:strike-through "dim gray")))))
