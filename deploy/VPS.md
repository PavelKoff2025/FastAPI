# Деплой на VPS с приватным Docker Registry

Пошаговая инструкция для выполнения задания: приватный Registry с TLS и аутентификацией, push образа, автодеплой через Watchtower.

## Требования

- VPS с Ubuntu/Debian, Docker и Docker Compose
- Открытые порты: `5000` (Registry), `8000` (API)
- IP-адрес VPS: `<VPS_IP>`

## 1. Подготовка VPS

```bash
git clone https://github.com/PavelKoff2025/FastAPI.git
cd FastAPI

# Сгенерировать TLS-сертификат и htpasswd
make registry-init REGISTRY_IP=<VPS_IP> REGISTRY_USER=admin REGISTRY_PASSWORD=<пароль>

# Доверить сертификат Docker-демону на VPS
make registry-trust REGISTRY_HOST=<VPS_IP>:5000

# Авторизоваться в Registry
make docker-login REGISTRY_HOST=<VPS_IP>:5000 REGISTRY_USER=admin REGISTRY_PASSWORD=<пароль>
```

## 2. Запуск полного стека на VPS

Registry + FastAPI + Watchtower:

```bash
make vps-up REGISTRY_HOST=<VPS_IP>:5000
```

Или по отдельности:

```bash
make registry-up
make prod-up REGISTRY_HOST=<VPS_IP>:5000
```

## 3. Push образа в приватный Registry (с локальной машины)

```bash
# На локальной машине: доверить сертификат Registry
sudo mkdir -p /etc/docker/certs.d/<VPS_IP>:5000
scp user@<VPS_IP>:~/FastAPI/registry/certs/registry.crt /tmp/registry.crt
sudo cp /tmp/registry.crt /etc/docker/certs.d/<VPS_IP>:5000/ca.crt
# macOS: перезапустить Docker Desktop

# Авторизация и push
make docker-login REGISTRY_HOST=<VPS_IP>:5000 REGISTRY_USER=admin REGISTRY_PASSWORD=<пароль>
make bp REGISTRY_HOST=<VPS_IP>:5000 TAG=v1.0.0
```

## 4. Проверка каталога Registry

```bash
make registry-catalog REGISTRY_IP=<VPS_IP> REGISTRY_USER=admin REGISTRY_PASSWORD=<пароль>
```

Ожидаемый ответ:

```json
{
    "repositories": ["fastapi-app"]
}
```

Или напрямую:

```bash
curl -sk -u admin:<пароль> https://<VPS_IP>:5000/v2/_catalog
```

## 5. Проверка автодеплоя Watchtower

```bash
# На VPS: смотреть логи Watchtower
make watchtower-logs

# После push нового образа Watchtower автоматически:
# 1. Обнаружит новый digest в Registry
# 2. Остановит старый контейнер fastapi-app
# 3. Запустит новый с обновлённым образом
```

Проверка обновления:

```bash
# Push новой версии с локальной машины
make bp REGISTRY_HOST=<VPS_IP>:5000 TAG=v1.0.1

# На VPS через ~30 сек (poll interval)
docker logs watchtower --tail 10
curl http://localhost:8000/health
```

## Архитектура

```
[Разработчик]  --make bp-->  [Приватный Registry :5000]  --Watchtower-->  [fastapi-app :8000]
                                    |
                              TLS + htpasswd
```

## Makefile — ключевые команды

| Команда | Описание |
|---------|----------|
| `make registry-init` | TLS-сертификаты + htpasswd |
| `make registry-up` | Запуск Registry |
| `make registry-catalog` | Проверка `https://<ip>:5000/v2/_catalog` |
| `make docker-login` | Авторизация в Registry |
| `make bp` | Сборка + push (TAG + latest) |
| `make vps-up` | Полный стек на VPS |
| `make watchtower-logs` | Логи автодеплоя |

## Структура Registry

```
registry/
  docker-compose.yml   # сервис Registry (TLS + htpasswd)
  certs/               # TLS-сертификаты (генерируются, не в git)
  auth/                # htpasswd (генерируется, не в git)
  scripts/init.sh      # инициализация certs + auth
```
