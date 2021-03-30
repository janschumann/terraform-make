# try to load account and environment
# from local state and determine the VAR_FILE name
ifneq ($(wildcard $(TERRAFORM_CACHE_DIR)/local_backend_account.txt),)
	LOCAL_STATE_ACCOUNT = $(shell cat $(TERRAFORM_CACHE_DIR)/local_backend_account.txt)
ifneq ($(wildcard $(TERRAFORM_CACHE_DIR)/environment),)
	VAR_FILE := $(LOCAL_STATE_ACCOUNT)-$(shell cat $(TERRAFORM_CACHE_DIR)/environment).tfvars
endif
endif
