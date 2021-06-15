###
### A makefile library for terraform
###
### This library can be extend by including provider specific extensions wich handle login session
### and/or backend state config
###
### Public variables:
###   - VAR_FILE         => a terraform tfvars file (required)
###   - DEFAULT_VAR_FILE => variables shared between environments, default: default.tfvars
###   - PROVIDER         => aws and azure are currently supported, default: aws
###   - BACKEND_TYPE     => s3 and azurerm arecurrently supported, default: s3
###   - STATE_NAME       => the state filename, default: unknown
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
###   - init                      => By default, the backend is always initialized on every call that
###                                  operates on the state. If it is posible to determine if a re-initialisation
###                                  this target should be extended to conditionally call force-init
###   - session                   => Get a new session for the cooresponding provider
###   - backup-state			  => will be called befor modifying the state.
###   - debug			          => Add some variable values to debug oputput
###   - before-state-modification => will be called before all targets that modify the state (refresh, plan, apply)
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

# default provider and backend
TERRAFORM_PROVIDER ?= aws
BACKEND_TYPE ?= s3

# VAR_FILE is the main parameter source in terraform tfvars format
# This is required, but if a state has been initialized,
# we can try to load the file name from there
ifeq ($(VAR_FILE),)
-include $(TERRAFORM_MAKE_LIB_HOME)/terraform-local-state-backend-$(BACKEND_TYPE).mk
endif

# still empty? use the default
ifeq ($(VAR_FILE),)
	VAR_FILE := default.tfvars
endif

# DEFAULT_VAR_FILE will always be loaded. defaults to VAR_FILE if emtpy
DEFAULT_VAR_FILE ?= default.tfvars
ifeq ($(wildcard $(DEFAULT_VAR_FILE)),)
	# no default var file? use the VAR_FILE instead
	DEFAULT_VAR_FILE = $(VAR_FILE)
endif

# determine the environment
ENVIRONMENT := $(shell if [ -f "$(VAR_FILE)" ]; then cat $(VAR_FILE) | grep "^environment[[:space:]]*=" | sed 's/^[^"]*"\(.*\)".*/\1/'; fi)
ifeq ($(ENVIRONMENT),)
	# fallback to default
	ENVIRONMENT := $(shell if [ -f "$(DEFAULT_VAR_FILE)" ]; then cat $(DEFAULT_VAR_FILE) | grep "^environment[[:space:]]*=" | sed 's/^[^"]*"\(.*\)".*/\1/'; fi)
endif

# if no environment is specified, use the default environment without a backend
# this is mainly used for targets that need basic initialization (e.g. validate)
ifeq ($(ENVIRONMENT),)
	ENVIRONMENT := default
	BACKEND_TYPE :=
endif

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

# include provider and backend plugins
-include $(TERRAFORM_MAKE_LIB_HOME)/$(TERRAFORM_PROVIDER).mk
-include $(TERRAFORM_MAKE_LIB_HOME)/terraform-backend-$(BACKEND_TYPE).mk

# if no plan is given, and the current plan file does not exist, we try PLAN_OUT as current plan file
ifeq ($(PLAN),)
	PLAN := $(CURRENT_PLAN_FILE)
endif
# still no plan? use plan out in case we will create and apply a plan at the same time
ifeq ($(PLAN),)
	PLAN := $(PLAN_OUT)
endif

debug-default:
	@echo ENVIRONMENT=$(ENVIRONMENT)
	@echo VAR_FILE=$(VAR_FILE)
	@echo DEFAULT_VAR_FILE=$(DEFAULT_VAR_FILE)
	@echo TF_ARGS=$(TF_ARGS)
	@echo TF_ARGS_INIT=$(TF_ARGS_INIT)
	@echo TF_ARGS_PLAN=$(TF_ARGS_PLAN)
	@echo CURRENT_PLAN=$(CURRENT_PLAN)
	@echo CURRENT_PLAN_FILE=$(CURRENT_PLAN_FILE)
	@echo PLAN=$(PLAN)
	@echo PLAN_OUT=$(PLAN_OUT)
	@echo STATE_KEY=$(STATE_KEY)
	@echo IS_DEPLOYMENT=$(IS_DEPLOYMENT)
	@echo BACKEND_TYPE=$(BACKEND_TYPE)
	@echo TERRAFORM_CMD=$(TERRAFORM_CMD)
	@echo TERRAFORM=$(TERRAFORM)
	@echo TERRAFORM_PLAN_DIR=$(TERRAFORM_PLAN_DIR)
	@echo TERRAFORM_CACHE_DIR=$(TERRAFORM_CACHE_DIR)
	@echo PRODUCTION_ENVIRONMENT_NAME=$(PRODUCTION_ENVIRONMENT_NAME)
	@echo EXPIRE=$(EXPIRE)
	@echo MIN_PERSIST=$(MIN_PERSIST)

