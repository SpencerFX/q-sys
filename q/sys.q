/ q-sys - a kdb+ library focused on q system commands
/ ---------------------------------------------------------------------------
/ Everything lives under the .sys namespace. Single file: load with
/   \l q/sys.q        (from the repo root)   or   q q/sys.q
/ -
/ What it gives you:
/   * .sys.run / .sys.sh      - one protected entry point for \-commands and
/                               for OS shell-outs, with a dry-run mode, an
/                               optional echo, and a shell allow/deny guard
/   * typed getters + setters  - .sys.port[] / .sys.setPort 5000, etc.
/   * introspection            - namespace tables/vars/funcs, \ts timing, expunge
/   * snapshot / diff / restore / with - capture the session's settings, see
/                               what changed, put them back
/   * .sys.help[] / .sys.man`p - a reference table and short manual entries
/ -
/ Notes for the reader: definitions are written fully-qualified at column 0
/ (no \d) on purpose - it sidesteps a pile of namespace-context quirks in this
/ kdb+ build. Every top-level statement is kept to a single line; multi-line
/ bodies only ever appear inside {}.
/ ---------------------------------------------------------------------------

.sys.version:"0.1.0"

/ ----- configuration / safety switches --------------------------------------
.sys.dryRun:0b        / 1b => commands are echoed and NOT executed (returns `dryRun)
.sys.verbose:0b       / 1b => every command is written to stderr before running
.sys.trap:1b          / 1b => a failure re-signals with the command as context
.sys.deny:()          / list of glob patterns; a shell cmd matching any is refused
.sys.allow:()         / list of glob patterns; if non-empty a shell cmd must match one
.sys.allowExit:0b     / guard: .sys.terminate refuses to exit unless this is 1b

