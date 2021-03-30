###
### Local state
###

TERRAFORM_STATE_LOCK := false
BACKEND_TERRAFORM_INIT_ARGS :=

init: LOCAL_STATE_DIR := terraform.tfstate.d/$(ENVIRONMENT)
init: session
	$(shell if [ ! -d $(LOCAL_STATE_DIR) ]; then echo $(MAKE) force-init ensure-workspace; fi)
	@echo "$(ACCOUNT)" > $(TERRAFORM_CACHE_DIR)/local_backend_account.txt

clean-state:
	@rm -f $(TERRAFORM_CACHE_DIR)/local_backend_account.txt
	@rm -f $(TERRAFORM_CACHE_DIR)/environment
