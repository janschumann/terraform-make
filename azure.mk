###
###
###

NC=\033[0m
RED=\033[0;31m
GREEN=\033[0;32m
YELLOW=\033[1;33m

AZURE_CMD ?= az
AZURE_CLI = $(shell command -v $(AZURE_CMD) 2> /dev/null)

ifeq ($(AZURE_CLI),)
$(error Azure cli not found: $(AZURE_CMD))
endif

OS := $(shell uname)
ifeq ($(OS),Darwin)
	DATE = $(shell gdate --utc +"%Y-%m-%d-%H-%M-%S")
else
	DATE = $(shell date --utc +"%Y-%m-%d-%H-%M-%S")
endif

# the path of the current plan for this region and environment
# this contains the actual file name of the current plan
CURRENT_PLAN := $(TERRAFORM_PLAN_DIR)/current-$(ENVIRONMENT)
# the path of the actual plan file
# empty if no current plan exists
CURRENT_PLAN_FILE := $(shell if [ -f "$(CURRENT_PLAN)" ]; then cat $(CURRENT_PLAN); fi)
# the path to save a new plan to
PLAN_OUT := $(TERRAFORM_PLAN_DIR)/$(ENVIRONMENT)-$(DATE).plan
# the path of a plan file to operate on
# defaults to the current plan
# might be changed to operate on a specific plan, such as previoussly created plans
PLAN ?= $(CURRENT_PLAN)

verify-azure:
	@if [ -z "$(ENVIRONMENT)" ]; then echo "$(RED)Please define an ENVIRONMENT$(NC)"; exit 1; fi
	@command -v $(AZURE_CLI) > /dev/null || echo "$(RED)azure cli not installed$(NC)"

session: azure-login
	@ true

azure-login: verify-azure
	@$(AZURE_CLI) login
