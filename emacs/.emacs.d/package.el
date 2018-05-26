(add-to-list 'package-archives '("melpa" . "https://melpa.org/packages/"))
(add-to-list 'package-archives '("org" . "https://orgmode.org/elpa/"))

(setq package-enable-at-startup nil)

(defun require-package (&rest packages)
  (mapcar
    (lambda (package)
      (if (package-installed-p package) nil
          (package-install package))
      (require package))
    packages))

(if (fboundp 'with-eval-after-load)
  (defmacro after (feature &rest body)
    "After FEATURE is loaded, evaluate BODY."
    (declare (indent defun))
    `(with-eval-after-load ,feature ,@body))
  (defmacro after (feature &rest body)
    "After FEATURE is loaded, evaluate BODY."
    (declare (indent defun))
    `(eval-after-load ,feature
       '(progn ,@body))))


(or (file-exists-p package-user-dir) (package-refresh-contents))
(package-initialize)
