## Part 0. ПОДГОТОВКА. Создание трёх виртуальных машин







> Для задания нужны именно ВМ, а не Docker-контейнеры. Самый простой способ на Ubuntu — Multipass (это утилита от Canonical, она создаёт лёгкие Ubuntu-ВМ через KVM в пару команд).

> Multipass по умолчанию использует QEMU/KVM на Linux — это значит, что ВМ будут запускаться через аппаратную виртуализацию, без оверхеда (overhead — накладные расходы) на эмуляцию.

![alt text](img/1/image.png)




**Создаём три ВМ**

![alt text](<img/1/image copy.png>)

**# Мастер-узел: 2 ядра, 2 ГБ ОЗУ, 15 ГБ диска**

**# Первый воркер**

**# Второй воркер**





![alt text](<img/1/image copy 2.png>)

**Проверка, что все три ВМ поднялись**





























## Part 1.  Установка k3s *

## 1) Отчет содержит список команд для установки дистрибутива Kubernetes k3s на трех удаленных виртуальных машинах. *





![alt text](<img/1/image copy 3.png>)

**Заходим в ВМ мастера:**






![alt text](<img/1/image copy 4.png>)

**Ставим k3s без Traefik (по заданию)**

- Что делает эта команда:

    1) curl -sfL — скачивает скрипт установки (-s тихо, -f падать при ошибке, -L следовать редиректам)
    2) sh -s - — выполнить скачанное через bash и передать дальше аргументы
    3) --disable=traefik — не ставить Traefik (мы поставим Nginx позже)
    4) --write-kubeconfig-mode 644 — сделать kubeconfig (файл с настройками доступа к кластеру) читаемым обычным пользователем, иначе придётся каждый раз через sudo
















**IP мастера**


```
s@Vivo:~/DO-11$ MASTER_IP=$(multipass info k3s-master | grep IPv4 | awk '{print $2}')
echo $MASTER_IP
10.174.8.95
```


**Токен для подключения воркеров**

```
ubuntu@k3s-master:~$ sudo cat /var/lib/rancher/k3s/server/node-token
K102a0844657ffcb3fa8e62ae92a742a9124d6b274346696ea625e70efa10ee391a::server:0d0768b3a3f9e758aec953c04b3e26d9
```

















**На воркерах**

- Заходим на первый воркер:

- Запускаем установку k3s в режиме агента (воркера). 

- Подставляем IP мастера и токен:










**Команда для установки k3s в режиме агента (воркера)**

```
curl -sfL https://get.k3s.io | K3S_URL=https://10.174.8.95:6443 K3S_TOKEN=K102a0844657ffcb3fa8e62ae92a742a9124d6b274346696ea625e70efa10ee391a::server:0d0768b3a3f9e758aec953c04b3e26d9 sh -
```




**worker1**

![alt text](<img/1/image copy 6.png>)


**worker2**

![alt text](<img/1/image copy 7.png>)



- Здесь:

    - K3S_URL — адрес API-сервера мастера (порт 6443 — стандартный для Kubernetes API)
    - K3S_TOKEN — тот самый токен, который мы получили на мастере
    - Когда указаны эти переменные, скрипт ставит k3s в режиме агента, а не сервера












1) МАСТЕР (первый узел):
   - команда БЕЗ K3S_URL и K3S_TOKEN
   - запускается как "сервер"
   - создаёт кластер

2) ВОРКЕР (следующие узлы):
   - команда С K3S_URL и K3S_TOKEN
   - запускается как "агент"
   - подключается к существующему кластеру




>  А можно ли установить k3s на воркере так же, как на мастере?

>  Технически — да, но это будет ошибка.

> - Установится k3s в режиме сервера
> - Он создаст свой собственный кластер на этом узле
> - Этот узел не подключится к твоему мастеру
> - В итоге: у будет 1 мастер + 2 изолированных сервера, которые не работают вместе






















## 2) Обратите внимание, что Kubernetes не содержит стандартный контроллер Ingress Traefik. *



