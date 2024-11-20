.PHONY: apply destroy

HELM_RELEASES := $(shell terraform state list | grep helm_release)

apply:
	terraform apply -target=kind_cluster.this -auto-approve
	terraform apply -auto-approve

destroy:
	@for release in $(HELM_RELEASES); do \
		terraform destroy -target="$$release" -auto-approve; \
	done
	terraform destroy -target=kind_cluster.this -auto-approve
