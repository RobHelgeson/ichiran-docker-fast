;;;; ichiran-server.asd — HTTP server for ichiran

(in-package :asdf)

(defsystem #:ichiran-server
  :serial t
  :description "HTTP server for ichiran Japanese morphological analyzer"
  :license "MIT"
  :depends-on (#:ichiran
               #:hunchentoot
               #:jsown
               #:bordeaux-threads)
  :components ((:file "server")))
