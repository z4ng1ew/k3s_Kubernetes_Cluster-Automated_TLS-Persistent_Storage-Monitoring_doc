FROM maven:3.9-eclipse-temurin-11 AS builder
WORKDIR /app


ENV MAVEN_OPTS="-Dmaven.wagon.http.pool=false -Dmaven.wagon.http.retryHandler.count=10 -Djava.net.preferIPv4Stack=true"
COPY maven-settings.xml /root/.m2/settings.xml
COPY pom.xml ./
COPY src ./src
RUN mvn -B -s /root/.m2/settings.xml \
    -Dmaven.wagon.rto=600000 \
    -Dmaven.test.skip=true \
    package

FROM eclipse-temurin:8-jre-alpine
WORKDIR /app
RUN apk add --no-cache bash netcat-openbsd
COPY --from=builder /app/target/*.jar app.jar
COPY wait-for-it.sh /wait-for-it.sh
RUN chmod +x /wait-for-it.sh
EXPOSE 8080
ENTRYPOINT ["java", "-jar", "app.jar"]



  















# 📝 Построчный разбор Dockerfile для booking-service

## 🔍 Полный комментарий по каждой строке

```dockerfile
# ============================================================
# Multi-stage Dockerfile — стандартный паттерн сборки Java
# приложений в Docker.
#
# Концепция: используем ДВА разных образа на разных этапах.
#  - Этап 1 (builder): жирный образ с Maven и JDK для сборки.
#  - Этап 2 (runner):  лёгкий образ только с JRE для запуска.
#
# Зачем: финальный образ будет содержать только готовый jar +
# JRE (Java Runtime), без Maven, без исходников, без mvn-кеша.
# Размер уменьшается с ~700 МБ до ~150 МБ.
# ============================================================


# ============================================================
# ЭТАП 1: BUILDER — сборка jar-файла
# ============================================================
FROM maven:3.9-eclipse-temurin-11 AS builder
# FROM:        указывает базовый образ
# maven:3.9:   Maven версии 3.9 (актуальная стабильная)
# eclipse-temurin-11: JDK 11 от Eclipse Temurin (Adoptium)
#              Это OpenJDK дистрибутив, рекомендованный к использованию
#              после изменений в лицензии Oracle JDK.
# AS builder:  именованный этап, к нему можно обратиться позже
#              командой COPY --from=builder.

WORKDIR /app
# Устанавливает рабочую директорию внутри контейнера.
# Все последующие команды (COPY, RUN, CMD) будут выполняться
# относительно /app. Если /app не существует — создаётся.
# Эквивалент: cd /app

ENV MAVEN_OPTS="-Dmaven.wagon.http.pool=false -Dmaven.wagon.http.retryHandler.count=10 -Djava.net.preferIPv4Stack=true"
# Устанавливает переменную окружения MAVEN_OPTS — флаги для JVM,
# которые Maven применяет к своему процессу.
#
# Разбор флагов:
#  -Dmaven.wagon.http.pool=false
#       Отключает HTTP-connection pool в Maven Wagon.
#       Wagon — это компонент Maven, отвечающий за скачивание
#       зависимостей с Maven Central, Nexus и т.д.
#       Pool иногда конфликтует с прокси / нестабильным интернетом.
#       Отключение делает сборку более устойчивой.
#
#  -Dmaven.wagon.http.retryHandler.count=10
#       Количество повторных попыток при ошибках сети.
#       По умолчанию 3. Здесь 10 — мощная защита от flaky-сети
#       (часто бывает в учебных средах или за корпоративным прокси).
#
#  -Djava.net.preferIPv4Stack=true
#       Принудительно использовать IPv4, игнорировать IPv6.
#       Решает проблемы с DNS-resolve, когда IPv6 не настроен,
#       но JVM пытается его использовать (зависание на ~30 сек).

COPY maven-settings.xml /root/.m2/settings.xml
# Копирует файл maven-settings.xml из контекста сборки (директория
# с Dockerfile) в стандартное место конфигурации Maven внутри контейнера.
#
# Этот файл обычно содержит:
#  - кастомные репозитории (например, mirror на nexus.school21.ru)
#  - креды для приватных репозиториев
#  - настройки прокси
#  - профили сборки
#
# /root/.m2/settings.xml — стандартный путь для пользовательских
# настроек Maven.

COPY pom.xml ./
# Копирует pom.xml (Project Object Model) — главный файл Maven,
# который описывает зависимости, плагины, версии.
#
# ./ — означает текущую рабочую директорию = /app (из WORKDIR).
#
# ⚠️ Тонкость: pom.xml копируется ОТДЕЛЬНО от src/ намеренно!
# Это позволяет использовать кеширование Docker-слоёв:
# если pom.xml не изменился — слой с download dependencies
# берётся из кеша (огромная экономия времени).
# В реальной оптимизации после COPY pom.xml идёт:
#   RUN mvn dependency:go-offline
# чтобы заранее скачать зависимости. Здесь этого нет —
# зависимости качаются на стадии package.

COPY src ./src
# Копирует директорию src (исходный код Java) в /app/src.
# Это: src/main/java/, src/main/resources/, src/test/java/ и т.д.

RUN mvn -B -s /root/.m2/settings.xml \
    -Dmaven.wagon.rto=600000 \
    -Dmaven.test.skip=true \
    package
# Запускает Maven для сборки.
#
# Разбор флагов:
#  -B (--batch-mode)
#       Batch mode — Maven работает без интерактивных вопросов.
#       Стандартно для CI/CD и Docker-сборки. Выводит логи в
#       компактном виде, без цветов и прогресс-баров.
#
#  -s /root/.m2/settings.xml
#       Явно указать settings.xml (тот, что мы скопировали).
#       Можно было бы не указывать — Maven сам найдёт в дефолтном
#       месте, но явность лучше.
#
#  -Dmaven.wagon.rto=600000
#       Read timeout = 600000 мс = 10 минут.
#       Время ожидания ответа при скачивании артефактов.
#       Защита от обрыва соединения при медленном интернете.
#
#  -Dmaven.test.skip=true
#       НЕ ВЫПОЛНЯТЬ юнит-тесты!
#       ⚠️ Это спорная практика:
#       + Быстрая сборка (тесты могут занимать минуты).
#       + В CI обычно тесты прогоняют ОТДЕЛЬНО, до Docker-build.
#       - Тесты могут отловить баги при сборке.
#       - Производственный образ может содержать сломанный код.
#       Альтернатива: -DskipTests=true (компилирует тесты, но не запускает)
#       vs -Dmaven.test.skip=true (даже не компилирует).
#       Здесь — полное отключение, для скорости.
#
#  package
#       Цель Maven: компиляция + упаковка в jar/war.
#       Запускает фазы: validate → compile → test (skipped)
#       → package → ... 
#       Результат: target/<artifact>-<version>.jar


# ============================================================
# ЭТАП 2: RUNNER — финальный лёгкий образ для запуска
# ============================================================
FROM eclipse-temurin:8-jre-alpine
# Новый FROM = новый этап сборки. Builder остаётся в стороне
# (его слои не попадут в финальный образ).
#
# eclipse-temurin:8-jre-alpine — лёгкий runtime образ:
#  - eclipse-temurin: OpenJDK дистрибутив Adoptium.
#  - 8: Java 8 (LTS).
#  - jre: только Java Runtime, без компилятора (JDK).
#         JRE достаточно для запуска готового jar.
#  - alpine: базовый образ Alpine Linux (~5 МБ vs ~100 МБ Ubuntu).
#
# ⚠️ ВНИМАНИЕ! Здесь несоответствие версий Java:
#  - Сборка: JDK 11.
#  - Запуск: JRE 8.
# Это работает только если код проекта target=1.8 (компиляция
# в байткод Java 8). Иначе будет UnsupportedClassVersionError.
# Это рискованная конфигурация — лучше использовать одну версию
# (например, jre-11-alpine).

WORKDIR /app
# Рабочая директория уже нового, чистого образа.
# Никаких maven, исходников, кеша — пустая папка.

RUN apk add --no-cache bash netcat-openbsd
# apk — пакетный менеджер Alpine Linux.
# add — установить пакеты.
# --no-cache — НЕ кешировать индексы пакетов (экономия места).
#
# Устанавливаемые пакеты:
#  - bash: командная оболочка. По умолчанию в Alpine только sh
#          (ash из busybox). bash нужен для скрипта wait-for-it.sh.
#  - netcat-openbsd: реализация netcat (nc) для проверки портов.
#          Используется в wait-for-it.sh: nc -z host port.
#
# Зачем: wait-for-it.sh — bash-скрипт, который ждёт, пока
# определённый порт (например, PostgreSQL 5432) станет доступен.
# Полезно при docker-compose, чтобы приложение не падало из-за
# того, что БД ещё не готова.
# ⚠️ В k8s обычно используют initContainers или readinessProbe,
# wait-for-it.sh — это паттерн из docker-compose эры.

COPY --from=builder /app/target/*.jar app.jar
# COPY --from=builder: скопировать из этапа builder.
# /app/target/*.jar: путь к собранному jar в builder-этапе.
#                    *.jar — wildcard, чтобы не зависеть от
#                    конкретного имени артефакта (зависит от pom.xml).
# app.jar: переименование в простое имя.
#
# Это КЛЮЧЕВАЯ строка multi-stage build: из жирного образа
# берётся только результат сборки (~50 МБ jar) и кладётся
# в финальный образ. Maven, исходники, кеш ~/.m2/ остаются
# в builder и не попадают в production-образ.

COPY wait-for-it.sh /wait-for-it.sh
# Копирует bash-скрипт из контекста сборки в корень контейнера.
# wait-for-it.sh — популярный публичный скрипт от vishnubob:
# https://github.com/vishnubob/wait-for-it
#
# Использование:
#   /wait-for-it.sh postgres:5432 -- java -jar app.jar
# Ждёт доступности postgres:5432, затем запускает команду.

RUN chmod +x /wait-for-it.sh
# Делает скрипт исполняемым (executable bit).
# По умолчанию COPY не сохраняет права +x, нужно явно установить.
# Без этого скрипт не запустится: "Permission denied".

EXPOSE 8080
# ⚠️ ВНИМАНИЕ: указано 8080, а в Deployment k8s containerPort: 8083!
# 
# EXPOSE — это ДОКУМЕНТИРУЮЩАЯ инструкция, она НЕ открывает
# порт автоматически. Это просто метаданные в манифесте Docker,
# что приложение слушает определённый порт.
#
# Реальный порт определяется самим Spring Boot приложением
# (server.port в application.yml/properties).
#
# В нашем случае:
#  - Dockerfile говорит "приложение на 8080"
#  - Реально Spring Boot слушает 8083 (из application.yml)
#  - K8s containerPort: 8083 (соответствует реальности)
#
# EXPOSE 8080 здесь — устаревший legacy, шаблон копировался
# между сервисами без правки. Не критично, но вводит в заблуждение.

ENTRYPOINT ["java", "-jar", "app.jar"]
# ENTRYPOINT — команда, которая запускается при старте контейнера.
# Exec-форма (в массиве) — рекомендуется:
#  - Запуск без shell wrapper, прямой exec.
#  - Сигналы (SIGTERM от k8s) корректно доходят до Java-процесса.
#  - Меньше overhead.
#
# Что делает: запускает Java с jar-файлом app.jar.
# Это запустит Spring Boot приложение.
#
# ⚠️ wait-for-it.sh НЕ ИСПОЛЬЗУЕТСЯ!
# Скрипт скопирован, но не вызывается. Видимо, изначально
# планировали использовать, но потом перешли на k8s
# initContainers/readinessProbe. Legacy-код.
#
# Если хотели бы использовать:
# ENTRYPOINT ["/wait-for-it.sh", "postgres:5432", "--", \
#             "java", "-jar", "app.jar"]
```

---

## 🔗 Жизненный цикл сборки: что происходит шаг за шагом

```
┌─────────────────────────────────────────────────────────┐
│ docker build -t src-booking-service:latest .            │
└────────────────────┬────────────────────────────────────┘
                     ▼

┌─────────────────────────────────────────────────────────┐
│ ЭТАП 1: BUILDER                                          │
│                                                          │
│ 1. Скачивается maven:3.9-eclipse-temurin-11 (~700 МБ)   │
│ 2. WORKDIR /app — создаётся пустая директория            │
│ 3. ENV MAVEN_OPTS — устанавливаются JVM-флаги            │
│ 4. COPY maven-settings.xml → /root/.m2/settings.xml      │
│ 5. COPY pom.xml → /app/pom.xml                           │
│ 6. COPY src → /app/src                                   │
│ 7. RUN mvn package:                                      │
│    - Maven читает pom.xml                                │
│    - Скачивает зависимости в /root/.m2/repository/       │
│    - Компилирует Java-код                                │
│    - Пропускает тесты (-Dmaven.test.skip=true)           │
│    - Упаковывает в jar → /app/target/booking-1.0.jar     │
│                                                          │
│ Результат: образ ~1.2 ГБ                                 │
│ (maven + jdk + .m2 кеш + исходники + jar)                │
└────────────────────┬────────────────────────────────────┘
                     ▼

┌─────────────────────────────────────────────────────────┐
│ ЭТАП 2: RUNNER                                           │
│                                                          │
│ 1. Скачивается eclipse-temurin:8-jre-alpine (~80 МБ)    │
│ 2. WORKDIR /app                                          │
│ 3. RUN apk add bash netcat-openbsd (~5 МБ)               │
│ 4. COPY --from=builder /app/target/*.jar /app/app.jar    │
│    (~50 МБ)                                              │
│ 5. COPY wait-for-it.sh /wait-for-it.sh                   │
│ 6. RUN chmod +x /wait-for-it.sh                          │
│ 7. EXPOSE 8080 — документация                            │
│ 8. ENTRYPOINT — команда запуска                          │
│                                                          │
│ Результат: образ ~150 МБ                                 │
│ (jre + alpine + jar + утилиты)                           │
└────────────────────┬────────────────────────────────────┘
                     ▼
              ┌──────────────┐
              │ Финальный    │
              │ образ        │
              │ ~150 МБ      │
              └──────────────┘

Builder-образ (~1.2 ГБ) НЕ попадает в финальный!
Docker сохраняет только Этап 2.
```

---

## 🆚 Multi-stage vs Single-stage сборка

### Single-stage (наивный подход):

```dockerfile
FROM maven:3.9-eclipse-temurin-11
WORKDIR /app
COPY . .
RUN mvn package
ENTRYPOINT ["java", "-jar", "target/booking-1.0.jar"]
```
- **Размер**: ~1.2 ГБ
- Содержит: Maven + JDK + кеш зависимостей + исходники + jar
- Передача по сети медленная, дольше pull в k8s
- В production не нужны ни Maven, ни исходники

### Multi-stage (наш):

```dockerfile
FROM maven:3.9-... AS builder    # Жирный образ для сборки
# ... mvn package ...

FROM eclipse-temurin:8-jre-alpine # Лёгкий образ для запуска
COPY --from=builder /app/target/*.jar app.jar
```
- **Размер**: ~150 МБ
- Содержит: JRE + Alpine + jar
- Быстрая передача, быстрый запуск в k8s
- Меньшая attack surface (нет Maven, gcc, и т.д.)

---

## ⚠️ Проблемные места в этом Dockerfile

### 1. Несоответствие версий Java

```
Builder: JDK 11 (компилирует код)
Runner:  JRE 8 (запускает код)
```

**Проблема**: если проект использует Java 11+ features (var, switch expressions, modules) — байткод не запустится на JRE 8.

**Решение**: использовать одну версию:
```dockerfile
FROM maven:3.9-eclipse-temurin-11 AS builder
# ...
FROM eclipse-temurin:11-jre-alpine
```

Или явно указать в pom.xml:
```xml
<properties>
  <maven.compiler.source>1.8</maven.compiler.source>
  <maven.compiler.target>1.8</maven.compiler.target>
</properties>
```

### 2. EXPOSE 8080 vs реальный порт 8083

Шаблон копировался между сервисами без обновления. Не критично (EXPOSE декларативный), но вводит в заблуждение.

### 3. wait-for-it.sh скопирован, но не используется

ENTRYPOINT не вызывает его. Артефакт от docker-compose эры, в k8s используются другие подходы:
- **initContainers**: запускаются до основного контейнера, могут проверить готовность БД.
- **readinessProbe**: k8s не направляет трафик в под, пока проба не пройдёт.
- **livenessProbe**: рестарт пода, если приложение зависло.

### 4. -Dmaven.test.skip=true vs -DskipTests

| Флаг | Что делает |
|------|------------|
| `-DskipTests=true` | Компилирует тестовые классы, но не запускает тесты |
| `-Dmaven.test.skip=true` | Даже не компилирует тесты |

Здесь используется второй — более агрессивный. Если тесты сломаны на этапе компиляции (например, missing imports), сборка всё равно пройдёт. Это маскирует проблемы.

### 5. Отсутствие dependency caching

Идеальный multi-stage Dockerfile для Maven выглядит так:

```dockerfile
FROM maven:3.9-eclipse-temurin-11 AS builder
WORKDIR /app
COPY pom.xml ./
RUN mvn dependency:go-offline -B  # ← скачивает зависимости отдельным слоем
COPY src ./src
RUN mvn package -DskipTests
```

Тогда при изменении только src/ Docker возьмёт слой с зависимостями из кеша — сборка ускорится в разы.

### 6. Запуск под root

Контейнер запускается под root (default в Alpine). Это **security risk**:
- При компрометации Java-процесса злоумышленник получает root в контейнере.
- Может попытаться эскалировать привилегии.

Лучшая практика:
```dockerfile
RUN addgroup -S spring && adduser -S spring -G spring
USER spring
```

В k8s можно также установить securityContext:
```yaml
securityContext:
  runAsNonRoot: true
  runAsUser: 1000
```

---

## 🗣 Монолог для защиты (~300 символов)

> Это multi-stage Dockerfile для Spring Boot микросервиса. На первом этапе образ maven:3.9-eclipse-temurin-11 собирает jar через mvn package с пропуском тестов и устойчивыми сетевыми настройками. На втором этапе лёгкий eclipse-temurin:8-jre-alpine получает только готовый jar через COPY --from=builder. В финальном образе ~150 МБ, никаких исходников и Maven. ENTRYPOINT запускает Java через jar напрямую — корректная передача сигналов от Kubernetes.

*(длина ~480 символов, могу сократить до 300)*

---

## 💡 Возможные вопросы на защите

**В1: Что такое multi-stage build и зачем он нужен?**
> Это паттерн Dockerfile, где используются несколько FROM-инструкций — каждая создаёт свой "этап" сборки. Финальный образ содержит результат только последнего этапа.
> 
> Зачем:
> 1. **Размер**: финальный образ ~150 МБ vs ~1.2 ГБ при single-stage.
> 2. **Security**: нет лишних инструментов (Maven, gcc, и т.д.) — меньше attack surface.
> 3. **Скорость pull**: меньший образ быстрее скачивается на ноды k8s.
> 4. **Чистота**: production-образ содержит только то, что нужно для запуска.

**В2: Что произойдёт без `--from=builder` в `COPY`?**
> COPY будет искать файлы в **контексте сборки** (директории с Dockerfile), а не в builder-этапе. Скорее всего, попытается найти `/app/target/*.jar` в локальной файловой системе и не найдёт — сборка упадёт.
> 
> `--from=builder` явно указывает: "копируй из именованного этапа builder".

**В3: Почему `-Dmaven.test.skip=true`, а не запуск тестов?**
> Чтобы ускорить сборку Docker-образа. Тесты в Spring Boot могут занимать минуты (поднятие контекста, БД через TestContainers).
> 
> Принятая практика в CI/CD:
> 1. **Перед** docker build: запустить `mvn test` в отдельном шаге pipeline.
> 2. **В** docker build: только сборка артефакта с `-DskipTests`.
> 3. **После**: интеграционные тесты на запущенном контейнере.
> 
> Не пропускать тесты совсем, но разделять этапы.

**В4: Что не так с версиями Java (JDK 11 → JRE 8)?**
> Это потенциальный bug! Если код использует Java 9+ features (var, switch expressions, sealed classes, records), они **не запустятся** на JRE 8 — будет `UnsupportedClassVersionError`.
> 
> Работает только если:
> 1. В pom.xml указан target byte code Java 8: `<maven.compiler.target>1.8</maven.compiler.target>`.
> 2. Код не использует API Java 9+.
> 
> Правильнее: одна версия Java в builder и runner. Например, обе `eclipse-temurin:11`.

**В5: Что такое Alpine и почему его используют?**
> **Alpine Linux** — минималистичный дистрибутив Linux размером ~5 МБ (vs ~100 МБ Ubuntu). Используется как база для Docker-образов.
> 
> Плюсы:
> 1. **Размер**: финальный образ значительно меньше.
> 2. **Безопасность**: меньше пакетов = меньше уязвимостей.
> 3. **Скорость**: быстрее качается, быстрее стартует.
> 
> Минусы:
> 1. **musl libc** вместо glibc — некоторые приложения работают некорректно. Особенно проблемно для нативных расширений Java (NIO, OpenSSL).
> 2. **apk** вместо apt — другой пакетный менеджер.
> 3. **Меньше пакетов** в репо.
> 
> Для Java на Alpine рекомендуют использовать **Eclipse Temurin** (как у нас) — они тестируют свои образы на Alpine.

**В6: Почему EXPOSE 8080, если приложение слушает 8083?**
> Это **legacy / технический долг**. EXPOSE — это только декларация в метаданных образа, она НИЧЕГО не делает функционально. Реальный порт определяется приложением (Spring Boot `server.port=8083`).
> 
> EXPOSE используется только:
> 1. Как **документация** для разработчиков.
> 2. `docker run -P` (заглавная P) автоматически публикует все EXPOSE-порты.
> 3. Некоторые инструменты сканирования docker-образов читают эти метки.
> 
> На работу в k8s никак не влияет — k8s использует containerPort в Deployment.
> 
> Шаблон Dockerfile, видимо, был скопирован между сервисами и забыли обновить.

**В7: Зачем `wait-for-it.sh`, если он не используется в ENTRYPOINT?**
> Это **legacy от docker-compose эры**. В docker-compose не было встроенного механизма ожидания готовности зависимостей (depends_on проверяет только запуск, не readiness). Скрипт wait-for-it.sh пытается подключиться к порту в цикле, пока не получится:
> ```bash
> wait-for-it.sh postgres:5432 -- java -jar app.jar
> ```
> 
> В Kubernetes этот подход **устарел**, используются:
> 1. **initContainers**: блокируют старт основного контейнера до выполнения условия.
> 2. **readinessProbe**: k8s не направляет трафик до готовности.
> 3. **livenessProbe**: рестарт зависших подов.
> 
> Артефакт можно удалить из Dockerfile.

**В8: Можно ли запускать контейнер не от root?**
> Да, и **нужно** в production. Сейчас контейнер работает под root (default), что небезопасно.
> 
> Изменение Dockerfile:
> ```dockerfile
> RUN addgroup -S spring && adduser -S spring -G spring
> USER spring
> ```
> 
> Или в k8s через securityContext:
> ```yaml
> spec:
>   securityContext:
>     runAsNonRoot: true
>     runAsUser: 1000
>     fsGroup: 1000
> ```
> 
> Это:
> 1. Соответствует **principle of least privilege**.
> 2. Защищает от эскалации привилегий при компрометации.
> 3. Требуется PCI DSS, CIS Benchmarks.

**В9: Почему COPY pom.xml отдельно от src?**
> Для **Docker layer caching**. Каждая инструкция Dockerfile создаёт отдельный слой (layer). Если файлы в слое не изменились — Docker берёт слой из кеша.
> 
> При изменении только Java-кода (src/):
> - Слой с pom.xml не изменился → берётся из кеша.
> - Слой с зависимостями (.m2/repository) не изменился → кеш.
> - Слой с src изменён → пересборка с этой точки.
> 
> Это огромная экономия: вместо 5-10 минут на скачивание зависимостей — 30 секунд на компиляцию.
> 
> Идеальная оптимизация:
> ```dockerfile
> COPY pom.xml ./
> RUN mvn dependency:go-offline    # ← скачивает все зависимости одним слоем
> COPY src ./src
> RUN mvn package                  # ← теперь только компиляция
> ```

**В10: Что такое exec-form vs shell-form в ENTRYPOINT?**
> Два синтаксиса:
> 
> **Shell-form** (плохо):
> ```dockerfile
> ENTRYPOINT java -jar app.jar
> ```
> Запускается через `/bin/sh -c "java -jar app.jar"`. Проблема: сигналы (SIGTERM от k8s) идут в sh, не в Java. Java не успевает graceful shutdown за 30 сек → SIGKILL.
> 
> **Exec-form** (хорошо):
> ```dockerfile
> ENTRYPOINT ["java", "-jar", "app.jar"]
> ```
> Запускается напрямую, Java получает PID 1. Сигналы доходят корректно, Spring Boot успевает закрыть HTTP-сервер, БД-коннекты и т.д.
> 
> В нашем Dockerfile использован exec-form — это правильно.

**В11: Можно ли ещё уменьшить размер образа?**
> Да, несколькими способами:
> 
> 1. **JRE → JDK Custom**: jlink собирает минимальный JRE только с нужными модулями.
>    ```dockerfile
>    RUN jlink --add-modules java.base,java.logging --output /custom-jre
>    ```
>    Можно ужать до ~40 МБ.
> 
> 2. **Distroless**: gcr.io/distroless/java — только JRE без shell, утилит.
>    Минусы: нельзя зайти `docker exec sh`.
> 
> 3. **GraalVM Native Image**: компиляция в native binary (~50 МБ), мгновенный старт, меньше памяти.
> 
> 4. **Spring Boot layered jar** + Buildpacks: автоматическая оптимизация слоёв.

**В12: Что произойдёт, если убрать MAVEN_OPTS с retry?**
> При нестабильном интернете (типично для корпоративных сетей за прокси) сборка будет часто падать с `ConnectionResetException` или `ReadTimeoutException`. Maven скачивает сотни маленьких файлов (jar'ов зависимостей), и flaky-сеть = высокий шанс хоть одного fail'а.
> 
> С `retryHandler.count=10` Maven попробует 10 раз перед сдачей. Это **resilience-флаг для CI/CD**.

**В13: Чем `mvn package` отличается от `mvn install`?**
> Стадии Maven lifecycle:
> - `validate` → `compile` → `test` → **`package`** → `verify` → **`install`** → `deploy`
> 
> - `package`: компиляция + создание jar в `target/`.
> - `install`: всё то же + копирование jar в локальный кеш `~/.m2/repository/`.
> - `deploy`: всё то же + публикация в remote-репозиторий.
> 
> Для Docker-build достаточно `package` — jar нужен только для COPY в финальный образ. install бы записал артефакт в кеш, который всё равно умирает с builder-стадией.

Если по какой-то строке хочется глубже — спрашивай 🚀