/ ----- internals ----------------------------------------------------------
.sys.i.win:.z.o in `w32`w64`wp64
.sys.i.log:{[m] if[.sys.verbose; -2 "[q-sys] ",m]; }
.sys.i.str:{$[10h=type x; x; -10h=type x; enlist x; -11h=type x; string x; 11h=type x; " " sv string x; -1h>type x; " " sv string x; .Q.s1 x]}
.sys.i.aslist:{$[10h=type x; enlist x; 0h=type x; x; enlist x]}
.sys.i.qpath:{[p] p:$[10h=type p; p; -11h=type p; 1 _ string p; string p]; p:$[.sys.i.win; ssr[p;"/";"\\"]; p]; "\"",p,"\""}
.sys.i.nsstr:{$[(::)~x; ""; -11h=type x; string x; 10h=type x; x; ""]}

.sys.i.check:{[cmd]
  dp:.sys.i.aslist .sys.deny;
  ap:.sys.i.aslist .sys.allow;
  if[count dp; if[any cmd like/: dp; '"q-sys: blocked by .sys.deny: ",cmd]];
  if[count ap; if[not any cmd like/: ap; '"q-sys: not permitted by .sys.allow: ",cmd]];
  cmd }

/ ----- core executors ----------------------------------------------------
/ .sys.run - run a q system command such as "p 5000", "P 10", "ts 2+2".
/ Accepts a string or a symbol. Honours .sys.dryRun / .sys.verbose / .sys.trap.
.sys.run:{[cmd]
  cmd:.sys.i.str cmd;
  .sys.i.log cmd;
  if[.sys.dryRun; :`dryRun];
  $[.sys.trap; @[system; cmd; {[c;e] '"q-sys: ",e," | while running: \\",c}[cmd]]; system cmd] }

.sys.raw:.sys.run   / alias

/ .sys.sh - shell out to the OS. Returns the command's stdout as a list of
/ strings (one per line). Runs the allow/deny guard first.
.sys.sh:{[cmd]
  cmd:.sys.i.check .sys.i.str cmd;
  .sys.i.log "$ ",cmd;
  if[.sys.dryRun; :`dryRun];
  $[.sys.trap; @[system; cmd; {[c;e] '"q-sys: shell failed: ",e," | ",c}[cmd]]; system cmd] }

.sys.shl:{[cmd] r:.sys.sh cmd; $[`dryRun~r; r; "\n" sv r]}          / output as one string
.sys.tryShell:{[cmd] @[{(1b; .sys.sh x)}; cmd; {(0b; enlist x)}]}   / never signals -> (ok;lines)

/ ----- session settings: getters + setters -----------------------------
.sys.port:{system"p"}
.sys.setPort:{[p] .sys.run "p ",string p}
.sys.precision:{system"P"}
.sys.setPrecision:{[n] .sys.run "P ",string n}
.sys.console:{system"c"}
.sys.setConsole:{[rc] .sys.run "c ",(" " sv string `long$rc)}
.sys.http:{system"C"}
.sys.setHttp:{[rc] .sys.run "C ",(" " sv string `long$rc)}
.sys.errorTrap:{system"e"}
.sys.setErrorTrap:{[m] .sys.run "e ",string m}
.sys.gcMode:{system"g"}
.sys.setGcMode:{[m] .sys.run "g ",string m}
.sys.threads:{system"s"}
.sys.setThreads:{[n] .sys.run "s ",string n}
.sys.timer:{system"t"}
.sys.setTimer:{[ms] .sys.run "t ",string ms}
.sys.timeout:{system"T"}
.sys.setTimeout:{[s] .sys.run "T ",string s}
.sys.weekOffset:{system"W"}
.sys.setWeekOffset:{[n] .sys.run "W ",string n}
.sys.dateFormat:{system"z"}
.sys.setDateFormat:{[n] .sys.run "z ",string n}
.sys.utcOffset:{`int$(.z.P - .z.p)%0D01:00:00}   / local hours ahead of UTC (\o is display-only)

/ ----- workspace / memory ---------------------------------------------
.sys.ws:{system"w"}          / raw list: used heap peak wmax mmap mphy syms symw
.sys.memory:{.Q.w[]}         / same numbers, labelled
.sys.collect:{.Q.gc[]}       / force garbage collection -> bytes returned to the OS

/ ----- files / working directory / loading --------------------------
.sys.cwd:{r:system"cd"; $[10h=type r; r; first r]}
.sys.cd:{[p] .sys.run "cd ",$[10h=type p; p; string p]}
.sys.load:{[p] .sys.run "l ",$[10h=type p; p; string p]}
.sys.rename:{[s;d] .sys.run "r ",(.sys.i.qpath s)," ",.sys.i.qpath d}
.sys.redirectOut:{[p] .sys.run "1 ",$[10h=type p; p; string p]}
.sys.redirectErr:{[p] .sys.run "2 ",$[10h=type p; p; string p]}

/ ----- namespace introspection --------------------------------------
.sys.namespace:{system"d"}
.sys.setNamespace:{[ns] .sys.run "d ",$[-11h=type ns; string ns; ns]}
.sys.tablesIn:{[ns] system "a ",.sys.i.nsstr ns}
.sys.funcsIn:{[ns] system "f ",.sys.i.nsstr ns}
.sys.varsIn:{[ns] system "v ",.sys.i.nsstr ns}
.sys.expunge:{[name] .sys.run "x ",$[-11h=type name; string name; name]}
.sys.brokenViews:{system"b"}
.sys.pendingViews:{system"B"}

/ ----- timing --------------------------------------------------------
.sys.ts:{[expr] system "ts ",.sys.i.str expr}                       / -> time(ms) space(bytes)
.sys.tsn:{[n;expr] system "ts:",(string n)," ",.sys.i.str expr}     / average over n runs
.sys.elapsed:{[expr] system "t ",.sys.i.str expr}                   / just the ms, via \t

/ ----- this process ------------------------------------------------
.sys.pid:{.z.i}
.sys.host:{.z.h}
.sys.qversion:{.z.K}
.sys.qbuild:{.z.k}
.sys.argv:{.z.x}
.sys.cmdline:{.z.X}
.sys.terminate:{[code] if[not .sys.allowExit; '"q-sys: refusing to exit; set .sys.allowExit:1b to allow"]; exit code}

/ ----- OS helpers (branch on .z.o) --------------------------------
.sys.env:{[n] getenv $[-11h=type n; n; `$n]}
.sys.setenv:{[n;v] setenv[$[-11h=type n; n; `$n]; $[10h=type v; v; string v]]}
.sys.ls:{[p] key hsym $[-11h=type p; p; `$$[10h=type p; p; string p]]}
.sys.exists:{[p] not ()~key hsym $[-11h=type p; p; `$$[10h=type p; p; string p]]}
.sys.which:{[n] n:$[10h=type n; n; string n]; .sys.sh $[.sys.i.win; "where ",n; "command -v ",n]}
.sys.mkdir:{[p] q:.sys.i.qpath p; .sys.sh $[.sys.i.win; "mkdir ",q; "mkdir -p ",q]}
.sys.cp:{[s;d] .sys.sh $[.sys.i.win; "copy /y ",(.sys.i.qpath s)," ",.sys.i.qpath d; "cp -r ",(.sys.i.qpath s)," ",.sys.i.qpath d]}
.sys.mv:{[s;d] .sys.sh $[.sys.i.win; "move /y ",(.sys.i.qpath s)," ",.sys.i.qpath d; "mv ",(.sys.i.qpath s)," ",.sys.i.qpath d]}
.sys.rm:{[p]
  h:hsym $[-11h=type p; p; `$$[10h=type p; p; string p]];
  k:key h;
  if[()~k; :`notFound];
  q:.sys.i.qpath h;
  $[.sys.i.win;
    .sys.sh $[11h=type k; "rmdir /s /q ",q; "del /f /q ",q];
    .sys.sh "rm -rf ",q] }

/ ----- snapshot / diff / restore / with --------------------------
.sys.i.getters:`port`precision`console`http`errorTrap`gcMode`threads`timer`timeout`weekOffset`dateFormat`utcOffset`namespace`cwd
.sys.i.restorers:`port`precision`console`http`errorTrap`gcMode`threads`timer`timeout`weekOffset`dateFormat!(.sys.setPort;.sys.setPrecision;.sys.setConsole;.sys.setHttp;.sys.setErrorTrap;.sys.setGcMode;.sys.setThreads;.sys.setTimer;.sys.setTimeout;.sys.setWeekOffset;.sys.setDateFormat)

.sys.snapshot:{
  g:`port`precision`console`http`errorTrap`gcMode`threads`timer`timeout`weekOffset`dateFormat`utcOffset`namespace`cwd;
  v:(.sys.port[];.sys.precision[];.sys.console[];.sys.http[];.sys.errorTrap[];.sys.gcMode[];.sys.threads[];.sys.timer[];.sys.timeout[];.sys.weekOffset[];.sys.dateFormat[];.sys.utcOffset[];.sys.namespace[];.sys.cwd[]);
  g!v }

.sys.diff:{[snap]
  now:.sys.snapshot[];
  k:key snap;
  ch:k where not snap[k]~'now k;
  ([] setting:ch; from:snap ch; to:now ch) }

.sys.restore:{[snap]
  d:.sys.i.restorers;
  ks:(key snap) inter key d;
  {[d;snap;k] @[d k; snap k; {[k;e] -2 "q-sys: could not restore ",string[k],": ",e}[k]]}[d;snap] each ks;
  .sys.diff snap }

/ run niladic thunk with temporary settings, then restore whatever it changed
.sys.with:{[overrides;thunk]
  snap:.sys.snapshot[];
  d:.sys.i.restorers;
  {[d;k;v] if[k in key d; d[k] v]}[d]'[key overrides; value overrides];
  r:@[thunk; ::; {[snap;e] .sys.restore snap; '"q-sys: ",e}[snap]];
  .sys.restore snap;
  r }

/ ----- reference table + manual --------------------------------------
.sys.i.mkref:{
  r:();
  r,:enlist(`p;`session;"listening port; 0 closes it, 0W lets the OS pick";"int";"p 5000");
  r,:enlist(`P;`session;"display precision in significant digits (0 = maximum)";"int 0-17";"P 10");
  r,:enlist(`c;`session;"console size as rows cols";"int int";"c 40 120");
  r,:enlist(`C;`session;"HTTP display size as rows cols";"int int";"C 36 2000");
  r,:enlist(`e;`session;"error-trap mode: 0 off, 1 suspend, 2 dump on error";"0|1|2";"e 1");
  r,:enlist(`g;`session;"garbage-collect mode: 0 deferred, 1 immediate";"0|1";"g 1");
  r,:enlist(`s;`session;"secondary (worker) threads to use";"int";"s 4");
  r,:enlist(`t;`session;"timer period in ms (0 stops it); with an expr, times it";"int | expr";"t 1000");
  r,:enlist(`T;`session;"client request timeout in seconds (0 = none)";"int";"T 30");
  r,:enlist(`w;`session;"workspace memory statistics";"none";"w");
  r,:enlist(`W;`session;"start-of-week offset (0 = Saturday)";"int";"W 2");
  r,:enlist(`z;`session;"date parse format: 0 = mm/dd/yyyy, 1 = dd/mm/yyyy";"0|1";"z 1");
  r,:enlist(`o;`session;"local time offset from UTC in hours";"none";"o");
  r,:enlist(`b;`introspect;"views whose dependencies changed (await recalculation)";"none";"b");
  r,:enlist(`B;`introspect;"views defined but not yet valued";"none";"B");
  r,:enlist(`a;`introspect;"tables in a namespace";"[.ns]";"a .");
  r,:enlist(`f;`introspect;"functions in a namespace";"[.ns]";"f .");
  r,:enlist(`v;`introspect;"variables in a namespace";"[.ns]";"v .");
  r,:enlist(`d;`introspect;"current namespace; with an arg, switch to it";"[.ns]";"d .foo");
  r,:enlist(`x;`introspect;"expunge a name / restore a default .z handler";"name";"x .z.pg");
  r,:enlist(`ts;`introspect;"time (ms) and space (bytes) used to evaluate an expression";"expr";"ts 2+2");
  r,:enlist(`l;`os;"load a script file or a directory";"path";"l tick.q");
  r,:enlist(`cd;`os;"current directory; with an arg, change to it";"[path]";"cd /tmp");
  r,:enlist(`r;`os;"rename / move a file";"src dst";"r a.txt b.txt");
  r,:enlist(`1;`os;"redirect stdout to a file";"path";"1 out.log");
  r,:enlist(`2;`os;"redirect stderr to a file";"path";"2 err.log");
  r,:enlist(`u;`process;"reload the -u user/password file";"none";"u");
  r,:enlist(`bs;`danger;"a lone backslash toggles q/k mode - never in a script";"none";"\\");
  r,:enlist(`quit;`danger;"\\\\ terminates the process";"none";"\\\\");
  flip `cmd`kind`summary`args`example!flip r }

.sys.i.ref:.sys.i.mkref[]

.sys.i.mkman:{
  d:()!();
  d[`p]:"\\p [port]  - listening port for IPC/HTTP clients. `\\p 0` closes it; `\\p 0W`\n            asks the OS for a free port; `\\p 5000W` binds multithreaded. Read\n            it back with `.sys.port[]`.";
  d[`P]:"\\P [n]     - number of significant digits shown when printing floats\n            (default 7). `\\P 0` prints the full 17-digit form. Purely a display\n            setting - stored precision is unchanged.";
  d[`c]:"\\c [r c]   - console page size (rows, cols). Output wider/taller is\n            truncated with `..`. Irrelevant when driving q programmatically.";
  d[`e]:"\\e [n]     - error-trap mode. 0: errors in callbacks just print. 1: drop\n            into the debugger (suspend). 2: dump a backtrace then continue.\n            Useful to bump to 1 or 2 while debugging server callbacks.";
  d[`g]:"\\g [n]     - garbage collection. 0 (deferred): memory is pooled and only\n            returned on `.Q.gc[]`. 1 (immediate): return each large block as\n            soon as its refcount hits zero - steadier RSS, a little slower.";
  d[`s]:"\\s [n]     - number of secondary threads for parallel primitives (peach,\n            parallel file reads). Capped at the value passed to `-s` at start.\n            `\\s 0` runs everything on the main thread.";
  d[`t]:"\\t [n]     - timer. With an integer: fire `.z.ts` every n ms (0 stops).\n            With an expression: return the milliseconds it took. `.sys.timer[]`\n            reads the interval; `.sys.elapsed\"expr\"` times a string.";
  d[`T]:"\\T [n]     - abort any single client request that runs longer than n\n            seconds (0 = unlimited). Guards a shared server against a runaway\n            query.";
  d[`ts]:"\\ts expr   - evaluate expr and report `time space`: elapsed milliseconds\n            and bytes allocated. `\\ts:n expr` repeats n times and reports the\n            total. Wrapped as `.sys.ts` / `.sys.tsn`.";
  d[`x]:"\\x name    - remove a global. The common use is `\\x .z.pg` (etc.) to drop\n            a handler you assigned and fall back to q's built-in behaviour.";
  d[`w]:"\\w         - memory stats: used, heap, peak, the `-w` limit, mmapped bytes,\n            physical RAM, then symbol count and symbol-table bytes. `.sys.memory[]`\n            returns the same numbers as a labelled dict.";
  d[`d]:"\\d [.ns]   - the namespace unqualified names resolve in. `\\d .foo` switches\n            (creating it); `\\d .` returns to root. Changing it mid-script is a\n            frequent source of confusion - prefer fully-qualified names.";
  d }

.sys.i.manText:.sys.i.mkman[]

/ .sys.help[]        -> the whole reference table
/ .sys.help[`p]      -> the row for \p
/ .sys.help[`session] -> every row of that kind
.sys.help:{[x] $[(::)~x; .sys.i.ref; not -11h=type x; .sys.i.ref; x in exec cmd from .sys.i.ref; select from .sys.i.ref where cmd=x; select from .sys.i.ref where kind=x]}

.sys.man:{[c]
  c:$[-11h=type c; c; `$c];
  $[c in key .sys.i.manText; -1 .sys.i.manText c; -1 "q-sys: no manual entry for \\",string c]; }

.sys.about:{-1 "q-sys ",.sys.version," loaded. .sys.help[] lists commands; .sys.man`p for detail."; }

.sys.about[]
