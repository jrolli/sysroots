#!/bin/bash
set -euo pipefail

export SYSROOT=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

source $SYSROOT/bashenv

echo "Target: $TARGET"
echo "Sysroot: $SYSROOT"

if [ $# -ne 0 ]
then
    $@
else
    export PS1="[$TARGET] \w$ "
    exec /bin/bash
fi
