#!/bin/bash

set -e

mkdir -p ~/.op

if [ $(cat ~/.op/my_expire 2> /dev/null || echo 0) -lt $(date --utc +"%s") ]; then
  rm -f ~/.op/my_expire
  rm -f ~/.op/my_token
  op signin my --raw > ~/.op/my_token
  date --utc --date "+25minutes" +"%s"  > ~/.op/my_expire
fi
