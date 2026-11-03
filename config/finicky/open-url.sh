#!/bin/sh
# Launched with one URL argument by Finicky's -n --args invocation.
# HTTP(S) stays in Finicky's browser rules; delegating it here would loop.
set -eu
[ "$#" -eq 1 ] || exit 64
case "$1" in
  [Hh][Tt][Tt][Pp]:*|[Hh][Tt][Tt][Pp][Ss]:*|[Ff][Ii][Nn][Ii][Cc][Kk][Yy]:*) exit 64 ;;
  [A-Za-z]*:*) exec /usr/bin/open "$1" ;;
  *) exit 64 ;;
esac