**Проверка**

![alt text](<img/1/image copy 8.png>)

**Со всеми тремя узлами в Ready.**


![alt text](<img/1/image copy 9.png>)

**Все системные поды (CoreDNS, metrics-server, local-path-provisioner). Главное — там не должно быть Traefik, потому что я его отключил.**

**Traefik действительно отключён, как требует задание!**






<br>




**Настройка kubectl на хосте**

- Чтобы не заходить каждый раз в ВМ мастера, скопировал kubeconfig на свой хост:

**kubectl get nodes**

![alt text](<img/1/image copy 10.png>)

















<br>
<br>
<br>





## Part  2. Настройка контроллера Ingress


## 1) Контроллер Ingress на основе nginx настраивается в кластере. *


> В k3s по умолчанию работает встроенный ServiceLB (раньше назывался klipper-lb) — это упрощённый балансировщик нагрузки (LoadBalancer), который выдаёт сервисам типа LoadBalancer IP-адреса самих нод кластера. Поэтому MetalLB ставить не нужно — Nginx Ingress сразу получит внешний IP.

**Задача: Установка Nginx Ingress Controller**

**Шаг 1: Применяем официальный манифест**


![alt text](<img/1/image copy 11.png>)



- Что именно делает этот манифест:

    1) Создаёт неймспейс (namespace — изолированное пространство имён в Kubernetes) ingress-nginx
    2) Создаёт Deployment — описание того, как разворачивать поды контроллера (сколько реплик, какой образ и т.д.)
    3) Создаёт Service типа LoadBalancer — точку входа в кластер. Именно его подхватит ServiceLB.
    4) Создаёт IngressClass с именем nginx — это «маркер», по которому потом наши Ingress-ресурсы поймут, какой контроллер их должен обрабатывать.
    5) Создаёт ServiceAccount, ClusterRole, ClusterRoleBinding — права доступа контроллера к API Kubernetes (он должен видеть все Ingress-ресурсы в кластере).
    6) Создаёт ValidatingWebhookConfiguration — это «проверяющий хук», он не пропускает в кластер некорректные Ingress-манифесты ещё до того, как они попадут в etcd.


> «Cloud» в URL — потому что версия cloud рассчитана на то, что в кластере есть LoadBalancer-провайдер (а у нас он есть благодаря ServiceLB k3s). Есть ещё версия baremetal — она ставит Service типа NodePort, но нам это менее удобно для дальнейших шагов с доменом.






LoadBalancer (Service) -  L4 (сеть) - Открывает внешний IP:порт → передаёт трафик в кластер

Ingress Controller     -  L7 (HTTP) - Читает домен/путь → направляет к нужному сервису



![alt text](<img/1/image copy 12.png>)

**Поды Nginx Ingress - контроллер Running**

**Сервис Nginx Ingress с EXTERNAL-IP - виден EXTERNAL-IP - 10.174.8.91**


![alt text](<img/1/image copy 13.png>)

> Должен ответить HTTP/1.1 404 Not Found с заголовком Server: nginx. 404 — это нормально, мы пока не создали ни одного Ingress-ресурса, поэтому Nginx не знает, куда направлять запрос. Главное — что отвечает именно nginx, а не «connection refused».




















nip.io — это публичная DNS-служба-фокусница. Любое имя вида <IP>.nip.io сам сервис автоматически разрешает (resolves — превращает имя в IP) в тот самый IP, что в начале имени. То есть 10.174.8.95.nip.io → 10.174.8.95. Поддомены тоже работают: app.10.174.8.95.nip.io → тот же 10.174.8.95. Нам не нужно ничего регистрировать, настраивать DNS-записи или платить. Это даёт нам «как будто домен» для учебных целей.

