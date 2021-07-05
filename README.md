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
export TF_MAKE_PATH=.terraform-make
```

### Tools

#### Oh-my-zsh plugin

- activate custom oh my zsh folder if not already done: see env variable `ZSH_CUSTOM` in `.zsh.rc`
- copy the plugin code to the plugin dir 
```bash 
$ cp tools/zsh-plugin $ZSH_CUSTOM/plugins/project
```
- define a plugin for each of your projects 
```bash
# $ZSH_CUSTOM/plugins/project-foo/project-foo.plugin.zsh
export FOO_IAM_ROLE="AccountAdministrator"
# this is optional if you use the same lib for each project
#export FOO_INFRA_HOME="path to terraform lib"
export FOO_IAM_USER="some.user"
# optional 1password integration
#export FOO_MFA_TOKEN_CMD="op-otp-token.sh thetoken"
```
- restart the shell
- try it out 
```bash
$ project-infra-init foo
```

