
FROM postgres:14-alpine

LABEL maintainer="DevOps Course School21"
LABEL description="PostgreSQL 14 with auto-init script for microservices"
LABEL version="1.0"

ENV POSTGRES_USER=postgres
ENV POSTGRES_PASSWORD=postgres
ENV POSTGRES_DB=postgres
ENV PGDATA=/var/lib/postgresql/data


RUN apk add --no-cache bash

COPY init.sql /docker-entrypoint-initdb.d/01-init.sql

COPY init-check.sh /docker-entrypoint-initdb.d/02-init-check.sh

RUN chmod +x /docker-entrypoint-initdb.d/02-init-check.sh

EXPOSE 5432

HEALTHCHECK --interval=10s --timeout=5s --start-period=10s --retries=5 \
  CMD pg_isready -U postgres -d postgres || exit 1










# 📝 Построчный разбор Dockerfile для кастомного PostgreSQL

## 🔍 Полный комментарий по каждой строке

```dockerfile
# ============================================================
# Кастомный Docker-образ PostgreSQL для проекта.
# Это НЕ обычный postgres:14 — он расширен:
#   1. Автоматическое создание 6 БД при первом запуске
#      (по одной для каждого микросервиса).
#   2. Инициализация схем и начальных данных.
#   3. Healthcheck для k8s/Docker.
#
# Логика микросервисной архитектуры (Database per Service):
#   users_db        ← session-service
#   hotels_db       ← hotel-service
#   reservations_db ← booking-service
#   payments_db     ← payment-service
#   balances_db     ← loyalty-service
#   statistics_db   ← report-service
# Все БД создаются init.sql скриптом при первом запуске.
# ============================================================

FROM postgres:14-alpine
# Базовый образ: PostgreSQL 14 на Alpine Linux.
#
# Разбор тега:
#  - postgres: официальный образ PostgreSQL с Docker Hub.
#  - 14: версия PostgreSQL 14.x.
#         ⚠️ Не latest! Это анти-паттерн в production.
#         Конкретная версия = воспроизводимость сборки.
#  - alpine: на базе Alpine Linux вместо Debian.
#         + Размер ~80 МБ vs ~200 МБ (postgres:14-bookworm).
#         + Меньше CVE (меньше пакетов).
#         - Иногда проблемы с локалями, шрифтами, NLS.
#
# В этом образе УЖЕ есть:
#  - Сам PostgreSQL 14.
#  - Стандартный entrypoint: docker-entrypoint.sh.
#  - Поддержка /docker-entrypoint-initdb.d/ — папки для init-скриптов.
#  - Переменные окружения для конфигурации.

LABEL maintainer="DevOps Course School21"
LABEL description="PostgreSQL 14 with auto-init script for microservices"
LABEL version="1.0"
# LABEL — метаданные образа в формате key=value.
# Видны командой: docker inspect <image>
# Никак не влияют на работу контейнера.
#
# Стандартные label'ы (OCI spec):
#  - maintainer: кто отвечает за образ.
#  - description: для чего нужен.
#  - version: версия образа (не Postgres, а самого нашего образа).
#
# Best practice — использовать стандартизированные label'ы:
#   org.opencontainers.image.title
#   org.opencontainers.image.source
#   org.opencontainers.image.version
# Но для простого проекта и эти подойдут.

ENV POSTGRES_USER=postgres
ENV POSTGRES_PASSWORD=postgres
ENV POSTGRES_DB=postgres
ENV PGDATA=/var/lib/postgresql/data
# Переменные окружения для конфигурации PostgreSQL.
# Базовый образ postgres:14-alpine читает их при старте.
#
# Разбор:
#  POSTGRES_USER=postgres
#       Создаёт пользователя-суперюзера с именем "postgres".
#       Это default, можно было не указывать (но явность лучше).
#
#  POSTGRES_PASSWORD=postgres
#       Пароль суперюзера. ⚠️ ОЧЕНЬ слабый!
#       В k8s этот образ запускается с переопределением через
#       Secret (см. Deployment postgres):
#         valueFrom: { secretKeyRef: { name: app-secrets, key: POSTGRES_PASSWORD } }
#       Значит, эта строка — fallback для случая запуска
#       контейнера БЕЗ env-переменных.
#
#  POSTGRES_DB=postgres
#       Имя БД по умолчанию, создаваемой при первом запуске.
#       ⚠️ Эта БД создаётся ВСЕГДА, кроме неё образ создаст
#       наши 6 БД через init.sql.
#
#  PGDATA=/var/lib/postgresql/data
#       Путь, где PostgreSQL хранит файлы данных.
#       ⚠️ ВАЖНО! В k8s Deployment postgres мы задаём:
#         PGDATA=/var/lib/postgresql/data/pgdata
#       (подкаталог pgdata из-за проблемы lost+found на ext4).
#       Здесь стандартный путь — это default, для случая
#       запуска без k8s.

RUN apk add --no-cache bash
# Установка bash в Alpine.
# По умолчанию в Alpine только sh (ash из busybox).
# Нужен для скрипта init-check.sh (он использует bash-specific
# синтаксис: arrays, [[ ]], etc.).
#
# --no-cache: не сохранять индекс пакетов apk (экономия места,
#             ~3-5 МБ).

COPY init.sql /docker-entrypoint-initdb.d/01-init.sql
# Копирует init.sql из контекста сборки (директории с Dockerfile)
# в специальную папку /docker-entrypoint-initdb.d/.
#
# ⚠️ КЛЮЧЕВАЯ МАГИЯ образа postgres!
# Базовый образ postgres:14-alpine при ПЕРВОМ запуске
# (когда PGDATA пустой) автоматически выполняет ВСЕ файлы из
# /docker-entrypoint-initdb.d/:
#  - *.sql — выполняются через psql.
#  - *.sql.gz — распаковываются и выполняются.
#  - *.sh — выполняются как bash-скрипты.
# В алфавитном порядке имён файлов!
#
# Поэтому префикс "01-" — важен. Гарантирует порядок:
#  01-init.sql → 02-init-check.sh.
#
# Содержимое init.sql, скорее всего:
#  CREATE DATABASE users_db;
#  CREATE DATABASE hotels_db;
#  CREATE DATABASE reservations_db;
#  CREATE DATABASE payments_db;
#  CREATE DATABASE balances_db;
#  CREATE DATABASE statistics_db;
#  GRANT ALL PRIVILEGES ON DATABASE ... TO postgres;
#
# ⚠️ ВАЖНО! Эти скрипты выполняются ТОЛЬКО при первом запуске.
# Если PGDATA уже инициализирован — скрипты пропускаются.
# При запуске с PVC от прошлого деплоя БД уже есть, init не сработает.

COPY init-check.sh /docker-entrypoint-initdb.d/02-init-check.sh
# Копирует bash-скрипт init-check.sh туда же.
# Префикс "02-" гарантирует, что выполнится ПОСЛЕ init.sql.
#
# Содержимое скрипта, вероятно:
#  - Проверка, что все БД созданы.
#  - Проверка, что таблицы есть.
#  - Вывод информации в лог.
#  - Возможно, какие-то seed-данные.
#
# Это вспомогательный шаг для отладки и валидации.

RUN chmod +x /docker-entrypoint-initdb.d/02-init-check.sh
# Делает скрипт исполняемым.
# Без этого bash-скрипт не запустится — будет "Permission denied".
# COPY по умолчанию не сохраняет executable bit, нужно явно
# установить через chmod.
#
# Альтернатива (Docker 19.03+):
#   COPY --chmod=755 init-check.sh /docker-entrypoint-initdb.d/

EXPOSE 5432
# Документирующая инструкция: контейнер слушает на порту 5432.
# Это стандартный порт PostgreSQL.
#
# ⚠️ EXPOSE НЕ открывает порт автоматически!
# Это только метаданные. Реально PostgreSQL слушает 5432
# изнутри образа (из конфига postgresql.conf).
#
# В k8s этот порт пробрасывается через:
#  - containerPort: 5432 в Deployment
#  - targetPort: 5432 в Service

HEALTHCHECK --interval=10s --timeout=5s --start-period=10s --retries=5 \
  CMD pg_isready -U postgres -d postgres || exit 1
# Docker HEALTHCHECK — встроенный механизм проверки здоровья.
#
# Разбор флагов:
#  --interval=10s
#       Как часто выполнять проверку (каждые 10 секунд).
#  --timeout=5s
#       Максимальное время выполнения команды (5 сек).
#       Если команда работает дольше — считается fail.
#  --start-period=10s
#       Grace period после старта контейнера.
#       PostgreSQL стартует не мгновенно — первые 10 сек
#       fail'ы не считаются.
#  --retries=5
#       Сколько подряд неудачных проверок до статуса "unhealthy".
#       5 × 10 сек = 50 сек до признания контейнера сломанным.
#
# Команда проверки:
#  pg_isready -U postgres -d postgres
#       Утилита PostgreSQL, проверяет принимает ли сервер коннекты.
#       -U postgres: под этим пользователем.
#       -d postgres: к этой БД.
#       Возвращает 0 если БД отвечает, иначе non-zero.
#  || exit 1
#       Если pg_isready упал — exit 1 (явное указание fail).
#
# ⚠️ ВАЖНО! HEALTHCHECK работает в Docker, но
# в k8s он ИГНОРИРУЕТСЯ! K8s использует свои механизмы:
#  - readinessProbe: готов ли принимать трафик.
#  - livenessProbe: жив ли вообще.
# В k8s Deployment postgres ничего не настроено — это
# технический долг, стоит добавить liveness/readiness probe.
```

