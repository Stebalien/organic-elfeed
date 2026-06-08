;;; organic-elfeed.el --- Configure elfeed subscriptions via org-mode files  -*- lexical-binding: t; -*-

;; Copyright (C) 2026  Steven Allen

;; Author: Steven Allen <steven@stebalien.com>
;; Keywords: news
;; Version: 0.1
;; Package-Requires: ((emacs "27.1") (elfeed "4.0.0") (org "9.7"))
;; URL: https://github.com/Stebalien/organic-elfeed

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

;; Configure Elfeed subscriptions via org-mode files.
;;
;; Define RSS/Atom feeds as org-mode headlines tagged with
;; `organic-elfeed-include-tag'. The headline's link text is the feed
;; URL; the link description (if any) is the feed title.
;;
;; Example:
;;
;;   * My Feeds :elfeed:
;;     ** https://example.com/feed1.xml :customtag:
;;     ** [[https://example.com/feed.xml][My Feed Title]]
;;
;; Archived and commented headlines are skipped, as are those tagged with
;; `organic-elfeed-exclude-tag'. Any additional `org-mode' tags are applied to
;; feed entries.
;;
;; The feed list is automatically updated after saving an org-mode file
;; listed in `organic-elfeed-files'.

;;; Code:
(require 'elfeed-db)
(require 'org-element)
(eval-when-compile (require 'org-macs))

(defgroup organic-elfeed nil
  "Org-mode integration for Elfeed."
  :group 'elfeed)

(defun organic-elfeed--set-and-update (symbol value)
  "Set the SYMBOL to VALUE and update `elfeed-feeds'."
  (set-default-toplevel-value symbol value)
  (when (featurep 'organic-elfeed)
    (organic-elfeed--update)))

(defcustom organic-elfeed-files nil
  "List of `org-mode' files to search for feeds.

Files may be absolute paths or relative to `org-directory'.

Each file should contain headlines tagged with
`organic-elfeed-include-tag', either directly or via tag inheritance.
The link text of each such headline is treated as a feed URL. See
the file commentary for a complete usage example."
  :type '(repeat file)
  :set #'organic-elfeed--set-and-update
  :group 'organic-elfeed)

(defcustom organic-elfeed-include-tag "elfeed"
  "Tag used to identify Elfeed feeds."
  :type '(repeat string)
  :set #'organic-elfeed--set-and-update
  :group 'organic-elfeed)

(defcustom organic-elfeed-exclude-tag "ignore"
  "Tag used to ignore Elfeed feeds."
  :type '(repeat string)
  :set #'organic-elfeed--set-and-update
  :group 'organic-elfeed)

;;;###autoload
(define-minor-mode organic-elfeed-mode
  "Populate `elfeed-feeds' from the `org-mode' files in `organic-elfeed-files'."
  :global t
  (if organic-elfeed-mode
      (add-hook 'org-mode-hook #'organic-elfeed--org-setup)
    (remove-hook 'org-mode-hook #'organic-elfeed--org-setup))
  (organic-elfeed--update))

(defun organic-elfeed--parse-buffer ()
  "Extract elfeed RSS feeds from current `org-mode' buffer.

Return a list of feed specifications suitable for inclusion in
`elfeed-feeds'. Each headline tagged with `organic-elfeed-include-tag'
contributes one feed, with its link text as the URL and link
description as the optional title."
  (let (feeds)
    (org-element-map (org-element-parse-buffer) 'headline
      (lambda (headline)
        (when (or (org-element-property :archivedp headline)
                  (org-element-property :commentedp headline))
          (throw :org-element-skip nil))
        (when-let* ((tags (org-get-tags headline))
                    ((member organic-elfeed-include-tag tags))
                    ((not (member organic-elfeed-exclude-tag tags)))
                    (title (org-element-property :title headline))
                    (link (org-element-map title
                              'link 'node nil 'first-match)))
          (push `(,(org-element-property :raw-link link)
                  ,@(when-let* ((title (org-element-contents link)))
                      (list :title (substring-no-properties (car title))))
                  :source organic-elfeed
                  ,@(apply 'append
                           (org-element-properties-map
                            (lambda (prop value)
                              (setq prop (symbol-name prop))
                              (when (string-prefix-p ":ELFEED:" prop)
                                (list
                                 (thread-last
                                   prop
                                   (string-remove-prefix ":ELFEED")
                                   (downcase)
                                   (intern))
                                 (intern value))))
                            headline))
                  ,@(delq 'elfeed (mapcar #'intern tags)))
                feeds))))
    (nreverse feeds)))

(defun organic-elfeed--parse-file (file)
  "Extract elfeed RSS feeds from the `org-mode' FILE.

Return a list of feed specifications suitable for inclusion in
`elfeed-feeds'. Each headline tagged with `organic-elfeed-include-tag'
contributes one feed, with its link text as the URL and link
description as the optional title."
  (org-with-file-buffer file (org-with-wide-buffer (organic-elfeed--parse-buffer))))

(defun organic-elfeed--feeds (files)
  "Parse FILES for Elfeed feed definitions.

FILES is a list of file paths to `org-mode' files. Return a
combined list of all feed specifications found across all files."
  (mapcan #'organic-elfeed--parse-file files))

(defun organic-elfeed--update ()
  "Update `elfeed-feeds' by parsing all files in `organic-elfeed-files'.

This function re-reads all `org-mode' files listed in `organic-elfeed-files'
and sets `elfeed-feeds' to the resulting list of feed specifications."
  (let ((default-directory org-directory)
        (feeds elfeed-feeds))
    (cl-callf2 cl-remove-if
        (lambda (feed) (eq (plist-get (cdr feed) :source) 'organic-elfeed))
        feeds)
    (when organic-elfeed-mode
      (cl-callf append feeds (organic-elfeed--feeds organic-elfeed-files)))
    (unless (eq feeds elfeed-feeds)
      (setopt elfeed-feeds feeds))))

(defun organic-elfeed--maybe-update-after-save ()
  "Update feeds if the current buffer is one of `organic-elfeed-files'."
  (let ((default-directory org-directory))
    (when (and buffer-file-name (cl-member buffer-file-name
                                           organic-elfeed-files
                                           :test #'file-equal-p))
      (organic-elfeed--update))))

(defun organic-elfeed--org-setup ()
  "Set up auto-update for elfeed when editing an `org-mode' file."
  (add-hook 'after-save-hook 'organic-elfeed--update nil t))


(provide 'organic-elfeed)
;;; organic-elfeed.el ends here
