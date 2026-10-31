#!/usr/bin/env bash
# CEMU_BIN wrapper: run Cemu under gdb; `kill -INT <cemu pid>` dumps all thread backtraces to /tmp/claude-1000/v3-bt.txt
exec gdb -batch -q -ex "set pagination off" -ex "handle SIGSEGV nostop noprint pass" -ex "handle SIGUSR1 nostop noprint pass" -ex "handle SIGUSR2 nostop noprint pass" -ex "handle SIGPIPE nostop noprint pass" -ex run -ex "thread apply all bt 25" -ex kill --args $HOME/Applications/Cemu-BetterVR/Cemu "$@" > /tmp/claude-1000/v3-bt.txt 2>&1
