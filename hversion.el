;;; hversion.el --- GNU Hyperbole version and system information setup  -*- lexical-binding: t; -*-
;;
;; Author:       Bob Weiner
;; Maintainer:   Bob Weiner, Mats Lidell
;;
;; Orig-Date:     1-Jan-94
;; Last-Mod:     25-Jun-23 at 10:11:43 by Mats Lidell
;;
;; SPDX-License-Identifier: GPL-3.0-or-later
;;
;; Copyright (C) 1994-2022  Free Software Foundation, Inc.
;; See the "HY-COPY" file for license information.
;;
;; This file is part of GNU Hyperbole.

;;; Commentary:

;;; Code:
;;; ************************************************************************
;;; Other required Elisp libraries
;;; ************************************************************************

(require 'hload-path)

;;; ************************************************************************
;;; Public variables
;;; ************************************************************************

(defconst hyperb:version "8.0.1pre" "GNU Hyperbole revision number.")


(defvar hyperb:mouse-buttons
  (if (or (and hyperb:microsoft-os-p (not (memq window-system '(w32 w64 x))))
	  (memq window-system '(ns dps)))
      2 3)
  "Number of live buttons available on the mouse.
Override this if the system-computed default is incorrect for
your specific mouse.")

;;; ************************************************************************
;;; Public declarations
;;; ************************************************************************
(declare-function br-to-view-window "ext:br")

;;; ************************************************************************
;;; Support functions
;;; ************************************************************************

(defun hyperb:window-sys-term (&optional frame)
  "Return first part of the term-type if running under a window system, else nil.
Where a part in the term-type is delimited by a `-' or  an `_'."
  (unless frame (setq frame (selected-frame)))
  (let* ((display-type window-system)
	 (term (cond ((or (memq display-type '(x gtk mswindows win32 w32 ns dps pm))
			  ;; May be a graphical client spawned from a
			  ;; dumb terminal Emacs, e.g. under X, so if
			  ;; the selected frame has mouse support,
			  ;; then there is a window system to support.
			  (display-mouse-p))
		      ;; X11, macOS, NEXTSTEP (DPS), or OS/2 Presentation Manager (PM)
		      "emacs")
		     ;; Keep NeXT as basis for 2-button mouse support
		     ((or (featurep 'eterm-fns)
			  (equal (getenv "TERM") "NeXT")
			  (equal (getenv "TERM") "eterm"))
		      ;; NEXTSTEP add-on support to Emacs
		      "next"))))
    (set-frame-parameter frame 'hyperb:window-system term)
    term))

(defun hyperb:window-system (&optional frame)
  "Return name of window system or term type where the selected FRAME is running.
If nil after system initialization, no window system or mouse
support is available."
  (unless frame (setq frame (selected-frame)))
  (frame-parameter frame 'hyperb:window-system))

;; Each frame could be on a different window system when under a
;; client-server window system, so set `hyperb:window-system'  for
;; each frame.
(mapc #'hyperb:window-sys-term (frame-list))
;; Ensure this next hook is appended so that if follows the hook that
;; selects the new frame.
(add-hook 'after-make-frame-functions #'hyperb:window-sys-term t)

;;; ************************************************************************
;;; Public functions used by pulldown and popup menus
;;; ************************************************************************

(if (not (fboundp 'id-browse-file))
(defalias 'id-browse-file 'view-file))

(unless (fboundp 'id-info)
(defun id-info (string)
  (if (stringp string)
      (progn (let ((wind (get-buffer-window "*info*")))
	       (cond (wind (select-window wind))
		     ((br-in-browser) (br-to-view-window))
		     (t (hpath:display-buffer (other-buffer)))))
	     ;; Force execution of Info-mode-hook which adds the
	     ;; Hyperbole man directory to Info-directory-list.
	     (info)
	     (condition-case ()
		 (Info-goto-node string)
	       ;; If not found as a node, try as an index item.
	       (error (id-info-item string))))
    (error "(id-info): Invalid Info argument, `%s'" string))))

(unless (fboundp 'id-info-item)
(defun id-info-item (index-item)
  (if (stringp index-item)
      (progn (let ((wind (get-buffer-window "*info*")))
	       (cond (wind (select-window wind))
		     ((br-in-browser) (br-to-view-window))
		     (t (hpath:display-buffer (other-buffer)))))
	     ;; Force execution of Info-mode-hook which adds the
	     ;; Hyperbole man directory to Info-directory-list.
	     (info)
	     (if (string-match "^(\\([^)]+\\))\\(.*\\)" index-item)
		 (let ((file (match-string-no-properties 1 index-item))
		       (item-name (match-string-no-properties 2 index-item)))
		   (if (and file (setq file (hpath:substitute-value file)))
		       (progn (Info-goto-node (concat "(" file ")"))
			      (Info-index item-name))
		     (Info-goto-node "(hyperbole)")
		     (Info-index index-item))
		   ;; Index may point to indented line immediately
		   ;; after the non-indented item definition line. If
		   ;; so, move back a line.
		   (when (and (looking-at "^[ \t]")
			      (looking-back "^[^ \t].*[\n\r]+" nil))
		     (forward-line -1))
		   (recenter 0))
	       (error "(id-info-item): Invalid Info index item: `%s'" index-item)))
    (error "(id-info-item): Info index item must be a string: `%s'" index-item))))

(if (not (fboundp 'id-tool-quit))
(defalias 'id-tool-quit #'eval))

(if (not (fboundp 'id-tool-invoke))
(defun id-tool-invoke (sexp)
  (if (commandp sexp)
      (call-interactively sexp)
    (funcall sexp))))

(provide 'hversion)

;;; hversion.el ends here
