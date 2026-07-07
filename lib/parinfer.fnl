;;; Indent-mode parinfer fallback for Fennel.
;;; Used when parinfer-rust is not available.
;;;
;;; Algorithm: scan characters, track open-delimiter stack.
;;; At each new line, pop openers whose column >= current indent and
;;; insert their closers at the end of the previous line.
;;; At EOF, append any remaining closers.
;;;
;;; Limitations vs parinfer-rust:
;;;   - does not remove extraneous closing delimiters mid-code
;;;   - does not handle paren mode
;;;   - sufficient for fixing LLM-generated missing-closer errors

(local openers {"(" true "[" true "{" true})
(local closer-of {"(" ")" "[" "]" "{" "}"})
(local closers {")" true "]" true "}" true})

(fn tokenize-line [line]
  "Return a sequence of {:type :col :ch} tokens for one line."
  (let [tokens []]
    (var i 1)
    (var in-string false)
    (var escape false)
    (while (<= i (# line))
      (let [c (line:sub i i)]
        (if escape
          (do
            (table.insert tokens {:type :char :col i :ch c})
            (set escape false))
          (if in-string
            (do
              (table.insert tokens {:type :str-char :col i :ch c})
              (if (= c "\\")
                (set escape true)
                (when (= c "\"")
                  (set in-string false))))
            (if (= c ";")
              (do
                (table.insert tokens {:type :comment :col i
                                      :ch (line:sub i)})
                (set i (+ (# line) 1)))
              (if (= c "\"")
                (do
                  (table.insert tokens {:type :str-open :col i :ch c})
                  (set in-string true))
                (if (. openers c)
                  (table.insert tokens {:type :open :col i :ch c})
                  (if (. closers c)
                    (table.insert tokens {:type :close :col i :ch c})
                    (table.insert tokens {:type :char :col i :ch c}))))))))
      (set i (+ i 1)))
    tokens))

(fn indent-of [line]
  "Number of leading spaces on a non-empty line."
  (let [s (line:match "^( *)")]
    (if s (# s) 0)))

(fn content? [line]
  "True if line has non-whitespace, non-comment content."
  (line:match "^%s*[^;%s]"))

(fn repair [source]
  (let [raw-lines (icollect [l (source:gmatch "[^\n]*\n?")] l)
        out []]
    (var stack [])  ;; [{:ch :col :closer}]
    (var pending-closers "")

    (each [_ raw (ipairs raw-lines)]
      (let [line (raw:gsub "\n$" "")
            nl (if (raw:match "\n$") "\n" "")]

        ;; On content lines: pop openers whose col >= indent and flush closers
        (when (content? line)
          (let [ind (indent-of line)]
            (while (and (> (# stack) 0)
                        (>= (. stack (# stack) :col) ind))
              (let [top (table.remove stack)]
                (set pending-closers (.. pending-closers top.closer))))))

        ;; Flush pending closers onto the previous output line
        (when (> (# pending-closers) 0)
          (when (> (# out) 0)
            (tset out (# out) (.. (. out (# out)) pending-closers)))
          (set pending-closers ""))

        ;; Process tokens to update the stack
        (let [tokens (tokenize-line line)]
          (each [_ tok (ipairs tokens)]
            (when (= tok.type :open)
              (table.insert stack {:ch tok.ch
                                   :col (- tok.col 1)  ;; 0-indexed
                                   :closer (. closer-of tok.ch)}))
            (when (= tok.type :close)
              (when (and (> (# stack) 0)
                         (= (. stack (# stack) :closer) tok.ch))
                (table.remove stack)))))

        (table.insert out (.. line nl))))

    ;; Append any remaining closers at EOF
    (when (> (# stack) 0)
      (let [tail (table.concat
                  (fcollect [i (# stack) 1 -1] (. stack i :closer)) "")]
        (tset out (# out) (.. (or (. out (# out)) "") tail))))

    (table.concat out "")))

;; Standalone: read stdin, repair, write stdout
(io.write (repair (io.read :*a)))
