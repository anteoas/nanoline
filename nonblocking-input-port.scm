;;; this is a workaround for blocking calls to read-char on
;;; current-input-port.

(use (only posix file-select file-close file-read)
     (only ports make-input-port)
     (only srfi-18 thread-wait-for-i/o!))

;; like open-input-file* but doesn't block other threads. obs: this
;; port isn't thread-safe (it may block all threads if used from
;; multiple threads). it's buffered, but not thread-safe. fd can be 0
;; for stdin.
(define (open-input-file*/nonblock fd)
  (##sys#file-nonblocking! fd)
  (define buffer '())
  (make-input-port
   (lambda ()
     (let retry ()
       (if (pair? buffer)
           (let ((head (car buffer)))
             (set! buffer (cdr buffer))
             head)
           ;; fill buffer and retry
           (begin
             (thread-wait-for-i/o! fd #:input)
             (let* ((r (file-read fd 1024))
                    (bytes (cadr r))
                    (data (substring (car r) 0 bytes)))
               (if (= 0 bytes) ;; we just waited for 0 bytes => eof
                   #!eof
                   (begin (set! buffer (string->list data))
                          (retry))))))))
   (lambda () (receive (r f) (file-select fd #f 0) r))
   (lambda () (file-close fd))))

