(local ltreesitter (require :ltreesitter))

(local fennel-lang
  (ltreesitter.load (or (os.getenv :FENNEL_TS_PATH)
                        (error "FENNEL_TS_PATH not set"))
                    :fennel))

;; --- helpers ---

(fn read-file [path]
  (let [f (assert (io.open path :r) (.. "Cannot open: " path))
        s (f:read :*a)]
    (f:close)
    s))

(fn write-file [path content]
  (let [f (assert (io.open path :w) (.. "Cannot write: " path))]
    (f:write content)
    (f:close)))

(fn parse [source]
  (let [parser (fennel-lang:parser)
        tree (parser:parse_string source)]
    (tree:root)))

(fn find-node [node text]
  "Pre-order DFS: returns first node whose source() equals text."
  (if (= (node:source) text)
    node
    (do
      (var result nil)
      (var i 0)
      (let [count (node:child_count)]
        (while (and (< i count) (= result nil))
          (set result (find-node (node:child i) text))
          (set i (+ i 1))))
      result)))

;; --- operations ---

(fn edit [{:file file :old_sexp old :new_sexp new}]
  (let [source (read-file file)
        root (parse source)
        node (find-node root old)]
    (if (not node)
      {:success false :message (.. "No matching sexp found in " file)}
      (let [start (node:start_byte_offset)
            finish (node:end_byte_offset)]
        (write-file file (.. (source:sub 1 start) new (source:sub (+ finish 1))))
        {:success true :message (.. "Replaced sexp in " file)}))))

(fn delete [{:file file :sexp sexp}]
  (let [source (read-file file)
        root (parse source)
        node (find-node root sexp)]
    (if (not node)
      {:success false :message (.. "No matching sexp found in " file)}
      (let [start (node:start_byte_offset)
            finish (node:end_byte_offset)
            raw (.. (source:sub 1 start) (source:sub (+ finish 1)))]
        ;; collapse runs of 3+ newlines left by the removal
        (write-file file (raw:gsub "\n\n\n+" "\n\n"))
        {:success true :message (.. "Deleted sexp from " file)}))))

(fn insert [{:file file :anchor anchor :form form :position position}]
  (let [source (read-file file)
        root (parse source)
        node (find-node root anchor)]
    (if (not node)
      {:success false :message (.. "No matching anchor sexp found in " file)}
      (let [start (node:start_byte_offset)
            finish (node:end_byte_offset)
            new-source (if (= position :before)
                         (.. (source:sub 1 start) form "\n\n" (source:sub (+ start 1)))
                         (.. (source:sub 1 finish) "\n\n" form (source:sub (+ finish 1))))]
        (write-file file new-source)
        {:success true :message (.. "Inserted form " position " anchor in " file)}))))

(fn append [{:file file :form form}]
  (let [source (read-file file)
        trimmed (source:gsub "%s+$" "")]
    (write-file file (.. trimmed "\n\n" form "\n"))
    {:success true :message (.. "Appended form to " file)}))

(fn fmt-node [node depth]
  (let [indent (string.rep "  " depth)
        src (node:source)
        short (if (> (# src) 60) (.. (src:sub 1 60) "…") src)
        preview (short:gsub "\n" "↵")
        line (.. indent (node:type) "  " preview "\n")]
    (var out line)
    (var i 0)
    (let [count (node:named_child_count)]
      (while (< i count)
        (set out (.. out (fmt-node (node:named_child i) (+ depth 1))))
        (set i (+ i 1))))
    out))

(fn view-ast [{:file file :sexp sexp}]
  (let [source (read-file file)
        root (parse source)
        target (if (and sexp (not= sexp ""))
                 (find-node root sexp)
                 root)]
    (if (and sexp (not= sexp "") (not target))
      {:success false :message (.. "No matching sexp found in " file)}
      {:success true :message (fmt-node target 0)})))

{:edit edit
 :delete delete
 :insert insert
 :append append
 :view-ast view-ast}
