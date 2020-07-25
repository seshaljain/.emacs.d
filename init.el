;;; -*- lexical-binding: t -*-

(defun tangle-init ()
  "If the current buffer is 'init.org' the code-blocks are
tangled, and the tangled file is compiled."
  (when (equal (buffer-file-name)
               (expand-file-name (concat user-emacs-directory "init.org")))
    ;; Avoid running hooks when tangling.
    (let ((prog-mode-hook nil))
      (org-babel-tangle)
      (byte-compile-file (concat user-emacs-directory "init.el")))))
(add-hook 'after-save-hook 'tangle-init)

(setq custom-file "~/.emacs.d/.custom.el")
(load custom-file t)

(global-set-key "\C-x\C-m" 'execute-extended-command)

(setq org-confirm-babel-evaluate nil)

(setq org-edit-src-content-indentation 0)

(custom-set-variables
 '(org-directory "~/Dropbox/org/til.org")
 '(org-startup-folded 'overview))

(global-set-key (kbd "C-c c") 'org-capture)

(setq org-capture-templates
      '(("t" "TIL" entry (file+headline "~/Dropbox/org/til.org" "TIL")
         "* %^{TIL} %^g\n%^{Description}\n%T" :prepend t)
				("l" "Link" entry (file+headline "~/Dropbox/org/links.org" "Links")
         "* %? %^L %^g\n%T" :prepend t)
        ("k" "Keybinding" entry (file "~/Dropbox/org/learn-keybindings.org")
         "* =%^{Keybinding}= %^g\n%^{Description}")))

