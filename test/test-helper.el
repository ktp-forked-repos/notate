(require 'cl)
(require 'dash)
(require 'dash-functional)
(require 's)

(require 'ert)
(require 'faceup)
(require 'f)

(progn (add-to-list 'load-path (-> (f-this-file) (f-parent) (f-parent)))
       (require 'virtual-indent))



;;; Asserts

(defun s-assert (s1 s2)
  "Combine `should' and `s-equals?'."
  (should (s-equals? s1 s2)))