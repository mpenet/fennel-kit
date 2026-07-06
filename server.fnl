(local json (require :cjson))
(local tool (require :fennel_edit))

(fn send! [msg]
  (io.write (json.encode msg))
  (io.write "\n")
  (io.stdout:flush))

(fn respond [id result]
  (send! {:jsonrpc :2.0 :id id :result result}))

(fn respond-error [id code message]
  (send! {:jsonrpc :2.0 :id id :error {:code code :message message}}))

(fn mk-result [result]
  {:content [{:type :text :text result.message}]
   :isError  (not result.success)})

(local tools
  [{:name :fennel_edit
    :description "Replace an S-expression in a Fennel file. Locates the form by exact text match via tree-sitter (validates it is a real AST node), then replaces its byte range. Refuses to match partial or structurally invalid nodes."
    :inputSchema {:type :object
                  :required [:file :old_sexp :new_sexp]
                  :properties {:file     {:type :string :description "Path to the .fnl file"}
                               :old_sexp {:type :string :description "Exact source text of the S-expression to replace"}
                               :new_sexp {:type :string :description "Replacement text"}}}}
   {:name :fennel_delete
    :description "Delete an S-expression from a Fennel file. Finds the form by exact text match, removes its byte range, and collapses leftover blank lines."
    :inputSchema {:type :object
                  :required [:file :sexp]
                  :properties {:file {:type :string :description "Path to the .fnl file"}
                               :sexp {:type :string :description "Exact source text of the S-expression to delete"}}}}
   {:name :fennel_insert
    :description "Insert a new form before or after an existing anchor S-expression in a Fennel file."
    :inputSchema {:type :object
                  :required [:file :anchor :form :position]
                  :properties {:file     {:type :string :description "Path to the .fnl file"}
                               :anchor   {:type :string :description "Exact source text of the anchor S-expression"}
                               :form     {:type :string :description "New form to insert"}
                               :position {:type :string :enum [:before :after] :description "Insert before or after the anchor"}}}}
   {:name :fennel_append
    :description "Append a new top-level form at the end of a Fennel file."
    :inputSchema {:type :object
                  :required [:file :form]
                  :properties {:file {:type :string :description "Path to the .fnl file"}
                               :form {:type :string :description "Form to append"}}}}
   {:name :fennel_view_ast
    :description "Show the tree-sitter AST of a Fennel file as indented text. Optionally scope to a specific S-expression. Use this to understand code structure before editing."
    :inputSchema {:type :object
                  :required [:file]
                  :properties {:file {:type :string :description "Path to the .fnl file"}
                               :sexp {:type :string :description "Optional: exact source text of a form to scope the view to"}}}}])

(local dispatch
  {:fennel_edit     #(tool.edit $)
   :fennel_delete   #(tool.delete $)
   :fennel_insert   #(tool.insert $)
   :fennel_append   #(tool.append $)
   :fennel_view_ast #(tool.view-ast $)})

(fn handle-tool-call [id params]
  (let [name    params.name
        handler (. dispatch name)]
    (if handler
      (let [(ok result) (pcall handler params.arguments)]
        (respond id (if ok
                      (mk-result result)
                      {:content [{:type :text :text (tostring result)}]
                       :isError true})))
      (respond-error id -32601 (.. "Unknown tool: " name)))))

(fn handle [req]
  (let [method req.method
        id     req.id]
    (match method
      :initialize
      (respond id {:protocolVersion :2024-11-05
                   :capabilities    {:tools {:listChanged false}}
                   :serverInfo      {:name :fennel-mcp :version :0.1.0}})

      :tools/list
      (respond id {:tools tools})

      :tools/call
      (handle-tool-call id req.params)

      :notifications/initialized nil

      _
      (when id
        (respond-error id -32601 (.. "Method not found: " method))))))

(io.stderr:write "fennel-mcp started\n")
(io.stderr:flush)

(each [line (io.lines)]
  (when (> (# line) 0)
    (let [(ok req) (pcall json.decode line)]
      (if ok
        (handle req)
        (io.stderr:write (.. "JSON decode error: " (tostring req) "\n"))))))
