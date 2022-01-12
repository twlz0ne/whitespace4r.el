;;; whitespace4r.el --- Minor mode to show whitespace for selected region -*- lexical-binding: t; -*-

;; Copyright (C) 2022 Gong Qijian <gongqijian@gmail.com>

;; Author: Gong Qijian <gongqijian@gmail.com>
;; Created: 2022/01/12
;; Version: 0.1.0
;; Package-Requires: ((emacs "25.1"))
;; URL: https://github.com/twlz0ne/whitespace4r
;; Keywords: tools

;; This program is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see <https://www.gnu.org/licenses/>.

;;; Commentary:

;; Minor mode to show whitespace for selected region.

;; See README.md for more information.

;;; Change Log:

;;  0.1.0  2022/01/12  Initial version.

;;; Code:

(require 'whitespace)

(defvar-local whitespace4r--region-mark nil
  "Used to save the last selected region.")

(defvar-local whitespace4r-font-lock-keywords
    "Used to save the value ‘whitespacer-mode’ adds to ‘font-lock-keywords’.")

(defun whitespace4r-font-lock-keywords ()
  "Return font lock keywords."
  `(
    ,@(when (memq 'spaces whitespace-active-style)
        ;; Show SPACEs.
        `(("\\(\s\\)"
           (1 (put-text-property
               (match-beginning 1)
               (match-end 1)
               'display (propertize "·" 'face whitespace-space))))
          ;; Show HARD SPACEs.
          ("\\(\u00A0\\)"
           (1 (put-text-property
               (match-beginning 1)
               (match-end 1)
               'display
               (propertize "¤" 'face whitespace-hspace))))))
    ,@(when (memq 'tabs whitespace-active-style)
        ;; Show TABs.
        `(("\\(\t\\)"
           (1 (let ((s (concat (make-string
                                    (- (current-column)
                                       (save-excursion
                                         (goto-char (match-beginning 1))
                                         (current-column))
                                       1)
                                    ?\s)
                               "»")))
                (put-text-property
                 (match-beginning 1)
                 (match-end 1)
                 'display (propertize s 'face whitespace-tab)))))))))

(defun whitespace4r-diff-regions (r1 r2)
  "Return a list of regions that contained in R1 but not R2."
  (remove nil (if (and r1 r2)
                  (list (if (> (car r2) (car r1))
                            (cons (car r1) (car r2)))
                        (if (< (cdr r2) (cdr r1))
                            (cons (cdr r2) (cdr r1))))
                (list r1))))

(defun whitespace4r--mark-region (region)
  "Mark the REGION."
  (when whitespace4r--region-mark
    (delete-overlay whitespace4r--region-mark))
  (when region
    (setq whitespace4r--region-mark
          (make-overlay (car region) (cdr region) nil nil t))))

(defun whitespace4r--marked-region ()
  "Return the marked retion."
  (when whitespace4r--region-mark
    (let ((beg (overlay-start whitespace4r--region-mark))
          (end (overlay-end whitespace4r--region-mark)))
      (when (and beg end)
        (cons beg end)))))

(defun whitespace4r--hide (regions)
  "Hide whitespace in REGIONS."
  (font-lock-remove-keywords nil whitespace4r-font-lock-keywords)
  (dolist (region regions)
    (let ((beg (car region))
          (end (cdr region)))
      (when (< beg end)
        (font-lock-flush beg end)
        (font-lock-ensure beg end)
        (run-with-timer
         0.1 nil `(lambda ()
                    (with-current-buffer ,(current-buffer)
                      (remove-text-properties ,beg ,end '(display nil)))))))))

(defun whitespace4r--show (regions)
  "Show whitespace in REGIONS."
  (font-lock-add-keywords nil whitespace4r-font-lock-keywords t)
  (dolist (region regions)
    (when (< (car region) (cdr region))
      (font-lock-flush (car region) (cdr region))
      (font-lock-ensure (car region) (cdr region)))))

(defun whitespace4r--update ()
  "Refresh screen when selected region changed."
  (if (region-active-p)
      (let ((font-lock-extend-region-functions
             (remove 'font-lock-extend-region-wholelines
                     font-lock-extend-region-functions))
            (last-region (whitespace4r--marked-region))
            (r (if (eq (bound-and-true-p evil-state) 'visual)
                   (cons (nth 0 (evil-visual-range))
                         (nth 1 (evil-visual-range)))
                 (cons (region-beginning)
                       (region-end)))))
        (whitespace4r--show (whitespace4r-diff-regions r last-region))
        (whitespace4r--hide (whitespace4r-diff-regions last-region r))
        (whitespace4r--mark-region r))
    (whitespace4r--mark-region nil)))

(defun whitespace4r--activate-mark-cb ()
  "Run after the mark becomes active."
  (setq-local whitespace-active-style
              (if (listp whitespace-style)
                  whitespace-style
                (list whitespace-style)))
  (setq whitespace4r-font-lock-keywords (whitespace4r-font-lock-keywords))
  (add-hook 'post-command-hook #'whitespace4r--update nil t))

(defun whitespace4r--deactivate-mark-cb ()
  "Run after the mark becomes deactive."
  (remove-hook 'post-command-hook #'whitespace4r--update t)
  (let ((last-region (whitespace4r--marked-region)))
    (when last-region
      (whitespace4r--hide (list last-region))))
  (whitespace4r--mark-region nil))

(defun whitespace4r--advice-kill-new (orig-fn string &optional replace)
  "Advice around `kill-new' (ORIG-FN) to remove text properties.

See `kill-new' for arguments STRING and REPLACE."
  (funcall orig-fn (if whitespace4r-mode
                       (substring-no-properties string)
                     string)
           replace))

(defun whitespace4r--advice-primitive-undo (orig-fn n list)
  "Advice around `primitive-undo' (ORIG-FN) to remove text properties.

See `primitive-undo' for arguments N and LIST."
  (when whitespace4r-mode
    (let ((s (caar (nthcdr n list))))
      (when (stringp s)
        (setf (caar (nthcdr n list))
              (substring-no-properties s)))))
  (funcall orig-fn n list))

;;;###autoload
(define-minor-mode whitespace4r-mode
  "Toggle whitespace visualization for selected region (Whitespace4r mode)."
  :lighter " ws4r"
  :init-value nil
  :global     nil
  :group      'whitespace4r
  (cond
   (whitespace4r-mode
    (add-hook 'activate-mark-hook #'whitespace4r--activate-mark-cb  100 t)
    (add-hook 'deactivate-mark-hook #'whitespace4r--deactivate-mark-cb 100 t)
    (advice-add 'kill-new :around #'whitespace4r--advice-kill-new)
    (advice-add 'primitive-undo :around #'whitespace4r--advice-primitive-undo)
    (whitespace4r--activate-mark-cb))
   (t
    (remove-hook 'activate-mark-hook #'whitespace4r--activate-mark-cb t)
    (remove-hook 'deactivate-mark-hook #'whitespace4r--deactivate-mark-cb t)
    (advice-remove 'kill-new #'whitespace4r--advice-kill-new)
    (advice-remove 'primitive-undo #'whitespace4r--advice-primitive-undo)
    (whitespace4r--deactivate-mark-cb))))

(provide 'whitespace4r)

;;; whitespace4r.el ends here
