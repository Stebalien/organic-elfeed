;;; organic-elfeed-test.el --- Unit tests for organic-elfeed  -*- lexical-binding: t; -*-

;; Copyright (C) 2026 Steven Allen

;; Author: Steven Allen <steven@stebalien.com>

;; This file is NOT a part of GNU Emacs.

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

;; Test cases for organic-elfeed.

;;; Code:


(require 'ert)
(require 'organic-elfeed)

(ert-deftest organic-elfeed-test-parse ()
  (let ((default-directory (file-name-directory (ert-test-file-name (ert-running-test)))))
    (should
     (equal (organic-elfeed--parse-file "organic-elfeed-test.org")
            '(("https://example.com/feed1.xml" :source organic-elfeed)
              ("https://example.com/feed2.xml" :title "Example News Feed" :source organic-elfeed)
              ("https://example.com/feed3.xml" :title "My Awesome Blog" :source organic-elfeed personal work)
              ("https://example.com/feed4.xml" :source organic-elfeed important news)
              ("https://example.com/feed5.xml" :title "Feed With Properties" :source organic-elfeed :readable t)
              ("https://archived.example.com/feed.xml" :source organic-elfeed)
              ("https://level3.example.com/feed.xml" :source organic-elfeed)
              ("https://level4.example.com/feed.xml" :source organic-elfeed)
              ("https://level5.example.com/feed.xml" :source organic-elfeed)
              ("https://inherited.example.com/feed.xml" :source organic-elfeed work)
              ("https://nested-inherited.example.com/feed.xml" :source organic-elfeed work personal)
              ("http://mixed.example.com/feed1.xml" :source organic-elfeed)
              ("https://mixed.example.com/feed2.xml" :source organic-elfeed)
              ("https://mixed.example.com/feed3.xml" :source organic-elfeed)
              ("https://mixed.example.com/feed4.xml" :title "Feed Title Here" :source organic-elfeed)
              ("https://multiple-tags.example.com/feed.xml" :source organic-elfeed read later another tag))))))

(provide 'organic-elfeed-test)
;;; organic-elfeed-test.el ends here
