;;; hui-em-but.el --- GNU Emacs button highlighting and flashing support -*- lexical-binding: t; -*-
;;
;; Author:       Bob Weiner
;;
;; Orig-Date:    21-Aug-92
;; Last-Mod:      9-Apr-23 at 03:22:01 by Bob Weiner
;;
;; SPDX-License-Identifier: GPL-3.0-or-later
;;
;; Copyright (C) 1992-2022  Free Software Foundation, Inc.
;; See the "HY-COPY" file for license information.
;;
;; This file is part of GNU Hyperbole.

;;; Commentary:
;;
;;   Can't use read-only buttons here because then outline-mode
;;   becomes unusable.

;;; Code:

(when noninteractive
  ;; Don't load this library
  (with-current-buffer " *load*"
    (goto-char (point-max))))

;;; ************************************************************************
;;; Other required Elisp libraries
;;; ************************************************************************

(require 'hload-path)
(require 'custom) ;; For defface.
(require 'hbut)
(eval-when-compile (require 'hyrolo))

;;; ************************************************************************
;;; Public variables
;;; ************************************************************************

(defcustom hproperty:but-highlight-flag t
"*Non-nil (default) applies `hproperty:but-face' highlight to labeled Hyperbole buttons."
  :type 'boolean
  :group 'hyperbole-buttons)

(defcustom hproperty:but-emphasize-flag nil
  "*Non-nil means visually emphasize that button under mouse cursor is selectable."
  :type 'boolean
  :group 'hyperbole-buttons)

(defcustom hproperty:but-flash-time 1000
  "*Emacs button flash delay."
  :type '(integer :match (lambda (_widget value) (and (integerp value) (> value 0))))
  :group 'hyperbole-buttons)
(make-obsolete-variable 'hproperty:but-flash-time "Use `hproperty:but-flash-time-seconds' instead" "8.0")

(defcustom hproperty:but-flash-time-seconds 0.05
  "*Emacs button flash delay."
  :type 'float
  :group 'hyperbole-buttons)

(defface hbut-flash
  '((((class color) (min-colors 88) (background light))
     :background "red3")
    (((class color) (min-colors 88) (background dark))
     :background "red3")
    (((class color) (min-colors 16) (background light))
     :background "red3")
    (((class color) (min-colors 16) (background dark))
     :background "red3")
    (((class color) (min-colors 8))
     :background "red3" :foreground "black")
    (t :inverse-video t))
  "Face for flashing buttons."
  :group 'hyperbole-buttons)

(defcustom hproperty:flash-face 'hbut-flash
  "Hyperbole face for flashing hyper-buttons."
  :type 'face
  :initialize #'custom-initialize-default
  :group 'hyperbole-buttons)

(defcustom hproperty:highlight-face 'highlight
  "Item highlighting face."
  :type 'face
  :initialize #'custom-initialize-default
  :group 'hyperbole-buttons)

(defface hbut-face
  '((((min-colors 88) (background dark)) (:foreground "salmon1"))
    (((background dark)) (:background "red" :foreground "black"))
    (((min-colors 88)) (:foreground "salmon4"))
    (t (:background "red")))
  "Face for explicit Hyperbole buttons."
  :group 'hyperbole-buttons)

(defcustom hproperty:but-face 'hbut-face
  "Hyperbole face for explicit buttons."
  :type 'face
  :initialize #'custom-initialize-default
  :group 'hyperbole-buttons)

(defface hbut-item-face
  '((((class color) (min-colors 88) (background light))
     :background "yellow")
    (((class color) (min-colors 88) (background dark))
     :background "yellow")
    (((class color) (min-colors 16) (background light))
     :background "yellow")
    (((class color) (min-colors 16) (background dark))
     :background "yellow")
    (((class color) (min-colors 8))
     :background "yellow" :foreground "black")
    (t :inverse-video t))
  "Face for Hyperbole list buttons."
  :group 'hyperbole-buttons)

(defcustom hproperty:item-face 'hbut-item-face
  "Hyperbole face for list hyper-buttons."
  :type 'face
  :initialize #'custom-initialize-default
  :group 'hyperbole-buttons)

(defface ibut-face
  '((((min-colors 88) (background dark)) (:foreground "rosybrown"))
    (((background dark)) (:background "rosybrown" :foreground "black"))
    (((min-colors 88)) (:foreground "rosybrown"))
    (t (:background "rosybrown")))
  "Face for implicit Hyperbole buttons."
  :group 'hyperbole-buttons)

(defcustom hproperty:ibut-face 'ibut-face
  "Hyperbole face for implicit buttons."
  :type 'face
  :initialize #'custom-initialize-default
  :group 'hyperbole-buttons)

;;; ************************************************************************
;;; Public functions
;;; ************************************************************************

;; Support NEXTSTEP and X window systems.
(and (not (fboundp 'display-color-p))
     (fboundp 'x-display-color-p)
     (defalias 'display-color-p 'x-display-color-p))

(defun hproperty:but-add (start end face)
  "Add between START and END a button using FACE in current buffer.
If `hproperty:but-emphasize-flag' is non-nil when this is called, emphasize
that button is selectable whenever the mouse cursor moves over it."
  (let ((but (make-overlay start end nil t)))
    (overlay-put but 'face face)
    (when hproperty:but-emphasize-flag (overlay-put but 'mouse-face 'highlight))))

(defun hproperty:but-clear (&optional face)
  "Remove optional Hyperbole button FACE from current buffer.
If FACE is nil, remove the explicit butotn face."
  (interactive)
  (let ((start (point-min)))
    (while (< start (point-max))
      (mapc (lambda (props)
	      (when (eq (overlay-get props 'face) (or face hproperty:but-face))
		(delete-overlay props)))
	    (overlays-at start))
      (setq start (next-overlay-change start)))))

(defun hproperty:but-create (&optional regexp-match)
  "Highlight all named Hyperbole buttons in buffer.
If REGEXP-MATCH is non-nil, only buttons matching this argument are
highlighted (all others are unhighlighted).

If `hproperty:but-emphasize-flag' is non-nil when this is called, emphasize
that button is selectable whenever the mouse cursor moves over it."
  (interactive)
  (hproperty:but-clear hproperty:but-face)
  (hproperty:but-clear hproperty:ibut-face)
  (hproperty:but-create-all regexp-match))

(defun hproperty:but-create-all (&optional regexp-match)
  "Mark all labeled Hyperbole buttons in buffer for later highlighting.
If REGEXP-MATCH is non-nil, only buttons matching this argument are
highlighted."
  (when hproperty:but-highlight-flag
    (ebut:map (lambda (_lbl start end)
		(hproperty:but-add start end hproperty:but-face))
	      regexp-match 'include-delims)
    (ibut:map (lambda (_lbl start end)
		(hproperty:but-add start end hproperty:ibut-face))
	      regexp-match 'include-delims)))

(defun hproperty:but-create-on-yank (_prop-value start end)
  (save-restriction
    (narrow-to-region start end)
    (hproperty:but-create-all)))

(add-to-list 'yank-handled-properties '(hproperty:but-face . hproperty:but-create-on-yank))

(defun hproperty:but-delete (&optional pos)
  (let ((but (hproperty:but-get pos)))
    (when but (delete-overlay but))))

;;; ************************************************************************
;;; Private functions
;;; ************************************************************************

(defun hproperty:but-get (&optional pos)
  (car (delq nil
	     (mapcar (lambda (props)
		       (if (memq (overlay-get props 'face)
				 (list hproperty:but-face
				       hproperty:flash-face))
			   props))
		     (overlays-at (or pos (point)))))))

(defsubst hproperty:list-cycle (list-ptr list)
  "Move LIST-PTR to next element in LIST or when at end to first element."
  (or (and list-ptr (setq list-ptr (cdr list-ptr)))
      (setq list-ptr list)))

;;; ************************************************************************
;;; Private variables
;;; ************************************************************************

(defconst hproperty:color-list
  (when (display-color-p)
    (defined-colors)))

(defvar hproperty:color-ptr nil
  "Pointer to current color name table to use for Hyperbole buttons.")

(defconst hproperty:good-colors
  (if (display-color-p)
      '(
	"medium violet red" "indianred4" "firebrick1" "DarkGoldenrod"
	"NavyBlue" "darkorchid" "tomato3" "mediumseagreen" "deeppink"
	"forestgreen" "mistyrose4" "slategrey" "purple4" "dodgerblue3"
	"mediumvioletred" "lightsalmon3" "orangered2" "turquoise4" "Gray55")
    hproperty:color-list)
  "Good colors for contrast against wheat background and black foreground.")


;;; ************************************************************************
;;; Public functions
;;; ************************************************************************

(defun hproperty:cycle-but-color (&optional color)
  "Switch button color.
Set color to optional COLOR name or next item referenced by
hproperty:color-ptr."
  (interactive "sHyperbole button color: ")
  (when (display-color-p)
    (when color (setq hproperty:color-ptr nil))
    (set-face-foreground
     hproperty:but-face (or color (car (hproperty:list-cycle hproperty:color-ptr hproperty:good-colors))))
    (redisplay t)
    t))

(defun hproperty:but-p (&optional pos)
  "Return non-nil at point or optional POS iff on a highlighted Hyperbole button."
  (memq t (mapcar (lambda (props)
		    (when (memq (overlay-get props 'face)
				(list hproperty:but-face hproperty:ibut-face))
		      t))
		  (overlays-at (or pos (point))))))

(defun hproperty:set-but-face (pos face)
  (let ((but (hproperty:but-get pos)))
    (when but (overlay-put but 'face face))))

(defun hproperty:but-flash ()
  "Flash a Hyperbole button at or near point to indicate selection."
  (interactive)
  (let* ((categ (hattr:get 'hbut:current 'categ))
	 (start (hattr:get 'hbut:current 'lbl-start))
	 (end   (hattr:get 'hbut:current 'lbl-end))
	 (categ-face (if (eq categ 'explicit)
			 hproperty:but-face
		       hproperty:ibut-face))
	 but-face
	 ibut
	 prev)
    (if (and start end (setq prev (hproperty:but-p start)
			     ibut t))
	(unless prev
	  (hproperty:but-add start end categ-face))
      (setq start (point)))
    (when (setq but-face (when (hproperty:but-p start) categ-face))
      (unwind-protect
	  (progn
	    (hproperty:set-but-face start hproperty:flash-face)
	    (sit-for hproperty:but-flash-time-seconds)) ;; Force display update
	(hproperty:set-but-face start but-face)
	(redisplay t)))
    (and ibut (not prev) (hproperty:but-delete start))))

(defun hproperty:select-item (&optional pnt)
  "Select item in current buffer at optional position PNT with hproperty:item-face."
  (when pnt (goto-char pnt))
  (skip-chars-forward " \t")
  (skip-chars-backward "^ \t\n\r")
  (let ((start (point)))
    (save-excursion
      (skip-chars-forward "^ \t\n\r")
      (hproperty:but-add start (point) hproperty:item-face)))
  (sit-for 0))  ;; Force display update

(defun hproperty:select-line (&optional pnt)
  "Select line in current buffer at optional position PNT with hproperty:item-face."
  (when pnt (goto-char pnt))
  (save-excursion
    (beginning-of-line)
    (hproperty:but-add (point) (progn (end-of-line) (point)) hproperty:item-face))
  (sit-for 0))  ;; Force display update

;;; ************************************************************************
;;; Private variables
;;; ************************************************************************

(defvar hproperty:item-button nil
  "Button used to highlight an item in a listing buffer.")
(make-variable-buffer-local 'hproperty:item-button)

(provide 'hui-em-but)

;;; hui-em-but.el ends here
