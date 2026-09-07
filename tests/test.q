/ q-sys test suite - run from the repo root:  q tests/test.q -q
/ Exits 0 on success, 1 on any failure.

\l q/sys.q

.t.n:0
.t.f:0
.t.ok:{[d;b] .t.n+:1; $[b; -1 "  ok   ",d; [.t.f+:1; -2 "  FAIL ",d]]; }
.t.eq:{[d;a;b] .t.ok[d; a~b]}
.t.thrown:{[d;f] .t.ok[d; `err~@[{x[]; `no}; f; {`err}]]}

-1 "q-sys ",.sys.version," -- tests";
-1 "";

/ --- core executor ---------------------------------------------------
.t.ok["version is a string"; 10h=type .sys.version];
.t.ok["port getter returns an int"; type[.sys.port[]] in -6 -7h];
.t.ok[".sys.run accepts a symbol"; not `dryRun~@[{.sys.run `P; 1b}; ::; {0b}]];

/ --- dry run: nothing should actually change ------------------------
p0:.sys.precision[];
.sys.dryRun:1b;
.t.eq["dryRun setter returns `dryRun"; .sys.setPrecision 3; `dryRun];
.t.eq["dryRun left precision untouched"; .sys.precision[]; p0];
.sys.dryRun:0b;

/ --- verbose echoes to stderr, still executes ---------------------
.sys.verbose:1b;
.sys.setPrecision 5;
.sys.verbose:0b;
.t.ok["verbose still applied the change"; 5 = .sys.precision[]];
.sys.setPrecision p0;
.t.eq["precision restored"; .sys.precision[]; p0];

/ --- snapshot / diff / restore ----------------------------------
snap:.sys.snapshot[];
.t.ok["snapshot is a dict"; 99h=type snap];
.t.ok["snapshot has the settings keys"; all `port`precision`timer`cwd in key snap];
.sys.setPrecision 9;
.sys.setTimer 0;
d:.sys.diff snap;
.t.ok["diff is a table"; 98h=type d];
.t.ok["diff caught the precision change"; `precision in d`setting];
.sys.restore snap;
.t.eq["restore put precision back"; .sys.precision[]; snap`precision];
.t.eq["restore put the timer back"; .sys.timer[]; snap`timer];

/ --- .sys.with: scoped settings -------------------------------
r:.sys.with[(enlist `precision)!enlist 3; {system"P"}];
.t.ok[".sys.with saw the override inside the thunk"; 3 = r];
.t.eq[".sys.with restored precision afterwards"; .sys.precision[]; snap`precision];
.t.thrown[".sys.with rethrows a thunk error"; {.sys.with[(enlist `precision)!enlist 3; {'"boom"}]}];
.t.eq[".sys.with still restored precision after a throw"; .sys.precision[]; snap`precision];

/ --- reference table + manual --------------------------------
ref:.sys.help[];
.t.ok["help[] is a table"; 98h=type ref];
.t.ok["help[] has a decent number of rows"; 20 < count ref];
.t.eq["help[`p] returns exactly one row"; count .sys.help[`p]; 1];
.t.ok["help[`session] filters by kind"; all `session = exec kind from .sys.help[`session]];
.t.ok["man`p prints something"; 10h = type .sys.i.manText`p];

/ --- timing --------------------------------------------------
ts:.sys.ts "2+2";
.t.ok[".sys.ts returns a 2-item numeric list"; 2 = count ts];

/ --- namespace introspection --------------------------------
.t.ok["tablesIn returns a symbol list"; 11h = type .sys.tablesIn[]];
.t.ok["varsIn[`.sys] finds our own globals"; `version in .sys.varsIn[`.sys]];

/ --- OS shell -----------------------------------------------
out:.sys.sh "echo q-sys-marker";
.t.ok["shell echo came back"; any out like "*q-sys-marker*"];
.t.eq["tryShell wraps success as (1b;lines)"; first .sys.tryShell "echo hi"; 1b];
.t.eq["tryShell wraps failure as (0b;...)"; first .sys.tryShell "definitely-not-a-real-command-xyz"; 0b];

/ --- shell guard ------------------------------------------
.sys.deny:enlist "rm *";
.t.thrown["deny list blocks a matching command"; {.sys.sh "rm somefile"}];
.t.ok["deny list lets an unrelated command through"; any (.sys.sh "echo ok") like "*ok*"];
.sys.deny:();
.sys.allow:enlist "echo *";
.t.thrown["allow list blocks a non-matching command"; {.sys.sh "cat x"}];
.t.ok["allow list permits a matching command"; any (.sys.sh "echo ok") like "*ok*"];
.sys.allow:();

/ --- env --------------------------------------------------
.t.ok["env reads PATH"; 0 < count .sys.env `PATH];
.sys.setenv[`QSYS_TEST; "42"];
.t.eq["setenv round-trips"; .sys.env `QSYS_TEST; "42"];

/ --- files ----------------------------------------------
.t.ok["exists[] is true for the loaded library"; .sys.exists "q/sys.q"];
.t.ok["exists[] is false for a missing path"; not .sys.exists "q/nope.q"];
.t.ok["ls[] lists the q directory"; `sys.q in .sys.ls "q"];

/ --- terminate guard --------------------------------------
.t.thrown["terminate refuses without .sys.allowExit"; {.sys.terminate 0}];

-1 "";
-1 "ran ",string[.t.n],", failed ",string .t.f;
exit .t.f>0
