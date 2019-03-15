;;; test-helper.el --- Testing Macros -*- lexical-binding: t -*-

(require 'ert)
(require 'faceup)
(require 'f)

(progn (add-to-list 'load-path (-> (f-this-file) (f-parent) (f-parent)))
       (require 'nt))

;;; Macros
;;;; Contexts

(defmacro nt-test--kind->context (kind)
  "See `nt-test--with-context' for documentation on KIND."
  `(cl-case ,kind
     ((minimal no-setup)
      (setq nt-bound?-fn (-const nil)
            ;; TODO the new 'nt-bound prop is still reached even
            ;; with the (-const nil) above. So need better way
            ;; to nil this out.
            nt-bound-fn (-juxt (-compose #'1+
                                         #'line-number-at-pos
                                         #'overlay-start)
                               (-compose #'1+
                                         #'line-number-at-pos
                                         #'overlay-start))))

     (simple
      (setq nt-bound?-fn #'identity
            nt-bound-fn (-juxt (-compose #'1+
                                         #'line-number-at-pos
                                         #'overlay-start)
                               (-compose #'1+ #'1+
                                         #'line-number-at-pos
                                         #'overlay-start))))

     (simple-2
      (setq nt-bound?-fn #'identity
            nt-bound-fn (-juxt (-compose #'1+
                                         #'line-number-at-pos
                                         #'overlay-start)
                               (-compose #'1+ #'1+ #'1+
                                         #'line-number-at-pos
                                         #'overlay-start))))

     (lispy
      (progn
        (setq nt-bound?-fn #'nt-bounds?--lisps
              nt-bound-fn #'nt-bounds--lisps)
        (set-syntax-table lisp-mode-syntax-table)))

     (otherwise
      (error "Supplied testing context KIND '%s' not implemented" ,kind))))

(defmacro nt-test--with-context (kind buffer-contents &rest body)
  "Run BODY in context KIND in temp-buffer with (`s-trim'med) BUFFER-CONTENTS.

KIND is a symbol identifying how notes will contribute to masks:

   'minimal: Notes will not contribute to any mask.

   'simple: Notes will always contribute to following line's mask.

   'simple-2: Notes will always contribute to following two line's masks.

   'lispy: Notes use lisp boundary functions to contribute to masks
           and inherit `lisp-mode-syntax-table'.

   'no-setup: Same as 'minimal but do not execute `nt-enable--agnostic'.

   'any: Execute BODY for each of the following values of KIND:
           minimal, simple and lispy

         Useful when note-mask interaction is present but doesn't
         modify the tested values, like note creation.

After setting the context, `nt-enable--agnostic' is executed. At the time of
writing, it instantiates empty masks for the buffer and sets up managed vars."
  (declare (indent 2))

  (if (eval `(equal 'any ,kind))
      `(nt-test--with-contexts ('minimal 'simple 'lispy) ,buffer-contents ,@body)
    `(with-temp-buffer
       (nt-disable)  ; just-in-case reset managed vars
       (nt-test--kind->context ,kind)

       (insert (s-trim ,buffer-contents))  ; so test lines 1-idxed not 2-idxed

       (unless (eq 'no-setup ,kind)
         (nt-enable--agnostic))
       ,@body
       (nt-disable))))

(defmacro nt-test--with-contexts (kinds buffer-contents &rest body)
  "Perform `nt-test--with-context' for all KINDS."
  (when kinds
    `(progn (nt-test--with-context ,(car kinds) ,buffer-contents ,@body)
            (nt-test--with-contexts ,(cdr kinds) ,buffer-contents ,@body))))

;;; Mocks
;;;; Notes

(defun nt-test--mock-note (string replacement)
  "Mock notes for STRING to REPLACEMENT."
  (save-excursion
    (goto-char (point-min))

    (let ((rx (nt-kwd--string->rx string))
          notes)
      (while (re-search-forward rx nil 'noerror)
        (-let* (((start end)
                 (match-data 1))
                (note
                 (nt-note--init string replacement start end)))
          (push note notes)))
      notes)))

(defun nt-test--mock-notes (string-replacement-alist)
  "Map `nt-test--mock-note' over list STRING-REPLACEMENT-ALIST and sort it."
  (->> string-replacement-alist
     (-mapcat (-applify #'nt-test--mock-note))
     nt-notes--sort))

;;; Expanded Shoulds

(defmacro should* (&rest fi)
  "Expands to (progn (should f1) (should f2) ...) for forms FI."
  (when fi
    `(progn (should ,(car fi))
            (should* ,@(cdr fi)))))

(defmacro should= (f1 &rest fi) `(should (= ,f1 ,@fi)))
(defmacro should-s= (f1 f2) `(should (s-equals? ,f1 ,f2)))
(defmacro should-size (coll size) `(should= (length ,coll) ,size))
