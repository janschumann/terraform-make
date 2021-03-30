STATE_KEY ?= $(STATE_NAME).tfstate

AZURERM_BACKEND_SUBSCRIPTION ?= $(ENVIRONMENT)
BACKEND_TERRAFORM_INIT_ARGS = -backend-config="storage_account_name=$(AZURERM_BACKEND_STORAGE_ACCOUNT_NAME)" -backend-config="container_name=$(STATE_BACKEND_CONTAINER)" -backend-config="access_key=$(AZURERM_BACKEND_STORAGE_ACCOUNT_ACCESS_KEY)" -backend-config="key=$(STATE_KEY)"

init: LOCAL_STATE_FILE := $(TERRAFORM_CACHE_DIR)/terraform.tfstate
init: CURRENT_STATE_KEY = $(shell if [ -f $(LOCAL_STATE_FILE) ]; then cat $(LOCAL_STATE_FILE) | grep "\"key\":" | awk -F\" '{print $$4}'; fi)
init: CURRENT_PROFILE = $(shell if [ -f $(LOCAL_STATE_FILE) ]; then cat $(LOCAL_STATE_FILE) | grep "\"profile\":" | awk -F\" '{print $$4}'; fi)
init: session
	$(shell if [ "$(SKIP_BACKEND)" == "false" ] && ([ "$(IS_DEPLOYMENT)" == "true" ] || [ "$(CURRENT_PROFILE)" != "$(AWS_PROFILE)" ] || [ "$(CURRENT_STATE_KEY)" != "$(STATE_KEY)" ]); then echo $(MAKE) force-init; fi)

backend.tf:
	@echo "terraform { \n  backend \"azurerm\" {} \n}" > backend.tf

AZURERM_BACKEND_STATE_ENV_SUFFIX = env:$(ENVIRONMENT)
ifeq ($(ENVIRONMENT),default)
	AZURERM_BACKEND_STATE_ENV_SUFFIX =
endif

backup-state: verify-azure
	@echo "Creating state snapshot"
	@az storage blob snapshot --subscription $(AZURERM_BACKEND_SUBSCRIPTION) --container-name $(STATE_BACKEND_CONTAINER) --account-name $(AZURERM_BACKEND_STORAGE_ACCOUNT_NAME) --account-key $(AZURERM_BACKEND_STORAGE_ACCOUNT_ACCESS_KEY) --name $(STATE_KEY)$(AZURERM_BACKEND_STATE_ENV_SUFFIX) 2> /dev/null
