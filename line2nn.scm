;; Publish every line from stdin on a nanomsg socket. The socket is
;; given as a command-line argument

(use (only nanomsg nn-socket nn-bind nn-connect nn-send nn-recv nn-close nn-subscribe)
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

(if (null? (cla)) (usage))

(define nn-protocol (string->symbol (car (cla))))
(define nnsock (nn-socket nn-protocol))

(define bound?      (let ((x #f)) (lambda (#!optional set) (if set (set! x #t) x))))
(define subscribed? (let ((x #f)) (lambda (#!optional set) (if set (set! x #t) x))))

(let loop ((args (cdr (command-line-arguments))))
  (match args
    (((or "-b" "--bind")      ep rest ...) (nn-bind      nnsock ep) (bound? #t) (loop rest))
    (((or "-c" "--connect")   ep rest ...) (nn-connect   nnsock ep) (bound? #t) (loop rest))
    (((or "-s" "--subscribe") px rest ...) (nn-subscribe nnsock px) (subscribed? #t) (loop rest))
    (())
    (else (error "unknown argument: " args))))

(if (not (bound?))
    (usage "error: no valid endpoints. use --connect / --bind"))

;; automatically subscribe to "" if nothing specified
(when (and (eq? nn-protocol 'sub)
           (not (subscribed?)))
  (info "subscribing to \"\"" nn-protocol)
  (nn-subscribe nnsock ""))

(define thread-recv
  (thread-start!
   (lambda ()
     (if (member nn-protocol in-protocols)
         (let loop ()
           (print (nn-recv nnsock))
           (loop))))))

(define thread-send
  (thread-start!
   (lambda ()
     (if (member nn-protocol out-protocols)
         (with-input-from-port (open-input-file*/nonblock 0)
           (lambda ()
             (port-for-each (lambda (line) (nn-send nnsock line)) read-line)))))))

(thread-join! thread-send)
(thread-join! thread-recv)

(nn-close nnsock)
