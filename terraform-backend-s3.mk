###
### S3 backend extension for terraform.mk
###
### Requires aws-session.mk to be included before
###

# the region where the state backend is located
STATE_BACKEND_REGION ?= $(DEFAULT_REGION)

# the container to store the state
# => bucket in s3
# => storate container in azure
STATE_CONTAINER ?= $(ORGANISATION)-terraform-state

STATE_LOCK_TABLE = terraform-state-lock

# the state name is part of the state key
STATE_NAME ?= account

# the state key
STATE_KEY ?= $(ACCOUNT)/$(REGION)/$(STATE_NAME).tfstate

STATE_ENCRYPT ?= true
# no encryption if no backend should be used
ifeq ($(SKIP_BACKEND),true)
	STATE_ENCRYPT = false
endif

# the kms key to encrypt state files in s3
# well be read from DEFAULT_VAR_FILE by default
KMS_KEY_ARN ?= $(shell cat $(DEFAULT_VAR_FILE) | grep "^kms_key_id[[:space:]]*=" | sed 's/^[^"]*"\(.*\)".*/\1/')
ifeq ($(STATE_ENCRYPT),false)
	KMS_KEY_ARN =
endif

STATE_BACKEND_S3_CONFIG_INIT_ARGS = -backend-config="bucket=$(STATE_CONTAINER)" -backend-config="key=$(STATE_KEY)" -backend-config="region=$(STATE_BACKEND_REGION)" -backend-config="encrypt=$(STATE_ENCRYPT)" -backend-config="acl=authenticated-read"
MIN_STATE_BACKEND_S3_CONFIG_INIT_ARGS = $(STATE_BACKEND_S3_CONFIG_INIT_ARGS)
ifeq ($(TERRAFORM_STATE_LOCK),true)
	MIN_STATE_BACKEND_S3_CONFIG_INIT_ARGS = $(STATE_BACKEND_S3_CONFIG_INIT_ARGS) -backend-config="dynamodb_table=$(STATE_LOCK_TABLE)"
endif
MIN_STATE_BACKEND_S3_INIT_ARGS = $(MIN_STATE_BACKEND_S3_CONFIG_INIT_ARGS)
# only add profile backend config, if not deploying
# on deployment, the IAM instance profile of the jenkins build slave
# should be used
ifneq ($(IS_DEPLOYMENT),true)
	MIN_STATE_BACKEND_S3_INIT_ARGS = $(MIN_STATE_BACKEND_S3_CONFIG_INIT_ARGS) -backend-config="profile=$(AWS_PROFILE)"
endif

BACKEND_TERRAFORM_INIT_ARGS = $(MIN_STATE_BACKEND_S3_INIT_ARGS)
ifneq ($(KMS_KEY_ARN),)
	BACKEND_TERRAFORM_INIT_ARGS = $(MIN_STATE_BACKEND_S3_INIT_ARGS) -backend-config="kms_key_id=$(KMS_KEY_ARN)"
endif

ifeq ($(SKIP_BACKEND),true)
	BACKEND_TERRAFORM_INIT_ARGS = -backend=false
endif

ifneq ($(SKIP_BACKEND),true)
	LOCAL_STATE_FILE := $(TERRAFORM_CACHE_DIR)/terraform.tfstate
endif

init: CURRENT_STATE_KEY = $(shell if [ -f $(LOCAL_STATE_FILE) ]; then cat $(LOCAL_STATE_FILE) | grep "\"key\":" | awk -F\" '{print $$4}'; fi)
init: CURRENT_PROFILE = $(shell if [ -f $(LOCAL_STATE_FILE) ]; then cat $(LOCAL_STATE_FILE) | grep "\"profile\":" | awk -F\" '{print $$4}'; fi)
init:
	$(shell if [ "$(SKIP_BACKEND)" == "false" ] && ([ "$(IS_DEPLOYMENT)" == "true" ] || [ "$(CURRENT_PROFILE)" != "$(AWS_PROFILE)" ] || [ "$(CURRENT_STATE_KEY)" != "$(STATE_KEY)" ]); then echo $(MAKE) force-init; fi)

ensure-backend:
	@echo "terraform { \n  backend \"s3\" {} \n}" > backend.tf
	@if [ "$(SKIP_BACKEND)" == "true" ]; then rm backend.tf; fi
