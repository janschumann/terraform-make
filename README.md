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


