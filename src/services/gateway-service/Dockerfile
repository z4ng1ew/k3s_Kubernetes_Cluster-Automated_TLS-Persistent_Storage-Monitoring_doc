FROM maven:3.9-eclipse-temurin-11 AS builder
WORKDIR /app
ENV MAVEN_OPTS="-Dmaven.wagon.http.pool=false -Dmaven.wagon.httpconnectionManager.ttlSeconds=120 -Dmaven.wagon.http.retryHandler.count=5 -Dhttp.keepAlive=false"
COPY maven-settings.xml /root/.m2/settings.xml
COPY pom.xml ./
RUN mvn -B -s /root/.m2/settings.xml -Dmaven.wagon.rto=300000 dependency:go-offline
COPY src ./src
RUN mvn -B -s /root/.m2/settings.xml -Dmaven.wagon.rto=300000 package -DskipTests

FROM eclipse-temurin:8-jre-alpine
WORKDIR /app
RUN apk add --no-cache bash netcat-openbsd
COPY --from=builder /app/target/*.jar app.jar
COPY wait-for-it.sh /wait-for-it.sh
RUN chmod +x /wait-for-it.sh
EXPOSE 8087
ENTRYPOINT ["java", "-jar", "app.jar"]





# 📝 Построчный разбор Dockerfile для gateway-service

## 🔍 Полный комментарий по каждой строке

```dockerfile
# ============================================================
# Multi-stage Dockerfile для gateway-service.
# Структурно похож на booking-service Dockerfile, но с двумя
# ключевыми отличиями:
#  1. Оптимизация Docker-кеша: pom.xml и зависимости качаются
#     отдельным слоем (RUN mvn dependency:go-offline).
#  2. EXPOSE 8087 — порт корректный для gateway-service.
#
# Это улучшенная (оптимизированная) версия Dockerfile-шаблона.
# ============================================================


# ============================================================
# ЭТАП 1: BUILDER — сборка jar
# ============================================================
FROM maven:3.9-eclipse-temurin-11 AS builder
# Базовый образ: Maven 3.9 + JDK 11 от Eclipse Temurin.
#  - maven:3.9: актуальная стабильная версия Maven.
#  - eclipse-temurin-11: OpenJDK 11 (рекомендован после
#    изменений лицензии Oracle).
#  - AS builder: именованный этап для COPY --from=builder.

WORKDIR /app
# Рабочая директория внутри контейнера. Все последующие
# инструкции (COPY, RUN) выполняются относительно /app.

ENV MAVEN_OPTS="-Dmaven.wagon.http.pool=false -Dmaven.wagon.httpconnectionManager.ttlSeconds=120 -Dmaven.wagon.http.retryHandler.count=5 -Dhttp.keepAlive=false"
# Переменная окружения MAVEN_OPTS — флаги JVM для процесса Maven.
# Все эти флаги — для устойчивой работы в нестабильной сети
# (типично за корпоративным прокси или в учебных средах).
#
# Разбор флагов:
#  -Dmaven.wagon.http.pool=false
#       Отключает HTTP connection pool в Maven Wagon.
#       Wagon = компонент Maven, скачивающий артефакты.
#       Pool иногда конфликтует с прокси / NAT, отключение
#       делает сборку более устойчивой.
#
#  -Dmaven.wagon.httpconnectionManager.ttlSeconds=120
#       TTL (time to live) для HTTP-соединений = 120 секунд.
#       После этого соединение принудительно закрывается и
#       создаётся новое. Защита от "залипших" connection'ов.
#
#  -Dmaven.wagon.http.retryHandler.count=5
#       5 повторных попыток при ошибках сети.
#       По умолчанию 3 — здесь чуть агрессивнее.
#       ⚠️ В booking-service Dockerfile было 10 — в gateway
#       чуть меньше, видимо, для скорости.
#
#  -Dhttp.keepAlive=false
#       Отключает HTTP keep-alive — каждый запрос идёт по
#       новому соединению. Защита от прокси, "режущих"
#       долго живущие соединения. Замедляет, но надёжнее.

COPY maven-settings.xml /root/.m2/settings.xml
# Копирует кастомный settings.xml в стандартное место Maven.
# Этот файл обычно содержит:
#  - mirror на корпоративный Nexus/Artifactory,
#  - креды для приватных репозиториев,
#  - настройки прокси.
#
# /root/.m2/settings.xml — дефолтное расположение
# пользовательских настроек Maven.

COPY pom.xml ./
# Копирует pom.xml (главный файл Maven) в /app/.
#
# ⚠️ КЛЮЧЕВОЕ оптимизационное решение!
# pom.xml копируется ОТДЕЛЬНЫМ слоем, ДО исходников.
# Это позволяет использовать Docker layer caching:
#  - Если pom.xml не изменился → слой со скачанными
#    зависимостями берётся из кеша.
#  - Если изменился только src/ → пересборка только
#    компиляции, без повторного скачивания.
# Экономит МИНУТЫ при каждой сборке.

RUN mvn -B -s /root/.m2/settings.xml -Dmaven.wagon.rto=300000 dependency:go-offline
# ⚠️ ВАЖНАЯ ОПТИМИЗАЦИЯ vs booking-service Dockerfile!
# Здесь явно вызывается dependency:go-offline — задача Maven,
# которая скачивает ВСЕ зависимости из pom.xml в локальный
# кеш ~/.m2/repository/.
#
# Разбор флагов:
#  -B (--batch-mode): без интерактивных вопросов (для CI/Docker).
#  -s /root/.m2/settings.xml: использовать наш settings.xml.
#  -Dmaven.wagon.rto=300000: read timeout = 300000 мс = 5 мин.
#                            Для медленных серверов / больших jar.
#  dependency:go-offline: цель — скачать все зависимости.
#
# Что происходит:
#  1. Maven читает pom.xml.
#  2. Скачивает все compile/runtime/test зависимости.
#  3. Кладёт в /root/.m2/repository/.
#  4. Готово к offline-сборке.
#
# Этот слой кешируется! При изменении только src/ — слой
# с зависимостями берётся из кеша. Огромная экономия:
# вместо 5-10 минут скачивания — 0 секунд.
#
# В booking-service Dockerfile этого шага НЕТ → зависимости
# качаются каждый раз при сборке. Это технический долг там.

COPY src ./src
# Копирует исходный код в /app/src.
# Это: src/main/java/, src/main/resources/, src/test/java/...
#
# Делается ПОСЛЕ скачивания зависимостей, чтобы изменения в
# коде не инвалидировали слой с зависимостями.

RUN mvn -B -s /root/.m2/settings.xml -Dmaven.wagon.rto=300000 package -DskipTests
# Финальная сборка артефакта.
#
# Разбор флагов:
#  -B: batch mode.
#  -s ...: settings.xml.
#  -Dmaven.wagon.rto=300000: read timeout.
#  package: цель — компиляция + упаковка в jar.
#  -DskipTests: пропустить запуск тестов.
#
# ⚠️ Отличие от booking-service Dockerfile:
#  - Там: -Dmaven.test.skip=true (НЕ компилирует тесты совсем).
#  - Здесь: -DskipTests (компилирует, но не запускает).
# Здесь поведение "мягче": если в тестах синтаксическая ошибка —
# сборка упадёт на компиляции тестов. Это плюс для качества кода.
#
# Результат: /app/target/<gateway>-<version>.jar


# ============================================================
# ЭТАП 2: RUNNER — минимальный образ для запуска
# ============================================================
FROM eclipse-temurin:8-jre-alpine
# Новый FROM = новый этап. Builder отбрасывается, не попадает
# в финальный образ.
#
# eclipse-temurin:8-jre-alpine:
#  - eclipse-temurin: OpenJDK от Adoptium.
#  - 8: Java 8 (LTS).
#  - jre: только runtime, без компилятора.
#  - alpine: лёгкий Alpine Linux.
#
# ⚠️ ВНИМАНИЕ! Несоответствие версий Java:
#  - Сборка: JDK 11.
#  - Запуск: JRE 8.
# Работает только если код использует target=1.8 (байткод Java 8).
# Иначе UnsupportedClassVersionError.
# Это рискованная конфигурация — лучше единая версия.

WORKDIR /app
# Рабочая директория в чистом runner-образе.

RUN apk add --no-cache bash netcat-openbsd
# Установка дополнительных пакетов через apk (пакетный менеджер
# Alpine).
#
# Пакеты:
#  - bash: оболочка, нужна для wait-for-it.sh.
#          По умолчанию в Alpine только sh (ash из busybox).
#  - netcat-openbsd: реализация nc (netcat).
#          Используется в wait-for-it.sh: nc -z host port.
#
# --no-cache: не кешировать индексы пакетов (экономия места).

COPY --from=builder /app/target/*.jar app.jar
# Копирование собранного jar из builder-этапа.
# Это ОСНОВНАЯ магия multi-stage build.
#
# /app/target/*.jar:
#  - *.jar: wildcard, чтобы не привязываться к конкретному имени.
#  - Имя artifact определяется в pom.xml (artifactId + version).
#
# app.jar: переименование в простое имя для запуска.

COPY wait-for-it.sh /wait-for-it.sh
# Bash-скрипт, ожидающий доступности TCP-порта.
# Источник: https://github.com/vishnubob/wait-for-it
# Использование:
#   /wait-for-it.sh host:port -- command-to-run
#
# В нашем случае скрипт СКОПИРОВАН, но НЕ ИСПОЛЬЗУЕТСЯ
# в ENTRYPOINT. Legacy от docker-compose эры.

RUN chmod +x /wait-for-it.sh
# Делает скрипт исполняемым.
# COPY не сохраняет +x bit, нужно явно установить.
# Иначе bash выдаст "Permission denied".

EXPOSE 8087
# ⚠️ Здесь правильный порт! 8087 = реальный порт gateway-service.
# Согласован с:
#  - server.port в application.yml gateway.
#  - containerPort: 8087 в k8s Deployment.
#  - Service port: 8087.
#  - Postman GATEWAY_PORT: "8087".
#
# В booking-service Dockerfile стоял EXPOSE 8080 (legacy bug),
# здесь исправлено.
#
# Напомню: EXPOSE — это документирующая инструкция, она
# НИЧЕГО не делает функционально. Реально порт открывает
# приложение (Spring Boot).

ENTRYPOINT ["java", "-jar", "app.jar"]
# Команда запуска контейнера в exec-form (массив).
#
# Преимущества exec-form:
#  - Java запускается напрямую, без обёртки sh.
#  - Получает PID 1 в контейнере.
#  - Сигналы (SIGTERM от k8s) корректно доходят до JVM.
#  - Spring Boot успевает выполнить graceful shutdown:
#    закрыть HTTP-сервер, освободить connection pool, и т.д.
#
# ⚠️ wait-for-it.sh скопирован, но не используется.
# Если бы хотели:
#   ENTRYPOINT ["/wait-for-it.sh", "session-service:8081", "--", \
#               "java", "-jar", "app.jar"]
```

---

## 🔗 Жизненный цикл сборки с оптимизацией кеша

```
┌─────────────────────────────────────────────────────────┐
│ docker build -t src-gateway-service:latest .            │
└────────────────────┬────────────────────────────────────┘
                     ▼

┌─────────────────────────────────────────────────────────┐
│ ЭТАП 1: BUILDER                                          │
│                                                          │
│ Layer 1: FROM maven:3.9-eclipse-temurin-11 (~700 МБ)    │
│          → берётся из кеша после первого pull            │
│                                                          │
│ Layer 2: WORKDIR /app                                    │
│          → мгновенно                                     │
│                                                          │
│ Layer 3: ENV MAVEN_OPTS                                  │
│          → мгновенно                                     │
│                                                          │
│ Layer 4: COPY maven-settings.xml                         │
│          → если файл не изменился → КЕШ                  │
│                                                          │
│ Layer 5: COPY pom.xml                                    │
│          → если pom.xml не изменился → КЕШ               │
│                                                          │
│ Layer 6: RUN mvn dependency:go-offline                   │
│          ★ КЛЮЧЕВОЙ для кеширования!                     │
│          → если Layers 4,5 из кеша → этот тоже из кеша   │
│          → скачивание зависимостей пропускается!         │
│          → экономия: 5-10 минут                          │
│                                                          │
│ Layer 7: COPY src ./src                                  │
│          → изменения в коде = инвалидация этого слоя     │
│                                                          │
│ Layer 8: RUN mvn package -DskipTests                     │
│          → если Layer 7 не из кеша → пересборка          │
│          → используются ОФФЛАЙН-зависимости из Layer 6   │
│          → быстрая компиляция (30-60 секунд)             │
└────────────────────┬────────────────────────────────────┘
                     ▼

┌─────────────────────────────────────────────────────────┐
│ ЭТАП 2: RUNNER                                           │
│                                                          │
│ Layer 1: FROM eclipse-temurin:8-jre-alpine (~80 МБ)     │
│ Layer 2: WORKDIR /app                                    │
│ Layer 3: RUN apk add bash netcat-openbsd                 │
│ Layer 4: COPY --from=builder *.jar (~50 МБ)              │
│ Layer 5: COPY wait-for-it.sh                             │
│ Layer 6: RUN chmod +x                                    │
│ Layer 7: EXPOSE 8087                                     │
│ Layer 8: ENTRYPOINT                                      │
└────────────────────┬────────────────────────────────────┘
                     ▼
              ┌──────────────┐
              │ Финальный    │
              │ образ        │
              │ ~150 МБ      │
              └──────────────┘
```

**Сценарий: сменили только один Java-класс**

```
Без оптимизации (как в booking-service Dockerfile):
  - Скачивание зависимостей: ~5-10 минут
  - Компиляция:               ~30 секунд
  - ИТОГО:                    ~5-10 минут

С оптимизацией (здесь, gateway-service Dockerfile):
  - Скачивание зависимостей: 0 (из кеша)
  - Компиляция:               ~30 секунд
  - ИТОГО:                    ~30 секунд
```

**Это улучшение в 10-20 раз** при итеративной разработке.

---

## 🆚 Сравнение с booking-service Dockerfile

| Аспект | booking-service | gateway-service (этот) |
|--------|-----------------|------------------------|
| **Этап 1 базовый образ** | maven:3.9-eclipse-temurin-11 | то же |
| **MAVEN_OPTS** | 3 флага | 4 флага (+ keepAlive=false) |
| **retryHandler.count** | 10 | 5 |
| **dependency:go-offline** | ❌ нет (плохая кеш-эффективность) | ✅ есть (отличный кеш) |
| **Флаг для тестов** | -Dmaven.test.skip=true | -DskipTests |
| **Этап 2 базовый образ** | eclipse-temurin:8-jre-alpine | то же |
| **Установка bash, nc** | да | да |
| **EXPOSE** | 8080 (legacy bug) | 8087 ✅ правильно |
| **wait-for-it.sh** | скопирован, не используется | скопирован, не используется |
| **ENTRYPOINT** | exec-form, без скрипта | то же |

**gateway-service Dockerfile — улучшенная версия шаблона!**

---

## ⚠️ Один и тот же критический недостаток

### Несоответствие версий Java

```
Builder: JDK 11
Runner:  JRE 8
```

Это **скрытая мина**. Работает только если:
1. В `pom.xml` указано:
   ```xml
   <maven.compiler.source>1.8</maven.compiler.source>
   <maven.compiler.target>1.8</maven.compiler.target>
   ```
2. Spring Boot версии 2.x (которая поддерживает Java 8).
3. Не используются API Java 9+: var, switch expressions, records, sealed classes.

**Если завтра кто-то добавит в код `var x = 10;`** — сборка пройдёт, но контейнер упадёт при запуске:
```
Error: A JNI error has occurred, please check your installation and try again
Exception in thread "main" java.lang.UnsupportedClassVersionError:
  com/example/Gateway has been compiled by a more recent version of the Java Runtime
  (class file version 55.0), this version of the Java Runtime only recognizes class file
  versions up to 52.0
```

**Правильнее**: единая версия Java:
```dockerfile
FROM maven:3.9-eclipse-temurin-11 AS builder
# ...
FROM eclipse-temurin:11-jre-alpine
```

Или, ещё лучше, переход на актуальную LTS:
```dockerfile
FROM maven:3.9-eclipse-temurin-17 AS builder
FROM eclipse-temurin:17-jre-alpine
```

---

## 🗣 Монолог для защиты (~300 символов)

> Это оптимизированный multi-stage Dockerfile для gateway-service. Ключевая особенность — отдельный слой dependency:go-offline для кеширования Maven-зависимостей: изменения только в src не приводят к повторному скачиванию артефактов. MAVEN_OPTS настроены на устойчивость к нестабильной сети. Финальный образ на eclipse-temurin:8-jre-alpine ~150 МБ. EXPOSE 8087 согласован с Spring Boot и k8s.

*(длина ~410 символов, могу сократить до 300)*

---

## 💡 Возможные вопросы на защите

**В1: Зачем `dependency:go-offline` отдельным слоем?**
> Для **максимально эффективного использования Docker layer cache**.
> 
> Docker строит образ по слоям. Каждая инструкция в Dockerfile = отдельный слой. Если содержимое слоя не изменилось — он берётся из кеша.
> 
> Структура моего Dockerfile:
> 1. COPY pom.xml (редко меняется).
> 2. RUN dependency:go-offline (5-10 минут, но кешируется!).
> 3. COPY src (часто меняется).
> 4. RUN package (быстрая компиляция, ~30 сек).
> 
> При изменении только src/:
> - Слои 1-2 берутся из кеша.
> - Слой 3 пересоздаётся.
> - Слой 4 пересоздаётся, но использует офлайн-зависимости из кеша.
> 
> **Итого: сборка вместо 5-10 минут занимает ~30 секунд.**
> 
> Это критично в CI/CD и при локальной разработке.

**В2: Чем отличается `-DskipTests` от `-Dmaven.test.skip=true`?**
> Оба пропускают запуск тестов, но по-разному:
> 
> | Флаг | Компиляция тестов | Запуск тестов |
> |------|-------------------|---------------|
> | `-DskipTests` | ✅ да | ❌ нет |
> | `-Dmaven.test.skip=true` | ❌ нет | ❌ нет |
> 
> **`-DskipTests`** (наш выбор):
> - Тестовые классы компилируются.
> - Если в тесте синтаксическая ошибка (missing import, typo) — сборка упадёт.
> - Это плюс: ловим проблемы тестового кода.
> 
> **`-Dmaven.test.skip=true`** (используется в booking-service Dockerfile):
> - Тесты даже не компилируются.
> - Сборка пройдёт даже если тестовый код сломан.
> - Скрывает деградацию качества кода.
> 
> Я выбрал `-DskipTests` как более безопасный.

**В3: Зачем `-Dhttp.keepAlive=false` в MAVEN_OPTS?**
> Это защита от **корпоративных прокси / NAT-устройств**, которые "режут" долго живущие HTTP-соединения.
> 
> Проблема: Maven открывает keep-alive соединение к Maven Central, качает много файлов один за другим. Прокси может закрыть соединение посередине → Maven получает `Connection reset` → fail.
> 
> С `-Dhttp.keepAlive=false`:
> - Каждый запрос идёт по новому соединению.
> - Прокси не успевает разозлиться.
> - Сборка надёжнее.
> 
> Минус: чуть медленнее (TCP-handshake на каждый запрос).
> 
> Это **пессимистичная настройка** для нестабильной сети. В стабильной среде можно убрать.

**В4: Что такое `httpconnectionManager.ttlSeconds`?**
> TTL (Time To Live) для HTTP-соединений в pool'е Maven Wagon. По умолчанию — бесконечность.
> 
> `ttlSeconds=120` означает: каждое соединение принудительно закрывается через 120 секунд после создания. Затем создаётся новое.
> 
> Зачем:
> - Защита от "залипших" connection'ов (когда сервер думает, что соединение разорвано, а клиент держит).
> - Защита от прокси/NAT, которые таймаутят бездействующие коннекты.
> - Лучшее распределение нагрузки на серверах Maven Central (если они load-balanced).
> 
> Это **тонкая настройка** для production CI/CD. В большинстве случаев не нужна, но не помешает.

**В5: Что произойдёт, если убрать `RUN mvn dependency:go-offline`?**
> Зависимости будут качаться **при каждой сборке**, даже если pom.xml не изменился. Сценарий:
> 
> ```
> 1. Изменили один Java-файл.
> 2. docker build:
>    - COPY pom.xml → кеш ✅
>    - COPY src → пересборка ❌
>    - RUN mvn package → MAVEN ВЕРХ скачивает все зависимости заново!
>    
>    Время: 5-10 минут вместо 30 секунд.
> ```
> 
> Это и есть антипаттерн, который встречается в booking-service Dockerfile.

**В6: Почему `RUN apk add --no-cache`, а не отдельно `apk update && apk add`?**
> Это **best practice для Alpine**:
> 
> Без `--no-cache`:
> ```dockerfile
> RUN apk update         # обновляет индексы → пишет ~3-5 МБ в /var/cache/apk/
> RUN apk add bash       # ставит пакет
> ```
> Индексы пакетов остаются в образе → ненужный bloat.
> 
> С `--no-cache`:
> ```dockerfile
> RUN apk add --no-cache bash   # обновляет индексы in-memory, не пишет на диск
> ```
> Индексы не сохраняются → размер образа меньше.
> 
> Альтернатива (если бы нужно было сохранить индексы):
> ```dockerfile
> RUN apk update && apk add bash && rm -rf /var/cache/apk/*
> ```

**В7: EXPOSE 8087 — что это делает фактически?**
> **Ничего функционально!** EXPOSE — это **документирующая** инструкция, она добавляет метаданные в образ.
> 
> Что НЕ делает EXPOSE:
> - Не открывает порт.
> - Не публикует наружу.
> - Не настраивает firewall.
> 
> Что ДЕЛАЕТ EXPOSE:
> 1. Записывает в `docker inspect <image>` информацию: "этот контейнер слушает 8087".
> 2. `docker run -P` (заглавная P) автоматически публикует все EXPOSE-порты на случайные хост-порты.
> 3. Некоторые инструменты сканирования (Trivy, Snyk) используют это для проверок.
> 
> Реальный порт открывает приложение (Spring Boot `server.port=8087`).
> 
> Так что EXPOSE — это "разработчику видно, что контейнер слушает на 8087", не более того.

**В8: Зачем wait-for-it.sh, если он не используется?**
> Это **legacy** из docker-compose эры. В docker-compose не было встроенного механизма ожидания готовности зависимостей. Скрипт wait-for-it.sh подключается к порту в цикле, пока сервис не отвечает:
> ```bash
> wait-for-it.sh postgres:5432 -- java -jar app.jar
> ```
> 
> В Kubernetes этот подход **устарел**, используются:
> 1. **initContainers**: блокируют старт основного контейнера до выполнения условия.
> 2. **readinessProbe**: k8s не направляет трафик до готовности.
> 3. **livenessProbe**: рестарт зависших подов.
> 
> Скрипт остался в Dockerfile как артефакт. В нашем gateway-service он не нужен — gateway сам ретраит подключения к downstream-сервисам при ошибках.

**В9: Можно ли использовать одну версию Java?**
> Да, и **нужно**! Текущая конфигурация (JDK 11 → JRE 8) — потенциальный bug.
> 
> Сейчас работает, потому что в pom.xml явно установлено:
> ```xml
> <maven.compiler.target>1.8</maven.compiler.target>
> ```
> Maven компилирует в байткод Java 8 → JRE 8 справляется.
> 
> Но если завтра кто-то использует Java 9+ feature (`var`, `Stream.toList()`, records) — сборка пройдёт, контейнер упадёт.
> 
> Правильнее:
> ```dockerfile
> FROM maven:3.9-eclipse-temurin-11 AS builder
> # ...
> FROM eclipse-temurin:11-jre-alpine
> ```
> 
> Ещё лучше — Java 17 LTS (актуальная для 2024-2025):
> ```dockerfile
> FROM maven:3.9-eclipse-temurin-17 AS builder
> # ...
> FROM eclipse-temurin:17-jre-alpine
> ```

**В10: Можно ли запускать контейнер не от root?**
> Да, и **нужно** для production. Сейчас Java-процесс работает под root (default), это security risk.
> 
> Исправление:
> ```dockerfile
> # В runner-этапе:
> RUN addgroup -S spring && adduser -S spring -G spring
> USER spring
> ENTRYPOINT ["java", "-jar", "app.jar"]
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
> Преимущества:
> 1. Принцип least privilege.
> 2. Защита от эскалации привилегий.
> 3. Требование CIS Benchmarks, PCI DSS.

**В11: Что делает `mvn -B` и почему всегда нужно?**
> `-B` (--batch-mode) переводит Maven в режим без интерактивности:
> 
> Без `-B`:
> - Maven показывает прогресс-бары (`[INFO] Downloaded from ...`).
> - В цветном выводе.
> - Может задавать вопросы (например, "Sign artifact? [y/n]").
> 
> С `-B`:
> - Компактный вывод (одна строка на событие).
> - Без цветов (не нужны в CI).
> - Не задаёт вопросов → не виснет.
> 
> Это **обязательный флаг для Docker и CI/CD**. Без него:
> - Логи раздуваются (прогресс-бары печатают тысячи строк).
> - Может зависнуть на вопросе → таймаут сборки.

**В12: Какой следующий шаг в оптимизации образа?**
> Несколько направлений:
> 
> 1. **Spring Boot Layered Jar** (Spring Boot 2.3+):
>    ```xml
>    <plugin>
>      <groupId>org.springframework.boot</groupId>
>      <artifactId>spring-boot-maven-plugin</artifactId>
>      <configuration>
>        <layers><enabled>true</enabled></layers>
>      </configuration>
>    </plugin>
>    ```
>    Затем в Dockerfile:
>    ```dockerfile
>    RUN java -Djarmode=layertools -jar app.jar extract
>    COPY --from=builder /app/dependencies/ ./
>    COPY --from=builder /app/snapshot-dependencies/ ./
>    COPY --from=builder /app/resources/ ./
>    COPY --from=builder /app/application/ ./
>    ```
>    Это разделяет jar на слои: dependencies (редко меняются), application (часто). Docker pull быстрее, потому что качаются только изменённые слои.
> 
> 2. **Custom JRE через jlink**:
>    ```dockerfile
>    RUN jlink \
>      --add-modules java.base,java.logging,java.sql,jdk.unsupported \
>      --output /custom-jre \
>      --strip-debug --no-man-pages --no-header-files --compress=2
>    ```
>    Создаёт минимальный JRE только с нужными модулями. Образ ~50 МБ вместо 150.
> 
> 3. **Distroless**:
>    ```dockerfile
>    FROM gcr.io/distroless/java17-debian12
>    ```
>    Образ без shell, без apt, без curl — только JRE + jar. Минимальный attack surface.
> 
> 4. **GraalVM Native Image**:
>    Компиляция в native binary (~50 МБ), мгновенный старт (10-50 мс vs 5-10 сек у JVM), меньше памяти.

**В13: Почему `retryHandler.count=5`, а в booking-service Dockerfile было 10?**
> Это **компромисс между надёжностью и временем сборки**:
> 
> - **5 попыток**: если 5 раз подряд fail — что-то реально сломано, проще упасть и понять что.
> - **10 попыток**: больше шансов "проскочить" через флаки-сеть, но дольше при настоящих проблемах.
> 
> 5 попыток с retry по экспоненциальному back-off:
> ```
> 1-я попытка: сразу
> 2-я: через ~1 сек
> 3-я: через ~2 сек
> 4-я: через ~4 сек
> 5-я: через ~8 сек
> ИТОГО: до 15 секунд на каждый артефакт
> ```
> 
> 10 попыток = до 1 минуты на артефакт. Если Maven Central реально лежит — это бесполезно.
> 
> 5 — разумный баланс. В booking-service Dockerfile значение 10 — overkill.

**В14: Что произойдёт без `MAVEN_OPTS`?**
> Maven использует дефолтные настройки JVM:
> - HTTP pool включён.
> - keep-alive активен.
> - 3 retry попытки.
> - IPv6 пробуется первым.
> 
> В **стабильной сети** всё работает отлично.
> 
> В **нестабильной сети** (учебная среда, корпоративный прокси):
> - Зависания на ~30 сек из-за IPv6 timeout.
> - `Connection reset` при долгих скачиваниях.
> - Только 3 retry — может не хватить.
> - Сборка падает с непонятными ошибками.
> 
> Наши MAVEN_OPTS делают Maven **более устойчивым** ценой небольшого замедления.

Если по какой-то строке хочется глубже — спрашивай 🚀