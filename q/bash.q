/ q-sys : bash.q  -  run OS commands through bash, with real exit codes
/ ---------------------------------------------------------------------------
/ Namespace .sys.bash. Depends on q/sys.q (auto-loaded below if missing).
/ -
/ Why a separate module: q's `system` shells out to cmd.exe on Windows and to
/ /bin/sh elsewhere, it never reports the child's exit status, and stdout and
/ stderr come back tangled. .sys.bash fixes all three: every call runs a real
/ `bash` script (written to a temp file, so there is no cross-platform quoting
/ nightmare) and returns `rc`out`err!(exit-code; stdout-lines; stderr-lines).
/ -
/ On Windows the `bash` from Git for Windows is found automatically; override
/ with .sys.bash.setBin.
/ -
/ Entry points:
/   .sys.bash.run  cmd        -> `rc`out`err dict (never signals on non-zero rc)
/   .sys.bash.sh   cmd        -> stdout lines; SIGNALS if rc<>0
/   .sys.bash.try  cmd        -> (rc; out; err) tuple, never signals
/   .sys.bash.ok   cmd        -> 1b iff rc=0
/   .sys.bash.rc   cmd        -> the exit code
/   .sys.bash.line cmd        -> first stdout line, trimmed
/   .sys.bash.script text     -> same as run, for multi-line scripts
/   .sys.bash.pipe [in;cmd]   -> feed `in` on stdin
/   .sys.bash.spawn[cmd;log]  -> start detached, return immediately
/ plus q-native wrappers: env whoami pwd hostname uname which has
/                         cat grep find wc ls du kill
/ -
/ Honours the same switches as the rest of q-sys: .sys.dryRun, .sys.verbose,
/ and the .sys.deny / .sys.allow shell guard (checked against the inner cmd).
/ ---------------------------------------------------------------------------