Подвох: Let's Encrypt не выдаёт wildcard-сертификаты для nip.io (их защита от злоупотреблений отрезает такие домены). Поэтому wildcard-сертификат *.10.174.8.95.nip.io мы выпустим через локальный CA внутри cert-manager — это формально полностью удовлетворяет требование задания «cert-manager генерирует wildcard-сертификат», но без зависимости от внешнего удостоверяющего центра.

> Типичный паттерн для внутренних корпоративных кластеров: компании выпускают свои корневые CA и подписывают ими сертификаты для своих внутренних сервисов. На работе сталкивался c с таким.


**Задача: Установка cert-manager**

**Применяем манифест**

- cert-manager ставится одной командой — официальный yaml-манифест в их GitHub-релизах. Берём актуальную стабильную версию:

![alt text](<img/1/image copy 14.png>)



- Что разворачивается:

    - Неймспейс cert-manager
    - CRD (Custom Resource Definitions — определения собственных ресурсов): Certificate, Issuer, ClusterIssuer, CertificateRequest, Order, Challenge. Это значит, что мы «учим» Kubernetes понимать новые типы объектов, которых в нём по умолчанию нет.

    - Три Deployment:

        - cert-manager — главный контроллер, который смотрит за всем
        - cert-manager-webhook — проверяет манифесты на корректность
        - cert-manager-cainjector — автоматически вставляет CA-сертификаты туда, куда нужно



![alt text](<img/1/image copy 15.png>)

**kubectl get pods -n cert-manager — все три пода в Running.**





















**Задача: Создание локального CA и wildcard-сертификата**


«Бутстрап» CA

«Бутстрап» (bootstrap — буквально «затянуть себя за шнурки», т.е. поднять с нуля) — это название процесса первоначальной инициализации. У нас задача: получить корневой CA, которым потом будем подписывать всё остальное. Но cert-manager-у, чтобы что-то выпустить, нужен Issuer (издатель). А Issuer-у нужен сертификат. Замкнутый круг.

Решение: сначала создаём самоподписанный Issuer — это «фейковый» издатель, который умеет выпускать сертификаты, подписанные ими же самими. Им мы подпишем наш собственный корневой сертификат CA. А потом из этого корневого сертификата делаем настоящий CA-Issuer, который уже будет подписывать всё остальное.


Цепочка:

```
selfsigned-bootstrap (издатель)
    └─ выпускает my-root-ca (корневой сертификат)
            └─ становится основой my-ca-issuer (настоящий издатель)
                    └─ выпускает wildcard-cert для *.10.174.8.95.nip.io
```









**Файл с CA-инфраструктурой  -/home/s/DO-11/src/manifests/ca-setup.yaml**

![alt text](<img/1/image copy 16.png>)


[text](manifests/ca-setup.yaml)

Термины:

ClusterIssuer vs Issuer: первый работает на весь кластер, второй — только в своём неймспейсе. Нам нужен ClusterIssuer, чтобы любой Ingress в любом неймспейсе мог через него выпустить сертификат.

Secret в k8s — это просто специальное хранилище ключ-значение для чувствительных данных (пароли, токены, ключи). 

Сертификаты и приватные ключи cert-manager кладёт именно туда.
CRD — мы пользуемся типами Certificate, ClusterIssuer именно благодаря CRD из cert-manager.

























![alt text](<img/1/image copy 17.png>)

**Применяем файл с CA-инфраструктурой**

**Проверяем, что корневой CA выпустился**








![alt text](<img/1/image copy 18.png>)

**Wildcard-сертификат**


Wildcard (буквально «джокер») — это звёздочка * в имени домена. Сертификат с *.10.174.8.95.nip.io будет валиден для любого поддомена первого уровня: app.10.174.8.95.nip.io, api.10.174.8.95.nip.io, grafana.10.174.8.95.nip.io — все они подойдут под этот один сертификат.













![alt text](<img/1/image copy 19.png>)
![alt text](<img/1/image copy 20.png>)

**Применяем файл с Wildcard-сертификатом и проверяем**








![alt text](<img/1/image copy 21.png>)

