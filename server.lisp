;;;; ichiran HTTP server — replaces the Node.js + execSync architecture
;;;; with a persistent hunchentoot server for dramatically better throughput.

(defpackage :ichiran/server
  (:use :cl :ichiran/all)
  (:export :start :stop-server))

(in-package :ichiran/server)

;;; JSON serialization for word-info (same as cli.lisp)
(defmethod jsown:to-json ((wi word-info))
  (jsown:to-json (word-info-gloss-json wi)))

;;; Server state
(defvar *acceptor* nil "The running hunchentoot acceptor")
(defvar *server-lock* (bordeaux-threads:make-lock "server-lock"))

;;; ---- Handlers ----

(hunchentoot:define-easy-handler (segmentation-handler :uri "/segmentation"
                                                        :default-request-type :post)
    ()
  (setf (hunchentoot:content-type*) "application/json")
  (let ((body (hunchentoot:raw-post-data :force-text t)))
    (handler-case
        (let* ((json (jsown:parse body))
               (text (jsown:val json "text")))
          (if (and text (plusp (length text)))
              (postmodern:with-connection ichiran/conn:*connection*
                (jsown:to-json (romanize* text :limit 1)))
              (progn
                (setf (hunchentoot:return-code*) 500)
                "")))
      (error (e)
        (hunchentoot:log-message* :error "Segmentation error: ~a" e)
        "[]"))))

(hunchentoot:define-easy-handler (health-handler :uri "/health"
                                                  :default-request-type :get)
    ()
  (setf (hunchentoot:content-type*) "application/json")
  "{\"status\":\"ok\"}")

;;; ---- Server lifecycle ----

(defun make-server (&key (port 80) (num-threads 8))
  "Create a hunchentoot acceptor with a multi-threaded taskmaster."
  (make-instance 'hunchentoot:easy-acceptor
                 :port port
                 :taskmaster (make-instance 'hunchentoot:one-thread-per-connection-taskmaster
                                            :max-thread-count num-threads
                                            :max-accept-count (+ num-threads 16))))

(defun start (&key (port 80) (num-threads 8))
  "Start the ichiran HTTP server. Blocks the calling thread."
  (load-connection-from-env)
  (format t "Initializing caches...~%")
  (finish-output)
  (postmodern:with-connection ichiran/conn:*connection*
    (init-all-caches)
    (init-suffixes t))
  (postmodern:clear-connection-pool)
  (let ((acceptor (make-server :port port :num-threads num-threads)))
    (bordeaux-threads:with-lock-held (*server-lock*)
      (setf *acceptor* acceptor))
    (format t "Starting ichiran server on port ~a (~a threads)~%" port num-threads)
    (finish-output)
    (hunchentoot:start acceptor)
    ;; Block forever so the process doesn't exit
    (loop (sleep 3600))))

(defun stop-server ()
  "Stop the running server (for REPL use)."
  (bordeaux-threads:with-lock-held (*server-lock*)
    (when *acceptor*
      (hunchentoot:stop *acceptor*)
      (setf *acceptor* nil))))
