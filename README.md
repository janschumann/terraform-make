## Terraform make library

This library wrapps around terraform and eases the workflow by handling 
- cloud provider session/login
- automatic backend initialization
- plan file handling

### Install

Add the following to your `Makefile`
```
STATE_NAME = my-awesome-workspace

-include $(shell curl -sSL -o .terraform-make.mk "https://git.io/install-tf-make"; echo .terraform-make.mk)
```

Install the library
```bash
make install
```

The following environment variables can be used to adjust repo and install path
```bash
export TF_MAKE_BRANCH=master
export TF_MAKE_CLONE_URL=https://github.com/janschumann/terraform-make.git
export TF_MAKE_PATH=${HOME}/.terraform-make
```

### Tools

#### Oh-my-zsh plugin

- activate custom oh my zsh folder if not already done: see env variable `ZSH_CUSTOM` in `.zsh.rc`
- copy the plugin code to the plugin dir 
```bash 
$ cp tools/zsh-plugins/project $ZSH_CUSTOM/plugins/project
```
- copy the example plugin code to the plugin dir
```bash 
$ cp tools/zsh-plugins/project-example $ZSH_CUSTOM/plugins/project-<project_name>
```
- define project params 
```bash
# $ZSH_CUSTOM/plugins/project-foo/project-foo.plugin.zsh
export EXAMPLE_INFRA_HOME="$HOME/Development/Projects/example/devops"
export EXAMPLE_IAM_ROLE="AccountAdministrator"
export EXAMPLE_IAM_USER="user.example"
export EXAMPLE_SESSION_TYPE="sso"
export EXAMPLE_SESSION_DURATION="1hour"
export EXAMPLE_SSO_START_URL="https://example.awsapps.com/start#/"
```
- restart the shell
- try it out 
```bash
$ project-infra-init project-foo
```

