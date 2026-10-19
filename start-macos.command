#!/bin/bash
# Double-click launcher for Finder: runs setup.sh next to this file.
cd "$(dirname "$0")" || exit 1
if [ ! -f setup.sh ]; then
    echo 'setup.sh was not found next to this launcher.'
    read -r -p 'Enter — закрыть...'
    exit 1
fi
bash setup.sh "$@"
status=$?
[ $status -eq 0 ] || read -r -p 'Enter — закрыть...'
exit $status
