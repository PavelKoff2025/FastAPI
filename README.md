# FastAPI App

Шаблонное FastAPI-приложение с Docker и настройками для деплоя.

## Структура

```
app/
  config.py        # настройки через переменные окружения
  routers/         # маршруты API
main.py            # точка входа
deploy/k8s/        # манифесты Kubernetes
docker-compose.yml # локальный запуск
Dockerfile         # production-образ
```

## Локальная разработка

```bash
python -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
cp .env.example .env
uvicorn main:app --reload --host 0.0.0.0 --port 8000
```

Документация API: http://localhost:8000/docs

## Docker

```bash
cp .env.example .env
docker compose up --build
```

## Kubernetes

```bash
docker build -t fastapi-app:latest .
kubectl apply -f deploy/k8s/
```

Перед деплоем обновите `host` в `deploy/k8s/ingress.yaml`.

## Эндпоинты

| Метод | Путь     | Описание              |
|-------|----------|-----------------------|
| GET   | `/`      | Приветствие           |
| GET   | `/health`| Liveness probe        |
| GET   | `/ready` | Readiness probe       |

## Переменные окружения

См. `.env.example`.
