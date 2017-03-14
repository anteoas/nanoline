;; Publish every line from stdin on a nanomsg socket. The socket is
;; given as a command-line argument

(use (only nanomsg nn-socket nn-bind nn-connect nn-send nn-recv nn-close)
     (only data-structures conc)
     (only extras)
     (only matchable match)
     (only ports port-for-each)
     (only srfi-1 delete-duplicates)
     (only srfi-13 string-join))

(include "nonblocking-input-port.scm")

(define (info . args) (with-output-to-port (current-error-port) (lambda () (apply print args))))
(define cla command-line-arguments)

(define in-protocols  '(pull sub pair bus))
(define out-protocols '(push pub pair bus))

;; TODO: add support for req? on req's, we could (display (nn-recv s))
(define (usage #!optional (msg ""))
  (error (conc msg "\n"
               "usage: " (car (argv))
               " <nn-protocol> [ --bind <nn-endpoint> | --connect <nn-endpoint> ] ...\n"
               "protocols include: "
               (string-join (map conc (delete-duplicates (append in-protocols out-protocols))) " "))))

;; returns two values: (<bind-endpoints> <connect-endpoints)
;; (fold-endpoints '("--bind" "b1" "-x" "--connect" "c1" "--bind" "b2"))
(define (fold-endpoints args)
  (let loop ((args args)
             (binds '())
             (connects '()))
    (match args
      (("--bind" endpoint rest ...)
       (loop rest
             (cons endpoint binds)
             connects))
      (("--connect" endpoint rest ...)
       (loop rest
             binds
             (cons endpoint connects)))
      ((unknown rest ...)
       (loop rest binds connects ))
      (else (values binds connects)))))

(if (null? (cla)) (usage))

(define nn-protocol (string->symbol (car (cla))))

(define-values (binds connects)
  (fold-endpoints (cdr (cla))))

(if (and (null? binds)
         (null? connects))
    (usage "error: no valid endpoints. use --connect / --bind"))

;; Nanomsg init
(define nnsock (nn-socket nn-protocol))
(for-each (cut nn-bind    nnsock <>) binds)
(for-each (cut nn-connect nnsock <>) connects)


(define thread-recv
  (thread-start!
   (lambda ()
     (if (member nn-protocol in-protocols)
         (let loop ()
           (print (nn-recv nnsock))
           (loop))
         (info "skipping nn-recv, protocol " nn-protocol " is \"write-only\"")))))

(define thread-send
  (thread-start!
   (lambda ()
     (if (member nn-protocol out-protocols)
         (with-input-from-port (open-input-file*/nonblock 0)
           (lambda ()
             (port-for-each
              (lambda (line)
                (nn-send nnsock line))
              read-line)))
         (info "skipping nn-send, protocol " nn-protocol " is \"read-only\"")))))



(thread-join! thread-send)
(thread-join! thread-recv)
;; Cleanup
(nn-close nnsock)
