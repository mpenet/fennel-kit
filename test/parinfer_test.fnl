(local fennel (require :fennel))
(local p (fennel.dofile "lib/parinfer.fnl"))
(local repair p.repair)

(var passed 0)
(var failed 0)

(fn check [label input expected]
  (let [result (repair input)]
    (if (= result expected)
      (do
        (set passed (+ passed 1))
        (print (.. "PASS  " label)))
      (do
        (set failed (+ failed 1))
        (print (.. "FAIL  " label))
        (print (.. "  input:    " (string.format "%q" input)))
        (print (.. "  expected: " (string.format "%q" expected)))
        (print (.. "  got:      " (string.format "%q" result)))))))

;; -- no change needed --
(check "already-correct"        "(+ 1 2)"          "(+ 1 2)")
(check "already-correct-nested" "(fn foo [] (+ 1))" "(fn foo [] (+ 1))")
(check "empty-string"           ""                  "")

;; -- missing closers at EOF --
(check "missing-one"   "(+ 1 2"        "(+ 1 2)")
(check "missing-two"   "(fn foo [x"    "(fn foo [x])")
(check "missing-three" "(let [x (+ 1"  "(let [x (+ 1)])")

;; -- extraneous / misplaced closers --
(check "extra-close"       "(foo))"    "(foo)")
(check "mismatched-close"  "(foo]"     "(foo)")
(check "wrong-bracket"     "[foo)"     "[foo]")

;; -- indent-based closing --
(check "indent-close-fn"
  "(fn foo []\n  (+ 1 2)\n(fn bar []\n  3"
  "(fn foo []\n  (+ 1 2))\n(fn bar []\n  3)")

(check "indent-close-let"
  "(let [x 1\n      y 2]\n  (+ x y)\n(foo)"
  "(let [x 1\n      y 2]\n  (+ x y))\n(foo)")

;; -- comments are not parsed for delimiters --
(check "comment-unclosed"  "; (unclosed"         "; (unclosed")
(check "comment-in-code"   "(foo ; bar\n  baz)"  "(foo ; bar\n  baz)")

;; -- strings are not parsed for delimiters --
(check "string-parens"   "\"(not code)\""   "\"(not code)\"")
(check "string-in-code"  "(foo \"(bar)\")"  "(foo \"(bar)\")")

;; -- escaped quote inside string --
(check "escaped-quote"
  "(foo \"he said \\\"hi\\\"\")"
  "(foo \"he said \\\"hi\\\"\")")

;; -- mismatched closer mid-code repaired via indent --
(check "mismatched-mid"
  "(fn foo [x)\n  x\n"
  "(fn foo [x]\n  x\n)")

;; -- summary --
(print (.. "\n" passed " passed, " failed " failed"))
(when (> failed 0)
  (os.exit 1))
