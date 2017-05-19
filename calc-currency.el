;;; calc-currency.el --- Fetches currency exchange rates for Calc

;; Author: J. W. Smith <jwsmith2spam at gmail dot com>
;; Keywords: calc, currency, exchange
;; Time-stamp: <2017-05-18 22:25:37 jws>

;;; Notes:

(require 'xml)  ;; to read XML files
(require 'cl)   ;; for the loop macro

;; The XML file containing the exchange rates
;; This one is provided by the European Union.
(defvar *exchange-rates-url* "https://www.ecb.europa.eu/stats/eurofxref/eurofxref-daily.xml")

;; Where to copy the exchange rates to
(defvar *exchange-rates-file* "/tmp/exchange.el")

;; How often to check for exchange rates
(defvar *exchange-rates-update-interval* 5)

;; The currency to use as the base for the final table
(defvar *base-currency* 'USD)

;; Names of currencies
(defvar *currency-names*
  '((USD . "United States dollar")
    (EUR . "European Union euro")
    (JPY . "Japanese yen")
    (BGN . "Bulgarian lev")
    (CZK . "Czech koruna")
    (DKK . "Danish kroner")
    (GBP . "British pound")
    (HUF . "Hungarian forint")
    (PLN . "Polish zloty")
    (RON . "Romanian new leu")
    (SEK . "Swedish krona")
    (CHF . "Swiss franc")
    (NOK . "Norwegian kroner")
    (HRK . "Croatian kuna")
    (RUB . "Russian ruble")
    (TRY . "Turkish new lira")
    (AUD . "Australian dollar")
    (BRL . "Brazilian real")
    (CAD . "Canadian dollar")
    (CNY . "Chinese yuan renminbi")
    (HKD . "Hong Kong dollar")
    (IDR . "Indonesian rupiah")
    (ILS . "Israeli new shekel")
    (INR . "Indian rupee")
    (KRW . "South Korean won")
    (MXN . "Mexican peso")
    (MYR . "Malaysian ringgit")
    (NZD . "New Zealand dollar")
    (PHP . "Philippine peso")
    (SGD . "Singaporean dollar")
    (THB . "Thai baht")
    (ZAR . "South African rand")))

(defun time-last-modified (file)
  "Return the time `file` was last modified, as a time value (e.g. like `current-time`)"
  (nth 5 (file-attributes file)))

(defun file-age (file)
  "Returns the number of days since `file` was last modified"
  (/ (float-time (time-subtract
                  (current-time)
                  (time-last-modified file)))
     (* 60 60 24)))

(defun download-exchange-rates ()
  "Download the latest exchange rates, return the file they were downloaded to"
  (let ((file (concat "/tmp/exchange." (format-time-string "%Y%m%d") ".xml")))
    (url-copy-file *exchange-rates-url* file t)
    file))

(defun assqv (key alist)
  "Finds `key` in `alist` and returns its `cdr`"
  (cdr (assq key alist)))

(defun process-currency (node)
  (let* ((attrs (xml-node-attributes node))
         (code (read (assqv 'currency attrs)))
         (rate (string-to-number (assqv 'rate attrs))))
    (cons code rate)))

(defun process-currency-rates ()
  (let* ((xml (xml-parse-file (download-exchange-rates)))
         (grandpappy-cube (xml-get-children (car xml) 'Cube))
         (pappy-cube (xml-get-children (car grandpappy-cube) 'Cube))
         (date (assq 'time (xml-node-attributes (car pappy-cube))))
         (baby-cubes (xml-get-children (car pappy-cube) 'Cube)))
    (cons (cons 'EUR 1)
          (loop for cube in baby-cubes
                collect (process-currency cube)))))

(defun build-currency-unit-table ()
  (let* ((rate-table (process-currency-rates))
         (base-rate (assqv *base-currency* rate-table))
         (base-desc (assqv *base-currency* *currency-names*))
         (rate-table-mod (assq-delete-all *base-currency* rate-table)))
    (cons (list *base-currency* nil base-desc)
          (loop for rate in rate-table
                collect (list
                         (car rate)
                         (format "%S / %f" *base-currency* (/ (cdr rate) base-rate))
                         (assqv (car rate) *currency-names*))))))

;; necessary for write-currency-unit-table to work properly
(setq-local eval-expression-print-length nil)
(defun write-currency-unit-table ()
  (write-region
   (pp (build-currency-unit-table))
   nil
   *exchange-rates-file*))

(defun check-currency-unit-table ()
  (if (or (not (file-readable-p *exchange-rates-file*))
          (> (file-age *exchange-rates-file*) *exchange-rates-update-interval*))
      (write-currency-unit-table)))

(defun read-currency-unit-table ()
  (with-temp-buffer
    (insert-file-contents *exchange-rates-file*)
    (read (buffer-string))))

;; FIXME I'll go back and try the following code:
;;  - if unit exists in math-additional-units, update that entry
;;  - otherwise, add unit

;; FIXME This probably isn't the best way to handle this!
(defun calc-undefine-unit-if-exists (unit)
  (condition-case nil
      (calc-undefine-unit unit)
    (error nil)))

;; FIXME And this probably isn't the best way to handle this!
(defun calc-currency-load ()
  (progn
    (check-currency-unit-table)
    (let ((currency-unit-table (read-currency-unit-table)))
      ;; For each unit of currency, undefine it in math-additional-units
      (loop for unit in currency-unit-table
            do (calc-undefine-unit-if-exists (car unit)))

      ;; Then, add math-standard-units to the units table
      (setq math-additional-units (append math-additional-units (read-currency-unit-table))
            math-units-table nil))))

(provide 'calc-currency)
