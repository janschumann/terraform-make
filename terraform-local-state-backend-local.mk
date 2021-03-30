#
# Extends terraform-backend-local.mk
#
# Fetch ACCOUNT and ENVIRONMENT from local state files
# and build the VAR_FILE
#

ifneq ($(wildcard $(TERRAFORM_CACHE_DIR)/backend-local-account),)
	LOCAL_STATE_ACCOUNT = $(shell cat $(TERRAFORM_CACHE_DIR)/backend-local-account)
ifneq ($(wildcard $(TERRAFORM_CACHE_DIR)/environment),)
	VAR_FILE := $(LOCAL_STATE_ACCOUNT)-$(shell cat $(TERRAFORM_CACHE_DIR)/environment).tfvars
endif
endif
