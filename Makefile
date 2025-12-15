.PHONY: help bootstrap check status clean

ARGOCD_NS ?= argocd
BOOTSTRAP_DIR = bootstrap

help:
	@echo "ArgoCD Manifests - Comandos disponíveis:"
	@echo ""
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  %-15s %s\n", $$1, $$2}'

check:
	@if ! kubectl cluster-info &> /dev/null; then \
		echo "Erro: kubectl não está configurado ou não consegue conectar ao cluster"; \
		exit 1; \
	fi
	@if ! kubectl get namespace $(ARGOCD_NS) &> /dev/null; then \
		echo "Erro: Namespace '$(ARGOCD_NS)' não existe. Instale o ArgoCD primeiro."; \
		exit 1; \
	fi
	@echo "Pré-requisitos OK"

bootstrap: check
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
	@echo "  1. Atualize as URLs dos repositórios nos arquivos YAML"
	@echo "  2. Faça commit e push para o repositório Git"
	@echo "  3. O ArgoCD sincronizará automaticamente"
	@echo ""
	@echo "Verifique o status: make status"

status:
	@echo "AppProjects:"
	@kubectl get appprojects -n $(ARGOCD_NS) || true
	@echo ""
	@echo "Applications:"
	@kubectl get applications -n $(ARGOCD_NS) || true

clean:
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
