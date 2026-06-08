;;; organic-elfeed-capture.el --- Org-capture integration for organic-elfeed  -*- lexical-binding: t; -*-

;; Copyright (C) 2026  Steven Allen
;; Copyright (C) 2020  Hiroki YAMAKAWA

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

;; This library provides a helper function for defining an org-capture
;; template to capture feeds.

;; The feed discovery logic in this file was originally written by Hiroki
;; YAMAKAWA as <https://github.com/HKey/feed-discovery>, but I've made
;; several improvements and adapted it for my org-capture use-case.

;;; Code:

(require 'seq)
(require 'dom)
(require 'url-expand)
(require 'org-capture)

(defconst organic-elfeed-capture-mime-types '("application/rss+xml"
                                              "application/feed+json"
                                              "application/atom+xml")
  "Feed MIME types.")

;;;###autoload
(defconst organic-elfeed-capture-template
  "* %(organic-elfeed-capture:annotation)
:PROPERTIES:
:CREATED: %U
:SOURCE: %:annotation
:END:"
  "Org-capture template for `organic-elfeed'.")

(defun organic-elfeed-capture--feed-link-p (element)
  "Non-nil if ELEMENT is an rss/atom/json feed link element."
  (and (eq (dom-tag element) 'link)
       (equal (dom-attr element 'rel) "alternate")
       (member (dom-attr element 'type) organic-elfeed-capture-mime-types)
       (dom-attr element 'href)))

(defsubst organic-elfeed-capture--strip-fragment (url)
  "Return the given URL with any fragments removed."
  (if-let* ((fragment (string-search "#" url)))
      (substring url 0 fragment)
    url))

(defsubst organic-elfeed-capture--find-base-url (dom url)
  "Find base url from DOM loaded from URL."
  (if-let* ((base-url (seq-some (lambda (el) (dom-attr el 'href))
                                (dom-by-tag dom 'base))))
      (url-expand-file-name
       base-url (organic-elfeed-capture--strip-fragment url))
    url))

(defun organic-elfeed-capture--discover-feeds (url)
  "Discover feeds from URL.
Returns an alist mapping feed URLs to titles."
  (with-temp-buffer
    (url-insert-file-contents url)
    (let* ((dom (libxml-parse-html-region))
           (base-url (organic-elfeed-capture--find-base-url dom url)))
      (cl-loop
       for elt in (dom-search dom #'organic-elfeed-capture--feed-link-p)
       for href = (dom-attr elt 'href)
       for title = (dom-attr elt 'title)
       collect
       (cons (url-expand-file-name href base-url)
             ;; Some websites don't use the "title" attribute correctly..."
             (unless (equal href title) title))))))

(defun organic-elfeed-capture--choose-feed (url)
  "Chooses a feed from the webpage at URL."
  (pcase (organic-elfeed-capture--discover-feeds url)
    (`(,feed) (car feed))
    ('nil (user-error "No feeds found!"))
    (feeds
     (let ((choices
            (mapcar
             (pcase-lambda (`(,feed-url . ,feed-title))
               (cons (if feed-title (format "%s (%s)" feed-title feed-url) feed-url)
                     feed-url))
             feeds)))
       (alist-get
        (completing-read "Choose Feed: " choices nil t)
        choices nil nil #'string=)))))

;;;###autoload
(defun organic-elfeed-capture:link ()
  "Choose an appropriate feed URL for the currently stored link."
  (organic-elfeed-capture--choose-feed (plist-get org-store-link-plist :link)))

;;;###autoload
(defun organic-elfeed-capture:annotation ()
  "Choose an appropriate feed link for the currently stored link.
The returned link will be formatted as an `org-mode' link [[URL][title]]."
  (let ((desc (plist-get org-store-link-plist :description)))
    (when-let* ((feed (organic-elfeed-capture:link)))
      (org-link-make-string
       feed (read-string (format-prompt "Feed Title" desc) nil nil desc)))))

(provide 'organic-elfeed-capture)
;;; organic-elfeed-capture.el ends here
