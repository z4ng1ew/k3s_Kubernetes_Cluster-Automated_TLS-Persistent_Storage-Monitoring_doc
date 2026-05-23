#!/bin/bash


set -e  


EXPECTED_DBS=(
    "users_db"
    "hotels_db"
    "reservations_db"
    "payments_db"
    "balances_db"
    "statistics_db"
)


echo "[init-check] Проверка списка созданных баз данных..."


ACTUAL_DBS=$(psql -U "$POSTGRES_USER" -d postgres -tAc "SELECT datname FROM pg_database WHERE datistemplate = false;")

echo "[init-check] Найдены базы данных:"
echo "$ACTUAL_DBS" | sed 's/^/  - /'

echo "[init-check] Проверяем наличие требуемых БД..."
for db in "${EXPECTED_DBS[@]}"; do
    if echo "$ACTUAL_DBS" | grep -qx "$db"; then
        echo "  [OK]    $db"
    else
        echo "  [FAIL]  $db — НЕ НАЙДЕНА!"
        exit 1
    fi
done


echo "[init-check] Все 6 баз данных созданы успешно."



















# 📝 Построчный разбор init-check.sh

## 🔍 Полный комментарий по каждой строке

```bash
#!/bin/bash
# Shebang — указывает интерпретатор для запуска скрипта.
# /bin/bash — путь к bash (не sh!).
# Использование bash оправдано, потому что в скрипте есть
# bash-specific конструкции:
#  - Массивы: EXPECTED_DBS=(...)
#  - [[ ]] вместо [ ]
#  - Подстановка ${arr[@]}
# В чистом sh (POSIX) этого нет.
#
# ⚠️ Поэтому в Dockerfile была команда:
#   RUN apk add --no-cache bash
# Без неё скрипт не запустится в Alpine.


set -e
# Опция bash: "exit on error".
# При первой неудачной команде (с exit code != 0) скрипт
# немедленно завершается с тем же кодом возврата.
#
# Без set -e:
#   command_that_fails
#   echo "Это выполнится несмотря на ошибку"  ← плохо!
#
# С set -e:
#   command_that_fails
#   echo "Это НЕ выполнится"  ← правильно
#
# Это fail-fast подход: лучше сразу упасть с ошибкой, чем
# продолжать выполнение в неконсистентном состоянии.
#
# В контексте Docker:
#  - Если init-check.sh упал → entrypoint вернёт non-zero.
#  - Контейнер пометится как failed.
#  - В k8s pod уйдёт в CrashLoopBackOff.
#  - Это сигнал, что инициализация прошла НЕ полностью.
#
# Альтернативы:
#  set -u  — fail при использовании неинициализированной переменной.
#  set -o pipefail — fail если любая команда в пайпе упала.
#  set -euo pipefail — все три сразу (best practice).


EXPECTED_DBS=(
    "users_db"
    "hotels_db"
    "reservations_db"
    "payments_db"
    "balances_db"
    "statistics_db"
)
# Bash-массив — список ожидаемых БД, которые должны быть
# созданы скриптом 01-init.sql.
#
# Синтаксис: var=("a" "b" "c")
# Доступ: ${var[0]}, ${var[1]}, ...
# Все элементы: ${var[@]}
# Длина: ${#var[@]}
#
# Это "источник истины" для валидации.
# Должен совпадать с CREATE DATABASE в 01-init.sql.
#
# Соответствие БД ↔ микросервис:
#  users_db        ← session-service  (POSTGRES_DB: users_db)
#  hotels_db       ← hotel-service    (POSTGRES_DB: hotels_db)
#  reservations_db ← booking-service  (POSTGRES_DB: reservations_db)
#  payments_db     ← payment-service  (POSTGRES_DB: payments_db)
#  balances_db     ← loyalty-service  (POSTGRES_DB: balances_db)
#  statistics_db   ← report-service   (POSTGRES_DB: statistics_db)


echo "[init-check] Проверка списка созданных баз данных..."
# Логирование начала проверки.
# Префикс [init-check] — для идентификации логов в выводе
# контейнера (рядом с логами PostgreSQL и других скриптов).
#
# Пример общего вывода контейнера:
#   ...
#   PostgreSQL init process complete; ready for start up.
#   [init-check] Проверка списка созданных баз данных...
#   ...


ACTUAL_DBS=$(psql -U "$POSTGRES_USER" -d postgres -tAc "SELECT datname FROM pg_database WHERE datistemplate = false;")
# Получение реального списка БД через psql.
#
# Разбор:
#  $(...) — command substitution: выполняет команду и подставляет вывод.
#
#  psql — клиент PostgreSQL для выполнения SQL-команд.
#
#  -U "$POSTGRES_USER":
#       Пользователь для подключения.
#       $POSTGRES_USER — переменная окружения из Dockerfile:
#         ENV POSTGRES_USER=postgres
#       Кавычки вокруг переменной — защита от пробелов в имени.
#
#  -d postgres:
#       Подключаемся к системной БД "postgres".
#       Эта БД создаётся автоматически при initdb.
#       Из неё можно запрашивать метаданные обо всех БД.
#
#  -t (tuples only):
#       Только данные, БЕЗ заголовков столбцов и итоговой
#       информации ("(N rows)"). Чистый список значений.
#
#  -A (unaligned):
#       Без выравнивания пробелами и табами. Компактный вывод.
#       Удобно для парсинга в shell.
#
#  -c "SQL":
#       Выполнить одну SQL-команду и выйти.
#       Альтернатива: -f file.sql для запуска скрипта.
#
#  SQL:
#       SELECT datname FROM pg_database WHERE datistemplate = false;
#       pg_database — системная таблица с инфой обо всех БД.
#       datname — имя БД.
#       datistemplate = false — исключить шаблонные БД (template0, template1).
#       Иначе в выводе были бы:
#         postgres
#         template0   ← мусор
#         template1   ← мусор
#         users_db
#         ...
#
# Результат: переменная ACTUAL_DBS содержит multi-line строку:
#   postgres
#   users_db
#   hotels_db
#   reservations_db
#   payments_db
#   balances_db
#   statistics_db


echo "[init-check] Найдены базы данных:"
echo "$ACTUAL_DBS" | sed 's/^/  - /'
# Красивый вывод найденных БД.
#
# echo "$ACTUAL_DBS" — печатает содержимое переменной.
# | — пайп: stdout одной команды → stdin следующей.
# sed 's/^/  - /' — добавляет "  - " в начало каждой строки.
#
# Разбор sed:
#  s/PATTERN/REPLACEMENT/  — команда substitute.
#  ^                       — начало строки (regex).
#  "  - "                  — что вставить (два пробела + дефис).
#
# Результат:
#   - postgres
#   - users_db
#   - hotels_db
#   - reservations_db
#   - payments_db
#   - balances_db
#   - statistics_db


echo "[init-check] Проверяем наличие требуемых БД..."
# Логирование начала валидации.


for db in "${EXPECTED_DBS[@]}"; do
    # Цикл по элементам массива EXPECTED_DBS.
    #
    # Разбор:
    #  for VAR in LIST; do ... done — синтаксис цикла bash.
    #  "${EXPECTED_DBS[@]}" — все элементы массива КАК ОТДЕЛЬНЫЕ
    #                        слова. Это критично!
    #
    # ⚠️ ВАЖНО! Различие:
    #  ${EXPECTED_DBS[@]}   — слова (с word splitting).
    #  "${EXPECTED_DBS[@]}" — слова, но защищены от word splitting.
    #  ${EXPECTED_DBS[*]}   — одна строка через IFS.
    #
    # Без кавычек элементы с пробелами разбились бы на части.
    # У нас имена БД без пробелов, но привычка использовать
    # кавычки — best practice.

    if echo "$ACTUAL_DBS" | grep -qx "$db"; then
        # Проверка наличия БД в выводе.
        #
        # Разбор:
        #  echo "$ACTUAL_DBS" — отдаём содержимое переменной.
        #  | grep -qx "$db"   — ищем имя БД в выводе.
        #
        # Флаги grep:
        #  -q (quiet):
        #       Не выводить совпадения. Только exit code:
        #         0 — найдено.
        #         1 — не найдено.
        #         2 — ошибка.
        #       Используется в if для проверки наличия.
        #
        #  -x (exact line match):
        #       Совпадение должно быть на ВСЮ строку.
        #       Без -x:
        #         grep "user" найдёт и "user_db", и "users_db".
        #       С -x:
        #         grep -x "users_db" найдёт ТОЛЬКО строку "users_db".
        #       Защита от ложных срабатываний.
        #
        # if команда; then ... fi — стандартный условный оператор.
        # Условие истинно, если команда вернула 0.

        echo "  [OK]    $db"
        # Печатаем подтверждение, что БД есть.

    else
        echo "  [FAIL]  $db — НЕ НАЙДЕНА!"
        # БД отсутствует в выводе → ошибка.

        exit 1
        # Завершение скрипта с кодом 1 (failure).
        #
        # ⚠️ Это критично! При exit 1:
        # 1. Скрипт прерывается на первой проблемной БД.
        # 2. Дальнейшие БД не проверяются (не нужно).
        # 3. docker-entrypoint.sh видит non-zero exit.
        # 4. Контейнер не стартует, помечается failed.
        # 5. В k8s pod уходит в CrashLoopBackOff.
        # 6. Логи показывают конкретную проблему.
        #
        # Это fail-fast подход. Лучше упасть с понятной
        # ошибкой, чем продолжать с битой инициализацией.
    fi
done
# Конец цикла.


echo "[init-check] Все 6 баз данных созданы успешно."
# Финальное подтверждение.
# Если мы дошли до этой строки — все проверки прошли,
# все 6 БД присутствуют.
#
# Скрипт завершается с exit code 0 (по умолчанию для bash).
# docker-entrypoint.sh продолжает работу, запускает основной
# процесс PostgreSQL.
```

