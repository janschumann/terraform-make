NC="\033[0m"
RED="\033[0;31m"
GREEN="\033[0;32m"
YELLOW="\033[1;33m"

function project-infra-current() {
  echo ${CURRENT_PROJECT}
}

function project-infra-init() {
  project=${1:-DEFAULT}

  if [[ "${project}" != "DEFAULT" ]]; then
    if (! _project-enabled ${project}); then
      echo -e "${RED}ERROR: ${YELLOW}${project#project-}${RED} is not enabled${NC}"
      return
    fi
  fi

  project=${project#project-}
  lib_path=${2:-$DEFAULT_MAKE_LIB_HOME}

  unset AWS_ROLE_NAME
  unset AWS_SESSION_TYPE
  unset TERRAFORM_INFRA_HOME
  unset AWS_MFA_TOKEN_CMD

  eval AWS_ROLE_NAME='$'${project:u}_IAM_ROLE
  eval AWS_SESSION_TYPE='$'${project:u}_SESSION_TYPE
  eval AWS_SSO_START_URL='$'${project:u}_SSO_START_URL
  eval TERRAFORM_INFRA_HOME='$'${project:u}_INFRA_HOME
  eval AWS_MFA_TOKEN_CMD='$'${project:u}_MFA_TOKEN_CMD

  if [[ -n $AWS_ROLE_NAME ]]; then
    export AWS_ROLE_NAME=$AWS_ROLE_NAME
  fi
  if [[ -n $AWS_SSO_START_URL ]]; then
    export AWS_SSO_START_URL=$AWS_SSO_START_URL
  fi
  if [[ -n $AWS_SESSION_TYPE ]]; then
    export AWS_SESSION_TYPE=$AWS_SESSION_TYPE
  fi
  if [[ -n $TERRAFORM_INFRA_HOME ]]; then
    export TERRAFORM_INFRA_HOME=$TERRAFORM_INFRA_HOME
  fi
  if [[ -n $AWS_MFA_TOKEN_CMD ]]; then
    export AWS_MFA_TOKEN_CMD=$AWS_MFA_TOKEN_CMD
  fi

  if [ ! -f $lib_path/terraform.mk ]; then
    echo -e "${RED}ERROR: ${lib_path} not found. ${YELLOW}Terraform make lib not set.${NC}"
    return
  fi
  export TERRAFORM_MAKE_LIB_HOME=$lib_path
  export TERRAFORM_TOOLS_HOME=$TERRAFORM_MAKE_LIB_HOME

  eval TOOLS_HOME='$'${project:u}_INFRA_TOOLS_HOME
  if [ -d "$TOOLS_HOME" ]; then
    export TERRAFORM_TOOLS_HOME=$TOOLS_HOME
  fi

  export CURRENT_PROJECT=${project}
}

function _project-enabled() {
  grep -e "^  $1" ~/.zshrc > /dev/null
  if [[ "0" == "$?" ]]; then
    return 0
  fi

  return 1
}

function project-enable() {
  grep -e "^# $1" ~/.zshrc > /dev/null
  if [[ "1" == "$?" ]] return
  sed -i '' "s/^# $1/  $1/" ~/.zshrc
  source ~/.zshrc
}

function project-disable() {
  grep -e "^  $1" ~/.zshrc > /dev/null
  if [[ "1" == "$?" ]] return
  sed -i '' "s/^  $1/# $1/" ~/.zshrc
  source ~/.zshrc
}

function project-status() {
  for p in $(find ~/.my-zsh/plugins -type d -name "project-*" ); do
    _project-status $(basename $p)
  done
}

function _project-status() {
  grep -e "^  $1" ~/.zshrc > /dev/null
  if [[ "0" == "$?" ]]; then
    echo -e "$1: ${GREEN}enabled${NC}"
  else
    echo -e "$1: ${RED}disabled${NC}"
  fi
}

function project-infra() {
  args=( ${@} )
  wtype=$args[1]
  wname=$args[2]
  account=$args[3]
  environment=$args[4]
  actions="${args[@]:4}"

  cd $TERRAFORM_INFRA_HOME/terraform-workspace-${wtype}-${wname}
  make VAR_FILE=${account}-${environment}.tfvars ${actions}
}

function project-infra-dir() {
  wname=terraform-workspace-$1
  if [[ $2 != "" ]] wname=$wname-$2

  cd $TERRAFORM_INFRA_HOME/${wname}
}

function project-account-infra() {
  args=( ${@} )
  account=$args[1]
  environment=$args[2]
  actions="${args[@]:2}"

  cd $TERRAFORM_INFRA_HOME/terraform-workspace-account
  make VAR_FILE=${account}-${environment}.tfvars ${actions}
}

function infra-plan() {
  make VAR_FILE=$1 fmt force-plan
}

function infra-apply() {
  make VAR_FILE=$1 apply
}

function infra-output() {
  make VAR_FILE=$1 output
}
