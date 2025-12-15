.PHONY: help bootstrap check status clean setup-github-secret update-github-token

ARGOCD_NS ?= argocd
BOOTSTRAP_DIR = bootstrap
GITHUB_USERNAME ?= eserafini
GITHUB_REPO_URL ?= https://github.com/eserafini/beconfident-api
GITHUB_SECRET_NAME ?= github-eserafini-repo

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
	@echo "  1. Configure a autenticação do GitHub: make setup-github-secret GITHUB_TOKEN=seu_token"
	@echo "  2. Faça commit e push para o repositório Git"
	@echo "  3. O ArgoCD sincronizará automaticamente"
	@echo ""
	@echo "Verifique o status: make status"

status: ## Mostra status dos AppProjects e Applications
	@echo "AppProjects:"
	@kubectl get appprojects -n $(ARGOCD_NS) || true
	@echo ""
	@echo "Applications:"
	@kubectl get applications -n $(ARGOCD_NS) || true
	@echo ""
	@echo "Secrets de repositório:"
	@kubectl get secrets -n $(ARGOCD_NS) -l argocd.argoproj.io/secret-type=repository || true

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

setup-github-secret: check ## Cria Secret do GitHub (use: make setup-github-secret GITHUB_TOKEN=seu_token)
	@if [ -z "$(GITHUB_TOKEN)" ]; then \
		echo "Erro: GITHUB_TOKEN não fornecido"; \
		echo "Uso: make setup-github-secret GITHUB_TOKEN=seu_token_do_github"; \
		echo ""; \
		echo "Para criar um token:"; \
		echo "  1. Acesse: https://github.com/settings/tokens"; \
		echo "  2. Generate new token (classic)"; \
		echo "  3. Selecione o escopo 'repo'"; \
		echo "  4. Copie o token e use no comando acima"; \
		exit 1; \
	fi
	@echo "Criando Secret do GitHub no ArgoCD..."
	@kubectl delete secret $(GITHUB_SECRET_NAME) -n $(ARGOCD_NS) 2>/dev/null || true
	@kubectl create secret generic $(GITHUB_SECRET_NAME) \
		--from-literal=type=git \
		--from-literal=url=$(GITHUB_REPO_URL) \
		--from-literal=username=$(GITHUB_USERNAME) \
		--from-literal=password="$(GITHUB_TOKEN)" \
		-n $(ARGOCD_NS)
	@kubectl label secret $(GITHUB_SECRET_NAME) argocd.argoproj.io/secret-type=repository -n $(ARGOCD_NS) --overwrite
	@echo "Secret criado com sucesso!"
	@echo "Reiniciando pods do ArgoCD para aplicar mudanças..."
	@kubectl delete pod -n $(ARGOCD_NS) -l app.kubernetes.io/name=argocd-repo-server 2>/dev/null || true
	@kubectl delete pod -n $(ARGOCD_NS) -l app.kubernetes.io/name=argocd-application-controller 2>/dev/null || true
	@echo ""
	@echo "Aguarde alguns segundos e verifique: make status"

update-github-token: setup-github-secret ## Alias para setup-github-secret (atualiza token existente)