---

## 🔗 Когда этот скрипт выполняется

```
┌─────────────────────────────────────────────────────────┐
│ k8s создаёт Pod postgres из образа src-postgres:latest  │
└────────────────────┬────────────────────────────────────┘
                     ▼

┌─────────────────────────────────────────────────────────┐
│ ENTRYPOINT базового образа: docker-entrypoint.sh        │
└────────────────────┬────────────────────────────────────┘
                     ▼

┌─────────────────────────────────────────────────────────┐
│ PGDATA пустой?                                           │
│                                                          │
│  ┌─── Да ────┐                                          │
│  ▼           ▼                                          │
│  initdb      Нет — пропустить init                      │
│  ↓                                                       │
│  Создан пользователь postgres                           │
│  Создана БД postgres                                    │
└────────────────────┬────────────────────────────────────┘
                     ▼ (только при первом запуске)

┌─────────────────────────────────────────────────────────┐
│ Выполнение скриптов /docker-entrypoint-initdb.d/         │
│ в алфавитном порядке                                     │
└────────────────────┬────────────────────────────────────┘
                     │
                     ▼
       ┌──────────────────────────────────────┐
       │ 1️⃣ 01-init.sql                       │
       │                                      │
       │ psql выполняет SQL-команды:          │
       │   CREATE DATABASE users_db;          │
       │   CREATE DATABASE hotels_db;         │
       │   CREATE DATABASE reservations_db;   │
       │   CREATE DATABASE payments_db;       │
       │   CREATE DATABASE balances_db;       │
       │   CREATE DATABASE statistics_db;     │
       └──────────────┬───────────────────────┘
                      ▼
       ┌──────────────────────────────────────┐
       │ 2️⃣ 02-init-check.sh ← НАШ СКРИПТ!    │
       │                                      │
       │ Проверяет, что все БД созданы.       │
       │ Если что-то не так → exit 1.         │
       └──────────────┬───────────────────────┘
                      ▼

┌─────────────────────────────────────────────────────────┐
│ Все скрипты завершились успешно                          │
└────────────────────┬────────────────────────────────────┘
                     ▼

┌─────────────────────────────────────────────────────────┐
│ Запуск основного процесса postgres                       │
│ PostgreSQL начинает слушать на 5432                      │
└─────────────────────────────────────────────────────────┘
```