###
### extension targets
###

# make targets with -default suffix extenable without warnings
%: %-default
	@ true

# if the local state file is missing or a deployment is in progress, we need to initialize
# this target can be extended by backends
init-default: force-init

# should install plugins that cannot be installed by terraform init
install-community-plugins-default:
	@ true

# get a new session
session-default:
	@ true

# backup the state
backup-state-default:
	@  true

# will be called before all targets that modify the state (refresh, plan, apply)
before-state-modification-default:
	@ true

# will be called before all targets that modify the state (refresh, plan, apply)
before-init-default:
	@ true

# each backend can provide a backend.tf target, which
# should create the backend.tf file which contains the terraform backend config
# no backend config if no backend plugin is loaded
backend.tf-default: remove-backend

# each backend should implement this target
# which should clean up local files related to the state
clean-state-default:
	@ true

###
###
### validation
###
###

validate: validate-fmt validate-code

# check format
validate-fmt:
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
fmt-and-validate: fmt validate

ensure-plan-dir-exists:
	@mkdir -p $(TERRAFORM_PLAN_DIR)

###
### cleanup
###

# force remove terraform cache dir
force-clean-terraform-cache: clean-terraform-cache
	@rm -rf $(TERRAFORM_CACHE_DIR)

# ensure terraform needs to re-init
# modules and plgins will not be removed
clean-terraform-cache:
	@if [ -d $(TERRAFORM_CACHE_DIR) ]; then find $(TERRAFORM_CACHE_DIR) -maxdepth 1 -type f -not -name $(TERRAFORM_CACHE_DIR) -not -name 'plugins' -not -name 'modules' -delete; fi
	@rm -rf exit_status.txt

clean-terraform-plans:
	@rm -rf $(TERRAFORM_PLAN_DIR)
	@rm -rf exit_status.txt

# clean plans and terraform cache
clean-all: clean-terraform-cache clean-terraform-plans remove-backend

# clean plans and terraform cache
force-clean-all: force-clean-terraform-cache clean-terraform-plans remove-backend

###
### default
###
.DEFAULT_GOAL := default
default: fmt validate

###
### initialzation
###
TF_ARGS_INIT = $(BACKEND_TERRAFORM_INIT_ARGS)

version:
	$(TERRAFORM) version

# force re-initialization of terraform state
force-init: backend.tf install-community-plugins before-init clean-state .tf-init
	@$(MAKE) ensure-workspace

.tf-init: session
	$(TERRAFORM) init $(TF_ARGS_INIT)

# update modules
update-modules:
	$(TERRAFORM) get -update=true

# create a new workspace
create-workspace: session init
	@$(TERRAFORM) workspace select $(ENVIRONMENT) &> /dev/null || $(TERRAFORM) workspace new $(ENVIRONMENT)

# ensure workspace selected
ensure-workspace: session init
	@if [ "$(shell $(TERRAFORM) workspace show)" != "$(ENVIRONMENT)" ]; then $(TERRAFORM) workspace select $(ENVIRONMENT)  || $(TERRAFORM) workspace new $(ENVIRONMENT); fi

# list configured workspaces
list-configured-workspaces:
	@echo "$(YELLOW)Workspaces defined for $(GREEN)$(ACCOUNT)$(NC)$(YELLOW):$(NC)"
	@find . -name "$(ACCOUNT)-*.tfvars" | grep -v default | awk -F'-' '{print $$2}' | sed 's/.tfvars//' | sort -u

# list workspaces that exist in backend
list-existing-workspaces: init
	@echo "$(YELLOW)Workspaces created for $(GREEN)$(ACCOUNT)$(NC)$(YELLOW):$(NC)"
	@$(TERRAFORM) workspace list | grep -v default | sed 's/* //' | sort -u

# list configured and existing workspaces
list-workspaces: list-configured-workspaces list-existing-workspaces

###
### plan
###
TERRAFORM_STATE_LOCK ?= false
ifeq ($(TERRAFORM_STATE_LOCK),true)
	TF_ARGS_LOCK := -lock=$(TERRAFORM_STATE_LOCK)
endif
ifeq ($(DISABLE_STATE_LOCK),true)
	TF_ARGS_LOCK :=
endif

TF_ARGS_VAR_IS_DEPLOYMENT = -var 'is_deployment=$(IS_DEPLOYMENT)'
TF_ARGS_VAR_FILE = -var-file '$(VAR_FILE)'
ifneq ($(DEFAULT_VAR_FILE),$(VAR_FILE))
	TF_ARGS_DEFAULT_VAR_FILE = -var-file '$(DEFAULT_VAR_FILE)'
