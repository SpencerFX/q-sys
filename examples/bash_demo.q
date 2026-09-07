/ q-sys bash.q demo - run from the repo root:  q examples/bash_demo.q -q
\l q/bash.q

-1 "\n== where is bash, and where do temp scripts go ==============";
show .sys.bash.info[];

-1 "\n== rc / stdout / stderr are all captured, separately =======";
show .sys.bash.run "echo to-stdout; echo to-stderr >&2; exit 4";

-1 "\n== .sys.bash.sh: lines out, signal on failure ==============";
show .sys.bash.sh "seq 3 | sed 's/^/row /'";
show @[{.sys.bash.sh "exit 9"}; ::; {"  (signalled: ",x,")"}];

-1 "\n== feed data on stdin ======================================";
show .sys.bash.pipe["banana\napple\ncherry"; "sort | head -2"]`out;

-1 "\n== a multi-line script =====================================";
show .sys.bash.script["total=0\nfor n in 1 2 3 4 5; do total=$((total+n)); done\necho \"sum=$total\""]`out;

-1 "\n== q-native wrappers =======================================";
-1 "whoami   : ",string .sys.bash.whoami[];
-1 "uname    : ",.sys.bash.uname[];
-1 "has git  : ",string .sys.bash.has `git;
-1 "which sh : ",.sys.bash.which `sh;
-1 "PATH has ",string[count ":" vs .sys.bash.env[][`PATH]]," entries";

-1 "\n== directory listing as a table ============================";
show `size xdesc .sys.bash.ls "q";

-1 "\n== guard + dry-run still apply =============================";
.sys.dryRun:1b;
show .sys.bash.run "echo nope";
.sys.dryRun:0b;

exit 0
