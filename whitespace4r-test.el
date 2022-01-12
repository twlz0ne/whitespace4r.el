;;; whitespace4r-test.el --- Test whitespace4r -*- lexical-binding: t; -*-

;; Copyright (C) 2022 Gong Qijian <gongqijian@gmail.com>

;; This program is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see <http://www.gnu.org/licenses/>.

;;; Code:

(require 'ert)
(require 'whitespace4r)

(when noninteractive
  (transient-mark-mode))

(ert-deftest whitespace4r-test-diff-regions ()
  (mapc (pcase-lambda (`(_ ,r1 _ ,r2 _ ,expected))
          (should (equal expected (whitespace4r-diff-regions r1 r2))))
        '((:r1 (10 . 22) :r2 (15 . 20) :expected ((10 . 15) (20 . 22)))
          (:r1 (10 . 22) :r2 nil       :expected ((10 . 22)))
          (:r1 nil       :r2 (15 . 20) :expected nil)
          (:r1 (10 . 22) :r2 (15 . 22) :expected ((10 . 15)))
          (:r1 (10 . 22) :r2 (10 . 20) :expected ((20 . 22)))
          (:r1 (10 . 22) :r2 (10 . 22) :expected nil))))

;;; whitespace4r-test.el ends here