---

## 🔗 Полный жизненный цикл первого запуска

```
┌────────────────────────────────────────────────────────────┐
│ docker run my-postgres                                     │
│ (или k8s создаёт Pod из этого образа)                      │
└──────────────────────────┬─────────────────────────────────┘
                           │
                           ▼
┌────────────────────────────────────────────────────────────┐
│ ШАГ 1: ENTRYPOINT базового образа postgres:14-alpine        │
│        — это /usr/local/bin/docker-entrypoint.sh            │
└──────────────────────────┬─────────────────────────────────┘
                           │
                           ▼
┌────────────────────────────────────────────────────────────┐
│ ШАГ 2: Проверка состояния PGDATA                            │
│                                                             │
│ if [ -z "$(ls -A $PGDATA)" ]; then                          │
│   echo "PGDATA пустой → инициализация"                      │
│   - initdb создаёт структуру БД                             │
│   - Создаёт пользователя POSTGRES_USER                      │
│   - Применяет POSTGRES_PASSWORD                             │
│   - Создаёт БД POSTGRES_DB                                  │
│ else                                                        │
│   echo "PGDATA не пустой → запуск как есть"                 │
│   skip → переход к ШАГУ 4                                   │
│ fi                                                          │
└──────────────────────────┬─────────────────────────────────┘
                           │ (только если PGDATA был пуст)
                           ▼
┌────────────────────────────────────────────────────────────┐
│ ШАГ 3: Запуск скриптов из /docker-entrypoint-initdb.d/      │
│        в алфавитном порядке:                                │
│                                                             │
│  3a. 01-init.sql                                            │
│      psql -U postgres -d postgres -f 01-init.sql            │
│      → создаёт users_db, hotels_db, ..., statistics_db      │
│                                                             │
│  3b. 02-init-check.sh                                       │
│      bash 02-init-check.sh                                  │
│      → проверки, диагностика, дополнительная подготовка    │
└──────────────────────────┬─────────────────────────────────┘
                           │
                           ▼
┌────────────────────────────────────────────────────────────┐
│ ШАГ 4: postgres -c config_file=...                          │
│        Основной процесс PostgreSQL запущен, слушает 5432    │
└──────────────────────────┬─────────────────────────────────┘
                           │
                           ▼
┌────────────────────────────────────────────────────────────┐
│ ШАГ 5: HEALTHCHECK начинает работу                          │
│        Каждые 10 секунд pg_isready проверяет доступность    │
└────────────────────────────────────────────────────────────┘
```