**kubernetes.io/tls — это значит, внутри лежат и сертификат, и приватный ключ.**



![alt text](<img/1/image copy 22.png>)

**Содержимое сертификата**






Здесь:

- jsonpath — мини-язык запросов, достаём поле tls.crt из секрета
- base64 -d — расшифровываем base64-кодирование (k8s хранит данные секретов в base64)
- openssl x509 -text -noout — показываем содержимое сертификата в человекочитаемом виде










**Файл с тестовым приложением - /home/s/DO-11/src/manifests/test-app.yaml**


![alt text](img/2/image.png)

[text](manifests/test-app.yaml)

















![alt text](<img/2/image copy.png>)

**2 пода Running и сервис с ClusterIP.**







![alt text](<img/1/image copy 23.png>)

**Файл с самим Ingress-ресурсом**

**Говорим cert-manager, что этим Ingress управляет наш CA-издатель**











![alt text](<img/1/image copy 24.png>)


![alt text](<img/2/image copy 2.png>)

**Проверяем**


```
 Address: hello.10.174.8.95.nip.io — это значит, Ingress «привязался» к контроллеру

TLS:
  wildcard-nipio-tls terminates hello.10.174.8.95.nip.io — сертификат подключён
```







![alt text](<img/2/image copy 3.png>)

**Доступ через браузер**

```
Server address: 10.42.2.6:80
Server name: hello-nginx-b77f8ffc4-mfxhd
Date: 22/May/2026:08:29:44 +0000
URI: /
Request ID: b15e3c0dbe22318dde2386ab8741fb3b
```




![alt text](<img/2/image copy 4.png>)

```
s@Vivo:~/DO-11/src/manifests$ curl -I http://hello.10.174.8.95.nip.io
HTTP/1.1 308 Permanent Redirect
Date: Fri, 22 May 2026 08:34:40 GMT
Content-Type: text/html
Content-Length: 164
Connection: keep-alive
Location: https://hello.10.174.8.95.nip.io
```

**HTTP без шифрования - Nginx перенаправляет на HTTPS**

**HTTP запрос → HTTP/1.1 308 Permanent Redirect с Location: https://... — Nginx Ingress автоматически редиректит на HTTPS.**







![alt text](<img/2/image copy 5.png>)

**HTTPS - флаг -k = не проверять CA (он у нас локальный, система его не знает)**


**HTTPS запрос → текст с именем пода (Server name: hello-nginx-xxx-xxx) и его IP. Если запустить несколько раз — поды будут чередоваться (это и есть балансировка).**







![alt text](<img/2/image copy 6.png>)



**Сам сертификат, который отдаёт наш Nginx Ingress**

**Прямое доказательство, что Nginx отдаёт именно наш wildcard-сертификат от нашего CA.**















## 2) Отчет содержит его конфигурацию и команды, необходимые для настройки контроллера. *








![alt text](<img/2/image copy 7.png>)


**Список параметров Deployment контроллера**






![alt text](<img/2/image copy 8.png>)




![alt text](<img/2/image copy 9.png>)


**Какие правила (rules) сейчас обрабатывает Nginx**



**Вторая команда показывает реальный сгенерированный nginx.conf внутри контроллера — это  доказательство того, что Ingress-ресурс автоматически превратился в конфиг Nginx.**









- Структура 2-го пункта отчёта:

```
## Part 2. Настройка контроллера Ingress
[вступление]

## 1) Контроллер Ingress на основе nginx настраивается в кластере. *
├─ Установка Nginx Ingress Controller  
├─ Поды и сервис (EXTERNAL-IP)  
├─ curl -I → 404 от nginx  
├─ nip.io как «домен»  
├─ Установка cert-manager  
├─ CA-инфраструктура (selfsigned → my-root-ca → my-ca-issuer)  
├─ Wildcard-сертификат  
├─ Тестовое приложение hello-nginx  
├─ Ingress-ресурс hello-ingress  
├─ curl HTTP → 308 редирект  
├─ curl -k HTTPS → работает  
└─ openssl s_client → сертификат от my-root-ca  ← граница

## 2) Отчет содержит его конфигурацию и команды, необходимые для настройки контроллера. *
├─ kubectl describe deployment ingress-nginx-controller  
└─ Реальный nginx.conf внутри контроллера
```







