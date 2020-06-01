###
### Local state
###

BACKEND_TERRAFORM_INIT_ARGS := -backend=false
LOCAL_STATE_FILE := terraform.tfstate.d/$(ENVIRONMENT)/terraform.tfstate

init:
	$(shell if [ ! -f $(LOCAL_STATE_FILE) ]; then echo $(MAKE) force-init; fi)