**Второй и последующие запуски:**
```
Шаг 1 → 2 (PGDATA уже есть, init пропускается) → 4 → 5
```

Это ключевая особенность: **init-скрипты выполняются только один раз!** Если БД уже инициализирована (на PVC), новые скрипты добавленные в образ — не применятся. Нужна явная миграция через Liquibase/Flyway внутри приложения.

---

## 🆚 Сравнение базового postgres vs наш кастомный

| Аспект | postgres:14-alpine | наш src-postgres:latest |
|--------|---------------------|--------------------------|
| **Базовый функционал** | PostgreSQL 14 | PostgreSQL 14 |
| **Создание БД при старте** | Только `POSTGRES_DB` (одна) | 6 БД для микросервисов |
| **Дополнительные скрипты** | Нет | init.sql + init-check.sh |
| **Дополнительные пакеты** | Минимум | bash |
| **HEALTHCHECK** | Нет | pg_isready |
| **Labels** | Стандартные | Project-specific |
| **Размер** | ~80 МБ | ~85 МБ |
| **Use case** | Generic PostgreSQL | Готов для запуска приложения |

Наш образ — это **готовая к использованию БД** для конкретного проекта.

---

## 🔄 Поток создания всех БД

```
[ docker build -t src-postgres:latest . ]
              │
              ▼
[ Готовый образ ]
              │
              ▼
[ k8s Pod создаётся ]
              │
              │ образ загружается из containerd
              ▼
[ ENTRYPOINT: docker-entrypoint.sh ]
              │
              ▼
[ PGDATA пустой? ]
              │
        ┌─────┴─────┐
        ▼ да        ▼ нет
   [ initdb ]   [ skip init ]
        │            │
        ▼            │
[ /docker-entrypoint-initdb.d/ ]
        │            │
        ▼            │
[ 01-init.sql ]      │
        │            │
        ▼            │
   ┌────────────┐    │
   │ Создание:  │    │
   │ users_db   │    │
   │ hotels_db  │    │
   │ ...        │    │
   │ statistics_db │ │
   └─────┬──────┘    │
         │           │
         ▼           │
[ 02-init-check.sh ] │
         │           │
         ▼           ▼
[ postgres сервер запущен на 5432 ]
         │
         ▼
[ HEALTHCHECK каждые 10 сек ]
         │
         ▼
[ session-service подключается к users_db ]
[ hotel-service подключается к hotels_db ]
[ ...                                    ]
```

