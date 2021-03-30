TF_MAKE_BRANCH ?= master
TF_MAKE_CLONE_URL ?= https://github.com/janschumann/terraform-make.git
TF_MAKE_PATH ?= terraform-make

-include $(TF_MAKE_PATH)/terraform.mk

.PHONY : install
install::
	@ git clone -c advice.detachedHead=false --depth=1 -b $(TF_MAKE_BRANCH) $(TF_MAKE_CLONE_URL) $(TF_MAKE_PATH)

.PHONY : clean
clean::
	@ rm -rf $(TF_MAKE_PATH)
