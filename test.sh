#!/bin/env bash

exists() {
  command -v "$1" > /dev/null
}

setup(){
  exists luarocks-5.1 || {
    echo "Please install luarocks for lua 5.1"
    exit 1
  }

  sudo luarocks-5.1 install busted
}

run(){
  exists busted || setup
  busted
}


run-dev(){
inotifywait -r -q -m -e close_write --format %e lua spec | while read -r ; do
busted
done
}

"$@"
