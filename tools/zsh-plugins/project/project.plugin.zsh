export DEFAULT_MAKE_LIB_HOME=$HOME/.terraform-make

export DEFAULT_IAM_ROLE="AccountAdministrator"
export DEFAULT_SESSION_TYPE="sso"
export DEFAULT_SESSION_DURATION="1hour"
export DEFAULT_SSO_START_URL=""
export DEFAULT_IAM_USER=""
export DEFAULT_MFA_TOKEN_CMD=""


export PATH=$PATH:$( echo $( cd "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P ) )/bin

source ${0:A:h}/project.zsh
source ${0:A:h}/project-autocomplete.zsh
source ${0:A:h}/pw-manager.zsh
