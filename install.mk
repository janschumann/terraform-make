TF_MAKE_BRANCH ?= master
TF_MAKE_CLONE_URL ?= https://github.com/janschumann/terraform-make.git
TF_MAKE_PATH ?= .terraform-make

TERRAFORM_MAKE_LIB_HOME := $(shell pwd)/$(TF_MAKE_PATH)

-include $(TERRAFORM_MAKE_LIB_HOME)/terraform.mk

.PHONY : install
install::
	@git clone -c advice.detachedHead=false --depth=1 -b $(TF_MAKE_BRANCH) $(TF_MAKE_CLONE_URL) $(TERRAFORM_MAKE_LIB_HOME)

.PHONY : clean
clean::
	@ rm -rf $(TERRAFORM_MAKE_LIB_HOME)
