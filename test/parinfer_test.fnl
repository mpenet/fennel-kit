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

(check "nested-three-deep" "(a (b (c" "(a (b (c)))")

(check "mixed-bracket-nested" "(let [x {:a 1" "(let [x {:a 1}])")

(check "blank-line-no-close"
  "(fn foo []\n\n  x\n"
  "(fn foo []\n\n  x\n)")

(check "comment-line-no-close"
  "(fn foo []\n  ;; body\n  x\n"
  "(fn foo []\n  ;; body\n  x\n)")

(check "whitespace-line-no-close"
  "(fn foo []\n   \n  x\n"
  "(fn foo []\n   \n  x\n)")

(check "two-levels-at-once"
  "(a\n  (b\n    c\n(d"
  "(a\n  (b\n    c))\n(d)")

(check "table-missing-close" "{:a 1 :b 2" "{:a 1 :b 2}")

(check "empty-parens" "()" "()")

(check "empty-brackets" "[]" "[]")

(check "empty-braces" "{}" "{}")

(check "string-close-paren" "(foo \"bar)\" baz" "(foo \"bar)\" baz)")

(check "interleaved-brackets" "([x)" "([x])")

(check "multi-wrong-close" "(foo})" "(foo)")

;; -- summary --
(print (.. "\n" passed " passed, " failed " failed"))
(when (> failed 0)
  (os.exit 1))
