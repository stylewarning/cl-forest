;;;; forest.lisp
;;;;
;;;; Licensed under the Apache License, Version 2.0 (the "License");
;;;; you may not use this file except in compliance with the License.
;;;; You may obtain a copy of the License at
;;;;
;;;;     http://www.apache.org/licenses/LICENSE-2.0
;;;;
;;;; Unless required by applicable law or agreed to in writing, software
;;;; distributed under the License is distributed on an "AS IS" BASIS,
;;;; WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
;;;; See the License for the specific language governing permissions and
;;;; limitations under the License.

;;; This file demonstrates how to use the Rigetti Forest API
;;; (http://forest.rigetti.com) by exposing the two most important
;;; functions: RUN and WAVEFUNCTION. Other, more advanced functions
;;; are supported by the API as well, but are not implemented
;;; here. This file is intended to be pedagogical and not production
;;; quality.
;;;
;;; The logic mostly follows the `forest` module of the open source
;;; library pyQuil, officially supported by Rigetti.
;;;
;;;     https://github.com/rigetticomputing/pyquil/blob/master/pyquil/forest.py

(in-package #:cl-forest)

(defparameter *endpoint* "https://api.rigetti.com/qvm")

(defvar *api-key* nil)

(defun check-api-key ()
  (unless (stringp *api-key*)
    (error "API key is not set. Set the variable CL-FOREST:*API-KEY* to ~
            a string containing your key.")))


;;; Helper function for JSON dictionaries.
(defun dict (&rest key-vals)
  (alexandria:plist-hash-table key-vals))


(defun post-json (json)
  "POST the JSON data structure (as interpreted by YASON) to Rigetti Forest.

Return two values:

    1. The response payload, either as a string, an octet vector, or a
       stream.

    2. The content length or NIL.
"
  (check-api-key)

  (multiple-value-bind (body status headers)
      (drakma:http-request
       *endpoint*
       :method ':post
       ;; Required for wavefunction output. See
       ;;
       ;;    https://github.com/rigetticomputing/pyquil/blob/master/pyquil/forest.py#L234
       :accept "application/octet-stream"
       :additional-headers `(("X-API-KEY" . ,*api-key*))
       :content (with-output-to-string (s)
                  (yason:encode json s)))

    ;; Check status.
    (unless (= 200 status)
      (error "Got a status that wasn't 200."))

    ;; Give the return value. The caller should handle what to do with
    ;; this value, which is either a string or a stream, as well as
    ;; the content length.
    (values body
            (ignore-errors
             (parse-integer (cdr (assoc ':content-length headers)))))))


;;; Corresponds to https://github.com/rigetticomputing/pyquil/blob/master/pyquil/forest.py#L293
(defun ping ()
  "Ping the Forest server."
  (values (post-json (dict "type" "ping"))))

(defun version ()
  "Query the version of the remote Forest software."
  (values (post-json (dict "type" "version"))))

;;; Helper function write write small snippets of raw Quil.
(defun quil (&rest instructions)
  "A helper function to make Quil program strings."
  (with-output-to-string (s)
    (loop :for instr :in instructions
          :do (write-line instr s))))


;;; Corresponds to https://github.com/rigetticomputing/pyquil/blob/master/pyquil/forest.py#L391
(defun run (program addresses &optional (num-trials 1))
  "Run the Quil program PROGRAM (as a string) a total number of
NUM-TRIALS (default: 1) times, reading the classical bits addressed by
the list of addresses ADDRESSES.

Return a list of lists of sampled bits corresponding to the requested
ADDRESSES.
"
  (yason:parse
   (post-json
    (dict "type" "multishot"
          "addresses" addresses
          "trials" num-trials
          "quil-instructions" program))))


(defconstant +octets-per-double+ 8)
(defconstant +octets-per-complex-double+ (* 2 +octets-per-double+))

;;; Corresponds to https://github.com/rigetticomputing/pyquil/blob/master/pyquil/forest.py#L311
(defun wavefunction (program &optional (addresses '()))
  "Get the wavefunctions for the program PROGRAM. Optionally, provide
a list of addresses of bits that should be returned as a second value.

Return two values:

    1. The wavefunction as an array of complex numbers.

    2. The requested memory addresses."
  (labels ((round-to-next (n m)
               (if (zerop (mod n m))
                   n
                   (- (+ n m)
                      (mod n m))))

           (octet-bits (octet)
             (loop :for i :below 8 :collect (ldb (byte 1 i) octet)))

           (decode-double (octets)
             (ieee-floats:decode-float64
              (reduce (lambda (bits octet)
                        (logior octet (ash bits 8)))
                      octets
                      :initial-value 0)))

           (recover-complexes (octets num-octets)
             (let* ((num-addresses (length addresses))
                    (num-mem-octets (floor (round-to-next num-addresses 8) 8))
                    (num-wf-octets (- num-octets num-mem-octets))
                    ;; Variables we calculate:
                    mem
                    (wf (make-array (/ num-wf-octets +octets-per-complex-double+))))
               ;; Get the classical memory.
               (loop :for i :below num-mem-octets
                     :append (octet-bits (aref octets i)) :into all-bits
                     :finally (setf mem (subseq all-bits 0 num-addresses)))

               ;; Get the wavefunction
               (loop :for i :from 0
                     :for p :from num-mem-octets :below num-octets :by +octets-per-complex-double+
                     :for re := (decode-double
                                 (subseq octets p (+ p +octets-per-double+)))
                     :for im := (decode-double
                                 (subseq octets
                                         (+ p +octets-per-double+)
                                         (+ p +octets-per-complex-double+)))
                     :do (setf (aref wf i) (complex re im)))

               ;; Return the wavefunction and memory..
               (values wf mem))))
    (multiple-value-bind (octets num-octets)
        (post-json
         (dict "type" "wavefunction"
               "quil-instructions" program
               "addresses" addresses))
      ;; Have to do a bit of decoding, since we got binary data
      ;; back. Wavefunctions can be huge!
      (recover-complexes octets num-octets))))

