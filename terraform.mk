###
### A makefile library for terraform
###
### This library can be extend by including provider specific extensions wich handle login session
### and/or backend state config
###
### Public variables:
###   - ENVIRONMENT (required before include)
###   - ORGANISATION
###   - ACCOUNT
###   - ACCOUNT_ID
###   - REGION
###   - DEFAULT_REGION
###   - STATE_BACKEND_REGION
###   - STATE_BACKEND_CONTAINER
###   - STATE_NAME
###   - STATE_KEY
###   - PROVIDER_TERRAFORM_INIT_ARGS => an extension can introduce this variable to control initialisation
###
### Public targets:
###   - fmt              => format terraform code recursively
###   - validate         => validate terraform code
###   - force-init       => forcibly initializes the backend removing all terraform created files first
###   - plan             => creates a plan
###   - plan-destroy     => creates a destroy plan
###   - apply            => apply a plan
###   - output			 => state output
###   - refresh			 => refresh the state
###
### Extension targets:
###   - install-community-plugins => should install plugins that cannot be installed by terraform init
###   - init                      => By default, the backend is always initialized on every call that
###                                  operates on the state. If it is posible to determine if a re-initialisation
###                                  this target should be extended to conditionally call force-init
###   - verify-active-session     => should fail, if no valid credentials can be found or the session is expired
###   - session                   => Get a new session for the cooresponding provider
###	  - ensure-backend            => create backend.tf file containing the backend decalration
###   - backup-state			  => will be called befor modifying the state.
###   - debug			          => Add some variable values to debug oputput
###
###


###
###
### variables
###
###

