ssh-add -K ~/.ssh/id_rsa

FW_CA_BUNDLE=/usr/local/etc/openssl/cert.pem
touch ~/.npmrc
LINE=$(cat ~/.npmrc | grep -n "${FW_CA_BUNDLE}" | awk -F':' '{print $1}')
if [[ $LINE != "" ]]; then
  #sed -i '' "${LINE}d" ~/.npmrc
fi
if [[ "$(curl -s ifconfig.me)" = "87.191.128.105" ]]; then
  export AWS_CA_BUNDLE=${FW_CA_BUNDLE}
  export REQUESTS_CA_BUNDLE=${FW_CA_BUNDLE}
  echo "cafile = \"${FW_CA_BUNDLE}\"" >> ~/.npmrc
else
  unset AWS_CA_BUNDLE
  unset REQUESTS_CA_BUNDLE
fi

function show-all-files() {
  TOGGLE=${1:-false}
  defaults write com.apple.finder AppleShowAllFiles -bool $TOGGLE
  killall Finder
}

export DEFAULT_MAKE_LIB_HOME=$HOME/Development/Projects/schumann-it/terraform-make-lib

export DEFAULT_IAM_ROLE="AccountAdministrator"
export DEFAULT_SESSION_TYPE="iam"
export DEFAULT_SSO_START_URL=""
export DEFAULT_INFRA_HOME="$HOME/Development/Projects/schumann-it/terraform"
export DEFAULT_IAM_USER="jan.schumann"
export DEFAULT_MFA_TOKEN_CMD=""

export PATH=$PATH:$( echo $( cd "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P ) )/bin

source ${0:A:h}/project.zsh
source ${0:A:h}/project-autocomplete.zsh
source ${0:A:h}/pw-manager.zsh