---

## 🎯 Что произойдёт в разных сценариях

### Сценарий 1: Всё хорошо

```
[init-check] Проверка списка созданных баз данных...
[init-check] Найдены базы данных:
  - postgres
  - users_db
  - hotels_db
  - reservations_db
  - payments_db
  - balances_db
  - statistics_db
[init-check] Проверяем наличие требуемых БД...
  [OK]    users_db
  [OK]    hotels_db
  [OK]    reservations_db
  [OK]    payments_db
  [OK]    balances_db
  [OK]    statistics_db
[init-check] Все 6 баз данных созданы успешно.

→ exit 0
→ docker-entrypoint.sh продолжает
→ PostgreSQL запускается
→ Pod в статусе Running
```

### Сценарий 2: Одна БД не создалась

```
[init-check] Проверка списка созданных баз данных...
[init-check] Найдены базы данных:
  - postgres
  - users_db
  - hotels_db
  - reservations_db
  - payments_db
  - balances_db
  (statistics_db отсутствует — например, ошибка в 01-init.sql)
[init-check] Проверяем наличие требуемых БД...
  [OK]    users_db
  [OK]    hotels_db
  [OK]    reservations_db
  [OK]    payments_db
  [OK]    balances_db
  [FAIL]  statistics_db — НЕ НАЙДЕНА!

→ exit 1
→ docker-entrypoint.sh видит non-zero exit
→ Контейнер падает
→ В k8s: CrashLoopBackOff
→ kubectl logs pod/postgres-xxx покажет [FAIL] статистика
→ Админ сразу видит проблему
```