<br>
<br>
<br>

















##    3. Kubernetes и тесты


![alt text](<img/2/image copy 11.png>)

**Все 8 образов собраны**

![alt text](<img/1/image copy 25.png>)

**Все 9 образов на всех 3 ВМ**






## 1) В Kubernetes создан постоянный том для базы данных PostgreSQL. *




![alt text](<img/2/image copy 12.png>)

```
s@Vivo:~/DO-11/src/manifests/k8s-app$ cd ~/DO-11/src/manifests/k8s-app

kubectl apply -f .
configmap/app-config created
secret/app-secrets created
persistentvolume/postgres-pv created
persistentvolumeclaim/postgres-pvc created
deployment.apps/postgres created
service/postgres created
deployment.apps/rabbitmq created
service/rabbitmq created
deployment.apps/session-service created
service/session-service created
deployment.apps/hotel-service created
service/hotel-service created
deployment.apps/booking-service created
service/booking-service created
deployment.apps/payment-service created
service/payment-service created
deployment.apps/loyalty-service created
service/loyalty-service created
deployment.apps/report-service created
service/report-service created
deployment.apps/gateway-service created
service/gateway-service created
ingress.networking.k8s.io/app-ingress created
s@Vivo:~/DO-11/src/manifests/k8s-app$ 
```


**это пункт 3.1 и 3.2 чек-листа — PV создан, приложение развёрнуто**



## 2) Приложение развернуто в Kubernetes и доступно по адресу кластера. *


![alt text](<img/2/image copy 13.png>)

**kubectl get pods -w - Смотрим, как поды переходят в Running**









![alt text](<img/2/image copy 14.png>)


```
kubectl get pv,pvc
kubectl describe pvc postgres-pvc
```

**Проверка PV**













![alt text](<img/2/image copy 15.png>)



```
s@Vivo:~/DO-11/src/manifests/k8s-app$ kubectl exec -it deployment/postgres -- psql -U postgres -c '\l'
                                    List of databases
      Name       |  Owner   | Encoding |  Collate   |   Ctype    |   Access privileges   
-----------------+----------+----------+------------+------------+-----------------------
 balances_db     | postgres | UTF8     | en_US.utf8 | en_US.utf8 | 
 hotels_db       | postgres | UTF8     | en_US.utf8 | en_US.utf8 | 
 payments_db     | postgres | UTF8     | en_US.utf8 | en_US.utf8 | 
 postgres        | postgres | UTF8     | en_US.utf8 | en_US.utf8 | 
 reservations_db | postgres | UTF8     | en_US.utf8 | en_US.utf8 | 
 statistics_db   | postgres | UTF8     | en_US.utf8 | en_US.utf8 | 
 template0       | postgres | UTF8     | en_US.utf8 | en_US.utf8 | =c/postgres          +
                 |          |          |            |            | postgres=CTc/postgres
 template1       | postgres | UTF8     | en_US.utf8 | en_US.utf8 | =c/postgres          +
                 |          |          |            |            | postgres=CTc/postgres
 users_db        | postgres | UTF8     | en_US.utf8 | en_US.utf8 | 
(9 rows)

s@Vivo:~/DO-11/src/manifests/k8s-app$ 
```




**Проверка, что БД создались**













![alt text](<img/2/image copy 16.png>)

```
s@Vivo:~/DO-11/src/manifests/k8s-app$ kubectl get ingress
NAME            CLASS   HOSTS                                                   ADDRESS       PORTS     AGE
app-ingress     nginx   session.10.174.8.95.nip.io,gateway.10.174.8.95.nip.io   10.174.8.91   80, 443   6m29s
hello-ingress   nginx   hello.10.174.8.95.nip.io                                10.174.8.91   80, 443   4h56m
```

