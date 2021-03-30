#
# Extends terraform-backend-s3.mk
#
# Fetch ACCOUNT and ENVIRONMENT from local state files
# and build the VAR_FILE
#

INIT_STATE_FILE := $(TERRAFORM_CACHE_DIR)/terraform.tfstate
ifneq ($(wildcard $(INIT_STATE_FILE)),)
	VAR_FILE := $(shell cat $(INIT_STATE_FILE) | grep "\"profile\":" | awk -F\" '{print $$4}' | awk -F- '{print $$2}')-$(shell cat $(INIT_STATE_FILE) | grep "\"profile\":" | awk -F\" '{print $$4}' | awk -F- '{print $$3}').tfvars
endif
