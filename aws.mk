###
###
###

BACKEND_TYPE ?= s3

### aws cli

NC=\033[0m
RED=\033[0;31m
GREEN=\033[0;32m
YELLOW=\033[1;33m

# aws-cli executable
AWS_CMD ?= aws
AWS = $(shell command -v $(AWS_CMD) 2> /dev/null)

ifeq ($(AWS),)
$(error aws-cli not installed? looking for $(AWS_CMD))
endif

# the organisation of this configuration
# well be read from DEFAULT_VAR_FILE by default
ORGANISATION ?= $(shell cat $(DEFAULT_VAR_FILE) | grep "^organisation_short_name[[:space:]]*=" | sed 's/^[^"]*"\(.*\)".*/\1/')

# the account of this configuration
# well be read from DEFAULT_VAR_FILE by default
ACCOUNT ?= $(shell cat $(VAR_FILE) | grep "^account_name[[:space:]]*=" | sed 's/^[^"]*"\(.*\)".*/\1/')
ACCOUNT_ID ?= $(shell cat $(VAR_FILE) | grep "^account_id[[:space:]]*=" | sed 's/^[^"]*"\(.*\)".*/\1/')

# the environment
ENVIRONMENT ?= $(shell cat $(VAR_FILE) | grep "^environment[[:space:]]*=" | sed 's/^[^"]*"\(.*\)".*/\1/')

# the region of this configuration. this is part of the the backend key name
# well be read from DEFAULT_VAR_FILE by default
REGION ?= $(shell cat $(DEFAULT_VAR_FILE) | grep "^default_region[[:space:]]*=" | sed 's/^[^"]*"\(.*\)".*/\1/')

# the default region of this configuration
DEFAULT_REGION ?= $(shell cat $(DEFAULT_VAR_FILE) | grep "^default_region[[:space:]]*=" | sed 's/^[^"]*"\(.*\)".*/\1/')

ifeq ($(VERBOSE),true)
	AWS_SESSION_VERBOSE_ARG = "-v"
endif
AWS_ROLE_NAME ?= $(AWS_DEFAULT_ROLE_NAME)

ifeq ($(IS_DEPLOYMENT),true)
	AWS_PROFILE =
	AWS_PROFILE_ARG =
else
	AWS_PROFILE ?= $(ORGANISATION)-$(ACCOUNT)-$(ENVIRONMENT)
	AWS_PROFILE_ARG = --profile $(AWS_PROFILE)
endif
PROVIDER_TERRAFORM_ARGS = -var 'default_profile=$(AWS_PROFILE)'

ifeq ($(MIN_SESSION_AGE),)
	MIN_SESSION_AGE = 15
endif

OS := $(shell uname)
ifeq ($(OS),Darwin)
	MIN_PERSIST = $(shell gdate --utc --date "now +$(MIN_SESSION_AGE)min" +"%Y-%m-%dT%H:%M:%SZ")
	DATE = $(shell gdate --utc --date "now" +"%Y-%m-%d-%H-%M-%S")
else
	MIN_PERSIST = $(shell date --utc -D "+$(MIN_SESSION_AGE)min" +"%Y-%m-%dT%H:%M:%SZ")
	DATE = $(shell date --utc -D +"0min" +"%Y-%m-%d-%H-%M-%S")
endif

# the path of the current plan for this region and environment
# this contains the actual file name of the current plan
CURRENT_PLAN := $(TERRAFORM_PLAN_DIR)/current-$(ACCOUNT)-$(ENVIRONMENT)-$(REGION)
# the path to save a new plan to
PLAN_OUT := $(TERRAFORM_PLAN_DIR)/$(ACCOUNT)-$(ENVIRONMENT)-$(REGION)-$(DATE).plan
# the path of the actual plan file
# empty if no current plan exists
CURRENT_PLAN_FILE := $(shell if [ -f "$(CURRENT_PLAN)" ]; then cat $(CURRENT_PLAN); fi)

ifeq ($(SESSION_TARGET_PROFILE),)
	SESSION_TARGET_PROFILE = $(ACCOUNT)-$(ENVIRONMENT)
endif

EXPIRE = $(shell aws --profile $(ORGANISATION)-$(SESSION_TARGET_PROFILE) configure get aws_session_expiration 2> /dev/null || echo 2000-01-01T00:00:00Z)
# never expire a session for deployments and in china region
IS_EXPIRED ?= $(shell if [[ -z $(EXPIRE) || $(EXPIRE) < $(MIN_PERSIST) ]] && [ "$(REGION)" != "cn-north-1" ] && [ "$(IS_DEPLOYMENT)" != "true" ]; then echo 1; else echo 0; fi)

verify-aws: warn-env-credentials
	@if [ -z "$(ORGANISATION)" ]; then echo "$(RED)Please define an ORGANISATION$(NC)"; exit 1; fi
	@if [ -z "$(ACCOUNT)" ]; then echo "$(RED)Please define an ACCOUNT$(NC)"; exit 1; fi
	@if [ -z "$(ENVIRONMENT)" ]; then echo "$(RED)Please define an ENVIRONMENT$(NC)"; exit 1; fi
	@command -v $(AWS) > /dev/null || echo "$(RED)aws cli not installed$(NC)"

show-account-id: verify-account-id
	@echo $(ACCOUNT_ID)

verify-account-id:
	@if [ -z "$(ACCOUNT_ID)" ]; then echo "$(RED)Please define an ACCOUNT ID$(NC)"; exit 1; fi

verify-credentials: warn-env-credentials
	@if [ -z "$(ACCESS_KEY_ID)" ]; then echo "$(RED)Please define an access key$(NC)"; exit 1; fi
	@if [ -z "$(SECRET_ACCESS_KEY)" ]; then echo "$(RED)Please define an secret access key$(NC)"; exit 1; fi

verify-active-session: warn-env-credentials
	@if [ 1 -eq $(IS_EXPIRED) ]; then echo "$(RED)Your Session $(YELLOW)$(AWS_PROFILE)$(RED) has expired. Aborting.$(NC)"; exit 1; fi

warn-env-credentials:
	@if [[ "$(shell env | grep AWS_PROFILE)" ]]; then echo "$(YELLOW)WARNING: AWS_PROFILE is defined as env variable$(NC)"; fi
	@if [[ "$(shell env | grep AWS_ACCESS_KEY_ID)" ]]; then echo "$(YELLOW)WARNING: AWS_ACCESS_KEY_ID is defined as env variable$(NC)"; fi
	@if [[ "$(shell env | grep AWS_SECRET_ACCESS_KEY_ID)" ]]; then echo "$(YELLOW)WARNING: AWS_SECRET_ACCESS_KEY_ID is defined as env variable$(NC)"; fi

session: access-$(AWS_ROLE_NAME)

access-$(AWS_ROLE_NAME): warn-env-credentials
	@if [ 1 -eq $(IS_EXPIRED) ]; then $(TERRAFORM_MAKE_LIB_HOME)/aws-session.sh -o $(ORGANISATION) -p $(SESSION_TARGET_PROFILE) -r $(AWS_ROLE_NAME) $(AWS_SESSION_VERBOSE_ARG); fi

show-access-cmd:
	@echo $(TERRAFORM_MAKE_LIB_HOME)/aws-session.sh -o $(ORGANISATION) -p $(SESSION_TARGET_PROFILE) -r $(AWS_ROLE_NAME)

reset-iam-config: IAM_USER ?= $(USER)
reset-iam-config: verify-aws verify-account-id
	@$(AWS) --profile $(ORGANISATION)-iam configure set account_id $(ACCOUNT_ID)
	@$(AWS) --profile $(ORGANISATION)-iam configure set iam_user $(IAM_USER)
	@$(AWS) --profile $(ORGANISATION)-iam configure set region $(REGION)

reset-account-config: verify-aws verify-account-id
	@$(AWS) --profile $(ORGANISATION)-$(ACCOUNT)-$(ENVIRONMENT) configure set account_id $(ACCOUNT_ID)
	@$(AWS) --profile $(ORGANISATION)-$(ACCOUNT)-$(ENVIRONMENT) configure set aws_session_expiration "2000-01-01T00:00:00Z"
	@$(AWS) --profile $(ORGANISATION)-$(ACCOUNT)-$(ENVIRONMENT) configure set region $(REGION)

override-credentials: verify-aws verify-credentials
	@$(AWS) --profile $(ORGANISATION)-$(ACCOUNT)-$(ENVIRONMENT) configure set aws_access_key_id $(ACCESS_KEY_ID)
	@$(AWS) --profile $(ORGANISATION)-$(ACCOUNT)-$(ENVIRONMENT) configure set aws_secret_access_key $(SECRET_ACCESS_KEY)
	@$(AWS) --profile $(ORGANISATION)-$(ACCOUNT)-$(ENVIRONMENT) configure set aws_session_expiration "$(shell date --utc --date "now +$(MIN_SESSION_AGE)min" +"%Y-%m-%dT%H:%M:%SZ")"

delete-login-profile: verify-aws
	@$(AWS) --profile ${ORGANISATION}-${ACCOUNT}-${ENVIRONMENT} iam get-user --user-name "$(IAM_USER)" &> /dev/null
	@$(AWS) --profile ${ORGANISATION}-${ACCOUNT}-${ENVIRONMENT} iam delete-login-profile --user-name "$(IAM_USER)" &> /dev/null || echo "Profile does not exists."
	@$(foreach SERIAL, $(shell $(AWS) --profile ${ORGANISATION}-${ACCOUNT}-${ENVIRONMENT} iam list-mfa-devices --user-name $(IAM_USER) | jq -r '.MFADevices[].SerialNumber'), $(AWS) --profile ${ORGANISATION}-${ACCOUNT}-${ENVIRONMENT} iam deactivate-mfa-device --user-name $(IAM_USER) --serial-number $(SERIAL))
	@$(foreach SERIAL, $(shell $(AWS) --profile ${ORGANISATION}-${ACCOUNT}-${ENVIRONMENT} iam list-mfa-devices --user-name $(IAM_USER) | jq -r '.MFADevices[].SerialNumber'), $(AWS) --profile ${ORGANISATION}-${ACCOUNT}-${ENVIRONMENT} iam delete-virtual-mfa-device --serial-number $(SERIAL))
	@$(foreach ACCESS_KEY, $(shell $(AWS) --profile ${ORGANISATION}-${ACCOUNT}-${ENVIRONMENT} iam list-access-keys --user-name $(IAM_USER) | jq -r '.AccessKeyMetadata[].AccessKeyId'), $(AWS) --profile ${ORGANISATION}-${ACCOUNT}-${ENVIRONMENT} iam delete-access-key --user-name $(IAM_USER) --access-key-id $(ACCESS_KEY))

create-login-profile: verify-aws
	@$(AWS) --profile ${ORGANISATION}-${ACCOUNT}-${ENVIRONMENT} iam create-login-profile --user-name "$(IAM_USER)" --password-reset-required --password "$(PASSWORD)"
