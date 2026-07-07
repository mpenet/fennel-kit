(local fennel (require :fennel))

(fn read-msg []
  (let [line (io.read :l)]
    (when line
      (let [n (tonumber line)]
        (when n (io.read n))))))

(fn reply [tag body]
  (io.write (.. tag "\n" body "\n"))
  (io.stdout:flush))

(var msg (read-msg))
(while msg
  (let [results (table.pack (pcall fennel.eval msg {:env _G :filename :eval}))
        ok (. results 1)]
    (if ok
      (let [vals (fcollect [i 2 results.n] (fennel.view (. results i)))]
        (reply :ok (table.concat vals "\t")))
      (reply :error (tostring (. results 2)))))
  (set msg (read-msg)))