### Сценарий 3: PostgreSQL недоступен во время проверки

```
[init-check] Проверка списка созданных баз данных...
psql: error: connection to server ... failed: ...

→ set -e срабатывает на ошибке psql
→ exit с кодом psql (обычно 2)
→ Контейнер падает
```

---

## ⚠️ Тонкие моменты bash

### 1. `set -e` не покрывает всё

```bash
set -e
false           # ← скрипт упадёт
echo "after"    # ← не выполнится
```

Но:
```bash
set -e
false || true   # ← НЕ упадёт (false вошло в || цепочку)
echo "after"    # ← выполнится

if false; then  # ← НЕ упадёт (false в условии if)
  ...
fi
```

В нашем скрипте `if grep ... ` — это допустимо, потому что бессмыслено падать при первом отсутствии БД (мы хотим узнать, что именно отсутствует).

### 2. Различие `[@]` vs `[*]`

```bash
arr=("a b" "c d")

echo "${arr[@]}"   # → "a b" "c d"  (два слова)
echo "${arr[*]}"   # → "a b c d"     (одна строка через IFS)
```

В for-цикле всегда `[@]` — каждый элемент отдельно.

### 3. Кавычки вокруг переменных

```bash
db="my db"
grep -qx $db    # ← плохо: grep -qx my db (два аргумента)
grep -qx "$db"  # ← хорошо: grep -qx "my db"
```

Защита от пробелов и спец. символов — best practice.

### 4. `grep -x` vs обычный grep

```bash
echo -e "user\nusers_db" | grep "user"     # → находит ОБА (user и users_db)
echo -e "user\nusers_db" | grep -x "user"  # → находит ТОЛЬКО "user"
```

Critical для нашего случая: без `-x` имя `user_db` нашлось бы в `users_db`.

---

## 🗣 Монолог для защиты (~300 символов)

> Это валидационный скрипт, который запускается после 01-init.sql и проверяет, что все 6 баз данных для микросервисов созданы. Через psql получает список БД из pg_database (исключая шаблонные), затем перебирает массив EXPECTED_DBS и для каждой проверяет наличие через grep -qx. При отсутствии любой БД — exit 1, контейнер не стартует, в k8s pod уходит в CrashLoopBackOff. Fail-fast стратегия с set -e.

*(длина ~430 символов, могу сократить до 300)*

---

## 💡 Возможные вопросы на защите

**В1: Зачем нужна валидация, если init.sql и так должен работать?**
> Чтобы поймать **скрытые ошибки** инициализации:
> 
> 1. **Опечатки в init.sql**: например, `CREATE DATABSE` вместо `CREATE DATABASE`. Без валидации скрипт молча пропустит ошибку (если нет `ON_ERROR_STOP`).
> 
> 2. **Конфликт имён**: если в init.sql два раза CREATE DATABASE с одинаковым именем — первый создаст, второй упадёт, но если без ON_ERROR_STOP — продолжит.
> 
> 3. **Изменения init.sql не применены**: при обновлении кода и забытом обновлении init.sql валидация быстро укажет на расхождение.
> 
> 4. **Документация as code**: массив EXPECTED_DBS — это явный список того, что должно быть. Любой разработчик сразу видит, какие БД нужны.
> 
> 5. **Fail-fast**: проблема в БД проявится при попытке микросервиса подключиться к несуществующей БД через несколько минут. Лучше упасть сразу при инициализации.

