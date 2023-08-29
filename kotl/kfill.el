;;; kfill.el --- Fill and justify koutline cells  -*- lexical-binding: t; -*-
;;
;; Author:       Bob Weiner
;;
;; Orig-Date:    23-Jan-94
;; Last-Mod:      8-Aug-23 at 23:10:00 by Bob Weiner
;;
;; SPDX-License-Identifier: GPL-3.0-or-later
;;
;; Copyright (C) 1994-2021  Free Software Foundation, Inc.
;; See the "../HY-COPY" file for license information.
;;
;; This file is part of GNU Hyperbole.
;; It was originally adapted from Kyle Jones' filladapt library.

;;; Commentary:

;;; Code:

;;; ************************************************************************
;;; Public variables
;;; ************************************************************************

(defvar kfill:prefix-table
  '(
    ;; Lists with hanging indents, e.g.
    ;; 1. xxxxx   or   1)  xxxxx   etc.
    ;;    xxxxx            xxx
    ;;
    ;; Be sure pattern does not match to:  (last word in parens starts
    ;; newline)
    (" *(?\\([0-9][0-9a-z.]*\\|[a-z][0-9a-z.]\\)) +" . kfill:hanging-list)
    (" *\\([0-9]+[a-z.]+[0-9a-z.]*\\|[0-9]+\\|[a-z]\\)\\([.>] +\\|  +\\)"
     . kfill:hanging-list)
    ;; Included text in news or mail replies
    ("[ \t]*\\(>+ *\\)+" . kfill:normal-included-text)
    ;; Included text generated by SUPERCITE.  We can't hope to match all
    ;; the possible variations, your mileage may vary.
    ("[ \t]*[A-Za-z0-9][^'`\"< \t\n\r]*>[ \t]*" . kfill:supercite-included-text)
    ;; Lisp comments
    ("[ \t]*\\(;+[ \t]*\\)+" . kfill:lisp-comment)
    ;; UNIX shell comments
    ("[ \t]*\\(#+[ \t]*\\)+" . kfill:sh-comment)
    ;; Postscript comments
    ("[ \t]*\\(%+[ \t]*\\)+" . kfill:postscript-comment)
    ;; C++ comments
    ("[ \t]*//[/ \t]*" . kfill:c++-comment)
    ("[?!~*+ -]+ " . kfill:hanging-list)
    ;; This keeps normal paragraphs from interacting unpleasantly with
    ;; the types given above.
    ("[^ \t/#%?!~*+-]" . kfill:normal))
"Value is an alist of the form

   ((REGXP . FUNCTION) ...)

