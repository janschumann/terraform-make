compdef _project project-enable
compdef _project project-disable
compdef _project project-infra-init
compdef _infra project-infra
compdef _infra_dir project-infra-dir
compdef _infra_account project-account-infra

function _project {
    local line

    projects=""
    for p in $(find ~/.my-zsh/plugins -type d -name "project-*" ); do
      projects="${projects} $(basename $p)"
    done

    _arguments -C \
        "1: :($projects)" \
        "*::arg:->args"
}

function __describe_workspace_actions() {
  actions=(
    'apply:Apply current plan, exit if no current plan exists'
    'clean-all:Remove cache and plan dir. Will not remove plugins and modules'
    'dismiss-plan:Dismiss the current plan'
    'debug:Display debug output'
    'fmt:Format terraform code'
    'force-clean-all:Remove cache and plan dir including plugins and modules'
    'force-init:Force backend and module re-initialisation'
    'force-plan:Dismiss current plan and create a new one'
    'force-session:Get a new session even if the current session is not expired yet'
    'plan:Create a new plan'
    'session:Make sure we can login to the provider'
    'show-plan:Show the current plan'
    'update-modules:Fetch required modules'
  )
  _describe -t action "action" actions
}

function __describe_workspace_types {
  wdir=$TERRAFORM_INFRA_HOME
  wtypes=($(find $wdir -name "terraform-workspace-*" -type d | sed "s|$wdir/terraform-workspace-||" | awk -F'-' '{print $1}' | sort -u))
  _describe -t wtype "workspace type" wtypes
}

function __describe_workspace_names {
  wdir=$TERRAFORM_INFRA_HOME
  wtype=$1
  wnames=($(find $TERRAFORM_INFRA_HOME -name "terraform-workspace-${wtype}-*" -type d | sed "s|$wdir/terraform-workspace-${wtype}-||" | sort -u))
  _describe -t wname "workspace name" wnames
}

function __describe_workspace_accounts {
  wname=terraform-workspace-$1
  if [[ "" != $2 ]] wname=$wname-$2
  wdir=$TERRAFORM_INFRA_HOME/${wname}
  accounts=($(find ${wdir} -name "*-*.tfvars" -type f | sed "s|$wdir/||" | awk -F'-' '{print $1}' | sort -u))
  _describe -t account "account" accounts
}

function __describe_workspace_environments {
  wname=terraform-workspace-$1
  if [[ "" != $2 ]] wname=$wname-$2
  wdir=$TERRAFORM_INFRA_HOME/${wname}
  account=$3
  environments=($(find $wdir -name "${account}-*.tfvars" -type f | sed "s|$wdir/||" | awk -F'-' '{print $2}' | sed "s|\.tfvars||" | sort -u))
  _describe -t environment "environment" environments
}

function _infra {
  local curcontext="$curcontext" state line
  local -a actions

  _arguments -C \
    ':wtype:->wtype' \
    ':wname:->wname' \
    ':account:->account' \
    ':environment:->environment' \
    '*::action:->action'

  case $state in
    (wtype)
        __describe_workspace_types
        return
    ;;
    (wname)
        __describe_workspace_names $line[1]
        return
    ;;
    (account)
        __describe_workspace_accounts $line[1] $line[2]
        return
    ;;
    (environment)
        __describe_workspace_environments $line[1] $line[2] $line[3]
        return
    ;;
    (action)
        __describe_workspace_actions
        return
    ;;
  esac
}

function _infra_account {
  local curcontext="$curcontext" state line

  _arguments -C \
    ':account:->account' \
    ':environment:->environment' \
    '*::action:->action'

  case $state in
    (account)
        __describe_workspace_accounts "account"
        return
    ;;
    (environment)
        __describe_workspace_environments "account" "" $line[1]
        return
    ;;
    (action)
        __describe_workspace_actions
        return
    ;;
  esac
}

function _infra_dir {
  local curcontext="$curcontext" state line

  _arguments -C \
    ':wtype:->wtype' \
    ':wname:->wname'

  case $state in
    (wtype)
        __describe_workspace_types
        return
    ;;
    (wname)
        __describe_workspace_names $line[1]
        return
    ;;
  esac
}