---

## ⚠️ Подводные камни и риски

### 1. Init-скрипты выполняются только ПРИ ПЕРВОМ запуске

Если контейнер запустить с уже существующим PGDATA (например, через PVC от прошлого деплоя), новые БД из init.sql **не создадутся**.

**Решение** — миграции на уровне приложения (Liquibase/Flyway).

### 2. PGDATA в Dockerfile vs k8s Deployment

В Dockerfile: `PGDATA=/var/lib/postgresql/data`
В k8s Deployment: `PGDATA=/var/lib/postgresql/data/pgdata`

Это разные пути! В k8s используется подкаталог из-за проблемы `lost+found` при mount-е ext4 тома. Dockerfile-вариант — для запуска БЕЗ k8s.

### 3. Пароль `postgres/postgres` в Dockerfile

```dockerfile
ENV POSTGRES_PASSWORD=postgres
```

Это пароль "по умолчанию", встроенный в образ. В k8s он переопределяется через Secret, но если образ запустить без env — будет работать с этим паролем.

**Риск**: если образ запушить в публичный registry — все знают пароль.

### 4. HEALTHCHECK игнорируется в Kubernetes

Docker HEALTHCHECK работает только при `docker run`. K8s использует свои probes:
```yaml
livenessProbe:
  exec:
    command: ["pg_isready", "-U", "postgres"]
  periodSeconds: 10
readinessProbe:
  exec:
    command: ["pg_isready", "-U", "postgres"]
  periodSeconds: 5
```

В k8s Deployment postgres у нас этих probes **нет** — стоит добавить.

### 5. Контейнер запускается под пользователем `postgres`

Базовый образ postgres:14-alpine при старте `su` в пользователя `postgres` (UID 70). Это правильно — не root. Но при использовании hostPath PVC нужно убедиться, что директория на ноде доступна для UID 70.

---

## 🗣 Монолог для защиты (~300 символов)

