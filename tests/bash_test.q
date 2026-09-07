/ q-sys bash.q test suite - run from the repo root:  q tests/bash_test.q -q
/ Exits 0 on success, 1 on any failure. Needs `bash` on PATH (or Git-for-Windows).

\l q/bash.q

.t.n:0
.t.f:0
.t.ok:{[d;b] .t.n+:1; $[b; -1 "  ok   ",d; [.t.f+:1; -2 "  FAIL ",d]]; }
.t.eq:{[d;a;b] .t.ok[d; a~b]}
.t.thrown:{[d;f] .t.ok[d; `err~@[{x[]; `no}; f; {`err}]]}

-1 "q-sys.bash -- tests  (bin: ",.sys.bash.bin,")";
-1 "";

/ --- run: rc / out / err -------------------------------------------
r:.sys.bash.run "echo hello";
.t.ok["run returns a `rc`out`err dict"; (99h=type r) and all `rc`out`err in key r];
.t.eq["stdout captured"; r`out; enlist "hello"];
.t.eq["rc is 0 on success"; r`rc; 0i];
.t.eq["err empty on success"; r`err; ()];

r:.sys.bash.run "echo oops >&2; exit 3";
.t.eq["non-zero rc captured, not signalled"; r`rc; 3i];
.t.eq["stderr captured separately"; r`err; enlist "oops"];
.t.eq["stdout empty here"; r`out; ()];

/ --- stdout / stderr really are separate -------------------------
r:.sys.bash.run "echo out; echo err >&2";
.t.eq["out stream"; r`out; enlist "out"];
.t.eq["err stream"; r`err; enlist "err"];

/ --- multi-line script + exit code of the last command ----------
r:.sys.bash.script "a=2\nb=3\necho done-$((a*b))\nfalse";
.t.eq["script ran, arithmetic worked"; first r`out; "done-6"];
.t.eq["script rc is the last command's"; r`rc; 1i];

/ --- sh: signals on failure, returns lines on success ----------
.t.eq["sh returns stdout lines"; .sys.bash.sh "printf '%s\\n' aa bb cc"; ("aa";"bb";"cc")];
.t.thrown["sh signals on non-zero exit"; {.sys.bash.sh "exit 7"}];

/ --- try / ok / rc / line -------------------------------------
.t.eq["try is a (rc;out;err) tuple"; .sys.bash.try "echo hi"; (0i; enlist "hi"; ())];
.t.ok["ok is 1b on success"; .sys.bash.ok "true"];
.t.ok["ok is 0b on failure"; not .sys.bash.ok "false"];
.t.eq["rc of `false` is 1"; .sys.bash.rc "false"; 1i];
.t.eq["line trims and takes the first line"; .sys.bash.line "printf '  spaced  \\n next '"; "spaced"];

/ --- pipe: stdin ------------------------------------------------
.t.eq["pipe feeds stdin (string)"; .sys.bash.pipe["cc\naa\nbb"; "sort"]`out; ("aa";"bb";"cc")];
.t.eq["pipe feeds stdin (lines)"; .sys.bash.pipe[("bb";"aa"); "sort"]`out; ("aa";"bb")];
.t.ok["pipe wc -l over stdin"; any .sys.bash.pipe[("xx";"yy";"zz"); "wc -l"][`out] like "*3*"];

/ --- spawn: detached, non-blocking ---------------------------
lg:.sys.bash.i.tmpdir,"/qsys_spawn_test_",(string .z.i),".log";
@[hdel; hsym `$lg; {}];
t0:.z.p;
.sys.bash.spawn["sleep 2; echo done-spawning"; lg];
.t.ok["spawn returns immediately"; 0D00:00:01 > .z.p - t0];
system "sleep 4";
.t.ok["spawned job ran and wrote its log"; any (@[read0; hsym `$lg; {()}]) like "*done-spawning*"];
@[hdel; hsym `$lg; {}];

/ --- guard + dryRun ------------------------------------------
.sys.deny:enlist "rm *";
.t.thrown["deny guard blocks a matching command"; {.sys.bash.run "rm -rf /"}];
.sys.deny:();
.sys.dryRun:1b;
r:.sys.bash.run "echo should-not-run";
.t.eq["dryRun does not execute"; r`out; enlist "dryRun"];
.sys.dryRun:0b;

/ --- q-native wrappers -------------------------------------
e:.sys.bash.env[];
.t.ok["env is a non-empty dict"; (99h=type e) and 0<count e];
.t.ok["env has PATH"; `PATH in key e];
.t.ok["whoami returns a symbol"; -11h=type .sys.bash.whoami[]];
.t.ok["pwd is a non-empty string"; 0<count .sys.bash.pwd[]];
.t.ok["has: bash is present"; .sys.bash.has `bash];
.t.ok["has: bogus command absent"; not .sys.bash.has `no_such_cmd_zzz];
.t.ok["which bash resolves to a path"; 0<count .sys.bash.which `bash];

/ --- ls table ---------------------------------------------
t:.sys.bash.ls "q";
.t.ok["ls returns a table"; 98h=type t];
.t.ok["ls found sys.q"; `sys.q in t`name];
.t.ok["ls has a numeric size column"; 7h=type t`size];
.t.ok["ls mtime is a timestamp column"; 12h=type t`mtime];
.t.ok["ls mtime is a sane recent date"; all (t`mtime) within (2015.01.01D0; .z.p+1D)];

/ --- wc / cat / grep -----------------------------------
.t.ok["wc counts lines of a real file"; 10 < .sys.bash.wc "q/bash.q"];
.t.ok["cat reads a file"; any (.sys.bash.cat "LICENSE") like "*MIT*"];
.t.ok["grep finds a known line"; 0 < count .sys.bash.grep["sys.bash"; "q/bash.q"]];
.t.eq["grep with no match returns empty"; .sys.bash.grep["zzz_no_such_token_zzz"; "LICENSE"]; ()];

/ --- info -----------------------------------------------
.t.ok["info reports the resolved bin"; .sys.bash.info[][`bin] ~ .sys.bash.bin];
.t.ok["help[] is a table"; 98h=type .sys.bash.help[]];
.t.eq["help[`run] is one row"; count .sys.bash.help[`run]; 1];

-1 "";
-1 "ran ",string[.t.n],", failed ",string .t.f;
exit .t.f>0
