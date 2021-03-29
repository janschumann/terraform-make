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
STATE_PATH := $(STATE_CONTAINER)/env:/$(ENVIRONMENT)/$(STATE_KEY)

# the kms key to encrypt state files in s3
VAR_FILE_KMS_KEY_ARN := $(shell if [ -f $(VAR_FILE) ]; then cat $(VAR_FILE) | grep "^kms_key_id[[:space:]]*=" | sed 's/^[^"]*"\(.*\)".*/\1/'; fi)
ifeq ($(VAR_FILE_KMS_KEY_ARN),)
	KMS_KEY_ARN ?= $(shell if [ -f $(DEFAULT_VAR_FILE) ]; then cat $(DEFAULT_VAR_FILE) | grep "^kms_key_id[[:space:]]*=" | sed 's/^[^"]*"\(.*\)".*/\1/'; fi)
else
	KMS_KEY_ARN ?= $(VAR_FILE_KMS_KEY_ARN)
endif

STATE_ENCRYPT ?= true
# no encryption if no backend should be used
ifeq ($(SKIP_BACKEND),true)
	STATE_ENCRYPT = false
endif

ifeq ($(STATE_ENCRYPT),false)
	KMS_KEY_ARN :=
endif

STATE_BACKEND_S3_CONFIG_INIT_ARGS = "bucket=\"$(STATE_CONTAINER)\"\nkey=\"$(STATE_KEY)\"\nregion=\"$(STATE_BACKEND_REGION)\"\n"
MIN_STATE_BACKEND_S3_CONFIG_INIT_ARGS = $(STATE_BACKEND_S3_CONFIG_INIT_ARGS)
ifeq ($(TERRAFORM_STATE_LOCK),true)
	MIN_STATE_BACKEND_S3_CONFIG_INIT_ARGS = "$(STATE_BACKEND_S3_CONFIG_INIT_ARGS)\ndynamodb_table=$(STATE_LOCK_TABLE)"
endif
MIN_STATE_BACKEND_S3_INIT_ARGS = $(MIN_STATE_BACKEND_S3_CONFIG_INIT_ARGS)
# only add profile backend config, if not deploying
# on deployment, the IAM instance profile of the jenkins build slave
# should be used
ifneq ($(IS_DEPLOYMENT),true)
	MIN_STATE_BACKEND_S3_INIT_ARGS = "$(STATE_BACKEND_S3_CONFIG_INIT_ARGS)profile=\"$(AWS_PROFILE)\"\\n"
endif

BACKEND_TERRAFORM_CONFIG = $(MIN_STATE_BACKEND_S3_INIT_ARGS)
ifneq ($(KMS_KEY_ARN),)
	BACKEND_TERRAFORM_CONFIG = "$(MIN_STATE_BACKEND_S3_INIT_ARGS)kms_key_id=\"$(KMS_KEY_ARN)\""
endif

BACKEND_TERRAFORM_INIT_ARGS = -backend-config=.backend-$(ACCOUNT)-$(ENVIRONMENT).tfvars
ifeq ($(SKIP_BACKEND),true)
	BACKEND_TERRAFORM_INIT_ARGS := -backend=false
endif

ifneq ($(SKIP_BACKEND),true)
	LOCAL_STATE_FILE := $(TERRAFORM_CACHE_DIR)/terraform.tfstate
endif

debug-backend:
	@echo AWS s3 terraform backend debug:
	@echo BACKEND_TERRAFORM_INIT_ARGS=$(BACKEND_TERRAFORM_INIT_ARGS)

ensure-backend-config:
	@echo $(BACKEND_TERRAFORM_CONFIG) > .backend-$(ACCOUNT)-$(ENVIRONMENT).tfvars

init: CURRENT_STATE_KEY = $(shell if [ -f $(LOCAL_STATE_FILE) ]; then cat $(LOCAL_STATE_FILE) | grep "\"key\":" | awk -F\" '{print $$4}'; fi)
init: CURRENT_PROFILE = $(shell if [ -f $(LOCAL_STATE_FILE) ]; then cat $(LOCAL_STATE_FILE) | grep "\"profile\":" | awk -F\" '{print $$4}'; fi)
init: ensure-backend-config warn-env-credentials
	$(shell if [ ! -f $(LOCAL_STATE_FILE) ] || ([ "$(IS_DEPLOYMENT)" != "true" ] && ([ "$(CURRENT_PROFILE)" != "$(AWS_PROFILE)" ] || [ "$(CURRENT_STATE_KEY)" != "$(STATE_KEY)" ])); then echo $(MAKE) force-init; fi)

disable-backend:
	@$(shell mv backend.tf backend.tf.disabled || true)

enable-backend:
	@$(shell mv backend.tf.disabled backend.tf || true)
	@if [[ ! -f backend.tf ]]; then echo "$(RED)Could not enable backend!!$(NC)"; exit 1; fi

backup-local-state: ensure-environment
	@mv terraform.tfstate.d/$(ENVIRONMENT)/terraform.tfstate $(ACCOUNT)-$(ENVIRONMENT).tfstate

push-local-state: ensure-environment enable-backend force-init ensure-workspace
	@echo
	@echo "$(YELLOW)You are uploading a local state to s3$(NC)!!"
	@read -p "Are you sure? (only yes will be accepted): " deploy; \
	if [[ $$deploy != "yes" ]]; then exit 1; fi
	$(TERRAFORM) state push $(ACCOUNT)-$(ENVIRONMENT).tfstate

drift: ensure-workspace
	AWS_PROFILE=$(AWS_PROFILE) driftctl scan --from tfstate+s3://$(STATE_PATH)