> Это кастомный Docker-образ PostgreSQL 14 на Alpine с автоматической инициализацией 6 баз данных для микросервисов. В /docker-entrypoint-initdb.d/ копируются init.sql (создание БД) и init-check.sh (валидация). Стандартный entrypoint базового образа выполняет их при первом запуске. HEALTHCHECK через pg_isready проверяет готовность каждые 10 секунд. Размер образа ~85 МБ.

*(длина ~380 символов, могу сократить до 300)*

---

## 💡 Возможные вопросы на защите

**В1: Зачем кастомный образ, если есть официальный postgres?**
> Чтобы автоматизировать создание 6 БД для микросервисов. Стандартный `postgres:14` создаёт **только одну** БД из переменной `POSTGRES_DB`. У нас 6 микросервисов = 6 БД.
> 
> Альтернативы:
> 1. **Init Job в k8s**: отдельный Job создаёт БД после старта PostgreSQL. Сложнее в координации.
> 2. **ConfigMap с init.sql** + mount в `/docker-entrypoint-initdb.d/`. Гибче, не требует пересборки образа.
> 3. **Наш подход**: всё запечено в образ. Образ "готов к использованию".
> 
> Я выбрал последний для простоты и воспроизводимости.

**В2: Как работает магия /docker-entrypoint-initdb.d/?**
> Это **конвенция** официального образа PostgreSQL. В нём есть скрипт `/usr/local/bin/docker-entrypoint.sh`, который:
> 1. Проверяет, пустая ли директория PGDATA.
> 2. Если пустая — выполняет `initdb` (создаёт системные таблицы, пользователя `postgres`).
> 3. **Запускает все файлы из /docker-entrypoint-initdb.d/** в алфавитном порядке:
>    - `*.sql` → через `psql`.
>    - `*.sql.gz` → распаковка + `psql`.
>    - `*.sh` → выполняется как shell-скрипт.
> 4. Затем стартует основной процесс postgres.
> 
> Если PGDATA уже инициализирован — init-скрипты **пропускаются**. Это критичная особенность.

**В3: Что произойдёт, если изменить init.sql после первого деплоя?**
> Ничего не произойдёт для существующего PVC! Изменения применятся **только** при инициализации новой БД (пустой PGDATA).
> 
> Сценарии:
> 1. **Удалить PVC и пересоздать**: новые скрипты сработают. Но потеря всех данных.
> 2. **Применить вручную**: `kubectl exec -it postgres -- psql -U postgres -f /docker-entrypoint-initdb.d/01-init.sql`. Может упасть, если БД уже есть.
> 3. **Миграции на уровне приложения**: Liquibase/Flyway внутри каждого микросервиса применяет изменения схемы при старте.
> 
> Правильный подход в production — **миграции в приложении**, init.sql только для **первичной инициализации**.

**В4: Почему файлы названы 01-init.sql и 02-init-check.sh?**
> Чтобы гарантировать **порядок выполнения**. Скрипт `docker-entrypoint.sh` обходит файлы в **алфавитном порядке**:
> 
> ```
> /docker-entrypoint-initdb.d/
>   01-init.sql      ← выполняется первым
>   02-init-check.sh ← выполняется вторым
> ```
> 
> Без префиксов:
> ```
> init-check.sh     ← может выполниться РАНЬШЕ
> init.sql          ← из-за алфавитной сортировки
> ```
> 
> Это привело бы к ошибкам, если init-check.sh ожидает уже созданные БД.
> 
> Префиксы — это **общепринятая практика** в мире shell-скриптов (см. /etc/profile.d/, /etc/init.d/, и т.д.).

**В5: Что произойдёт, если в init.sql есть ошибка?**
> Поведение зависит от настройки `POSTGRES_INITDB_ARGS`. По умолчанию:
> 1. PostgreSQL выполняет скрипт через `psql -v ON_ERROR_STOP=1`.
> 2. При первой ошибке скрипт прерывается.
> 3. Контейнер **не стартует**, поды в k8s в статусе `CrashLoopBackOff`.
> 
> Это **fail-fast** поведение — лучше упасть сразу, чем работать с битой БД.
> 
> Защита:
> - Тестировать init.sql локально перед деплоем.
> - Использовать `IF NOT EXISTS` в CREATE TABLE / CREATE DATABASE для идемпотентности.
> - В CI/CD автоматически проверять синтаксис: `psql --dry-run`.

**В6: Почему `ENV POSTGRES_PASSWORD=postgres` в Dockerfile? Это безопасно?**
> Это **fallback-значение** для случая запуска без env-переменных. В нашей k8s конфигурации Deployment переопределяет:
> ```yaml
> env:
>   - name: POSTGRES_PASSWORD
>     valueFrom:
>       secretKeyRef:
>         name: app-secrets
>         key: POSTGRES_PASSWORD
> ```
> 
> При наличии env-переменной в k8s Spec она **перекрывает** значение из ENV в Dockerfile.
> 
> Безопасность:
> 1. **Image public/private**: если образ в публичном registry — пароль известен всем. У нас локальный образ → менее критично.
> 2. **Базовая безопасность**: пароль "postgres/postgres" хорош ТОЛЬКО для разработки. В production обязательно сильный пароль из Secret.
> 3. **Альтернатива**: не задавать пароль в ENV вообще, требовать обязательной передачи через k8s Secret.

**В7: Что значит `PGDATA=/var/lib/postgresql/data` и почему в k8s другой путь?**
> `PGDATA` — переменная окружения PostgreSQL, указывающая директорию для хранения файлов БД.
> 
> Стандартный путь: `/var/lib/postgresql/data`.
> 
> Проблема в k8s: когда монтируется PVC с hostPath (или AWS EBS), в директории появляется системный артефакт `lost+found` от ext4. PostgreSQL проверяет, что PGDATA **полностью пустой** при инициализации — видит `lost+found` → отказывается стартовать с ошибкой:
> ```
> initdb: error: directory "/var/lib/postgresql/data" exists but is not empty
> ```
> 
> Решение: указать **подкаталог** для PGDATA:
> ```yaml
> env:
>   - name: PGDATA
>     value: /var/lib/postgresql/data/pgdata
> ```
> 
> Тогда:
> - `/var/lib/postgresql/data/lost+found` ← остаётся (но не мешает)
> - `/var/lib/postgresql/data/pgdata/` ← создаётся PostgreSQL и используется для данных

**В8: Зачем устанавливать bash, если есть sh в Alpine?**
> Bash и sh — разные оболочки:
> 
> **sh (ash в Alpine)**:
> - Минималистичный POSIX shell из BusyBox.
> - Только базовые возможности: переменные, циклы, if/else.
> - Без массивов, без `[[ ]]`, без `==` (только `=`).
> 
> **bash**:
> - GNU Bash, расширенный shell.
> - Массивы: `arr=(a b c)`.
> - Условия: `[[ "$var" == "value" ]]`.
> - Process substitution: `<(command)`.
> - Множество удобств.
> 
> `init-check.sh` использует bash-specific синтаксис — поэтому нужен bash. Без него скрипт упал бы с `syntax error`.

**В9: HEALTHCHECK работает в Kubernetes?**
> **Нет, в k8s HEALTHCHECK из Dockerfile игнорируется!** K8s использует свои механизмы:
> 
> 1. **livenessProbe**: жив ли контейнер? Если падает — k8s **перезапускает** под.
> 2. **readinessProbe**: готов ли принимать трафик? Если падает — Service **исключает** под из endpoints.
> 3. **startupProbe**: для медленно стартующих приложений (k8s 1.16+).
> 
> Чтобы использовать pg_isready в k8s, в Deployment нужно:
> ```yaml
> livenessProbe:
>   exec:
>     command: ["pg_isready", "-U", "postgres"]
>   initialDelaySeconds: 30
>   periodSeconds: 10
> readinessProbe:
>   exec:
>     command: ["pg_isready", "-U", "postgres"]
>   initialDelaySeconds: 5
>   periodSeconds: 5
> ```
> 
> В моём проекте этого нет — **технический долг**. Если PostgreSQL зависнет, k8s не поймёт и не перезапустит.

**В10: Какие БД создаются в init.sql и почему?**
> Согласно архитектуре микросервисов (**Database per Service**):
> 
> | БД | Сервис | Назначение |
> |----|--------|------------|
> | users_db | session-service | пользователи, сессии |
> | hotels_db | hotel-service | каталог отелей |
> | reservations_db | booking-service | бронирования |
> | payments_db | payment-service | транзакции |
> | balances_db | loyalty-service | баланс баллов |
> | statistics_db | report-service | агрегированные данные |
> 
> Каждая БД полностью изолирована: разные таблицы, разные схемы. Это:
> - **Защита данных**: компрометация одного сервиса не даёт доступ к чужим данным.
> - **Независимая эволюция**: миграции в одной БД не ломают других.
> - **Возможность подмены БД**: завтра hotel-service переедет на MongoDB — никто не пострадает.

**В11: Можно ли вместо init.sql использовать ConfigMap?**
> Да, и это даже **предпочтительнее** для k8s:
> 
> ```yaml
> apiVersion: v1
> kind: ConfigMap
> metadata:
>   name: postgres-init
> data:
>   01-init.sql: |
>     CREATE DATABASE users_db;
>     CREATE DATABASE hotels_db;
>     -- и т.д.
> ```
> 
> И в Deployment postgres:
> ```yaml
> volumes:
>   - name: init-scripts
>     configMap:
>       name: postgres-init
> containers:
>   - name: postgres
>     image: postgres:14-alpine  # ← стандартный образ!
>     volumeMounts:
>       - name: init-scripts
>         mountPath: /docker-entrypoint-initdb.d/
> ```
> 
> Плюсы:
> 1. Используется **стандартный** образ postgres, не кастомный.
> 2. Изменения init.sql **не требуют пересборки образа** — только обновить ConfigMap.
> 3. ConfigMap версионируется в git вместе с другими манифестами.
> 
> Это вариант оптимизации, который можно сделать в следующих итерациях проекта.

**В12: Что делает init-check.sh?**
> Не видя содержимого, могу предположить (это типичный паттерн):
> ```bash
> #!/bin/bash
> set -e
> 
> echo "Checking that all databases were created..."
> for db in users_db hotels_db reservations_db payments_db balances_db statistics_db; do
>   psql -U postgres -d postgres -c "SELECT 1 FROM pg_database WHERE datname='$db';" \
>     | grep -q 1 \
>     && echo "✓ $db exists" \
>     || (echo "✗ $db missing!" && exit 1)
> done
> 
> echo "All databases initialized successfully"
> ```
> 
> Назначение:
> 1. **Валидация**: проверяет, что init.sql отработал корректно.
> 2. **Логирование**: в логах контейнера видно состояние БД.
> 3. **Fail-fast**: если что-то не так — контейнер падает, k8s видит проблему.

**В13: Что произойдёт при попытке запустить эту же миграцию на работающей БД?**
> При повторном запуске init.sql:
> ```sql
> CREATE DATABASE users_db;
> ```
> Получим ошибку:
> ```
> ERROR: database "users_db" already exists
> ```
> 
> Защита — **идемпотентность**:
> ```sql
> CREATE DATABASE IF NOT EXISTS users_db;
> ```
> 
> ⚠️ **Внимание**: PostgreSQL **не поддерживает** `CREATE DATABASE IF NOT EXISTS`! Это синтаксис MySQL.
> 
> В PostgreSQL правильнее:
> ```sql
> SELECT 'CREATE DATABASE users_db'
> WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'users_db')
> \gexec
> ```
> 
> Или просто использовать миграции (Liquibase/Flyway), которые сами отслеживают, что применено.

**В14: Какие resource limits подходят для PostgreSQL в k8s?**
> Зависит от нагрузки, но базовые:
> ```yaml
> resources:
>   requests:
>     cpu: "200m"
>     memory: "512Mi"
>   limits:
>     cpu: "1000m"
>     memory: "1Gi"
> ```
> 
> Особенности:
> 1. **Память важнее CPU**: PostgreSQL агрессивно кеширует данные. `shared_buffers` обычно 25% от RAM. Маленький limit = плохой кеш = медленная работа.
> 2. **CPU throttling**: PostgreSQL хорошо переживает throttling, но индексы могут перестраиваться медленно.
> 3. **Swap должен быть выключен**: иначе latency катастрофическая.
> 
> Для production обычно ставят VPA (Vertical Pod Autoscaler) или мониторят и подкручивают вручную.

Если по какой-то строке хочется глубже — спрашивай 🚀