**В2: Что такое `set -e` и почему оно важно в этом скрипте?**
> `set -e` (errexit) заставляет bash **немедленно завершать скрипт** при первой неудачной команде (exit code != 0).
> 
> Без `set -e`:
> ```bash
> psql -U postgres -c "SELECT ... "   # ← упало с ошибкой
> echo "Это всё равно выполнится"     # ← bad
> exit 0                              # ← скрипт "успешно завершён"
> ```
> Результат: контейнер стартует, но БД не валидирована.
> 
> С `set -e`:
> ```bash
> psql -U postgres -c "SELECT ... "   # ← упало с ошибкой
> # дальше скрипт прерван
> ```
> 
> Это fail-fast: контейнер не стартует, проблема видна сразу.
> 
> Best practice — комбинация:
> ```bash
> set -euo pipefail
> ```
> - `-e`: exit at error
> - `-u`: error при использовании unset переменной (защита от typos)
> - `-o pipefail`: pipeline fails if любая команда в нём упала

**В3: Почему `grep -qx`, а не просто `grep`?**
> Каждый флаг важен:
> 
> **`-q` (quiet)**: подавляет вывод. grep возвращает только exit code (0 — найдено, 1 — нет). Идеально для использования в `if`.
> 
> **`-x` (exact line)**: требует совпадения на **всю строку**, не подстроку.
> 
> Без `-x`:
> ```bash
> echo "users_db" | grep -q "user_db"
> # → нашёл бы! (user_db есть подстрока users_db)
> # exit 0 → ложное срабатывание
> ```
> 
> С `-x`:
> ```bash
> echo "users_db" | grep -qx "user_db"
> # → не нашёл (нужно точное совпадение строки)
> # exit 1 → корректное поведение
> ```
> 
> Без `-x` скрипт пропустил бы баг, когда вместо `users_db` создана `user_db`.

**В4: Почему `psql -tAc`, что значат флаги?**
> Три флага для **компактного, парсимого вывода**:
> 
> **`-t`** (tuples only):
> Без `-t`:
> ```
>  datname
> ---------
>  postgres
>  users_db
> (2 rows)
> ```
> С `-t`:
> ```
>  postgres
>  users_db
> ```
> Убраны заголовки и итоговая строка.
> 
> **`-A`** (unaligned):
> Без `-A`:
> ```
>           datname
> -------------------------
>  postgres
>  users_db
> ```
> С `-A`:
> ```
> postgres
> users_db
> ```
> Без выравнивания пробелами/табами. Компактнее.
> 
> **`-c "SQL"`** (command):
> Выполнить одну SQL-команду и выйти. Альтернатива `-f script.sql`.
> 
> Комбинация `-tAc` — стандарт для shell-парсинга вывода psql.

**В5: Что такое `datistemplate` и зачем фильтровать?**
> `datistemplate` — поле в системной таблице `pg_database`, флаг "является ли БД шаблоном".
> 
> Шаблонные БД в PostgreSQL:
> - **template0**: чистая системная БД, неизменяемая. Используется для создания новых БД с разными locales.
> - **template1**: дефолтный шаблон. При `CREATE DATABASE foo` копируется из template1.
> 
> Без фильтра `datistemplate = false`:
> ```
> postgres
> template0   ← это не реальная БД, шаблон
> template1   ← тоже шаблон
> users_db
> ...
> ```
> 
> С фильтром:
> ```
> postgres
> users_db
> ...
> ```
> 
> Логически шаблоны не должны попадать в проверку — мы хотим знать про **реальные** БД.

**В6: Почему массив, а не просто список через запятую?**
> Bash-массив — это **type-safe структура** для списка строк:
> 
> ```bash
> EXPECTED_DBS=("users_db" "hotels_db" ...)
> ```
> 
> Преимущества vs строка:
> 1. **Элементы изолированы**: `${EXPECTED_DBS[@]}` — каждый отдельно. Защита от пробелов в именах.
> 2. **Длина**: `${#EXPECTED_DBS[@]}` — узнать количество.
> 3. **Доступ по индексу**: `${EXPECTED_DBS[0]}`.
> 4. **Удобство добавления**: новая строка → новый элемент.
> 
> Альтернатива через строку:
> ```bash
> EXPECTED_DBS="users_db hotels_db ..."
> for db in $EXPECTED_DBS; do  # ← word splitting, рисковано
> ```
> 
> Bash-массив — современный, надёжный подход.

