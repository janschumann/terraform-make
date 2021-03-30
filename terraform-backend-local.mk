###
### Local state
###

TERRAFORM_STATE_LOCK := false
BACKEND_TERRAFORM_INIT_ARGS :=

init: LOCAL_STATE_DIR := terraform.tfstate.d/$(ENVIRONMENT)
init: session
	$(shell if [ ! -d $(LOCAL_STATE_DIR) ]; then echo $(MAKE) force-init; fi)
	@echo "$(ACCOUNT)" > $(TERRAFORM_CACHE_DIR)/backend-local-account

clean-state:
	@rm -f $(TERRAFORM_CACHE_DIR)/backend-local-account
	@rm -f $(TERRAFORM_CACHE_DIR)/environment
