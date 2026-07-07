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

(fn normalize [s]
  (let [s2 (: (or s "") :gsub "%s+" " ")]
    (or (s2:match "^%s*(.-)%s*$") "")))

(fn find-all-nodes [node norm-text acc]
  "Pre-order DFS: collects matching nodes into acc, stops once 2 found."
  (when (= (normalize (node:source)) norm-text)
    (table.insert acc node))
  (when (< (# acc) 2)
    (var i 0)
    (let [count (node:child_count)]
      (while (and (< i count) (< (# acc) 2))
        (find-all-nodes (node:child i) norm-text acc)
        (set i (+ i 1)))))
  acc)

;; --- operations ---

(fn text->pattern [s]
  (let [escaped (s:gsub "([%(%)%.%%%+%-%*%?%[%]%^%$])" "%%%1")]
    (escaped:gsub "%s+" "%%s+")))

(fn find-range [source root text]
  "Tries AST match, exact substring, then pattern. Returns start, finish, node-or-nil, err-or-nil."
  (let [matches (find-all-nodes root (normalize text) [])
        n (# matches)
        pat (text->pattern text)]
    (if (> n 1)
      (values nil nil nil "ambiguous: text matches multiple nodes")
      (let [node (. matches 1)]
        (if node
          (values (node:start_byte_offset) (node:end_byte_offset) node nil)
          (let [(s e) (source:find text 1 true)]
            (if s
              (if (source:find text (+ e 1) true)
                (values nil nil nil "ambiguous: text matches multiple locations")
                (values (- s 1) e nil nil))
              (let [(s e) (source:find pat)]
                (if s
                  (if (source:find pat (+ e 1))
                    (values nil nil nil "ambiguous: text matches multiple locations")
                    (values (- s 1) e nil nil))
                  (values nil nil nil nil))))))))))

(fn edit [{:file file :old_sexp old :new_sexp new}]
  (let [source (read-file file)
        root (parse source)
        (start finish _ err) (find-range source root old)]
    (if (or err (not start))
      {:success false :message (or err (.. "No matching sexp found in " file))}
      (do
        (write-file file (.. (source:sub 1 start) new (source:sub (+ finish 1))))
        {:success true :message (.. "Replaced sexp in " file)}))))

(fn delete [{:file file :sexp sexp}]
  (let [source (read-file file)
        root (parse source)
        (start finish _ err) (find-range source root sexp)]
    (if (or err (not start))
      {:success false :message (or err (.. "No matching sexp found in " file))}
      (let [raw (.. (source:sub 1 start) (source:sub (+ finish 1)))]
        ;; collapse runs of 3+ newlines left by the removal
        (write-file file (raw:gsub "\n\n\n+" "\n\n"))
        {:success true :message (.. "Deleted sexp from " file)}))))

(fn insert [{:file file :anchor anchor :form form :position position}]
  (let [source (read-file file)
        root (parse source)
        (start finish _ err) (find-range source root anchor)]
    (if (or err (not start))
      {:success false :message (or err (.. "No matching anchor sexp found in " file))}
      (let [new-source (if (= position :before)
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
        (start finish node err) (if (and sexp (not= sexp ""))
                                  (find-range source root sexp)
                                  (values nil nil root nil))]
    (if (or err (and sexp (not= sexp "") (not start)))
      {:success false :message (or err (.. "No matching sexp found in " file))}
      (let [target (or node (parse (source:sub (+ start 1) finish)))]
        {:success true :message (fmt-node target 0)}))))

{:edit edit
 :delete delete
 :insert insert
 :append append
 :view-ast view-ast}