NC=\033[0m
RED=\033[0;31m
GREEN=\033[0;32m
YELLOW=\033[1;33m

# the terraform executable.
TERRAFORM_CMD ?= terraform
TERRAFORM = $(shell command -v $(TERRAFORM_CMD) 2> /dev/null)
ifeq ($(TERRAFORM),)
$(error Terraform cmd not found: $(TERRAFORM_CMD))
endif

# dir to save plans
TERRAFORM_PLAN_DIR ?= .terraform-plans

# terraform uses TF_DATA_DIR env variable to set the path to its
# cache storage, so we also respect that variable
TERRAFORM_CACHE_DIR := $(TF_DATA_DIR)
ifeq ($(TERRAFORM_CACHE_DIR),)
	TERRAFORM_CACHE_DIR := .terraform
endif

# terraforms state dir. state initialization is done here
TERRAFORM_STATE_DIR := terraform.tfstate.d

# if no specific backend gets loaded, this setting has no effect
# backends MUST clear all backend initialisation parameters if this is set to true
SKIP_BACKEND ?= false

# wether to lock state operations
# defaults to true
# may be disabled for backend that do not support locking
TERRAFORM_STATE_LOCK ?= true
ifeq ($(SKIP_BACKEND),true)
	TERRAFORM_STATE_LOCK = false
endif

# indicates a deployment
# this causes this build tool to omit profile configuration
# on terraform backend initialisation to delegate that to IAM instance profile
# this is exposed to terraform commands via -var deplyment=$(IS_DEPOYMENT)
# so that terraform configs can also decide to
# omit profile config
# default is false. no other value than "true" wil change anything
IS_DEPLOYMENT ?= false

# the name ot the production environment
# used to display warning when attempting to deploy to this environment
PRODUCTION_ENVIRONMENT_NAME ?= prod

# var file to load environment specific values from
# defaults to terraform.tfvars
VAR_FILE ?= terraform.tfvars
ifeq ($(wildcard $(VAR_FILE)),)
$(error Variable file not found: VAR_FILE=$(VAR_FILE))
endif
# var file to load default values from
# will be added before other var files to terraform calls, so that values can be
# overridden in environment specific var files
# if the default var file does not exist, VAR_FILE is used as fallback
DEFAULT_VAR_FILE ?= default.tfvars
ifeq ($(wildcard $(DEFAULT_VAR_FILE)),)
	DEFAULT_VAR_FILE = $(VAR_FILE)
endif
ifeq ($(wildcard $(DEFAULT_VAR_FILE)),)
$(error Default Variable file not found: DEFAULT_VAR_FILE=$(DEFAULT_VAR_FILE))
endif

# the default is sourced from the given var file
ENVIRONMENT ?= $(shell cat $(VAR_FILE) | grep "^environment[[:space:]]*=" | sed 's/^[^"]*"\(.*\)".*/\1/')

# this contains the actual file name of the current plan
# backends MUST override this setting
CURRENT_PLAN := $(TERRAFORM_PLAN_DIR)/current-$(ENVIRONMENT)
# the path of the actual plan file
# empty if no current plan exists
# backends MUST override this setting
CURRENT_PLAN_FILE := $(shell if [ -f "$(CURRENT_PLAN)" ]; then cat $(CURRENT_PLAN); fi)
# the path to save a new plan to
# backends MUST override this setting
PLAN_OUT := $(TERRAFORM_PLAN_DIR)/$(ENVIRONMENT).plan
# the path of a plan file to operate on
# defaults to the current plan
# might be changed to operate on a specific plan, such as previoussly created plans
# backends MUST override this setting
PLAN ?= $(CURRENT_PLAN)

LOCAL_STATE_FILE ?= $(TERRAFORM_STATE_DIR)/$(ENVIRONMENT)/terraform.tfstate
ifeq ($(ENVIRONMENT),default)
	LOCAL_STATE_FILE = terraform.tfstate
endif

debug-default:
	@echo ENVIRONMENT=$(ENVIRONMENT)
	@echo VAR_FILE=$(VAR_FILE)
	@echo DEFAULT_VAR_FILE=$(DEFAULT_VAR_FILE)
	@echo TF_ARGS=$(TF_ARGS)
	@echo TF_ARGS_INIT=$(TF_ARGS_INIT)
	@echo TF_ARGS_PLAN=$(TF_ARGS_PLAN)
	@echo CURRENT_PLAN=$(CURRENT_PLAN)
	@echo PLAN=$(PLAN)
	@echo LOCAL_STATE_FILE=$(LOCAL_STATE_FILE)
	@echo IS_DEPLOYMENT=$(IS_DEPLOYMENT)
	@echo SKIP_BACKEND=$(SKIP_BACKEND)
ifeq ($(VERBOSE),true)
	@echo TERRAFORM_CMD=$(TERRAFORM_CMD)
	@echo TERRAFORM=$(TERRAFORM)
	@echo TERRAFORM_PLAN_DIR=$(TERRAFORM_PLAN_DIR)
	@echo TERRAFORM_CACHE_DIR=$(TERRAFORM_CACHE_DIR)
	@echo TERRAFORM_STATE_DIR=$(TERRAFORM_STATE_DIR)
	@echo TERRAFORM_STATE_LOCK=$(TERRAFORM_STATE_LOCK)
	@echo PRODUCTION_ENVIRONMENT_NAME=$(PRODUCTION_ENVIRONMENT_NAME)
endif

###
### extension targets
###

# make targets with -default suffix extenable without warnings
%: %-default
	@  true

# should install plugins that cannot be installed by terraform init
install-community-plugins-default:
	@  true

# should fail, if no valid credentials can be found or the session is expired
verify-active-session-default:
	@  true

# should create a backend.tf file contining the base backend declaration
ensure-backend-default:
	@  true

# get a new session
session-default:
	@  true

###
###
### validation
###
###

ifeq ($(ENVIRONMENT),)
$(error Please define the ENVIRONMENT env variable or set the environment in the var file $(VAR_FILE))
endif

# check the format
validate: validate-code
	@echo "==> Checking that code complies with terraform fmt requirements..."
	@$(TERRAFORM) fmt -check -recursive || (echo; echo "$(RED)Please correct the files above$(NC)"; echo; exit 1)
	@echo "==> $(GREEN)Ok.$(NC)"

# validate code
validate-code: init
	$(TERRAFORM) validate

# format terraform code
fmt:
	@$(TERRAFORM) fmt -recursive

# format and validate
fmt-and-validate: init fmt validate

ensure-plan-dir-exists:
	@mkdir -p $(TERRAFORM_PLAN_DIR)

###
### cleanup
###

# force remove terraform cache dir
clean-terraform-state:
	@rm -rf $(TERRAFORM_CACHE_DIR)
	@rm -rf $(TERRAFORM_STATE_DIR)
	@rm -rf terraform.tfstate

# ensure terraform needs to re-init
# modules and plgins will not be removed
clean-terraform:
	@if [ -d $(TERRAFORM_CACHE_DIR) ]; then find $(TERRAFORM_CACHE_DIR) -type f -not -name $(TERRAFORM_CACHE_DIR) -not -name 'plugins' -not -name 'modules' -maxdepth 1 -delete; fi
	@rm -rf backend.tf

# force cleanup plans and terraform cache
force-clean-terraform: clean-terraform clean-terraform-state

# clean plans and terraform cache
clean-all: clean-terraform
	@rm -rf $(TERRAFORM_PLAN_DIR)

###
### initialzation
###
TF_ARGS_INIT = -lock=$(TERRAFORM_STATE_LOCK) $(BACKEND_TERRAFORM_INIT_ARGS)
ifeq ($(SKIP_BACKEND),true)
	TF_ARGS_INIT = -lock=false -backend=false
endif

# force re-initialization of terraform state
force-init: clean-terraform update-modules install-community-plugins session ensure-backend
	$(TERRAFORM) init $(TF_ARGS_INIT)

# if the local state file is missing or a deployment is in progress, we need to initialize
# this target can be extended by backends
init-default: session
	$(shell if [ "$(IS_DEPLOYMENT)" == "true" ] || [ ! -f $(LOCAL_STATE_FILE) ]; then echo $(MAKE) force-init; fi)

# update modules
update-modules:
	$(TERRAFORM) get -update=true

# create a new workspace
create-workspace: session init
	@$(TERRAFORM) workspace select $(ENVIRONMENT) &> /dev/null || $(TERRAFORM) workspace new $(ENVIRONMENT)

# ensure workspace selected
ensure-workspace: session init verify-active-session ensure-backend
	@if [ "$(shell $(TERRAFORM) workspace show)" != "$(ENVIRONMENT)" ]; then $(TERRAFORM) workspace select $(ENVIRONMENT); fi

# list configured workspaces
list-configured-workspaces:
	@echo "$(YELLOW)Workspaces defined for $(GREEN)$(ACCOUNT)$(NC)$(YELLOW):$(NC)"
	@find . -name "$(ACCOUNT)-*.tfvars" | grep -v default | awk -F'-' '{print $$2}' | sed 's/.tfvars//' | sort -u

# list workspaces that exist in backend
list-existing-workspaces: session init verify-active-session
	@echo "$(YELLOW)Workspaces created for $(GREEN)$(ACCOUNT)$(NC)$(YELLOW):$(NC)"
	@$(TERRAFORM) workspace list | grep -v default | sed 's/* //' | sort -u

# list configured and existing workspaces
list-workspaces: list-configured-workspaces list-existing-workspaces

###
### plan
###
TF_ARGS_LOCK = -lock=$(TERRAFORM_STATE_LOCK)
TF_ARGS_VAR_IS_DEPLOYMENT = -var 'is_deployment=$(IS_DEPLOYMENT)'
TF_ARGS_VAR_FILE = -var-file '$(VAR_FILE)'
ifneq ($(DEFAULT_VAR_FILE),$(VAR_FILE))
	TF_ARGS_DEFAULT_VAR_FILE = -var-file '$(DEFAULT_VAR_FILE)'
endif
TF_ARGS = $(TF_ARGS_DEFAULT_VAR_FILE) $(TF_ARGS_VAR_FILE) $(TF_ARGS_VAR_IS_DEPLOYMENT) $(PROVIDER_TERRAFORM_ARGS)
TF_ARGS_PLAN = $(TF_ARGS_LOCK) $(TF_ARGS)

# create a new plan, if not exists
plan: check-plan-missing session ensure-workspace
	@rm -f exit_code.txt
	$(TERRAFORM) plan $(TF_ARGS_PLAN) -out=$(PLAN_OUT)
	@echo $(PLAN_OUT) > $(CURRENT_PLAN)
	@echo ""
	@echo "$(GREEN)Plan created at $(YELLOW)$(PLAN_OUT)$(GREEN) and made current.$(NC)"
	@echo "$(GREEN)Apply with 'make apply'$(NC)"
	@echo "$(GREEN)Dismiss with 'make dismiss-plan'$(NC)"

# force create new plan
force-plan: dismiss-plan plan

# dismiss current plan
dismiss-plan:
# remove accociated plan file
	@if [ -f "$(CURRENT_PLAN_FILE)" ]; then rm -f $(CURRENT_PLAN_FILE); fi
# remove current plan
	@if [ -f "$(CURRENT_PLAN)" ]; then rm -f $(CURRENT_PLAN); fi

# check if CURRENT PLAN is missing
check-plan-missing: ensure-plan-dir-exists
	@if [ -f "$(CURRENT_PLAN)" ]; then echo "$(RED)Current plan exists. Please dismiss first.$(NC)"; exit 1; fi

# check if PLAN exists
# uses the current plan as default if PLAN is not defined
check-plan-exists: ensure-plan-dir-exists
ifeq ($(PLAN),$(CURRENT_PLAN))
	@if [ ! -f "$(CURRENT_PLAN_FILE)" ]; then echo "$(RED)Current plan for $(REGION) $(ENVIRONMENT) is missing.$(NC)"; exit 1; fi
else
	@if [ ! -f "$(PLAN)" ]; then echo "$(RED)Plan $(PLAN) does not exist.$(NC)"; exit 1; fi
endif

# show PLAN
# uses the current plan as default if PLAN is not defined
show-plan: check-plan-exists
ifeq ($(PLAN),$(CURRENT_PLAN))
	$(TERRAFORM) show $(CURRENT_PLAN_FILE)
else
	$(TERRAFORM) show $(PLAN)
endif

# create a destructive plan
plan-destroy: check-plan-missing session ensure-workspace
	$(TERRAFORM) plan $(TF_ARGS_PLAN) -out=$(PLAN_OUT) -destroy
	@echo $(PLAN_OUT) > $(CURRENT_PLAN)
	@echo ""
	@echo "$(GREEN)Plan created at $(YELLOW)$(PLAN_OUT)$(GREEN) and made current.$(NC)"
	@echo "$(GREEN)Apply with 'make apply'$(NC)"
	@echo "$(GREEN)Dismiss with 'make dismiss-plan'$(NC)"

###
### apply
###

prompt-for-production:
ifeq ($(ENVIRONMENT),$(PRODUCTION_ENVIRONMENT_NAME))
	@echo
	@echo
	@read -p "You are deploying to PRODUCTION!! Are you sure? (only yes will be accepted): " deploy; \
	if [[ $$deploy != "yes" ]]; then exit 1; fi
endif


# apply plan
apply: check-plan-exists prompt-for-production session ensure-workspace backup-state
ifeq ($(PLAN),$(CURRENT_PLAN))
	$(TERRAFORM) apply $(TF_ARGS_LOCK) $(CURRENT_PLAN_FILE)
	@rm $(CURRENT_PLAN_FILE)
	@rm $(CURRENT_PLAN)
else
	$(TERRAFORM) apply $(TF_ARGS_LOCK) $(PLAN)
endif

###
### state and info
###

# check infrastructure is up-to-dare
ifeq ($(VERBOSE),true)
	CHECK_STATE_VERBOSE_ARG = ""
else
	CHECK_STATE_VERBOSE_ARG = "&> /dev/null"
endif
check-state: session ensure-workspace
	@rm -f exit_status.txt
	@$(TERRAFORM) plan $(TF_ARGS_PLAN) -detailed-exitcode $(CHECK_STATE_VERBOSE_ARG); echo $$? > exit_status.txt

# list resources in the state
list: session ensure-workspace
	$(TERRAFORM) state list

# display output variables from the state
output: ITEM ?=
output: session ensure-workspace
	$(TERRAFORM) output $(ITEM)

# update the state with information from infrastructure
refresh: session ensure-workspace backup-state
	$(TERRAFORM) refresh $(TF_ARGS_PLAN)
