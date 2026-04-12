#!/usr/bin/env sh

case $- in
  *i*) ;;
  *) return 0 2> /dev/null || exit 0 ;;
esac

compress() {
  tar -czf "${1%/}.tar.gz" "${1%/}"
}

alias decompress='tar -xzf'
