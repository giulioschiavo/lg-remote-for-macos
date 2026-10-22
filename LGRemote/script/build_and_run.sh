#!/bin/zsh
set -eu
cd "$(dirname "$0")/.."
./build.command
open "dist/Telecomando LG.app"
