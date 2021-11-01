#!/bin/bash

set -e

op-session.sh
op get --session $(cat ~/.op/my_token) totp $1
