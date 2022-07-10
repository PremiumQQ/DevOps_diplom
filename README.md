# Дипломный практикум в YandexCloud

## Цели:

1) Зарегистрировать доменное имя (любое на ваш выбор в любой доменной зоне).
2) Подготовить инфраструктуру с помощью Terraform на базе облачного провайдера YandexCloud.
3) Настроить внешний Reverse Proxy на основе Nginx и LetsEncrypt.
4) Настроить кластер MySQL.
5) Установить WordPress.
6) Развернуть Gitlab CE и Gitlab Runner.
7) Настроить CI/CD для автоматического развёртывания приложения.
8) Настроить мониторинг инфраструктуры с помощью стека: Prometheus, Alert Manager и Grafana.

## Этапы выполнения:
## Регистрация доменного имени

Было зарегистрировано доменное имя: ```stazy.ru``` в регистраторе <code>[reg.ru](https://www.reg.ru)</code>. 

Возможность прописывать dns записи и редактировать ААА записи:

![reg.ru](/img/reg.ru.PNG)

## Создание инфраструктуры Terraform.

В папке terraform лежат все конфиги и ноды для развертывания инфраструктуры. Развернуть инфраструктуру можно командной:
```
sudo terraform apply
```
Удалить все, что создалось можно командной:
```
sudo terraform destroy
```
Workspace по умолчанию prod:
```
premiumq@TOP:/opt/diplom/terraform$ terraform workspace list
  default
* prod
```
В файлике key.json (не прикладываю) указаны следующие переменные:
```
"id":
"service_account_id":
"created_at":
"key_algorithm":
"public_key":
"private_key":
```
Создаваемые ВМ:

![YandexCloud](/img/yo_1.PNG)

## Настройка внешнего Reverse Proxy на основе Nginx и LetsEncrypt.

Роль по установке Nginx находится в папке ansible/nginx.yml.
Роль выполнит play по установке nginx, настройке Reverse Proxy, установке обычного proxy (с использованием privoxy) и LetsEncrypt.
Так же сгенерирует сертификаты с помощью LetsEncrypt для каждой машины, используя tasks:

```
- name: Create letsencrypt certificate front
  shell: letsencrypt certonly -n --webroot --staging -w /var/www/letsencrypt -m {{ letsencrypt_email }} --agree-tos -d {{ domain_name }}
  args:
    creates: /etc/letsencrypt/live/{{ domain_name }}
```
Для запуска ролей, использовалась версия ansible [core 2.12.7].

## Установка кластера MySQL

Роль по установке MySQL и настройке находится в папке ansible/mysql.yml.

Роль выполнит play по установке MySQL на двух серверах, так же после этого настроит master/slave репликацию. 

Проверить что репликация настроена и работает, можно подключившись на ВМ и ввести команду:

```
SHOW SLAVE STATUS\G
```
Если все хорошо, то можно увидеть следующее:

![MySQL](/img/mysql_1.PNG)

## Установка кластера WordPress

Роль по установке WordPress и настройке находится в папке ansible/wordpress.yml.

Роль выполнит play по установке и настройке wordpress. 

Wordpress работает через Apache2 и доступен через https.

![Wordpress](/img/wordpress_2.PNG)

Так же выполняется автоматическая настройка подключения к БД настроенного сервера MySQL. К базе с иминем wordpress, под пользователем wordpress и паролем wordpress.

Т.к. у машины нет статистического IP, в конфиге Wordpress прописано прокси на машину с Reverse Proxy.

```
define('WP_PROXY_HOST', '192.168.10.101');
define('WP_PROXY_PORT', '8118');
define('WP_PROXY_BYPASS_HOSTS', 'localhost');
```

## Установка кластера Gitlab CE и Gitlab Runner

Роль по установке Gitlab и настройке находится в папке ansible/gitlab.yml.

Роль выполнит play по установке и настройке gitlab.

Gitlab доступен по https:

![Gitlab](/img/gitlab_1.PNG)

Вход доступен под логином ```root``` и паролем ```netology```.

Если пароль не корректен, сбросить пароль можно двумя способами:

```
gitlab-rake "gitlab:password:reset[root]
```
или 

```
gitlab-rails console -e production
user = User.where(id: 1).first
user.password = 'netology'
user.password_confirmation = 'netology'
user.save!
```
Для регистрации Gitlab Runner, нужно выполнить следующую команду на ВМ runner:

```
sudo gitlab-runner register --url https://gitlab.stazy.ru/ --registration-token {TOKEN}
```

Далее в GUI Gitlab можно увидеть зарегистрированного Runner:

![Gitlab](/img/gitlab_2.PNG)

Файл ```.gitlab-ci.yml``` для pipeline получился следующий: 

```
image: alpine:latest

pages:
  stage: deploy
  before_script:
  - 'command -v ssh-agent >/dev/null || ( apk add --update openssh )' 
  - eval $(ssh-agent -s)
  - echo "$SSH_PRIVATE_KEY" | tr -d '\r' | ssh-add -
  - mkdir -p ~/.ssh
  - chmod 700 ~/.ssh
  - ssh-keyscan $VM_IPADDRESS >> ~/.ssh/known_hosts
  - chmod 644 ~/.ssh/known_hosts
  script:
    - echo "Deploying application..." 
    - ssh -o StrictHostKeyChecking=no $SSH_USER@$VM_IPADDRESS sudo chown $SSH_USER /var/www/wordpress/ -R
    - rsync -vz -e "ssh -o StrictHostKeyChecking=no" ./* $SSH_USER@$VM_IPADDRESS:/var/www/wordpress/
    - ssh -o StrictHostKeyChecking=no $SSH_USER@$VM_IPADDRESS rm -rf /var/www/wordpress/.git
    - ssh -o StrictHostKeyChecking=no $SSH_USER@$VM_IPADDRESS sudo chown www-data /var/www/wordpress/ -R
  artifacts:
    paths:
    - public
  only:
  - master
```
В настройках, во вкладке Variables заполнены следующие переменные:

SSH_PRIVATE_KEY  (SSH PRIVATE ключ, для подключения к ВМ с Wordpress)

VM_IPADDRESS (IP ВМ с Wordpress в нашем случае 192.168.10.104)

SSH_USER (Имя пользователя ВМ с Wordpress, в нашем случае ubuntu)

Для корректной работы скрипты, нужно добавить публичный SSH ключ на ВМ с Wordpress, по пути ```/home/ubuntu/.ssh/authorized_keys```

## Установка кластера Grafana, Prometheus и Alert Manager.

Роль по установке Grafana, Prometheus и Alert Manager и настройке находится в папке ansible/grafana.yml.

Роль выполнит play по установке и настройке Grafana, Prometheus и Alert Manager.

Сервис Grafana доступен по https:

![Grafana](/img/grafana_1.PNG)

Сервис Prometheus доступен по https:

![Prometheus](/img/prometheus_1.PNG)

Предварительно, на все ВМ был установлен Node Exporter.

Конфиг Prometheus прописан и настраивается автоматически. Все Node доступны по всем созданным ВМ.

Сервис Alert Manager доступен по https:

![Alert Manager](/img/alertmanager_1.PNG)

В Alert Manager автоматически прописано одно правило ``` PrometheusTargetMissing ```. Если одна из нод перестанет быть доступна, alertmanager оповестит об этом. 
Так же можно настроить почтовый сервис, чтобы оповещение приходило на почту.

Сервис Grafana подключается к БД Prometheus по адресу localhost:9090 и тестируется без ошибок: 

![Alert Manager](/img/grafana_2.PNG)