endif
TF_ARGS = $(TF_ARGS_DEFAULT_VAR_FILE) $(TF_ARGS_VAR_FILE) $(TF_ARGS_VAR_IS_DEPLOYMENT) $(PROVIDER_TERRAFORM_ARGS)
TF_ARGS_PLAN = $(TF_ARGS_LOCK) $(TF_ARGS)

WRITE_PLAN_STATUS ?= false
ifeq ($(WRITE_PLAN_STATUS),true)
	WRITE_PLAN_STATUS_ARG = -detailed-exitcode; echo $$? > exit_status.txt
endif

# create a new plan, if not exists
plan: check-plan-missing ensure-workspace validate before-state-modification
	@rm -f exit_code.txt
	$(TERRAFORM) plan $(TF_ARGS_PLAN) -out=$(PLAN_OUT)  $(WRITE_PLAN_STATUS_ARG)
	@echo $(PLAN_OUT) > $(CURRENT_PLAN)
	@echo "$(GREEN)Plan created at $(YELLOW)$(PLAN_OUT)$(GREEN) and made current.$(NC)"
	@echo "$(GREEN)Apply with 'make apply'$(NC)"
	@echo "$(GREEN)Dismiss with 'make dismiss-plan'$(NC)"

plan-json: check-plan-exists ensure-workspace validate
	$(TERRAFORM) show -json $(CURRENT_PLAN_FILE) | jq -r '( [.resource_changes[]?.change.actions?] | flatten ) | { "create":(map(select(.=="create")) | length), "update":(map(select(.=="update")) | length), "delete":(map(select(.=="delete")) | length) }' > $(CURRENT_PLAN_FILE).json

plan-target:
	#$(TERRAFORM) plan $(TF_ARGS_PLAN) -out=$(PLAN_OUT) -target $(PLAN_TARGET)
	@echo $(PLAN_OUT)

# force create new plan
force-plan: dismiss-plan plan

# dismiss current plan
dismiss-plan: ensure-workspace
	@if [ -f "$(CURRENT_PLAN)" ]; then rm -f $(CURRENT_PLAN_FILE); rm -f $(CURRENT_PLAN); fi

# check if PLAN file is missing
check-plan-missing: ensure-workspace ensure-plan-dir-exists
	@if [ -f "$(PLAN)" ]; then echo "$(RED)Current plan exists. Please dismiss first.$(NC)"; exit 1; fi

# check if PLAN exists
# uses the current plan as default if PLAN is not defined
check-plan-exists: ensure-workspace ensure-plan-dir-exists
	@if [ ! -f "$(PLAN)" ]; then echo "$(RED)Plan $(PLAN) does not exist.$(NC)"; exit 1; fi

# show PLAN
# uses the current plan as default if PLAN is not defined
show-plan: ensure-workspace check-plan-exists
	$(TERRAFORM) show $(PLAN)

current-plan:
	@echo $(PLAN)

# create a destructive plan
plan-destroy: check-plan-missing ensure-workspace validate before-state-modification
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
ifneq ($(IS_DEPLOYMENT),true)
	@echo
	@echo "$(YELLOW)You are deploying to $(RED)PRODUCTION$(NC)!!"
	@read -p "Are you sure? (only yes will be accepted): " deploy; \
	if [[ $$deploy != "yes" ]]; then exit 1; fi
endif
endif

# apply plan
apply: check-plan-exists prompt-for-production ensure-workspace validate backup-state before-state-modification
	$(TERRAFORM) apply $(TF_ARGS_LOCK) $(PLAN)
	@rm -f $(CURRENT_PLAN_FILE)
	@rm -f $(PLAN)

force-apply: prompt-for-production session ensure-workspace validate backup-state before-state-modification
	$(TERRAFORM) apply $(TF_ARGS_PLAN) -auto-approve

###
### state and info
###

# list resources in the state
list: ensure-workspace
	$(TERRAFORM) state list

# display output variables from the state
output: ITEM ?=
output: ensure-workspace
	$(TERRAFORM) output $(ITEM)

# update the state with information from infrastructure
refresh: ensure-workspace backup-state before-state-modification
	$(TERRAFORM) refresh $(TF_ARGS_PLAN)

###
### maintain the backend config
###
remove-backend:
	@$(shell rm -f backend.tf*)

disable-backend:
	@$(shell mv backend.tf backend.tf.disabled || true)

enable-backend:
	@$(shell mv backend.tf.disabled backend.tf || true)
	@if [[ ! -f backend.tf ]]; then echo "$(RED)Could not enable backend!!$(NC)"; exit 1; fi

re-write-backend: remove-backend backend.tf

backup-local-state:
	@mv terraform.tfstate.d terraform.tfstate.d.backup
