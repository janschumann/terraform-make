###
### S3 backend extension for terraform.mk
###
### Requires aws-session.mk to be included before
###

# s3 supports locking
TERRAFORM_STATE_LOCK := true

# the region where the state backend is located
STATE_BACKEND_REGION ?= $(DEFAULT_REGION)

# the container to store the state
# => bucket in s3
# => storate container in azure
STATE_CONTAINER ?= $(ORGANISATION)-terraform-state

STATE_LOCK_TABLE ?= terraform-state-lock
STATE_ENCRYPT ?= true
STATE_ACL ?= authenticated-read

# the kms key to encrypt state files in s3
VAR_FILE_KMS_KEY_ARN := $(shell if [ -f $(VAR_FILE) ]; then cat $(VAR_FILE) | grep "^kms_key_id[[:space:]]*=" | sed 's/^[^"]*"\(.*\)".*/\1/'; fi)
ifeq ($(VAR_FILE_KMS_KEY_ARN),)
	KMS_KEY_ARN ?= $(shell if [ -f $(DEFAULT_VAR_FILE) ]; then cat $(DEFAULT_VAR_FILE) | grep "^kms_key_id[[:space:]]*=" | sed 's/^[^"]*"\(.*\)".*/\1/'; fi)
else
	KMS_KEY_ARN ?= $(VAR_FILE_KMS_KEY_ARN)
endif

# the state name is part of the state key
STATE_NAME ?= unknown

# the state key
STATE_KEY ?= $(ACCOUNT)/$(REGION)/$(STATE_NAME).tfstate

BACKEND_TERRAFORM_INIT_ARGS = -backend-config="key=$(STATE_KEY)"
# only add profile backend config, if not deploying
# on deployment, the IAM instance profile of the jenkins build slave
# should be used
ifneq ($(IS_DEPLOYMENT),true)
	BACKEND_TERRAFORM_INIT_ARGS := $(BACKEND_TERRAFORM_INIT_ARGS) -backend-config="profile=$(AWS_PROFILE)"
endif

init: LOCAL_STATE_FILE := $(TERRAFORM_CACHE_DIR)/terraform.tfstate
init: CURRENT_STATE_KEY := $(shell if [ -f $(LOCAL_STATE_FILE) ]; then cat $(LOCAL_STATE_FILE) | grep "\"key\":" | awk -F\" '{print $$4}'; fi)
init: CURRENT_PROFILE := $(shell if [ -f $(LOCAL_STATE_FILE) ]; then cat $(LOCAL_STATE_FILE) | grep "\"profile\":" | awk -F\" '{print $$4}'; fi)
init: session backend.tf warn-env-credentials
	$(shell if [ ! -f $(LOCAL_STATE_FILE) ] || ([ "$(IS_DEPLOYMENT)" != "true" ] && ([ "$(CURRENT_PROFILE)" != "$(AWS_PROFILE)" ] || [ "$(CURRENT_STATE_KEY)" != "$(STATE_KEY)" ])); then echo $(MAKE) force-init; fi)

backend.tf:
	@sed 's|$${state_bucket}|$(ORGANISATION)-terraform-state|' $(TERRAFORM_MAKE_LIB_HOME)/terraform-backend-s3.tf.tpl | sed 's|$${state_kms_key_id}|$(KMS_KEY_ARN)|' | sed 's|$${state_region}|$(STATE_BACKEND_REGION)|' | sed 's|$${state_lock_table}|$(STATE_LOCK_TABLE)|' | sed 's|$${state_encrypt}|$(STATE_ENCRYPT)|' | sed 's|$${state_acl}|$(STATE_ACL)|' > backend.tf

push-local-state: ensure-environment force-init ensure-workspace
	@echo
	@echo "$(YELLOW)You are uploading a local state to s3$(NC)!!"
	@read -p "Are you sure? (only yes will be accepted): " deploy; \
	if [[ $$deploy != "yes" ]]; then exit 1; fi
	$(TERRAFORM) state push $(ACCOUNT)-$(ENVIRONMENT).tfstate

clean-state:
	@rm -f $(TERRAFORM_CACHE_DIR)/terraform.tfstate
	@rm -f $(TERRAFORM_CACHE_DIR)/environment
