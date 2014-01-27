(in-package :cl-user)
(defpackage cl21.re
  (:use :cl
        :cl-ppcre)
  (:import-from :cl21.core.readtable
                :defreadtable
                :in-readtable)
  (:import-from :cl-ppcre
                :create-scanner
                :scan-to-strings)
  (:import-from :alexandria
                :remove-from-plist)
  (:export :re-match
           :re-replace
           :re-split
           :enable-cl21-re-syntax
           :disable-cl21-re-syntax))
(in-package :cl21.re)

(defun re-match (re string &rest keys &key start end)
  (declare (ignore start end))
  (etypecase re
    (function
     (apply re string keys))
    (string (apply #'ppcre:scan-to-strings re string keys))))

(defun re-replace (re string replacement &rest keys &key start end global)
  (declare (ignore start end))
  (setf keys
        (remove-from-plist keys :global))
  (etypecase re
    (function
     (multiple-value-bind (scanner modifiers) (funcall re)
       (if (or (find #\G modifiers) global)
           (apply #'ppcre:regex-replace-all scanner string replacement keys)
           (apply #'ppcre:regex-replace scanner string replacement keys))))
    (string (apply (if global
                       #'ppcre:regex-replace-all
                       #'ppcre:regex-replace)
                   re string replacement keys))))

(defun re-split (re target-string &rest keys &key start end limit)
  (declare (ignore start end limit))
  (apply #'ppcre:split (etypecase re
                         (function (funcall re))
                         (string re)) target-string keys))

(defun whitespacep (char)
  (member char '(#\Space #\Tab #\Newline #\Return #\Linefeed) :test #'char=))

(defun segment-reader (stream ch n)
  (if (> n 0)
      (let ((chars))
        (do ((curr (read-char stream)
                   (read-char stream)))
            ((char= ch curr))
          (push curr chars))
        (cons (coerce (nreverse chars) 'string)
              (segment-reader stream ch (- n 1))))))

(defun modifier-reader (stream)
  (let ((char (read-char stream nil)))
    (unread-char char stream)
    (unless (whitespacep char)
      (read-preserving-whitespace stream))))

(defun regex-with-modifier (regex modifier)
  (format nil "~@[(?~(~a~))~]~a" modifier regex))

(defun regexp-reader (stream sub-char numarg)
  (declare (ignore numarg))
  (let* ((segment (segment-reader stream sub-char 1))
         (modifiers (modifier-reader stream)))
    `(lambda (&optional str &rest keys)
       (if str
           (apply #'ppcre:scan-to-strings
                  ,(regex-with-modifier (car segment) modifiers)
                  str
                  keys)
           (values (ppcre:create-scanner
                    ,(regex-with-modifier (car segment)
                                          (and modifiers
                                               (remove #\G (symbol-name modifiers)))))
                   ,(coerce (symbol-name modifiers) 'simple-vector))))))

(defreadtable (cl21-re-readtable :cl21.re)
  (:merge :standard)
  (:dispatch-macro-char #\# #\/ #'regexp-reader))

(defun enable-cl21-re-syntax ()
  (in-readtable cl21-re-readtable)
  (values))

(defun disable-cl21-re-syntax ()
  (in-readtable nil)
  (values))