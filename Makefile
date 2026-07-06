.PHONY: help install env dev run check \
        registry-init registry-up registry-down registry-catalog registry-trust \
        docker-login docker-build docker-push bp \
        docker-up docker-down docker-logs \
        vps-up vps-down prod-up prod-down watchtower-logs \
        k8s-deploy k8s-delete clean

PYTHON ?= python3
VENV := .venv
BIN := $(VENV)/bin

# Private Registry (задание: push/pull через свой Registry на VPS)
REGISTRY_HOST ?= localhost:5000
REGISTRY_IP ?= localhost
REGISTRY_PORT ?= 5000
REGISTRY_USER ?= admin
REGISTRY_PASSWORD ?= changeme

IMAGE_NAME ?= fastapi-app
TAG ?= latest
IMAGE_REPO := $(REGISTRY_HOST)/$(IMAGE_NAME)
IMAGE := $(IMAGE_REPO):$(TAG)
IMAGE_LATEST := $(IMAGE_REPO):latest
PORT ?= 8000

help: ## Показать справку
	@grep -E '^[a-zA-Z0-9_-]+:.*##' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*## "}; {printf "  \033[36m%-18s\033[0m %s\n", $$1, $$2}'

install: $(VENV)/bin/activate ## Создать venv и установить зависимости

$(VENV)/bin/activate: requirements.txt
	$(PYTHON) -m venv $(VENV)
	$(BIN)/pip install -r requirements.txt

env: ## Создать .env с настройками по умолчанию
	@test -f .env || (printf '%s\n' \
		'APP_NAME=FastAPI App' \
		'APP_VERSION=0.1.0' \
		'DEBUG=false' \
		'HOST=0.0.0.0' \
		'PORT=8000' \
		'WORKERS=1' \
		'LOG_LEVEL=info' \
		'REGISTRY_HOST=localhost:5000' \
		'REGISTRY_IP=localhost' \
		'REGISTRY_PORT=5000' \
		'REGISTRY_USER=admin' \
		'REGISTRY_PASSWORD=changeme' > .env)
	@echo ".env готов"

dev: install env ## Запустить dev-сервер с hot reload
	$(BIN)/uvicorn main:app --reload --host 0.0.0.0 --port $(PORT)

run: install env ## Запустить сервер без reload
	$(BIN)/uvicorn main:app --host 0.0.0.0 --port $(PORT)

check: install ## Проверить, что приложение импортируется
	$(BIN)/python -c "from main import app; print('OK:', app.title)"

registry-init: ## Инициализировать TLS-сертификаты и htpasswd для Registry
	chmod +x registry/scripts/init.sh
	REGISTRY_IP=$(REGISTRY_IP) REGISTRY_USER=$(REGISTRY_USER) REGISTRY_PASSWORD=$(REGISTRY_PASSWORD) \
		registry/scripts/init.sh

registry-up: ## Запустить приватный Docker Registry (TLS + auth)
	docker compose -f registry/docker-compose.yml up -d

registry-down: ## Остановить приватный Registry
	docker compose -f registry/docker-compose.yml down

registry-catalog: ## Проверить каталог Registry: https://<ip>:5000/v2/_catalog
	@echo "GET https://$(REGISTRY_IP):$(REGISTRY_PORT)/v2/_catalog"
	@curl -sk -u "$(REGISTRY_USER):$(REGISTRY_PASSWORD)" \
		"https://$(REGISTRY_IP):$(REGISTRY_PORT)/v2/_catalog" | python3 -m json.tool

registry-trust: ## Установить CA-сертификат Registry в Docker (Linux/VPS)
	@test -f registry/certs/registry.crt || (echo "Сначала: make registry-init"; exit 1)
	sudo mkdir -p /etc/docker/certs.d/$(REGISTRY_HOST)
	sudo cp registry/certs/registry.crt /etc/docker/certs.d/$(REGISTRY_HOST)/ca.crt
	@echo "Перезапустите Docker: sudo systemctl restart docker"

docker-login: ## Авторизация в приватном Registry
	@echo "$(REGISTRY_PASSWORD)" | docker login "$(REGISTRY_HOST)" \
		-u "$(REGISTRY_USER)" --password-stdin

docker-build: ## Собрать Docker-образ (тег TAG и latest)
ifeq ($(TAG),latest)
	docker build -t $(IMAGE) .
else
	docker build -t $(IMAGE) -t $(IMAGE_LATEST) .
endif

docker-push: docker-build docker-login ## Push образа в приватный Registry (TAG + latest)
	docker push $(IMAGE)
ifneq ($(TAG),latest)
	docker push $(IMAGE_LATEST)
endif

bp: docker-push ## Сборка + push в приватный Registry (TAG + latest)

docker-up: env ## Локальный запуск (сборка из Dockerfile)
	docker compose up --build -d

docker-down: ## Остановить docker compose
	docker compose down

docker-logs: ## Показать логи API-контейнера
	docker compose logs -f api

vps-up: env ## VPS: Registry + API + Watchtower (полный стек)
	docker compose -f docker-compose.vps.yml up -d

vps-down: ## Остановить VPS-стек
	docker compose -f docker-compose.vps.yml down

prod-up: env ## Запустить API + Watchtower (Registry уже запущен)
	docker compose -f docker-compose.prod.yml up -d

prod-down: ## Остановить prod-стек
	docker compose -f docker-compose.prod.yml down

watchtower-logs: ## Логи Watchtower
	docker logs watchtower -f

k8s-deploy: docker-build ## Применить манифесты Kubernetes
	kubectl apply -f deploy/k8s/

k8s-delete: ## Удалить ресурсы из K8s
	kubectl delete -f deploy/k8s/ --ignore-not-found

clean: ## Удалить venv и кэш Python
	rm -rf $(VENV) __pycache__ app/__pycache__ app/routers/__pycache__ .pytest_cache
