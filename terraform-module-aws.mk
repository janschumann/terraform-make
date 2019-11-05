REGION ?= "eu-central-1"

prepare-provider:
	$(shell echo "provider \"aws\" { region = \"$(REGION)\" }" > $(PROVIDER_FILE))
