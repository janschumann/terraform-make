# try to load account and environment
# from local state and determine the VAR_FILE name
INIT_STATE_FILE := $(TERRAFORM_CACHE_DIR)/terraform.tfstate
ifneq ($(wildcard $(INIT_STATE_FILE)),)
	VAR_FILE := $(shell cat $(INIT_STATE_FILE) | grep "\"key\":" | awk -F\" '{print $$4}' | awk -F/ '{print $$1}')-$(shell cat $(INIT_STATE_FILE) | grep "\"profile\":" | awk -F\" '{print $$4}' | awk -F- '{print $$3}').tfvars
endif
