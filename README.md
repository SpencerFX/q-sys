# q-sys

A small kdb+/q library focused on **q system commands** — the `\`-commands that
control a running q session (`\p`, `\P`, `\ts`, `\g`, `\s`, …) and the
`system "…"` shell-out. It wraps them in one namespace, `.sys`, with:

- **one protected entry point** for every command, with a *dry-run* mode, an
  optional echo, and an allow/deny guard for shell-outs;
- **typed getters and setters** — `.sys.port[]`, `.sys.setPrecision 10`, … — so
  you never hand-format a command string;
- **introspection** — namespace tables/vars/functions, `\ts` timing, expunge;
- **snapshot / diff / restore / with** — capture the session's settings, see
  what changed, and put them back (including automatically, around a block);
- **a reference table and short manual entries** — `.sys.help[]`, `` .sys.man`g ``.

Tested against kdb+ 4.0 (w64, 2023.01.20) on Windows; the OS helpers branch on
`.z.o` for `cmd.exe` vs. POSIX shells.

## Install

No dependencies. Copy the repo somewhere and load the single file:

```q
q)\l q/sys.q
q-sys 0.1.0 loaded. .sys.help[] lists commands; .sys.man`p for detail.
```

For OS commands run through a real **bash** (exit codes, separated
stdout/stderr, stdin, no cross-platform quoting nightmare) load the companion
module — it pulls in `sys.q` itself:

```q
q)\l q/bash.q
q-sys.bash loaded (bin: bash). .sys.bash.help[] for the list.
```

Run the tests / demos from the repo root:

```
q tests/test.q -q
q tests/bash_test.q -q
q examples/demo.q -q
q examples/bash_demo.q -q
```

## Quick tour

```q
.sys.port[]                  / 0i   (current listening port)
.sys.setPort 5010            / \p 5010
.sys.precision[]             / 7i
.sys.setThreads 4            / \s 4

.sys.ts "sum til 1000000"    / 3 8388880   (ms, bytes)
.sys.memory[]                / labelled \w
.sys.collect[]               / .Q.gc[]

.sys.snapshot[]              / dict of every gettable setting
snap:.sys.snapshot[];
.sys.setPrecision 12;
.sys.diff snap               / ([] setting; from; to)
.sys.restore snap            / put it all back

/ run a block with temporary settings, restored afterwards (even on error)
.sys.with[(enlist `precision)!enlist 12; {string acos -1}]

.sys.help[]                  / the whole reference table
.sys.help[`session]          / just the session-control commands
.sys.help[`ts]               / the row for \ts
.sys.man `g                  / a paragraph on \g
```

## Shell-outs, safely

`.sys.sh` runs an OS command and returns its stdout as a list of lines.
`.sys.shl` joins them; `.sys.tryShell` never signals and returns `(ok; lines)`.

```q
.sys.sh "git rev-parse HEAD"
.sys.tryShell "some-command-that-might-not-exist"   / (0b; ("...error..."))
```

Two optional guards are checked before anything runs:

```q
.sys.deny: enlist "rm *";      / refuse any command matching a glob here
.sys.allow: ("git *"; "ls *"); / if non-empty, ONLY these may run
```

And two global switches affect **every** `.sys.run` / `.sys.sh`:

```q
.sys.dryRun: 1b;   / log the command, don't execute, return `dryRun
.sys.verbose: 1b;  / echo every command to stderr before running it
```

## API

### Core

| name | purpose |
|---|---|
| `.sys.run cmd` | run a q system command (`"p 5000"`, `` `P ``, …); honours dryRun/verbose/trap |
| `.sys.sh cmd` | OS shell-out → list of stdout lines; runs the allow/deny guard |
| `.sys.shl cmd` | as `.sys.sh`, output joined into one string |
| `.sys.tryShell cmd` | → `(ok; lines)`, never signals |

### Session settings — getter `/` setter

`port`/`setPort`, `precision`/`setPrecision`, `console`/`setConsole`,
`http`/`setHttp`, `errorTrap`/`setErrorTrap`, `gcMode`/`setGcMode`,
`threads`/`setThreads`, `timer`/`setTimer`, `timeout`/`setTimeout`,
`weekOffset`/`setWeekOffset`, `dateFormat`/`setDateFormat`,
`namespace`/`setNamespace`. Read-only: `utcOffset`.

### Workspace / files / process

`.sys.ws`, `.sys.memory`, `.sys.collect`, `.sys.cwd`, `.sys.cd`, `.sys.load`,
`.sys.rename`, `.sys.redirectOut`, `.sys.redirectErr`, `.sys.pid`, `.sys.host`,
`.sys.qversion`, `.sys.qbuild`, `.sys.argv`, `.sys.cmdline`, `.sys.terminate`
(guarded by `.sys.allowExit`).

### Introspection / timing

`.sys.tablesIn`, `.sys.funcsIn`, `.sys.varsIn`, `.sys.expunge`,
`.sys.brokenViews`, `.sys.pendingViews`, `.sys.ts`, `.sys.tsn`, `.sys.elapsed`.

### OS helpers (cross-platform)

`.sys.env`, `.sys.setenv`, `.sys.ls`, `.sys.exists`, `.sys.which`, `.sys.mkdir`,
`.sys.cp`, `.sys.mv`, `.sys.rm`.

### Settings management

`.sys.snapshot`, `.sys.diff`, `.sys.restore`, `.sys.with`, `.sys.help`, `.sys.man`.

## `bash.q` — OS commands through bash (`.sys.bash`)

q's `system` shells out to `cmd.exe` on Windows / `/bin/sh` elsewhere, never
reports the child's exit status, and tangles stdout with stderr. `.sys.bash`
fixes all three: each call writes a real bash script to a temp file (so there
is no cross-platform quoting to get wrong) and returns
`` `rc`out`err!(exit-code; stdout-lines; stderr-lines) ``. On Windows the
`bash` from Git for Windows is found automatically (`.sys.bash.setBin` to
override). It honours the same `.sys.dryRun` / `.sys.verbose` / `.sys.deny` /
`.sys.allow` switches as the rest of q-sys.

```q
\l q/bash.q

.sys.bash.run "make -j4"                 / `rc`out`err dict, never signals
.sys.bash.sh  "git rev-parse HEAD"       / stdout lines; SIGNALS if rc<>0
.sys.bash.try "flaky-thing"              / (rc; out; err) tuple, never signals
.sys.bash.ok  "test -f build/app"        / 1b / 0b
.sys.bash.rc  "grep -q TODO src.q"       / just the exit code
.sys.bash.line "date +%s"                / first stdout line, trimmed

.sys.bash.script "for f in *.q; do wc -l \"$f\"; done"
.sys.bash.pipe["3\n1\n2"; "sort -n"]     / feed stdin
.sys.bash.spawn["./long-job.sh"; "job.log"]   / detached, returns at once

.sys.bash.env[]         / the shell environment as a q dict
.sys.bash.whoami[]      / `giantsteps
.sys.bash.has `docker   / 1b / 0b
.sys.bash.which `jq     / "/usr/bin/jq"  ("" if absent)
.sys.bash.ls "src"      / ([] name; kind; size; mtime)  as a table
.sys.bash.grep["TODO"; "src.q"]   / matching lines, numbered
.sys.bash.wc "src.q"   / 128
.sys.bash.info[]        / `bin`tmpdir`strict`opts

.sys.bash.strict:1b     / prefix every script with `set -euo pipefail`

.sys.bash.help[]        / the wrapper list
```

## License

MIT — see [LICENSE](LICENSE).
