.PHONY: help bootstrap check status clean refresh

ARGOCD_NS ?= argocd
BOOTSTRAP_DIR = bootstrap

help: ## Mostra comandos disponíveis
	@echo "ArgoCD Manifests - Comandos disponíveis:"
	@echo ""
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  %-25s %s\n", $$1, $$2}'

check: ## Verifica pré-requisitos (kubectl e namespace)
	@if ! kubectl cluster-info &> /dev/null; then \
		echo "Erro: kubectl não está configurado ou não consegue conectar ao cluster"; \
		exit 1; \
	fi
	@if ! kubectl get namespace $(ARGOCD_NS) &> /dev/null; then \
		echo "Erro: Namespace '$(ARGOCD_NS)' não existe. Instale o ArgoCD primeiro."; \
		exit 1; \
	fi
	@echo "Pré-requisitos OK"

bootstrap: check ## Aplica recursos de bootstrap (AppProjects + Application raiz)
	@echo "Aplicando AppProjects..."
	@kubectl apply -n $(ARGOCD_NS) -f $(BOOTSTRAP_DIR)/projects/business.yaml
	@echo "AppProjects criados"
	@echo ""
	@echo "Aplicando Application raiz..."
	@kubectl apply -n $(ARGOCD_NS) -f $(BOOTSTRAP_DIR)/applications/root.yaml
	@echo "Application raiz criada"
	@echo ""
	@echo "Bootstrap concluído"
	@echo ""
	@echo "Próximos passos:"
	@echo "  1. Faça commit e push para o repositório Git"
	@echo "  2. O ArgoCD sincronizará automaticamente"
	@echo ""
	@echo "Verifique o status: make status"

status: ## Mostra status dos AppProjects e Applications
	@echo "AppProjects:"
	@kubectl get appprojects -n $(ARGOCD_NS) || true
	@echo ""
	@echo "Applications:"
	@kubectl get applications -n $(ARGOCD_NS) || true

refresh: check ## Força refresh de uma Application (use: make refresh APP=gitops-test-app)
	@if [ -z "$(APP)" ]; then \
		echo "Erro: APP não fornecido"; \
		echo ""; \
		echo "Uso: make refresh APP=<nome-da-application>"; \
		echo "Exemplo: make refresh APP=gitops-test-app"; \
		exit 1; \
	fi
	@echo "Forçando refresh hard da Application '$(APP)'..."
	@kubectl patch application $(APP) -n $(ARGOCD_NS) \
		--type merge \
		-p '{"metadata":{"annotations":{"argocd.argoproj.io/refresh":"hard"}}}' || \
		(echo "Erro: Application '$(APP)' não encontrada. Verifique com 'make status'"; exit 1)
	@echo "✅ Refresh hard solicitado para '$(APP)'"
	@echo "Aguarde alguns segundos e verifique: make status"

clean: ## Remove recursos de bootstrap
	@echo "ATENÇÃO: Isso vai remover todos os recursos de bootstrap!"
	@read -p "Tem certeza? [y/N] " -n 1 -r; \
	echo; \
	if [[ $$REPLY =~ ^[Yy]$$ ]]; then \
		kubectl delete -n $(ARGOCD_NS) -f $(BOOTSTRAP_DIR)/applications/root.yaml || true; \
		kubectl delete -n $(ARGOCD_NS) -f $(BOOTSTRAP_DIR)/projects/business.yaml || true; \
		echo "Recursos removidos"; \
	else \
		echo "Operação cancelada"; \
	fi
