.PHONY: help bootstrap check status clean setup-github-app

ARGOCD_NS ?= argocd
BOOTSTRAP_DIR = bootstrap
GITHUB_REPO_URL ?= https://github.com/eserafini/gitops-test-app
GITHUB_SECRET_NAME ?= github-gitops-test-app

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
	@echo "  1. Configure autenticação GitHub App:"
	@echo "     make setup-github-app GITHUB_APP_ID=xxx GITHUB_APP_INSTALLATION_ID=xxx GITHUB_APP_PRIVATE_KEY_PATH=/path/to/key.pem"
	@echo "  2. Faça commit e push para o repositório Git"
	@echo "  3. O ArgoCD sincronizará automaticamente"
	@echo ""
	@echo "Ver documentação: docs/GITHUB_APP_SETUP.md"
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

setup-github-app: check ## Configura GitHub App (RECOMENDADO) - use: make setup-github-app GITHUB_APP_ID=xxx GITHUB_APP_INSTALLATION_ID=xxx GITHUB_APP_PRIVATE_KEY_PATH=/path/to/key.pem
	@if [ -z "$(GITHUB_APP_ID)" ] || [ -z "$(GITHUB_APP_INSTALLATION_ID)" ] || [ -z "$(GITHUB_APP_PRIVATE_KEY_PATH)" ]; then \
		echo "Erro: Parâmetros obrigatórios não fornecidos"; \
		echo ""; \
		echo "Uso: make setup-github-app \\"; \
		echo "  GITHUB_APP_ID=<app_id> \\"; \
		echo "  GITHUB_APP_INSTALLATION_ID=<installation_id> \\"; \
		echo "  GITHUB_APP_PRIVATE_KEY_PATH=/path/to/private-key.pem \\"; \
		echo "  GITHUB_REPO_URL=$(GITHUB_REPO_URL)"; \
		echo ""; \
		echo "Para criar um GitHub App:"; \
		echo "  1. Acesse: https://github.com/settings/apps/new"; \
		echo "  2. Configure permissões (Contents: Read-only)"; \
		echo "  3. Instale o App nos repositórios necessários"; \
		echo "  4. Gere uma private key e baixe"; \
		echo "  5. Anote o App ID e Installation ID"; \
		echo ""; \
		echo "Ver documentação completa: docs/GITHUB_APP_SETUP.md"; \
		exit 1; \
	fi
	@if [ ! -f "$(GITHUB_APP_PRIVATE_KEY_PATH)" ]; then \
		echo "Erro: Arquivo de chave privada não encontrado: $(GITHUB_APP_PRIVATE_KEY_PATH)"; \
		exit 1; \
	fi
	@echo "Configurando GitHub App no ArgoCD..."
	@kubectl delete secret $(GITHUB_SECRET_NAME) -n $(ARGOCD_NS) 2>/dev/null || true
	@kubectl create secret generic $(GITHUB_SECRET_NAME) \
		--from-literal=type=git \
		--from-literal=url=$(GITHUB_REPO_URL) \
		--from-literal=githubAppID="$(GITHUB_APP_ID)" \
		--from-literal=githubAppInstallationID="$(GITHUB_APP_INSTALLATION_ID)" \
		--from-file=githubAppPrivateKey="$(GITHUB_APP_PRIVATE_KEY_PATH)" \
		-n $(ARGOCD_NS)
	@kubectl label secret $(GITHUB_SECRET_NAME) argocd.argoproj.io/secret-type=repository -n $(ARGOCD_NS) --overwrite
	@echo "✅ GitHub App configurado!"
	@echo "   App ID: $(GITHUB_APP_ID)"
	@echo "   Installation ID: $(GITHUB_APP_INSTALLATION_ID)"
	@echo "   Repositório: $(GITHUB_REPO_URL)"
	@echo ""
	@echo "Reiniciando pods do ArgoCD..."
	@kubectl delete pod -n $(ARGOCD_NS) -l app.kubernetes.io/name=argocd-repo-server 2>/dev/null || true
	@kubectl delete pod -n $(ARGOCD_NS) -l app.kubernetes.io/name=argocd-application-controller 2>/dev/null || true
	@echo ""
	@echo "Aguarde alguns segundos e verifique: make status"
