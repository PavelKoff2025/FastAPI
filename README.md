# FastAPI App

Production-ready шаблон FastAPI с приватным Docker Registry, автодеплоем через Watchtower и Makefile.

## Структура

```
main.py                  # точка входа
app/                     # конфигурация и роутеры
registry/                # приватный Docker Registry (TLS + htpasswd)
docker-compose.vps.yml   # полный стек: Registry + API + Watchtower
docker-compose.prod.yml  # API + Watchtower
Makefile                 # сборка, push в Registry, проверка каталога
deploy/VPS.md            # инструкция деплоя на VPS
```

## Быстрый старт (локально)

```bash
make dev                 # разработка
make registry-init       # TLS + auth для Registry
make registry-up         # запуск Registry
make bp                  # сборка + push в localhost:5000
make registry-catalog    # проверка https://localhost:5000/v2/_catalog
```

## Деплой на VPS

Полная инструкция: [deploy/VPS.md](deploy/VPS.md)

```bash
# На VPS
make registry-init REGISTRY_IP=<VPS_IP>
make registry-trust REGISTRY_HOST=<VPS_IP>:5000
make vps-up REGISTRY_HOST=<VPS_IP>:5000

# С локальной машины
make bp REGISTRY_HOST=<VPS_IP>:5000 TAG=v1.0.0
make registry-catalog REGISTRY_IP=<VPS_IP>
```

## Makefile

```bash
make help                # все команды
```

| Команда | Описание |
|---------|----------|
| `make bp` | Сборка + push в приватный Registry (TAG + latest) |
| `make registry-init` | Сертификаты TLS + htpasswd |
| `make registry-catalog` | Проверка `https://<ip>:5000/v2/_catalog` |
| `make vps-up` | Registry + API + Watchtower |
| `make docker-login` | Авторизация в Registry |

## Эндпоинты

| Метод | Путь | Описание |
|-------|------|----------|
| GET | `/` | Приветствие |
| GET | `/health` | Liveness probe |
| GET | `/ready` | Readiness probe |

## Лицензия

MIT
