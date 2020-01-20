#!/bin/bash

# create session (aka credential profile for a given account and role
# for convenience an alias should be created
# e.g. alias get_session="<path_to_this_file"

# if the token parameter is omitted, we try to retrieve a token via https://pypi.python.org/pypi/mfa
# using the ${ORG} variable as key
function help
{
   echo "USAGE: aws-session.sh -o <organisation_short_name> -p <account_short_name> -r <role> [-t <token>] [-v]"
   exit;
}

NC="\033[0m"
RED="\033[0;31m"
GREEN="\033[0;32m"
YELLOW="\033[1;33m"

while getopts "o:t:r:p:v" opt; do
  case $opt in
    o)
        ORG=$OPTARG
        ;;
    t)
        TOKEN=$OPTARG
        ;;
    r)
        ROLE=$OPTARG
        ;;
    p)
        TO_PROFILE="${ORG}-${OPTARG}"
        ;;
    v)
        VERBOSE=true
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

echo -e "Getting session in ${YELLOW}${TO_PROFILE}${NC} for ${YELLOW}${ROLE}${NC}"

if test -z "${ORG}"; then
  help
  exit 1
fi

if test -n "${VERBOSE}"; then
  echo -e -n "Fetching iam account id for ${YELLOW}${ORG}${NC} ... "
fi
PROFILE="${ORG}-iam"
MAIN_ACCOUNT_ID=$(aws --profile ${PROFILE} configure get account_id)
if test -z "${MAIN_ACCOUNT_ID}"; then
  echo
  echo -e "${RED}Account ID for the main account${NC} ${YELLOW}${PROFILE} ${RED}not found.${NC}"
  help
  exit 1
fi
if test -n "${VERBOSE}"; then
  echo -e "${YELLOW}${MAIN_ACCOUNT_ID}${NC}"
fi

if test -n "${VERBOSE}"; then
  echo -n -e "Fetching user for ${YELLOW}${TO_PROFILE}${NC} ... "
fi
USER=$(aws --profile ${PROFILE} configure get iam_user)
if test -z "${USER}"; then
  echo
  echo -e "${RED}Username not found for account${NC} ${YELLOW}${PROFILE}${NC}"
  help
  exit 1
fi
if test -n "${VERBOSE}"; then
  echo -e "${YELLOW}${USER}${NC}"
fi

TO_ACCOUNT_ID=$(aws --profile ${TO_PROFILE} configure get account_id)
if test -z "${TO_ACCOUNT_ID}"; then
  echo -e "${RED}Account ID not found for account${NC} ${YELLOW}${TO_PROFILE}${NC}"
  help
  exit 2
fi

ACCESS_KEY_ID=$(aws --profile ${PROFILE} configure get aws_access_key_id)
if test -z "${ACCESS_KEY_ID}"; then
  echo -e "${RED}No access key found for profile${NC} ${YELLOW}${ORG}-iam${NC}"
  help
  exit 2
fi

if test -n "${VERBOSE}"; then
  echo "Checking session age ..."
fi
if test -z "${MAX_ACCESS_KEY_AGE}"; then
  MAX_ACCESS_KEY_AGE=90
fi
if test -z "${WARNING_BEFORE_DAYS}"; then
  WARNING_BEFORE_DAYS=10
fi
WARNING_ACCESS_KEY_AGE=$(($MAX_ACCESS_KEY_AGE - $WARNING_BEFORE_DAYS))
QUERY=".AccessKeyMetadata[] | select(.AccessKeyId == \"${ACCESS_KEY_ID}\") | .CreateDate"
CREATE_DATE=$(aws --profile ${PROFILE} iam list-access-keys --user-name ${USER} | jq -r "${QUERY}") # | select(.AccessKeyId == '${ACCESS_KEY_ID}') | .CreateDate")
EXPIRE=$(date --utc --date "${CREATE_DATE} +${MAX_ACCESS_KEY_AGE}days" +"%s")
EXPIRE_SOON=$(date --utc --date "${CREATE_DATE} +${WARNING_ACCESS_KEY_AGE}days" +"%s")
DATE=$(date --utc --date "now" +"%s")
if test -n "${VERBOSE}"; then
  echo -e "Session create date is ${YELLOW}${CREATE_DATE}${NC}"
  echo -e "          Will warn on ${YELLOW}${EXPIRE_SOON}${NC}"
  echo -e "        Will expire on ${YELLOW}${EXPIRE}${NC}"
  echo -e "               Date is ${YELLOW}${DATE}${NC}"
fi
if [[ -z $CREATE_DATE || $EXPIRE_SOON -lt $DATE ]]; then
  if [[ -z $CREATE_DATE || $EXPIRE -lt $DATE ]]; then
    echo -e "${RED}Your access Key has expired and will be deleted NOW${NC}"
    echo "Please login and create new Access Keys here: "
    echo "https://console.aws.amazon.com/iam/home?region=${REGION}#/users/${USER}?section=security_credentials"
    aws --profile ${PROFILE} iam delete-access-key --access-key-id ${ACCESS_KEY_ID} --user-name ${USER}
    exit 2
  else
    echo -e "${YELLOW}Your key will expire on ${RED}${EXPIRE}${YELLOW}. Please create a new one today!${NC}"
  fi
fi

if test -z "${TOKEN}"; then
  echo -n -e "Please enter a token for ${YELLOW}${ORG}${NC}: "
  read TOKEN
fi

if test -z "${TOKEN}"; then
  echo -e "${RED}MFA token not provided${NC}"
  help
  exit 1
fi

CMD="aws sts --profile ${PROFILE} assume-role \
    --role-arn arn:aws:iam::${TO_ACCOUNT_ID}:role/${ROLE} \
    --role-session-name ${TO_ACCOUNT_ID}-${TO_PROFILE}-${ROLE} \
    --serial-number arn:aws:iam::${MAIN_ACCOUNT_ID}:mfa/${USER} \
    --token-code ${TOKEN}"

if test -n "${VERBOSE}"; then
    echo -e "Fetching session for ${YELLOW}${TO_PROFILE} ${ROLE}${NC} ..."
    echo -e "${YELLOW}${CMD}${NC}"
fi

# get the session
SESSION=$( ${CMD} )

if test -z "${SESSION}"; then
  aws configure --profile ${TO_PROFILE} set aws_session_expiration "0"
  echo -e "${RED}Session could not be retrieved.${NC}"
  exit 3
else
  if test -n "${VERBOSE}"; then
    echo -e "Writing session for ${YELLOW}${ROLE}${NC} to profile ${YELLOW}${TO_PROFILE}${NC}"
  fi
  # write the credentials profile
  aws configure --profile ${TO_PROFILE} set aws_access_key_id "$(echo ${SESSION} | jq -r '.Credentials.AccessKeyId')"
  aws configure --profile ${TO_PROFILE} set aws_secret_access_key "$(echo ${SESSION} | jq -r '.Credentials.SecretAccessKey')"
  aws configure --profile ${TO_PROFILE} set aws_session_token "$(echo ${SESSION} | jq -r '.Credentials.SessionToken')"
  # write expiration time to config
  aws configure --profile ${TO_PROFILE} set aws_session_expiration "$(date --date "$(echo ${SESSION} | jq -r '.Credentials.Expiration')" +"%s")"
  # write default region from iam profile
  aws configure --profile ${TO_PROFILE} set region $(aws configure --profile ${PROFILE} get region)

  echo -e "${GREEN}Session saved to profile ${YELLOW}${TO_PROFILE}${NC}"
  if test -n "${VERBOSE}"; then
    echo ${SESSION} | jq -r
  fi
fi

exit 0