**Проверка Ingress**






![alt text](<img/2/image copy 17.png>)

**Логин (вернул 200 + заголовок Authorization)**


```
s@Vivo:~/DO-11/src/manifests/k8s-app$ curl -k -i -H "Authorization: Basic VXNlcjpxd2VydHk=" \
  https://session.10.174.8.95.nip.io/api/v1/auth/authorize
HTTP/2 200 
date: Fri, 22 May 2026 13:25:50 GMT
content-length: 0
vary: Origin
vary: Access-Control-Request-Method
vary: Access-Control-Request-Headers
authorization: Bearer eyJhbGciOiJSUzI1NiJ9.eyJzdWIiOiI2ZDJjYjVhMC05NDNjLTRiOTYtOWFhNi04OWVhYzdiZGZkMmIiLCJleHAiOjE3ODA2MTc2MDB9.CdagQ_s-hEhcC4tbWr2jbiiwXe1DFINsEKtMdhGy9Ke_xYQ0yDx4GrShoIY2ER1EgjYDYKPnMmOYb1f-Gtwg8aMj7efeGh92jO7jnCIRtNa6BAmj_Qe-rCnxzAmSGqeChyHC3s50rSWiGaPZq9QSsmED_KIHO4RVV26i-o_UceiXDSGrD-TZOSRRwk72o4ZV4g2AvYxHo-lBG6ymsnXd7ddW00k7IptD8iWUSMLIY5Rt3STFSP9QJNA7bX8XN5ks35Dbm0FAgXsgkE2bwM27z7pIgggyPzEej19uHbMgaktjEhMZO3hsf7hh-sc-o8KtnkQ_n5LZozg7afVE8P3ebQ
access-control-expose-headers: authorization
x-content-type-options: nosniff
x-xss-protection: 1; mode=block
cache-control: no-cache, no-store, max-age=0, must-revalidate
pragma: no-cache
expires: 0
strict-transport-security: max-age=31536000; includeSubDomains
x-frame-options: DENY
```





![alt text](<img/2/image copy 18.png>)

**Список отелей (нужен валидный Bearer-токен из предыдущего запроса)**



```
s@Vivo:~/DO-11/src/manifests/k8s-app$ TOKEN=$(curl -ks -H "Authorization: Basic VXNlcjpxd2VydHk=" \
  https://session.10.174.8.95.nip.io/api/v1/auth/authorize -D - | grep -i ^authorization | sed 's/[Aa]uthorization: //' | tr -d '\r')
s@Vivo:~/DO-11/src/manifests/k8s-app$ curl -k -H "Authorization: $TOKEN" \
  https://gateway.10.174.8.95.nip.io/api/v1/gateway/hotels
[{"hotelUid":"9d05ba36-bf8d-11eb-8529-0242ac130003","name":"Hotel 1","location":{"country":"Country 1","city":"City 1","address":"Address 1"},"cost":2000.0},{"hotelUid":"ab84f4e6-bf8d-11eb-8529-0242ac130003","name":"Hotel 2","location":{"country":"Country 1","city":"City 2","address":"Address 2"},"cost":3000.0},{"hotelUid":"b0698102-bf8d-11eb-8529-0242ac130003","name":"Hotel 3","location":{"country":"Country 2","city":"City 3","address":"Address 3"},"cost":5000.0}]s@Vivo:~/DO-11/src/manifests/k8s-app$ 
```
























## 3) Предоставлены скриншоты результатов теста Postman. *




![alt text](<img/2/image copy 19.png>)


**результаты - 200/201**

