(fn protocol [format-function fennel-module]
  (let [fennel-module (or fennel-module :fennel)
        (ok fennel) (pcall require fennel-module)]
    (if (not ok)
        (-> [[:id {:sym 0}]
             [:op {:string "init"}]
             [:status {:string "fail"}]
             [:data {:string (.. "unable to load Fennel from module: "
                                 (tostring fennel-module) "\n"
                                 (tostring fennel))}]]
            (setmetatable
             {:__fennelview
              (fn [data]
                ;; faking protocol environment for the format-function to work
                (format-function {:fennel {:view #(string.format "%q" $)}} data))}))
        (let [{: view : eval : traceback : parser :version fennel-version} fennel
              {:concat t/concat} table
              pack (fn [...] (doto [...] (tset :n (select :# ...))))
              unpack (or _G.unpack table.unpack)
              InternalError {}
              protocol-env (collect [k v (pairs _G)]
                             (when (or (not= k :_G)
                                       (not= k :___repl___))
                               (values k v)))
              protocol* {:version "0.6.4"
                         :id -1
                         :op nil
                         :env protocol-env}
              protocol {}
              protocol (->> {:__index protocol*
                             :__newindex
                             (fn [self k v]
                               (if (. protocol* k)
                                   (protocol.internal-error
                                    (: "modification of the protocol.%s field is forbidden" :format k))
                                   (rawset self k v)))}
                            (setmetatable protocol))]
          (doto protocol*.env
            (tset :_G protocol-env)
            (tset :fennel fennel)
            (tset :protocol protocol))

          (var expr-count 0)
          (var sending? false)
          (var reading? false)

          ;; Protocol methods
          (fn protocol.internal-error [cause message]
            (error {:type InternalError :cause cause :data message}))

          (set protocol*.internal-error protocol.internal-error)

          (set protocol.format #(format-function protocol*.env $))

          ;; protocol.message and protocol.receive are defined later

          ;; Protocol initialization
          (case _G.___repl___
            {:onValues on-values :readChunk read-chunk
             :env env :onError on-error :pp pp &as ___repl___}
            (let [{:fennel fennel-ver :lua lua-ver} (fennel.runtime-version true)
                  {:write io/write :read io/read
                   : stdin : stdout : stderr} env.io
                  {:write fd/write :read fd/read &as fd}
                  (. (getmetatable env.io.stdin) :__index)
                  lua-print print]

              (fn valid-fmt? [fmt]
                (or (= :number (type fmt))
                    (and (= :string (type fmt))
                         (not= nil (fmt:match "^%*?[nalL]")))))

              (fn read-one [fmt]
                (protocol.message [[:id {:sym protocol.id}]
                                   [:op {:string :read}]
                                   [:formats {:list [(view fmt)]}]])
                (let [data (. (protocol.receive protocol.id) :data)]
                  (if (and (= :string (type fmt)) (fmt:match "^%*?n"))
                      (tonumber data)
                      data)))

              (fn protocol.read [...]
                (let [formats (pack ...)]
                  (if (= 0 formats.n)
                      (read-one :l)
                      (let [res []]
                        (var n 0)
                        (var stop? false)
                        (for [i 1 formats.n &until stop?]
                          (let [fmt (. formats i)]
                            (when (not (valid-fmt? fmt))
                              (error (: "bad argument #%d to 'read' (invalid format)" :format i)))
                            (let [data (read-one fmt)]
                              (set n (+ n 1))
                              (tset res n data)
                              (when (= nil data)
                                (set stop? true)))))
                        (unpack res 1 n)))))

              (fn join [sep ...]
                ;; Concatenate multiple values into a string using `sep` as a
                ;; separator.
                (t/concat
                 (fcollect [i 1 (select :# ...)]
                   (tostring (select i ...))) sep))

              (fn install-io [env]
                ;; Install IO interceptors for current environment.
                (fn env.print [...]
                  (if sending?
                      (lua-print ...)
                      (do (env.io.write (.. (join "\t" ...) "\n")) nil)))
                (fn env.io.write [...]
                  (if sending?
                      (io/write ...)
                      (: (env.io.output) :write ...)))
                (fn env.io.read [...]
                  (if reading?
                      (io/read ...)
                      (let [input (env.io.input)]
                        (if (= input stdin)
                            (protocol.read ...)
                            (input:read ...)))))
                (fn fd.write [fd ...]
                  (if sending?
                      (fd/write fd ...)
                      (if (or (= fd stdout) (= fd stderr))
                          (protocol.message [[:id {:sym protocol.id}]
                                             [:op {:string :print}]
                                             [:descr {:string (if (= fd stdout) :stdout :stderr)}]
                                             [:data {:string (join "" ...)}]])
                          (fd/write fd ...)))
                  fd)
                (fn fd.read [fd ...]
                  (if reading?
                      (fd/read fd ...)
                      (if (= fd stdin)
                          (env.io.read ...)
                          (fd/read fd ...)))))

              (fn uninstall-io [env]
                ;; Resets IO to original handlers.
                (set env.print lua-print)
                (set env.io.write io/write)
                (set env.io.read io/read)
                (set fd.read fd/read)
                (set fd.write fd/write))

              (fn with-flag [set-flag! f]
                ;; uses `set-flag!` callback to manage protocol state
                ;; around call to `f`.
                (set-flag! true)
                (let [res (pack (pcall f))]
                  (set-flag! false)
                  (if (. res 1)
                      (unpack res 2 res.n)
                      (error (. res 2)))))

              (fn done [id]
                ;; Sends the message that processing the `id` is complete and
                ;; resets the `protocol.id`.
                (when (> id 0)
                  (set protocol*.id -1)
                  (protocol.message [[:id {:sym id}]
                                     [:op {:string :done}]])))

              (fn err [id ?kind mesg ?trace]
                ;; Sends back the error information and completes the
                ;; communication.
                (protocol.message [[:id {:sym id}]
                                   [:op {:string :error}]
                                   [:type {:string (if ?kind ?kind :runtime)}]
                                   [:data {:string mesg}]
                                   (when ?trace
                                     [:traceback {:string ?trace}])])
                (done id))

              (fn protocol.receive [id]
                ;; Read one message from the protocol environment. If
                ;; the received message doesn't correspond to the
                ;; current protocol.id, send a retry OP so the client
                ;; retries the message later.
                (let [mesg (with-flag #(set reading? $)
                             #(read-chunk {:stack-size 0}))]
                  (match (pcall eval mesg {:env {}})
                    (true {:id id &as response}) response
                    (true msg?) (do (protocol.message
                                     [[:id {:sym id}]
                                      [:op {:string :retry}]
                                      [:message {:string (fennel.view msg? {:one-line? true})}]])
                                    (protocol.receive id))
                    (false msg?) (err id nil (or msg? "failed to read data") nil))))

              (fn protocol.message [data]
                ;; General purpose way of sending messages to the editor.
                (with-flag #(set sending? $)
                  #(on-values [(protocol.format data)]))
                (io.flush))

              (fn count-expressions [data]
                ;; Counts the number of expressions in the given
                ;; string.  If the string fails to parse, returns 1 as
                ;; expression count, Because the expression will break
                ;; down the line.
                (let [(ok? n)
                      (pcall #(accumulate [i 0 _ _ (parser data)] (+ i 1)))]
                  (if ok? n 1)))

              (fn accept [id op msg callback]
                ;; Accept the message.  Sets the current ID to `id` and writes
                ;; back a message that the communication was successful.
                (when (not (= :number (type id)))
                  (protocol.internal-error "message ID must be a positive number" (view id)))
                (when (< id 1)
                  (protocol.internal-error "message ID must be greater than 0" id))
                (protocol.message [[:id {:sym id}]
                                   [:op {:string :accept}]])
                (set protocol*.id id)
                (set protocol*.op op)
                (set expr-count 1)
                (case op
                  :eval (set expr-count (count-expressions msg))
                  :downgrade (callback) ; downgrade passed as a callback
                  :exit (done id))
                (when (or (= msg "") (= 0 expr-count)) (done id))
                (.. (tostring msg) "\n"))

              (fn data [id data]
                ;; Sends the data back to the process and completes the
                ;; communication.
                (when (not= :string (type protocol.op))
                  (protocol.internal-error "protocol OP is not a string" (view protocol.op)))
                (when (not= protocol.op :nop)
                  (protocol.message [[:id {:sym id}]
                                     [:op {:string protocol.op}]
                                     [:values {:list (icollect [_ v (ipairs data)] (view v))}]]))
                (done id))

              (fn remove-locus [msg]
                ;; Removes error information from the message.
                (if (= :string (type msg))
                    (pick-values 1 (msg:gsub "^[^:]*:%d+:%s+" ""))
                    (view msg)))

              (fn downgrade []
                ;; Reset the REPL back to its original state.
                (uninstall-io env)
                (doto ___repl___
                  (tset :readChunk read-chunk)
                  (tset :onValues on-values)
                  (tset :onError on-error)
                  (tset :pp pp)))

              (fn protocol.env-set! [k v]
                ;; set key `k` to value `v` in the user environment
                (tset env k v))

              (fn upgrade []
                ;; Upgrade the REPL to use the protocol-based communication.
                (install-io env)
                (fn ___repl___.readChunk [{: stack-size &as parser-state}]
                  (if (> stack-size 0)
                      (error "incomplete message")
                      (let [msg (with-flag #(set reading? $)
                                  #(read-chunk parser-state))]
                        (case (and msg (eval msg {:env protocol.env}))
                          {: id :eval code} (accept id :eval code)
                          {: id :complete sym} (accept id :complete (.. ",complete " (tostring sym)))
                          {: id :doc sym} (accept id :doc (.. ",doc " (tostring sym)))
                          {: id :reload module} (accept id :reload (.. ",reload " (tostring module)))
                          {: id :find val} (accept id :find (.. ",find " (tostring val)))
                          {: id :compile expr} (accept id :compile (.. ",compile " (tostring expr)))
                          {: id :return expr} (accept id :return (.. ",return " (tostring expr)))
                          {: id :apropos re} (accept id :apropos (.. ",apropos " (tostring re)))
                          {: id :apropos-doc re} (accept id :apropos-doc (.. ",apropos-doc " (tostring re)))
                          {: id :apropos-show-docs re} (accept id :apropos-show-docs (.. ",apropos-show-docs " (tostring re)))
                          {: id :help ""} (accept id :help ",help")
                          {: id :reset ""} (accept id :reset ",reset")
                          {: id :exit ""} (accept id :exit ",exit")
                          {: id :downgrade ""} (accept id :downgrade "" downgrade)
                          {: id :nop ""} (accept id :nop "nil")
                          _ (protocol.internal-error "message did not conform to protocol" (view msg))))))
                (fn ___repl___.onValues [xs]
                  (set expr-count (- expr-count 1))
                  (when (= 0 expr-count)
                    (data protocol.id xs)))
                (fn ___repl___.onError [type* msg source]
                  (match (values type* msg)
                    (_ {:type InternalError : cause :data ?msg})
                    (err -1 :proto-repl (if ?msg (.. (tostring cause) ": " (remove-locus ?msg)) cause))
                    "Lua Compile"
                    (err protocol.id :lua
                         (.. "Bad code generated - likely a bug with the compiler:\n"
                             "--- Generated Lua Start ---\n"
                             (tostring source)
                             "\n--- Generated Lua End ---\n"))
                    "Runtime"
                    (err protocol.id :runtime
                         (remove-locus msg)
                         (traceback nil 3))
                    _ (err protocol.id (string.lower type*)
                           (remove-locus msg))))
                (fn ___repl___.pp [x] (view x))
                (protocol.message [[:id {:sym 0}]
                                   [:op {:string "init"}]
                                   [:status {:string "done"}]
                                   [:protocol {:string protocol*.version}]
                                   [:fennel {:string (or fennel-ver "unknown")}]
                                   [:lua {:string (or lua-ver "unknown")}]]))

              (upgrade))
            _
            ;; Bail out if the REPL doesn't expose the ___repl___ table or its
            ;; contents differ.  Fennelview is used to communicate back the
            ;; response in the protocol-based message format.
            (-> [[:id {:sym 0}]
                 [:op {:string "init"}]
                 [:status {:string "fail"}]
                 [:data {:string (.. "unsupported Fennel version: " (tostring fennel-version))}]]
                (setmetatable {:__fennelview #(protocol.format $)})))))))
