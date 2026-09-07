/ q-sys demo - run from the repo root:  q examples/demo.q -q
\l q/sys.q

-1 "\n== the session right now =====================================";
show .sys.snapshot[];

-1 "\n== reference table (first rows) =============================";
show 8 sublist .sys.help[];

-1 "\n== a manual entry ==========================================";
.sys.man `g;

-1 "\n== temporarily bump precision, then restore =================";
-1 "pi at default : ",string acos -1;
.sys.with[(enlist `precision)!enlist 12; {-1 "pi at \\P 12   : ",string acos -1}];
-1 "pi at default : ",string acos -1;

-1 "\n== time an expression (\\ts) ================================";
show .sys.ts "sum til 1000000";

-1 "\n== memory =================================================";
show .sys.memory[];

-1 "\n== dry-run mode ===========================================";
.sys.dryRun:1b;
-1 "setPort 5000 -> ",string .sys.setPort 5000;
-1 "port unchanged: ",string .sys.port[];
.sys.dryRun:0b;

-1 "\n== a guarded shell-out ====================================";
.sys.deny:enlist "rm *";
show .sys.tryShell "rm -rf /";
.sys.deny:();
show .sys.sh "echo hello from the OS";

exit 0
