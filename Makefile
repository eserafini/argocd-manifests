.PHONY: help bootstrap check status clean refresh

ARGOCD_NS ?= argocd
BOOTSTRAP_DIR = bootstrap

help:
	@echo "ArgoCD Manifests - Available commands:"
	@echo ""
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  %-25s %s\n", $$1, $$2}'

check:
	@if ! kubectl cluster-info &> /dev/null; then \
		echo "Error: kubectl is not configured or cannot connect to the cluster"; \
		exit 1; \
	fi
	@if ! kubectl get namespace $(ARGOCD_NS) &> /dev/null; then \
		echo "Error: Namespace '$(ARGOCD_NS)' does not exist. Install ArgoCD first."; \
		exit 1; \
	fi
	@echo "Prerequisites OK"

bootstrap: check
	@echo "Applying AppProjects..."
	@kubectl apply -n $(ARGOCD_NS) -f $(BOOTSTRAP_DIR)/projects/business.yaml
	@echo "AppProjects created"
	@echo ""
	@echo "Applying Root Application..."
	@kubectl apply -n $(ARGOCD_NS) -f $(BOOTSTRAP_DIR)/applications/root.yaml
	@echo "Root Application created"
	@echo ""
	@echo "Bootstrap completed"
	@echo ""
	@echo "Next steps:"
	@echo "  1. Commit and push to Git repository"
	@echo "  2. ArgoCD will synchronize automatically"
	@echo ""
	@echo "Check status: make status"

status:
	@echo "AppProjects:"
	@kubectl get appprojects -n $(ARGOCD_NS) || true
	@echo ""
	@echo "Applications:"
	@kubectl get applications -n $(ARGOCD_NS) || true

refresh: check
	@if [ -z "$(APP)" ]; then \
		echo "Error: APP not provided"; \
		echo ""; \
		echo "Usage: make refresh APP=<application-name>"; \
		echo "Example: make refresh APP=gitops-test-app"; \
		exit 1; \
	fi
	@echo "Forcing hard refresh of Application '$(APP)'..."
	@kubectl patch application $(APP) -n $(ARGOCD_NS) \
		--type merge \
		-p '{"metadata":{"annotations":{"argocd.argoproj.io/refresh":"hard"}}}' || \
		(echo "Error: Application '$(APP)' not found. Check with 'make status'"; exit 1)
	@echo "Refresh hard requested for '$(APP)'"
	@echo "Waiting for a few seconds and check: make status"

clean:
	@echo "WARNING: This will remove all bootstrap resources!"
	@read -p "Are you sure? [y/N] " -n 1 -r; \
	echo; \
	if [[ $$REPLY =~ ^[Yy]$$ ]]; then \
		kubectl delete -n $(ARGOCD_NS) -f $(BOOTSTRAP_DIR)/applications/root.yaml || true; \
		kubectl delete -n $(ARGOCD_NS) -f $(BOOTSTRAP_DIR)/projects/business.yaml || true; \
		echo "Resources removed"; \
	else \
		echo "Operation cancelled"; \
	fi
