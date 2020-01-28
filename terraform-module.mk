-include $(TERRAFORM_MAKE_LIB_HOME)/terraform-module-$(TERRAFORM_PROVIDER).mk

# terraform executable. set as env variable to overwrite.
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

PROVIDER_FILE ?= "terraform-provider-tmp.tf"

# make targets with -default suffix extenable without warnings
%: %-default
	@ true

# should install plugins that cannot be installed by terraform init
prepare-provider-default:
	@ true

# clean terraform working dir
clean:
	@rm -Rf .terraform
	@rm -f $(PROVIDER_FILE)

# clean modules. need to call make init or make update modules after this
clean-modules:
	@rm -Rf .terraform/modules

# clean plugins. need to call make init after this
clean-plugins:
	@rm -Rf .terraform/plugins

# force update the modules
update-modules: clean-modules
	@$(TERRAFORM) get -update

# format terraform files recursively
fmt:
	@$(TERRAFORM) fmt -recursive

# check format
validate-fmt:
	@echo "==> Checking that code complies with terraform fmt requirements..."
	@$(TERRAFORM) fmt -check -recursive || (echo; echo "$(RED)Please correct the files above$(NC)"; echo; exit 1)
	@echo "==> $(GREEN)Ok.$(NC)"

# validate code
validate-code: prepare-provider init
	$(TERRAFORM) validate
	@rm -f $(PROVIDER_FILE)

validate: validate-fmt validate-code

# clean plugins and moules before init
force-init: clean init

# init backend config and modules if necessary
# if you get 'Plugin reinitialization required.' errors, call make force-init
# if you get 'Module not installed' errors, make update-modules should be sufficient
init:
	$(TERRAFORM) init

# format, validate the code and re-initialize
.DEFAULT_GOAL := default
default: fmt validate
