;;; elfeed-org-test.el --- Unit tests for elfeed-org  -*- lexical-binding: t; -*-

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

;; Test cases for elfeed-org.

;;; Code:


(require 'ert)
(require 'elfeed-org)

(ert-deftest elfeed-org-test-parse ()
  (let ((default-directory (file-name-directory (ert-test-file-name (ert-running-test)))))
    (should
     (equal (elfeed-org--parse-file "elfeed-org-test.org")
            '(("https://example.com/feed1.xml" :source elfeed-org)
              ("https://example.com/feed2.xml" :title "Example News Feed" :source elfeed-org)
              ("https://example.com/feed3.xml" :title "My Awesome Blog" :source elfeed-org personal work)
              ("https://example.com/feed4.xml" :source elfeed-org important news)
              ("https://archived.example.com/feed.xml" :source elfeed-org)
              ("https://level3.example.com/feed.xml" :source elfeed-org)
              ("https://level4.example.com/feed.xml" :source elfeed-org)
              ("https://level5.example.com/feed.xml" :source elfeed-org)
              ("https://inherited.example.com/feed.xml" :source elfeed-org work)
              ("https://nested-inherited.example.com/feed.xml" :source elfeed-org work personal)
              ("http://mixed.example.com/feed1.xml" :source elfeed-org)
              ("https://mixed.example.com/feed2.xml" :source elfeed-org)
              ("https://mixed.example.com/feed3.xml" :source elfeed-org)
              ("https://mixed.example.com/feed4.xml" :title "Feed Title Here" :source elfeed-org)
              ("https://multiple-tags.example.com/feed.xml" :source elfeed-org read later another tag))))))

(provide 'elfeed-org-test)
;;; elfeed-org-test.el ends here
