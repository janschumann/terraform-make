###
### Local state
###

BACKEND_TERRAFORM_INIT_ARGS := -backend=false
LOCAL_STATE_FILE := terraform.tfstate.d/$(ENVIRONMENT)/terraform.tfstate

debug-backend:
	@echo local terraform backend debug:
	@echo BACKEND_TERRAFORM_INIT_ARGS=$(BACKEND_TERRAFORM_INIT_ARGS)

init:
	$(shell if [ ! -f $(LOCAL_STATE_FILE) ]; then echo $(MAKE) force-init; fi)
