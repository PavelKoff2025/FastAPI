.PHONY: help install env dev run check \
        docker-login docker-build docker-push bp docker-up docker-down docker-logs \
        prod-up prod-down watchtower-logs \
        k8s-deploy k8s-delete clean

PYTHON ?= python3
VENV := .venv
BIN := $(VENV)/bin
IMAGE_NAME ?= fastapi-app
TAG ?= latest
REGISTRY ?=
IMAGE_REPO := $(if $(REGISTRY),$(REGISTRY)/$(IMAGE_NAME),$(IMAGE_NAME))
IMAGE := $(IMAGE_REPO):$(TAG)
IMAGE_LATEST := $(IMAGE_REPO):latest
PORT ?= 8000

help: ## Показать справку
	@grep -E '^[a-zA-Z0-9_-]+:.*##' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*## "}; {printf "  \033[36m%-16s\033[0m %s\n", $$1, $$2}'

install: $(VENV)/bin/activate ## Создать venv и установить зависимости

$(VENV)/bin/activate: requirements.txt
	$(PYTHON) -m venv $(VENV)
	$(BIN)/pip install -r requirements.txt

env: ## Скопировать .env.example в .env
	@test -f .env || cp .env.example .env
	@echo ".env готов"

dev: install env ## Запустить dev-сервер с hot reload
	$(BIN)/uvicorn main:app --reload --host 0.0.0.0 --port $(PORT)

run: install env ## Запустить сервер без reload
	$(BIN)/uvicorn main:app --host 0.0.0.0 --port $(PORT)

check: install ## Проверить, что приложение импортируется
	$(BIN)/python -c "from main import app; print('OK:', app.title)"

docker-login: ## Авторизация в Registry (нужен REGISTRY)
	@test -n "$(REGISTRY)" || (echo "Ошибка: укажите REGISTRY, например make docker-login REGISTRY=pavelkoff"; exit 1)
	@if echo "$(REGISTRY)" | grep -q '^ghcr.io'; then \
		if [ -n "$(DOCKER_USER)" ] && [ -n "$(DOCKER_PASSWORD)" ]; then \
			echo "$(DOCKER_PASSWORD)" | docker login ghcr.io -u "$(DOCKER_USER)" --password-stdin; \
		else \
			docker login ghcr.io; \
		fi; \
	else \
		if [ -n "$(DOCKER_USER)" ] && [ -n "$(DOCKER_PASSWORD)" ]; then \
			echo "$(DOCKER_PASSWORD)" | docker login -u "$(DOCKER_USER)" --password-stdin; \
		else \
			docker login; \
		fi; \
	fi

docker-build: ## Собрать Docker-образ (тег TAG и latest)
ifeq ($(TAG),latest)
	docker build -t $(IMAGE) .
else
	docker build -t $(IMAGE) -t $(IMAGE_LATEST) .
endif

docker-push: docker-build docker-login ## Загрузить образ в registry (TAG и latest)
	docker push $(IMAGE)
ifneq ($(TAG),latest)
	docker push $(IMAGE_LATEST)
endif

bp: docker-push ## Собрать, авторизоваться и загрузить (TAG + latest)

docker-up: env ## Запустить через docker compose
	docker compose up --build -d

docker-down: ## Остановить docker compose
	docker compose down

docker-logs: ## Показать логи контейнера
	docker compose logs -f api

prod-up: env ## Запустить prod-стек с Watchtower (образ из Registry)
	docker compose -f docker-compose.prod.yml up -d

prod-down: ## Остановить prod-стек
	docker compose -f docker-compose.prod.yml down

watchtower-logs: ## Логи Watchtower
	docker logs watchtower -f

k8s-deploy: docker-build ## Собрать образ и применить манифесты K8s
	kubectl apply -f deploy/k8s/

k8s-delete: ## Удалить ресурсы из K8s
	kubectl delete -f deploy/k8s/ --ignore-not-found

clean: ## Удалить venv и кэш Python
	rm -rf $(VENV) __pycache__ app/__pycache__ app/routers/__pycache__ .pytest_cache