if[not `sh in key `.sys;
  @[system;"l q/sys.q";{@[system;"l sys.q";{'"q-sys/bash.q: load q/sys.q first"}]}] ];

.sys.bash.strict:0b     / 1b => every script is prefixed with `set -euo pipefail`
.sys.bash.opts:""       / extra flags inserted before the script path (e.g. "-x")

/ ----- internals -------------------------------------------------------
.sys.bash.i.q1:{[s] "'",(ssr[s;"'";"'\\''"]),"'"}         / quote for use inside bash
.sys.bash.i.q2:{[s] "\"",s,"\""}                          / quote a path for the outer shell
.sys.bash.i.strip:{[s] trim s except "\r"}
.sys.bash.i.ctr:0
.sys.bash.i.findTmp:{
  c:(getenv `TMPDIR; getenv `TEMP; getenv `TMP);
  c:c where 0<count each c;
  $[count c; ssr[first c;"\\";"/"]; "."] }
.sys.bash.i.tmpdir:.sys.bash.i.findTmp[]
.sys.bash.i.tmp:{[ext] .sys.bash.i.ctr+:1; .sys.bash.i.tmpdir,"/qsysbash_",(string .z.i),"_",(string .sys.bash.i.ctr),ext}
.sys.bash.i.findBin:{
  if[not .sys.i.win; :"bash"];
  if[@[{count system "where bash 2>NUL"};::;{0}]; :"bash"];
  p:("C:/Program Files/Git/bin/bash.exe"; "C:/Program Files/Git/usr/bin/bash.exe"; "C:/Program Files (x86)/Git/bin/bash.exe");
  h:p where .sys.exists each p;
  $[count h; first h; "bash"] }
.sys.bash.bin:.sys.bash.i.findBin[]
.sys.bash.setBin:{[p] .sys.bash.bin:$[10h=type p; p; string p]; .sys.bash.bin }

.sys.bash.i.slurp:{[f] @[{read0 hsym `$x}; f; {()}]}
.sys.bash.i.del:{[f] @[hdel; hsym `$f; {}]; }
.sys.bash.i.binq:{$[.sys.bash.bin like "* *"; .sys.bash.i.q2 .sys.bash.bin; .sys.bash.bin]}

/ assemble a full outer-shell command line: `bash [opts] <parts...>`.
/ On Windows, cmd.exe strips one surrounding quote pair from the whole line,
/ so wrap the lot to survive a quoted bash path.
.sys.bash.i.cmdline:{[parts]
  inner:.sys.bash.i.binq[],$[count .sys.bash.opts; " ",.sys.bash.opts; ""],(raze " ",/:parts);
  $[.sys.i.win; "\"",inner,"\""; inner] }

/ the workhorse. stdinTxt is (::) for none, or a string / list of lines.
.sys.bash.i.run:{[cmd;stdinTxt]
  cmd:.sys.i.str cmd;
  .sys.i.check cmd;
  .sys.i.log "bash< ",(", " sv "\n" vs cmd);
  if[0=count cmd; :`rc`out`err!(0i;();())];
  if[.sys.dryRun; :`rc`out`err!(0i; enlist "dryRun"; ())];
  sf:.sys.bash.i.tmp ".sh"; of:.sys.bash.i.tmp ".out"; ef:.sys.bash.i.tmp ".err"; rf:.sys.bash.i.tmp ".rc";
  hasIn:not (::)~stdinTxt;
  inf:$[hasIn; .sys.bash.i.tmp ".in"; ""];
  if[hasIn; (hsym `$inf) 0: $[10h=type stdinTxt; enlist stdinTxt; stdinTxt]];
  redir:" > ",(.sys.bash.i.q1 of)," 2> ",(.sys.bash.i.q1 ef),$[hasIn; " < ",.sys.bash.i.q1 inf; ""];
  / a subshell (...), not a { } group: a user `exit N` then stops only the
  / subshell, so our exit-code capture still runs.
  script:(),$[.sys.bash.strict; enlist "set -euo pipefail"; ()];
  script,:(enlist"("; cmd; ") ",redir; "__qs=$?"; "printf %s \"$__qs\" > ",(.sys.bash.i.q1 rf); "exit $__qs");
  (hsym `$sf) 0: script;
  full:.sys.bash.i.cmdline enlist .sys.bash.i.q2 sf;
  se:@[{system x; ""}; full; {x}];
  out:.sys.bash.i.strip each .sys.bash.i.slurp of;
  err:.sys.bash.i.strip each .sys.bash.i.slurp ef;
  rc:@[{"I"$first read0 hsym `$x}; rf; {-1i}];
  .sys.bash.i.del each (sf;of;ef;rf),$[hasIn; enlist inf; ()];
  if[rc<0; err:err,enlist "q-sys.bash: bash did not run (",se,")"];
  `rc`out`err!(rc; out; err) }

/ ----- public execution API -----------------------------------------
.sys.bash.run:{[cmd] .sys.bash.i.run[cmd; ::]}
.sys.bash.script:.sys.bash.run
.sys.bash.pipe:{[stdinTxt;cmd] .sys.bash.i.run[cmd; stdinTxt]}
.sys.bash.try:{[cmd] r:.sys.bash.run cmd; (r`rc; r`out; r`err)}
.sys.bash.rc:{[cmd] (.sys.bash.run cmd)`rc}
.sys.bash.ok:{[cmd] 0i=(.sys.bash.run cmd)`rc}
.sys.bash.sh:{[cmd]
  r:.sys.bash.run cmd;
  if[r`rc; '"q-sys.bash: exit ",(string r`rc)," from <",(.sys.i.str cmd),">: ","; " sv r`err];
  r`out }
.sys.bash.line:{[cmd] o:.sys.bash.sh cmd; $[count o; .sys.bash.i.strip first o; ""]}

.sys.bash.spawn:{[cmd;logfile]
  cmd:.sys.i.str cmd;
  .sys.i.check cmd;
  lg:$[count logfile; .sys.i.str logfile; "/dev/null"];
  .sys.i.log "bash& ",cmd;
  if[.sys.dryRun; :`dryRun];
  / two files: the job itself, and a launcher that backgrounds it and exits
  jf:.sys.bash.i.tmp ".sh"; lf:.sys.bash.i.tmp ".sh";
  (hsym `$jf) 0: (),$[.sys.bash.strict; enlist "set -euo pipefail"; ()],enlist cmd;
  (hsym `$lf) 0: enlist "nohup bash ",(.sys.bash.i.q1 jf)," > ",(.sys.bash.i.q1 lg)," 2>&1 &";
  system .sys.bash.i.cmdline enlist .sys.bash.i.q2 lf;
  jf }

/ ----- q-native wrappers -------------------------------------------
.sys.bash.env:{
  r:.sys.bash.run "env";
  if[r`rc; '"q-sys.bash.env: ","; " sv r`err];
  ln:r[`out] where (r`out) like "*=*";
  i:ln?\:"=";
  (`$i#'ln)!(1+i)_'ln }
.sys.bash.whoami:{`$.sys.bash.line "whoami"}
.sys.bash.pwd:{.sys.bash.line "pwd"}
.sys.bash.hostname:{`$.sys.bash.line "hostname"}
.sys.bash.uname:{.sys.bash.line "uname -a"}
.sys.bash.which:{[n] r:.sys.bash.run "command -v -- ",.sys.bash.i.q1 .sys.i.str n; $[r`rc; ""; $[count r`out; .sys.bash.i.strip first r`out; ""]]}
.sys.bash.has:{[n] 0i=(.sys.bash.run "command -v -- ",.sys.bash.i.q1 .sys.i.str n)`rc}
.sys.bash.cat:{[path] .sys.bash.sh "cat -- ",.sys.bash.i.q1 .sys.i.str path}
.sys.bash.grep:{[pat;path]
  r:.sys.bash.run "grep -n -e ",(.sys.bash.i.q1 .sys.i.str pat)," -- ",(.sys.bash.i.q1 .sys.i.str path);
  $[r[`rc]>1; '"q-sys.bash.grep: ","; " sv r`err; r`out] }
.sys.bash.find:{[path;pat] .sys.bash.sh "find ",(.sys.bash.i.q1 .sys.i.str path)," -name ",(.sys.bash.i.q1 .sys.i.str pat)}
.sys.bash.wc:{[path] "J"$.sys.bash.line "wc -l < ",.sys.bash.i.q1 .sys.i.str path}
.sys.bash.du:{[path] "J"$first "\t" vs .sys.bash.line "du -sk -- ",.sys.bash.i.q1 .sys.i.str path}
.sys.bash.kill:{[pid;sig] .sys.bash.ok "kill -",(.sys.i.str sig)," ",.sys.i.str pid}
.sys.bash.ls:{[path]
  p:.sys.i.str path;
  r:.sys.bash.run "find ",(.sys.bash.i.q1 p)," -maxdepth 1 -mindepth 1 -printf '%y\\t%s\\t%T@\\t%f\\n'";
  if[r`rc; '"q-sys.bash.ls: ","; " sv r`err];
  rows:"\t" vs/: r[`out] where 0<count each r`out;
  rows:rows where 4=count each rows;
  ([] name:`$rows[;3]; kind:`$rows[;0]; size:"J"$rows[;1]; mtime:1970.01.01D00:00:00+`long$1e9*"F"$rows[;2]) }

/ ----- discovery -------------------------------------------------
.sys.bash.info:{`bin`tmpdir`strict`opts!(.sys.bash.bin; .sys.bash.i.tmpdir; .sys.bash.strict; .sys.bash.opts)}
.sys.bash.i.mkhelp:{
  r:();
  r,:enlist(`run;"run a command, get `rc`out`err back (never signals)";"\"ls -la\"");
  r,:enlist(`sh;"run a command, return stdout lines, signal on non-zero exit";"\"git status\"");
  r,:enlist(`try;"like run, as a (rc;out;err) tuple";"\"make\"");
  r,:enlist(`ok;"1b iff the command exits 0";"\"test -f x\"");
  r,:enlist(`rc;"the exit code only";"\"grep -q foo f\"");
  r,:enlist(`line;"first stdout line, trimmed";"\"date +%s\"");
  r,:enlist(`script;"run a multi-line script";"\"for f in *; do echo $f; done\"");
  r,:enlist(`pipe;"[stdin; cmd] - feed data on stdin";"(\"a\\nb\"; \"sort\")");
  r,:enlist(`spawn;"[cmd; logfile] - start detached, return at once";"(\"./long.sh\"; \"run.log\")");
  r,:enlist(`env;"the shell environment as a q dict";"");
  r,:enlist(`which;"resolve a command to its path (\"\" if absent)";"`jq");
  r,:enlist(`has;"1b iff a command exists on PATH";"`docker");
  r,:enlist(`ls;"directory listing as a table: name kind size mtime";"\".\"");
  r,:enlist(`grep;"[pattern; path] - matching lines (numbered)";"(\"TODO\"; \"a.q\")");
  r,:enlist(`wc;"line count of a file";"\"a.q\"");
  r,:enlist(`du;"size in KiB of a path";"\".\"");
  flip `fn`summary`example!flip r }
.sys.bash.i.help:.sys.bash.i.mkhelp[]
.sys.bash.help:{[x]
  if[(::)~x; :.sys.bash.i.help];
  k:$[-11h=type x; x; `$x];
  select from .sys.bash.i.help where fn=k }

-1 "q-sys.bash loaded (bin: ",.sys.bash.bin,"). .sys.bash.help[] for the list.";
