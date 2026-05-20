;;; elfeed-org.el --- Configure elfeed subscriptions via org-mode files  -*- lexical-binding: t; -*-

;; Copyright (C) 2026  Steven Allen

;; Author: Steven Allen <steven@stebalien.com>
;; Keywords: news
;; Version: 0.1
;; Package-Requires: ((emacs "27.1") (elfeed "3.4.2") (org "9.7"))
;; URL: https://github.com/Stebalien/elfeed-org

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
;; `elfeed-org-include-tag'. The headline's link text is the feed
;; URL; the link description (if any) is the feed title.
;;
;; Example:
;;
;;   * My Feeds :elfeed:
;;     ** https://example.com/feed1.xml :customtag:
;;     ** [[https://example.com/feed.xml][My Feed Title]]
;;
;; Archived and commented headlines are skipped, as are those tagged with
;; `elfeed-org-exclude-tag'. Any additional `org-mode' tags are applied to
;; feed entries.
;;
;; The feed list is automatically updated after saving an org-mode file
;; listed in `elfeed-org-files'.

;;; Code:
(require 'seq)
(require 'elfeed-db)
(require 'org-element)
(eval-when-compile (require 'org-macs))

(defgroup elfeed-org nil
  "Org-mode integration for Elfeed."
  :group 'elfeed)

(defun elfeed-org--set-and-update (symbol value)
  "Set the SYMBOL to VALUE and update `elfeed-feeds'."
  (set-default-toplevel-value symbol value)
  (when (featurep 'elfeed-org)
    (elfeed-org-update)))

(defcustom elfeed-org-files nil
  "List of `org-mode' files to search for feeds.

Each file should contain headlines tagged with
`elfeed-org-include-tag', either directly or via tag inheritance.
The link text of each such headline is treated as a feed URL. See
the file commentary for a complete usage example."
  :type '(repeat file)
  :set #'elfeed-org--set-and-update
  :group 'elfeed-org)

(defcustom elfeed-org-include-tag "elfeed"
  "Tag used to identify Elfeed feeds."
  :type '(repeat string)
  :set #'elfeed-org--set-and-update
  :group 'elfeed-org)

(defcustom elfeed-org-exclude-tag "ignore"
  "Tag used to ignore Elfeed feeds."
  :type '(repeat string)
  :set #'elfeed-org--set-and-update
  :group 'elfeed-org)


(defun elfeed-org--headline-link (headline)
  "Extract the first link from HEADLINE's title.

Returns the link element found in the headline's secondary string
title, or nil if no link is present."
  (org-element-map (org-element-property :title headline)
      'link 'node nil 'first-match))

(defun elfeed-org--buffer-feeds ()
  "Parse the current `org-mode' buffer for elfeed feed definitions.

Return a list of feed specifications suitable for inclusion in
`elfeed-feeds'. Each headline tagged with `elfeed-org-include-tag'
contributes one feed, with its link text as the URL and link
description as the optional title."
  (let (feeds)
    (org-element-map (org-element-parse-buffer) 'headline
      (lambda (headline)
        (let ((tags (org-get-tags headline)))
          (when (or (member elfeed-org-exclude-tag tags)
                    (org-element-property :archivedp headline)
                    (org-element-property :commentedp headline))
            (throw :org-element-skip nil))
          (when-let* (((member elfeed-org-include-tag tags))
                      (link (elfeed-org--headline-link headline)))
            (push `(,(org-element-property :raw-link link)
                    ,@(when-let* ((title (org-element-contents link)))
                        (list :title (substring-no-properties (car title))))
                    :source elfeed-org
                    ,@(delq 'elfeed (mapcar #'intern tags)))
                  feeds)))))
    (nreverse feeds)))

(defun elfeed-org--feeds (files)
  "Parse FILES for Elfeed feed definitions.

FILES is a list of file paths to `org-mode' files. Return a
combined list of all feed specifications found across all files."
  (mapcan
   (lambda (file)
    (org-with-file-buffer (expand-file-name file org-directory)
      (org-with-wide-buffer
       (elfeed-org--buffer-feeds))))
   files))

(defun elfeed-org-update ()
  "Update `elfeed-feeds' by parsing all files in `elfeed-org-files'.

This function re-reads all `org-mode' files listed in `elfeed-org-files'
and sets `elfeed-feeds' to the resulting list of feed specifications."
  (setq elfeed-feeds
        (append
         (seq-remove
          (lambda (feed) (eq (plist-get (cdr feed) :source) 'elfeed-org))
          elfeed-feeds)
         (elfeed-org--feeds elfeed-org-files))))

(defun elfeed-org--maybe-update-after-save ()
  "Update feeds if the current buffer is one of `elfeed-org-files'."
  (let ((default-directory org-directory))
    (when (and
           buffer-file-name
           (seq-contains-p elfeed-org-files buffer-file-name #'file-equal-p))
      (elfeed-org-update))))

(defun elfeed-org--org-setup ()
  "Set up auto-update for elfeed when editing an `org-mode' file.

Adds `elfeed-org-update' to the local `after-save-hook' so that
saving an `org-mode' file listed in `elfeed-org-files' automatically
refreshes the feed list."
  (add-hook 'after-save-hook 'elfeed-org-update nil t))

(add-hook 'org-mode-hook #'elfeed-org--org-setup)
(elfeed-org-update)

(provide 'elfeed-org)
;;; elfeed-org.el ends here