**В7: Что произойдёт при `exit 1` внутри Docker-контейнера?**
> Цепочка событий:
> 
> 1. `exit 1` завершает наш скрипт `02-init-check.sh` с кодом 1.
> 2. Docker-entrypoint.sh видит non-zero exit от init-скрипта.
> 3. Согласно логике entrypoint, **дальнейшие init-скрипты НЕ выполняются**.
> 4. Контейнер завершается с тем же exit code.
> 5. В Docker: контейнер помечается как failed (Exit Status: 1).
> 6. В k8s:
>    - kubelet видит, что под завершился с ошибкой.
>    - По default restart policy `Always` — пробует перезапустить.
>    - Если init опять упадёт → CrashLoopBackOff.
>    - С каждой попыткой задержка увеличивается экспоненциально: 10s → 20s → 40s → 80s → 160s → 300s.
> 7. `kubectl describe pod` покажет: "Back-off restarting failed container".
> 8. `kubectl logs pod/postgres-xxx` покажет наш [FAIL] вывод.

**В8: Можно ли вместо grep использовать массивы bash?**
> Да, и это может быть чище:
> 
> ```bash
> # Получить список БД в массив
> mapfile -t ACTUAL_DBS < <(psql -U "$POSTGRES_USER" -d postgres -tAc \
>   "SELECT datname FROM pg_database WHERE datistemplate = false;")
> 
> # Функция проверки наличия в массиве
> contains() {
>   local needle="$1"
>   shift
>   for item in "$@"; do
>     [[ "$item" == "$needle" ]] && return 0
>   done
>   return 1
> }
> 
> # Проверка
> for db in "${EXPECTED_DBS[@]}"; do
>   if contains "$db" "${ACTUAL_DBS[@]}"; then
>     echo "[OK] $db"
>   else
>     echo "[FAIL] $db"
>     exit 1
>   fi
> done
> ```
> 
> Преимущества:
> 1. Чисто bash, без зависимости от grep.
> 2. Понятнее для bash-разработчика.
> 3. Не зависит от форматирования (трейлинг whitespace и т.д.).
> 
> Текущий подход с grep тоже корректен и работает.

**В9: Что если PostgreSQL не успел запуститься к моменту проверки?**
> В контексте `docker-entrypoint-initdb.d/`:
> 
> 1. Перед запуском init-скриптов, docker-entrypoint.sh **запускает PostgreSQL** на временном Unix-сокете (не на TCP).
> 2. Скрипты выполняются с подключением к этому сокету через psql.
> 3. **PostgreSQL гарантированно доступен** во время выполнения init-скриптов.
> 
> Это часть конвенции официального образа. Поэтому наш `psql -U postgres` без `-h hostname` корректно работает — он подключается через сокет автоматически.
> 
> После завершения всех init-скриптов:
> - Временный сокет закрывается.
> - PostgreSQL перезапускается на TCP-порту 5432.
> - Готов принимать внешние коннекты.

**В10: Что если в init.sql добавили 7-ю БД, а в EXPECTED_DBS нет?**
> Сценарий: разработчик добавил `CREATE DATABASE new_service_db;` в init.sql, но забыл обновить EXPECTED_DBS.
> 
> Поведение скрипта:
> 1. БД создаётся в 01-init.sql.
> 2. 02-init-check.sh запускается.
> 3. Перебирает 6 элементов EXPECTED_DBS, все находит.
> 4. **Скрипт проходит успешно** — ничего не сломалось.
> 
> Но проблема в том, что **скрипт не сообщает о "лишних" БД**. Это:
> - Не баг (БД создана корректно).
> - Может скрыть проблему: если БД создана случайно (опечатка в init.sql типа `CREATE DATABASE users_dbb`) — никто не заметит.
> 
> Улучшение: добавить проверку "no unexpected databases":
> ```bash
> # Сравнить ACTUAL_DBS с EXPECTED_DBS + postgres + template*
> # Если есть лишние — warning или fail.
> ```
> 
> Это **strict mode** для параноидальной валидации.