When `fill-paragraph' is called, the REGEXP of each alist element is compared
with the beginning of the current line.  If a match is found the corresponding
FUNCTION is called.  FUNCTION is called with one argument, which is non-nil
when invoked on the behalf of `fill-paragraph'.  It is the job of FUNCTION to
set the values of the paragraph-* variables (or set a clipping region, if
paragraph-start and paragraph-separate cannot be made discerning enough) so
that `fill-paragraph' works correctly in various contexts.")

;;; ************************************************************************
;;; Private variables
;;; ************************************************************************

(defconst kfill:hanging-expression
  (cons 'or
	(delq nil (mapcar (lambda (pattern-type)
			    (when (eq (cdr pattern-type) 'kfill:hanging-list)
			      (list 'looking-at (car pattern-type))))
			  kfill:prefix-table)))
  "Conditional expression used to test for hanging indented lists.")

(defvar prior-fill-prefix nil
  "Prior string inserted at front of new line during filling, or nil for none.
Setting this variable automatically makes it local to the current buffer.")
(make-variable-buffer-local 'prior-fill-prefix)

;;; ************************************************************************
;;; Public functions
;;; ************************************************************************

(defun kfill:forward-line (&optional n)
  "Move N lines forward (backward if N is negative) to the start of line.
If there isn’t room, go as far as possible (no error).

Return the count of lines left to move.  If moving forward, that is N minus
the number of lines moved; if backward, N plus the number moved.

  Always return 0."
  (unless (integerp n)
    (setq n 1))
  (let ((start-line (line-number-at-pos)))
    (forward-visible-line n)
    (unless (< n 0)
      (skip-chars-forward "\n\r"))
    (if (>= n 0)
	(- n (min n (- (line-number-at-pos) start-line)))
      (- n (max n (- (line-number-at-pos) start-line))))))

(defun kfill:do-auto-fill ()
  "Kotl-mode auto-fill function.  Return t if any filling is done."
  (save-restriction
    (if (null fill-prefix)
	(let ((paragraph-ignore-fill-prefix nil)
	      ;; Need this or Emacs ignores fill-prefix when inside a
	      ;; comment.
	      (comment-multi-line t)
	      (fill-paragraph-handle-comment t)
	      fill-prefix)
	  (kfill:adapt nil)
	  (do-auto-fill))
      (do-auto-fill))))

(defun kfill:fill-paragraph (&optional arg skip-prefix-remove)
  "Fill paragraph at or after point when in kotl-mode.
Prefix ARG means justify as well.  If SKIP-PREFIX-REMOVE is not
nil, keep the paragraph prefix."
  (interactive (progn
		 (barf-if-buffer-read-only)
		 (list (when current-prefix-arg 'full) nil)))
  ;; This may be called from `fill-region-as-paragraph' in "filladapt.el"
  ;; which narrows the region to the current paragraph.  A side-effect is
  ;; that the cell identifier and indent information needed by this function
  ;; when in kotl-mode is no longer visible.  So we temporarily rewiden the
  ;; buffer here.  Don't rewiden past the paragraph of interest or any
  ;; following blank line may be removed by the filling routines.
  (save-restriction
    (when (eq major-mode 'kotl-mode)
      (narrow-to-region 1 (point-max)))
    ;; Emacs expects a specific symbol here.
    (when (and arg (not (symbolp arg))) (setq arg 'full))
    (or skip-prefix-remove (kfill:remove-paragraph-prefix))
    (catch 'done
      (unless fill-prefix
	(let ((paragraph-ignore-fill-prefix nil)
	      ;; Need this or Emacs ignores fill-prefix when
	      ;; inside a comment.
	      (comment-multi-line t)
	      (fill-paragraph-handle-comment t)
	      (paragraph-start paragraph-start)
	      (paragraph-separate paragraph-separate)
	      fill-prefix)
	  (when (kfill:adapt t)
	    (throw 'done (fill-paragraph arg)))))
      ;; Kfill:adapt failed or fill-prefix is set, so do a basic
      ;; paragraph fill as adapted from par-align.el.
      (kfill:fallback-fill-paragraph arg skip-prefix-remove))))

;;;
;;; Redefine this built-in function so that it sets `prior-fill-prefix' also.
;;;
(defun set-fill-prefix (&optional turn-off)
  "Set `fill-prefix' to the current line up to point.
Remove it if optional TURN-OFF flag is non-nil.  Also sets
`prior-fill-prefix' to the previous value of `fill-prefix'.
Filling removes any prior fill prefix, adjusts line lengths and
then adds the fill prefix at the beginning of each line."
  (interactive)
  (setq prior-fill-prefix fill-prefix)
  (let ((left-margin-pos (save-excursion (move-to-left-margin) (point))))
    (setq fill-prefix
          (when (> (point) left-margin-pos)
            (unless turn-off
	      (buffer-substring left-margin-pos (point))))))
  (when (equal prior-fill-prefix "")
    (setq prior-fill-prefix nil))
  (when (equal fill-prefix "")
    (setq fill-prefix nil))
  (cond (fill-prefix
	 (message "fill-prefix: \"%s\"; prior-fill-prefix: \"%s\""
		  fill-prefix (or prior-fill-prefix "")))
	(prior-fill-prefix
	 (message "fill-prefix cancelled; prior-fill-prefix: \"%s\""
		  prior-fill-prefix))
	(t (message "fill-prefix and prior-fill-prefix cancelled"))))

;;; ************************************************************************
;;; Private functions
;;; ************************************************************************

(defun kfill:adapt (paragraph)
  (let ((table kfill:prefix-table)
	case-fold-search
	success )
    (save-excursion
      (beginning-of-line)
      (while table
	(if (not (looking-at (car (car table))))
	    (setq table (cdr table))
	  (funcall (cdr (car table)) paragraph)
	  (setq success t table nil))))
    success ))

(defun kfill:c++-comment (paragraph)
  (setq fill-prefix (buffer-substring (match-beginning 0) (match-end 0)))
  (when paragraph
    (setq paragraph-separate "^[^ \t/]")))

(defun kfill:fallback-fill-paragraph (justify-flag &optional leave-prefix)
  (save-excursion
    (end-of-line)
    ;; Backward to para begin
    (when (re-search-backward (concat "\\`\\|" paragraph-separate) nil t)
      (kfill:forward-line 1)
      (let* ((region-start (point))
	     (filladapt-mode
	      (if prior-fill-prefix
		  ;; filladapt-mode must be disabled for this command or it
		  ;; will override the removal of prior-fill-prefix.
		  nil
		(or (when (boundp 'filladapt-mode)
		      filladapt-mode)
		    adaptive-fill-mode)))
	     (adaptive-fill-mode filladapt-mode)
	     from)
	(kfill:forward-line -1)
	(setq from (point))
	(forward-paragraph)
	;; Forward to real paragraph end
	(when (re-search-forward (concat "\\'\\|" paragraph-separate) nil t)
	  (unless (= (point) (point-max))
	    (beginning-of-line))
	  (unless leave-prefix
	    ;; Remove any leading occurrences of `prior-fill-prefix'.
	    (kfill:replace-string prior-fill-prefix "" nil region-start (point)))
	  (or (and fill-paragraph-function
		   (not (eq fill-paragraph-function t))
		   (let ((func fill-paragraph-function)
			 fill-paragraph-function)
		     (goto-char region-start)
		     (funcall func justify-flag)))
	      (fill-region-as-paragraph from (point) justify-flag)))))))

(defun kfill:hanging-list (paragraph)
  (let (prefix match beg end)
    (setq prefix (make-string (- (match-end 0) (match-beginning 0)) ?\ ))
    (when paragraph
      (setq match (buffer-substring (match-beginning 0) (match-end 0)))
      (if (string-match "^ +$" match)
	  (save-excursion
	    (while (and (not (bobp)) (looking-at prefix))
	      (kfill:forward-line -1))

	    (cond ((eval kfill:hanging-expression)
		   ;; Point is in front of a hanging list.
		   (setq beg (point)))
		  (t (setq beg (progn (kfill:forward-line 1) (point))))))
	(setq beg (point)))
      (save-excursion
	(kfill:forward-line)
	(while (and (looking-at prefix)
		    (not (equal (char-after (match-end 0)) ?\ )))
	  (kfill:forward-line))
	(setq end (point)))
      (narrow-to-region beg end))
    (setq fill-prefix prefix)))

(defun kfill:lisp-comment (paragraph)
  (setq fill-prefix (buffer-substring (match-beginning 0) (match-end 0)))
  (when paragraph
    (setq paragraph-separate
	  (concat "^" fill-prefix " *;\\|^"
		  (kfill:negate-string fill-prefix)))))

(defun kfill:negate-string (string)
  (let ((len (length string))
	(i 0) string-list)
    (setq string-list (cons "\\(" nil))
    (while (< i len)
      (setq string-list
	    (cons (if (= i (1- len)) "" "\\|")
		  (cons "]"
			(cons (substring string i (1+ i))
			      (cons "[^"
				    (cons (regexp-quote (substring string 0 i))
					  string-list)))))
	    i (1+ i)))
    (setq string-list (cons "\\)" string-list))
    (apply 'concat (nreverse string-list))))

(defun kfill:normal (paragraph)
  (when paragraph
    (setq paragraph-separate
	  (concat paragraph-separate "\\|^[ \t/#%?!~*+-]"))))

(defun kfill:normal-included-text (paragraph)
  (setq fill-prefix (buffer-substring (match-beginning 0) (match-end 0)))
  (when paragraph
    (setq paragraph-separate
	  (concat "^" fill-prefix " *>\\|^"
		  (kfill:negate-string fill-prefix)))))

(defun kfill:postscript-comment (paragraph)
  (setq fill-prefix (buffer-substring (match-beginning 0) (match-end 0)))
  (when paragraph
    (setq paragraph-separate
	  (concat "^" fill-prefix " *%\\|^"
		  (kfill:negate-string fill-prefix)))))

(defun kfill:remove-paragraph-prefix (&optional indent-str)
  "Remove fill prefix from current paragraph."
  (save-excursion
    (end-of-line)
    ;; Backward to para begin
    (re-search-backward (concat "\\`\\|" paragraph-separate))
    (kfill:forward-line 1)
    (let ((region-start (point)))
      (kfill:forward-line -1)
      (forward-paragraph)
      ;; Forward to real paragraph end
      (re-search-forward (concat "\\'\\|" paragraph-separate))
      (or (= (point) (point-max)) (beginning-of-line))
      (kfill:replace-string (or fill-prefix prior-fill-prefix)
				(if (eq major-mode 'kotl-mode)
				    (or indent-str
					(make-string (kcell-view:indent) ?  ))
				  "")
				nil region-start (point)))))

(defun kfill:replace-string (fill-str-prev fill-str &optional suffix start end)
  "Replace whitespace separated FILL-STR-PREV with FILL-STR.
Optional SUFFIX non-nil means replace at ends of lines, default is beginnings.
Optional arguments START and END specify the replace region, default is the
current region."
  (when fill-str-prev
    (if start
	(let ((s (min start end)))
	  (setq end (max start end)
		start s))
      (setq start (region-beginning)
	    end (region-end)))
    (unless fill-str (setq fill-str ""))
    (save-excursion
      (save-restriction
	(narrow-to-region start end)
	(goto-char (point-min))
	(let ((prefix
	       (concat
		(unless suffix "^")
		"[ \t]*"
		(regexp-quote
		 ;; Get non-whitespace separated fill-str-prev
		 (substring
		  fill-str-prev
		  (or (string-match "[^ \t]" fill-str-prev) 0)
		  (when (string-match
		         "[ \t]*\\(.*[^ \t]\\)[ \t]*$"
		         fill-str-prev)
		    (match-end 1))))
		"[ \t]*"
		(when suffix "$"))))
	  (while (re-search-forward prefix nil t)
	    (replace-match fill-str nil t)))))))

(defun kfill:sh-comment (paragraph)
  (setq fill-prefix (buffer-substring (match-beginning 0) (match-end 0)))
  (when paragraph
      (setq paragraph-separate
	    (concat "^" fill-prefix " *#\\|^"
		    (kfill:negate-string fill-prefix)))))

(defun kfill:supercite-included-text (paragraph)
  (setq fill-prefix (buffer-substring (match-beginning 0) (match-end 0)))
  (when paragraph
      (setq paragraph-separate
	    (concat "^" (kfill:negate-string fill-prefix)))))

(provide 'kfill)

;;; kfill.el ends here