(defadvice org-capture-finalize
		(after delete-capture-frame activate)
	"Advise capture-finalize to close the frame"
  (if (equal "capture" (frame-parameter nil 'name))
      (delete-frame)))

(defadvice org-capture-destroy
    (after delete-capture-frame activate)
  "Advise capture-destroy to close the frame"
  (if (equal "capture" (frame-parameter nil 'name))
      (delete-frame)))

(eval-after-load 'org
  '(progn (add-to-list 'org-structure-template-alist
											 '("s" "#+BEGIN_SRC emacs-lisp\n?\n#+END_SRC" ""))))

(require 'package)
(let* ((no-ssl (and (memq system-type '(windows-nt ms-dos))
										(not (gnutls-available-p))))
			 (proto (if no-ssl "http" "https")))
  (add-to-list 'package-archives (cons "melpa" (concat proto "://melpa.org/packages/")) t)
  (when (< emacs-major-version 24)
    ;; For important compatibility libraries like cl-lib
    (add-to-list 'package-archives '("gnu" . (concat proto "://elpa.gnu.org/packages/")))))

(package-initialize)

(unless (package-installed-p 'use-package)
  (package-refresh-contents)
  (package-install 'use-package))

(require 'use-package)
(setq use-package-always-ensure t)

(use-package windmove
  :bind
  (("C-c f"  . 'windmove-right)
   ("C-c b"  . 'windmove-left)
   ("C-c n"  . 'windmove-down)
   ("C-c p"  . 'windmove-up)))

(defun my/reload-config()
	"Reload init.el"
	(interactive)
  (load-file "~/.emacs.d/init.el"))

(defun my/kill-other-buffers ()
	"Kill all buffers except the active buffer"
	(interactive)
	(dolist (buffer (buffer-list))
		(unless (or (eql buffer (current-buffer)) (not (buffer-file-name buffer)))
			(kill-buffer buffer))))

(defun my/kill-all-buffers ()
  "Kill all buffers without regard for their origin."
  (interactive)
  (mapc 'kill-buffer (buffer-list)))

(global-set-key (kbd "C-M-s-k") 'my/kill-all-buffers)

(defun my/kill-dired-buffers ()
  "Kill all dired buffers."
  (interactive)
  (mapc (lambda (buffer)
          (when (eq 'dired-mode (buffer-local-value 'major-mode buffer))
            (kill-buffer buffer)))
        (buffer-list)))

(defun my/kill-inner-word ()
  "Kills the entire word under cursor."
  (interactive)
  (forward-char 1)
  (backward-word)
  (kill-word 1))

(global-set-key (kbd "C-c w k") 'my/kill-inner-word)

(defun my/sudo-file-name (filename)
  "Prepend '/sudo:root@`system-name`:' to FILENAME if appropriate.
This is, when it doesn't already have a sudo-prefix."
  (if (not (or (string-prefix-p "/sudo:root@localhost:"
																filename)
							 (string-prefix-p (format "/sudo:root@%s:" (system-name))
																filename)))
			(format "/sudo:root@%s:%s" (system-name) filename)
    filename))

(defun my/sudo-save-buffer ()
  "Save FILENAME with sudo if the user approves."
  (interactive)
  (when buffer-file-name
    (let ((file (my/sudo-file-name buffer-file-name)))
			(if (yes-or-no-p (format "Save file as %s? " file))
					(write-file file)))))

(advice-add 'save-buffer :around
						'(lambda (fn &rest args)
							 (when (or (not (buffer-file-name))
												 (not (buffer-modified-p))
												 (file-writable-p (buffer-file-name))
												 (not (my/sudo-save-buffer)))
								 (call-interactively fn args))))

(defun my/xdg-open (&optional @fname)
  "Open the current file or dired marked files in external app."
  (interactive)
  (let* (($file-list
					(if @fname (progn (list @fname))
						(if (string-equal major-mode "dired-mode")
								(dired-get-marked-files)
							(list (buffer-file-name)))))
				 ($do-it-p (if (<= (length $file-list) 5)
											 t (y-or-n-p "Open more than 5 files? "))))
    (when $do-it-p
			(cond ((string-equal system-type "darwin")
						 (mapc
							(lambda ($fpath)
								(shell-command
								 (concat "open "
												 (shell-quote-argument $fpath))))  $file-list))
						((string-equal system-type "gnu/linux")
						 (mapc
							(lambda ($fpath) (let ((process-connection-type nil))
																 (start-process "" nil "xdg-open" $fpath))) $file-list))))))

(put 'dired-find-alternate-file 'disabled nil)

(setq-default dired-listing-switches "-alh")

(defun my/dired-find-file-other-frame ()
  "In Dired, visit this file or directory in another window."
  (interactive)
  (find-file-other-frame (dired-get-file-for-visit)))

(eval-after-load "dired"
  '(define-key dired-mode-map (kbd "C-c C-o") 'my/dired-find-file-other-frame))

(unless (package-installed-p 'exec-path-from-shell)
	(package-refresh-contents)
	(package-install 'exec-path-from-shell))

;; Safeguard, so this only runs on Linux (or MacOS)
(when (memq window-system '(mac ns x))
  (exec-path-from-shell-initialize))

(setq gc-cons-threshold 20000000)

(fset 'yes-or-no-p 'y-or-n-p)

(global-auto-revert-mode t)

(defvar my-term-shell "/bin/bash")
(defadvice ansi-term (before force-bash)
  (interactive (list my-term-shell)))
(ad-activate 'ansi-term)

(defun my/vsplit-last-buffer ()
	"Split frame vertically and open previous buffer in other window"
  (interactive)
  (split-window-vertically)
  (other-window 1 nil)
  (switch-to-next-buffer))

(defun my/hsplit-last-buffer ()
	"Split frame horizontally and open previous buffer in other
window"
  (interactive)
  (split-window-horizontally)
  (other-window 1 nil)
  (switch-to-next-buffer))

(defun my/open-last-buffer ()
	"Open previous buffer in new frame"
  (interactive)
  (switch-to-buffer-other-frame (other-buffer)))

(global-set-key (kbd "C-x 2") 'my/vsplit-last-buffer)
(global-set-key (kbd "C-x 3") 'my/hsplit-last-buffer)

(prefer-coding-system       'utf-8)
(set-terminal-coding-system 'utf-8)
(set-keyboard-coding-system 'utf-8)
(when (display-graphic-p)
  (setq x-select-request-type '(UTF8_STRING COMPOUND_TEXT TEXT STRING)))

(add-to-list 'default-frame-alist '(fullscreen . maximized))
(setq inhibit-startup-message t)
(setq initial-major-mode 'org-mode)
(setq initial-scratch-message "<s")

(use-package dracula-theme
	:config (load-theme 'dracula))

(add-to-list 'default-frame-alist '(font . "Victor Mono 14"))
(set-face-font 'variable-pitch "Inter")

(setq scroll-margin 10
scroll-step 1
scroll-conservatively 100
scroll-preserve-screen-position 1)

(setq mouse-wheel-follow-mouse 't)
(setq mouse-wheel-scroll-amount '(1 ((shift) . 1)))

(scroll-bar-mode -1)
;; (menu-bar-mode -1)
(tool-bar-mode -1)

(setq echo-keystrokes 0.1)

(show-paren-mode 1)

(electric-pair-mode 1)

(setq make-backup-files nil)

(setq backup-directory-alist
			`((".*" . ,temporary-file-directory)))
(setq auto-save-file-name-transforms
			`((".*" ,temporary-file-directory t)))

(put 'narrow-to-region 'disabled nil)

(setq-default tab-width 2
							intent-tabs-mode nil)

;;(setq js-indent-level 2)

;;(setq python-indent 2)

;;(setq css-indent-offset 2)

;;(setq web-mode-markup-indent-offset 2)

(setq require-final-newline t)

(add-hook 'write-file-hooks 'delete-trailing-whitespace)