**В11: Безопасно ли использовать переменные среды напрямую?**
> Частично. В нашем скрипте:
> ```bash
> psql -U "$POSTGRES_USER" -d postgres -tAc "SELECT ..."
> ```
> 
> Возможные риски:
> 
> 1. **Unset variable**: если `$POSTGRES_USER` не задана:
>    - Без `set -u`: `psql -U "" -d postgres ...` → ошибка, но запутанная.
>    - С `set -u`: четкая ошибка "unbound variable".
> 
> 2. **Injection через SQL**: если переменная содержит ` "; DROP DATABASE ...; --`:
>    - В нашем случае `$POSTGRES_USER` не попадает в SQL-строку (только в `-U` аргумент psql).
>    - Безопасно.
> 
> 3. **Injection в shell**: если переменная содержит `$(rm -rf /)`:
>    - Кавычки `"$POSTGRES_USER"` защищают от word splitting.
>    - Но не от command substitution в double quotes.
>    - В нашем контексте (Docker, env из ConfigMap) — практически нет риска.
> 
> Best practice: всегда кавычки + `set -u` + проверка переменных:
> ```bash
> : "${POSTGRES_USER:?POSTGRES_USER not set}"
> ```

**В12: Можно ли запускать этот скрипт повторно?**
> Технически — да, это **идемпотентный** скрипт:
> - Не модифицирует данные.
> - Только читает и проверяет.
> - Повторный запуск даст тот же результат.
> 
> Но в контексте docker-entrypoint-initdb.d:
> - Скрипт запускается **только при первом старте** контейнера (когда PGDATA пустой).
> - При следующих стартах /docker-entrypoint-initdb.d/* игнорируется.
> 
> Если хочется запускать каждый раз, скрипт нужно переместить из init.d в:
> - `CMD` или `ENTRYPOINT` (но это сломает стандартный postgres-entrypoint).
> - Отдельный k8s Job с зависимостью от postgres.
> - **livenessProbe** / **readinessProbe** — проверка при каждом polling.

**В13: Как улучшить этот скрипт?**
> Несколько направлений:
> 
> 1. **Strict mode**:
> ```bash
> set -euo pipefail
> IFS=$'\n\t'
> ```
> 
> 2. **Цветной вывод**:
> ```bash
> GREEN='\033[0;32m'
> RED='\033[0;31m'
> NC='\033[0m'  # No Color
> echo -e "${GREEN}[OK]${NC} $db"
> ```
> 
> 3. **Проверка таблиц, не только БД**:
> ```bash
> # Проверить, что миграции применились
> psql -U postgres -d users_db -c "SELECT COUNT(*) FROM users;"
> ```
> 
> 4. **Параллельная проверка** (если БД много):
> ```bash
> for db in "${EXPECTED_DBS[@]}"; do
>   check_db "$db" &
> done
> wait
> ```
> 
> 5. **JSON-вывод для интеграции с мониторингом**:
> ```bash
> echo '{"check": "init", "status": "ok", "databases": [...]}'
> ```
> 
> 6. **Retry logic** на случай временных проблем psql:
> ```bash
> for i in 1 2 3; do
>   ACTUAL_DBS=$(psql ...) && break
>   sleep 2
> done
> ```

**В14: Что произойдёт, если убрать `-q` из grep?**
> grep по умолчанию **печатает совпадения в stdout**.
> 
> Без `-q`:
> ```bash
> if echo "$ACTUAL_DBS" | grep -x "$db"; then
>   echo "  [OK]    $db"
> fi
> ```
> 
> Вывод будет:
> ```
> users_db          ← это grep напечатал
>   [OK]    users_db
> hotels_db         ← это grep напечатал
>   [OK]    hotels_db
> ...
> ```
> 
> Дублирование вывода. `-q` это подавляет — оставляется только наш кастомный `[OK]` вывод. Чистота логов.

**В15: Может ли `psql` зависнуть и блокировать скрипт?**
> Теоретически — да, если PostgreSQL не отвечает (deadlock, OOM).
> 
> Защита через timeout:
> ```bash
> ACTUAL_DBS=$(timeout 10 psql -U "$POSTGRES_USER" -d postgres -tAc "SELECT ...")
> ```
> 
> Если psql не завершится за 10 секунд — `timeout` его убьёт с кодом 124.
> 
> В нашем скрипте этого нет, и в контексте init-фазы это норма: PostgreSQL только что инициализирован, всё свежее, проблем быть не должно. Но в production-сценариях добавить timeout — best practice.

Если по какой-то строке хочется глубже — спрашивай 🚀