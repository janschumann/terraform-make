#!/bin/bash

set -e

mkdir -p ~/.op

rm -f ~/.op/my_expire
rm -f ~/.op/my_token

op-session.sh
