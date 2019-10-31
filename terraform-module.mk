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

# clean terraform working dir
clean:
	@rm -Rf .terraform
	@rm -f provider-tmp.tf

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

# prepare validate wich needs a region set in aws provider
validate-prepare:
	$(shell if [ "$(PROVIDER)" == "aws" ]; then echo "provider \"aws\" { region = \"eu-central-1\" }" > provider-tmp.tf; fi)

# check terraform code
validate: validate-prepare validate-code
	@echo "==> Checking that code complies with terraform fmt requirements..."
	@$(TERRAFORM) fmt -check -recursive || (echo; echo "$(RED)Please correct the files above$(NC)"; echo; exit 1)
	@echo "==> $(GREEN)Ok.$(NC)"

# validate code
validate-code: validate-prepare init
	@$(TERRAFORM) validate
	@rm -f provider-tmp.tf

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
