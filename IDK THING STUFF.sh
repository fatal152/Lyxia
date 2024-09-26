#!/bin/sh
echo -ne '\033c\033]0;Testing stuff out\a'
base_path="$(dirname "$(realpath "$0")")"
"$base_path/IDK THING STUFF.x86_64" "$@"