```
s@Vivo:~/DO-11/src$ cd ~/DO-11/src

newman run application_tests.k8s.postman_collection.json \
  --insecure \
  --reporters cli,htmlextra \
  --reporter-htmlextra-export newman-report.html \
  --reporter-htmlextra-title "DO11 K8s Application Tests"
newman

Application Tests

→ Login User
  GET https://session.10.174.8.95.nip.io:443/api/v1/auth/authorize [200 OK, 952B, 809ms]
  ✓  Login as a regular user

→ Get Hotles
  GET https://gateway.10.174.8.95.nip.io:443/api/v1/gateway/hotels [200 OK, 944B, 716ms]
  ✓  Get hotels info

→ Get Hotel
  GET https://gateway.10.174.8.95.nip.io:443/api/v1/gateway/hotels/9d05ba36-bf8d-11eb-8529-0242ac130003 [200 OK, 630B, 96ms]
  ✓  Get hotels info

→ Book Hotel
  POST https://gateway.10.174.8.95.nip.io:443/api/v1/gateway/booking [201 Created, 439B, 6.5s]
  ✓  Book hotel

→ Get User's Loyalty Balance
  GET https://gateway.10.174.8.95.nip.io:443/api/v1/gateway/loyalty [200 OK, 509B, 105ms]
  ✓  Get user's loyalty balance

┌─────────────────────────┬────────────────────┬───────────────────┐
│                         │           executed │            failed │
├─────────────────────────┼────────────────────┼───────────────────┤
│              iterations │                  1 │                 0 │
├─────────────────────────┼────────────────────┼───────────────────┤
│                requests │                  5 │                 0 │
├─────────────────────────┼────────────────────┼───────────────────┤
│            test-scripts │                 10 │                 0 │
├─────────────────────────┼────────────────────┼───────────────────┤
│      prerequest-scripts │                  5 │                 0 │
├─────────────────────────┼────────────────────┼───────────────────┤
│              assertions │                  5 │                 0 │
├─────────────────────────┴────────────────────┴───────────────────┤
│ total run duration: 8.4s                                         │
├──────────────────────────────────────────────────────────────────┤
│ total data received: 658B (approx)                               │
├──────────────────────────────────────────────────────────────────┤
│ average response time: 1660ms [min: 96ms, max: 6.5s, s.d.: 2.4s] │
└──────────────────────────────────────────────────────────────────┘
s@Vivo:~/DO-11/src$ 
```




![alt text](<img/2/image copy 20.png>)

newman-reporter-htmlextra — это дополнительный плагин для красивых HTML-отчётов. Они выглядят гораздо лучше, чем стандартный вывод Newman, и отлично смотрятся в отчёте


<br>
<br>
<br>


















    4. Оператор Prometheus

1) Отчет содержит описание запуска оператора Prometheus и скриншоты результатов.

    0 1 2 3 4 5






















<br>
<br>
<br>














## Part 1. Развертывание собственного кластера k3s

### Задание

1. Получить набор виртуальных машин для кластера.

2. Установить k3s на всех трех машинах. При установке не использовать стандартный Ingress Controller при помощи флага `--disable=traefik`.

3. Выполнить подключение узлов к кластеру, используя команду `k3s server` и флаги `--token` и `--server` для рабочих узлов и мастера соответственно. Когда k3s установлен, можно использовать переменную окружения `NODE_TOKEN`.

4. Установить Ingress Controller Nginx вместо стандартного. Ты можешь использовать официальный файл манифеста Ingress контроллера на базе Nginx, доступный на GitHub.

5. Получить доменное имя и сконфигурировать внутри кластера утилиту `cert-manager`, которая должна генерировать wildcard-сертификат для полученного домена.

6. Создать ресурс Ingress для своего личного домена и настроить его для использования контроллера nginx ingress и полученного сертификата.

7. Создать PV (Persistent Volume) для базы данных PostgreSQL в манифесте из десятого проекта.

8. Запустить приложение, описанное в манифесте.

9. Запустить функциональные тесты Postman и удостовериться в работоспособности приложения.

10. Установить и запустить Prometheus Operator для сбора метрик в системе. Продемонстрировать в отчете результат выполнения команды `kubectl get pods -n monitoring`.
