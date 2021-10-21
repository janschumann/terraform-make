#!/bin/bash

set -e

function help
{
   echo "USAGE: aws-session-sso.sh -p <profile> -e <expire date>"
   exit;
}

NC="\033[0m"
GREEN="\033[0;32m"
YELLOW="\033[1;33m"

while getopts "p:e:" opt; do
  case $opt in
    p)
        PROFILE=$OPTARG
        ;;
    e)
        EXPIRE=$OPTARG
        ;;
    \?)
        help
        exit 1;
        ;;
    :)
        echo "Option -$OPTARG requires an argument." >&2
        exit 1
        ;;
  esac
done

echo -e "Getting session for ${YELLOW}${PROFILE}${NC}"
aws sso login --profile ${PROFILE}
aws configure --profile ${PROFILE} set aws_session_expiration ${EXPIRE}
echo -e "${GREEN}Session saved to profile ${YELLOW}${PROFILE}${NC}"
