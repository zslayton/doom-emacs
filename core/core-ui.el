;; core-ui.el --- draw me like one of your French editors

(defvar doom-ui-fringe-size '3 "Default fringe width")

(defvar doom-ui-default-background "#333333"
  "The default frame background color.")

(defvar doom-ui-default-foreground "#CCCCCC"
  "The default frame foreground color.")

(setq bidi-display-reordering nil ; disable bidirectional text for tiny performance boost
      blink-matching-paren nil    ; don't blink--too distracting
      cursor-in-non-selected-windows nil  ; hide cursors in other windows
      frame-inhibit-implied-resize t
      ;; remove continuation arrow on right fringe
      fringe-indicator-alist (delq (assq 'continuation fringe-indicator-alist)
                                   fringe-indicator-alist)
      highlight-nonselected-window nil
      image-animate-loop t
      indicate-buffer-boundaries nil
      indicate-empty-lines nil
      max-mini-window-height 0.3
      mode-line-default-help-echo nil  ; disable mode-line mouseovers
      resize-mini-windows 'grow-only ; Minibuffer resizing
      show-help-function nil         ; hide :help-echo text
      show-paren-delay 0.075
      show-paren-highlight-openparen t
      show-paren-when-point-inside-paren t
      split-width-threshold nil      ; favor horizontal splits
      uniquify-buffer-name-style nil
      use-dialog-box nil             ; always avoid GUI
      visible-cursor nil
      x-stretch-cursor t
      ;; no beeping or blinking please
      ring-bell-function 'ignore
      visible-bell nil
      ;; Ask for confirmation on quit only if real buffers exist
      confirm-kill-emacs (lambda (_) (if (doom-real-buffers-list) (y-or-n-p "››› Quit?") t)))

(fset 'yes-or-no-p 'y-or-n-p) ; y/n instead of yes/no

;; auto-enabled in Emacs 25+; I'd rather enable it manually
(global-eldoc-mode -1)

;; show typed keystrokes in minibuffer
(setq echo-keystrokes 0.02)
;; ...but hide them while isearch is active
(@add-hook isearch-mode     (setq echo-keystrokes 0))
(@add-hook isearch-mode-end (setq echo-keystrokes 0.02))

;; A minor mode for toggling the mode-line
(defvar doom--hidden-modeline-format nil
  "The modeline format to use when `doom-hide-modeline-mode' is active. Don't
set this directly. Bind it in `let' instead.")
(defvar-local doom--old-modeline-format nil
  "The old modeline format, so `doom-hide-modeline-mode' can revert when it's
disabled.")
(define-minor-mode doom-hide-modeline-mode
  "Minor mode to hide the mode-line in the current buffer."
  :init-value nil
  :global nil
  (if doom-hide-modeline-mode
      (setq doom--old-modeline-format mode-line-format
            mode-line-format doom--hidden-modeline-format)
    (setq mode-line-format doom--old-modeline-format
          doom--mode-line nil))
  (force-mode-line-update))
;; Ensure major-mode or theme changes don't overwrite these variables
(put 'doom--old-modeline 'permanent-local t)
(put 'doom-hide-modeline-mode 'permanent-local t)


;;
;; Bootstrap
;;

(tooltip-mode -1) ; relegate tooltips to echo area only
(menu-bar-mode -1)
(when (display-graphic-p)
  (scroll-bar-mode -1)
  (tool-bar-mode -1)
  ;; buffer name  in frame title
  (setq-default frame-title-format '("%b"))
  ;; standardize fringe width
  (fringe-mode doom-ui-fringe-size)
  (setq default-frame-alist
        (append `((left-fringe  . ,doom-ui-fringe-size)
                  (right-fringe . ,doom-ui-fringe-size)
                  (background-color . ,doom-ui-default-background)
                  (foreground-color . ,doom-ui-default-foreground))
                default-frame-alist))
  ;; no fringe in the minibuffer
  (@add-hook (emacs-startup minibuffer-setup)
    (set-window-fringes (minibuffer-window) 0 0 nil)))


;;
;; Plugins
;;

;; I modified the built-in `hideshow' package to enable itself when needed. A
;; better, more vim-like code-folding plugin would be the `origami' plugin, but
;; until certain breaking bugs are fixed in it, I won't switch over.
(@def-package hideshow ; built-in
  :commands (hs-minor-mode hs-toggle-hiding hs-already-hidden-p)
  :init
  (defun doom*autoload-hideshow ()
    (unless (bound-and-true-p hs-minor-mode)
      (hs-minor-mode 1)))
  (advice-add 'evil-toggle-fold :before 'doom*autoload-hideshow))

;; Show uninterrupted indentation markers with some whitespace voodoo.
(@def-package highlight-indent-guides
  :commands highlight-indent-guides-mode
  :config
  (setq highlight-indent-guides-method 'character)

  (defun doom|inject-trailing-whitespace (&optional start end)
    "The opposite of `delete-trailing-whitespace'. Injects whitespace into
buffer so that `highlight-indent-guides-mode' will display uninterrupted indent
markers. This whitespace is stripped out on save, as not to affect the resulting
file."
    (interactive (progn (barf-if-buffer-read-only)
                        (if (use-region-p)
                            (list (region-beginning) (region-end))
                          (list nil nil))))
    (unless indent-tabs-mode
      (save-match-data
        (save-excursion
          (let ((end-marker (copy-marker (or end (point-max))))
                (start (or start (point-min))))
            (goto-char start)
            (while (and (re-search-forward "^$" end-marker t) (not (>= (point) end-marker)))
              (let (line-start line-end next-start next-end)
                (save-excursion
                  ;; Check previous line indent
                  (forward-line -1)
                  (setq line-start (point)
                        line-end (save-excursion (back-to-indentation) (point)))
                  ;; Check next line indent
                  (forward-line 2)
                  (setq next-start (point)
                        next-end (save-excursion (back-to-indentation) (point)))
                  ;; Back to origin
                  (forward-line -1)
                  ;; Adjust indent
                  (let* ((line-indent (- line-end line-start))
                         (next-indent (- next-end next-start))
                         (indent (min line-indent next-indent)))
                    (insert (make-string (if (zerop indent) 0 (1+ indent)) ? )))))
              (forward-line 1)))))
      (set-buffer-modified-p nil))
    nil)

  (@add-hook highlight-indent-guides-mode
    (if highlight-indent-guides-mode
        (progn
          (doom|inject-trailing-whitespace)
          (add-hook 'after-save-hook 'doom|adjust-indent-guides nil t))
      (remove-hook 'after-save-hook 'doom|adjust-indent-guides t)
      (delete-trailing-whitespace))))

;; Some modes don't adequately highlight numbers, therefore...
(@def-package highlight-numbers :commands highlight-numbers-mode)

;; Line highlighting
(@def-package hl-line ; built-in
  :init
  ;; stickiness doesn't play nice with emacs 25+
  (setq hl-line-sticky-flag nil
        global-hl-line-sticky-flag nil))

;; Line number column. A faster (or equivalent, in the worst case) line number
;; plugin than the built-in `linum'.
(@def-package nlinum
  :commands nlinum-mode
  :preface (defvar nlinum-format "%4d ")
  :init
  (@add-hook
    (markdown-mode prog-mode scss-mode web-mode conf-mode groovy-mode
     nxml-mode snippet-mode php-mode)
    'nlinum-mode)

  :config
  ;; Optimization: calculate line number column width beforehand
  (@add-hook nlinum-mode
    (setq nlinum--width (length (save-excursion (goto-char (point-max))
                                                (format-mode-line "%l")))))

  ;; Disable nlinum explicitly before making a frame, otherwise nlinum throws
  ;; linum face errors that prevent the frame from spawning.
  (@add-hook '(before-make-frame-hook after-make-frame-functions)
    (nlinum-mode -1)))

;; Helps us distinguish stacked delimiter pairs. Especially in parentheses-drunk
;; languages like Lisp.
(@def-package rainbow-delimiters
  :commands rainbow-delimiters-mode
  :config (setq rainbow-delimiters-max-face-count 3)
  :init
  (@add-hook (emacs-lisp-mode lisp-mode js-mode css-mode c-mode-common)
    'rainbow-delimiters-mode))


;;
;; Modeline
;;

;; TODO Improve docstrings
(defmacro @def-modeline-segment (name &rest forms)
  "Defines a modeline segment function and byte compiles it."
  (declare (indent defun) (doc-string 2))
  `(defun ,(intern (format "doom-modeline-segment--%s" name)) ()
     ,@forms))

(defsubst doom--prepare-modeline-segments (segments)
  (-non-nil
   (--map (if (stringp it)
              it
            (list (intern (format "doom-modeline-segment--%s" (symbol-name it)))))
          segments)))

(defmacro @def-modeline (name lhs &optional rhs)
  "Defines a modeline format and byte-compiles it.

Example:
   (@def-modeline minimal
     (bar matches \" \" buffer-info)
     (media-info major-mode))
   (setq-default mode-line-format (doom-modeline 'minimal))"
  (let ((sym (intern (format "doom-modeline-format--%s" name)))
        (lhs-forms (doom--prepare-modeline-segments lhs))
        (rhs-forms (doom--prepare-modeline-segments rhs)))
    (prog1
        `(progn
           (defun ,sym ()
             (let ((lhs (list ,@lhs-forms))
                   (rhs (list ,@rhs-forms)))
               (list lhs
                     (propertize
                      " " 'display
                      `((space :align-to (- (+ right right-fringe right-margin)
                                            ,(+ 1 (string-width (format-mode-line rhs)))))))
                     rhs)))
           ,(unless (bound-and-true-p byte-compile-current-file)
              `(let (byte-compile-warnings)
                 (byte-compile ',sym)))))))

(defun doom-modeline (key)
  "TODO"
  (let ((fn (intern (format "doom-modeline-format--%s" key))))
    (unless (functionp fn)
      (error "Modeline format doesn't exist: %s" key))
    `(:eval (,fn))))

(provide 'core-ui)
;;; core-ui.el ends here
