# acc-server-autoinstaller

**Русский** | [English](README.en.md)

Open-source CLI-утилита для полностью автоматической установки и удаления
**Assetto Corsa Competizione Dedicated Server** на Ubuntu.

После установки вы получаете готовый к работе Dedicated Server с панелью
управления **ACCWeb** — без необходимости вручную выполнять какие-либо команды.

## Возможности

- Полная установка «из коробки»: зависимости, Wine, SteamCMD, Dedicated Server, ACCWeb.
- Автоматическая настройка `configuration.json` и `settings.json` (корректная работа с UTF-16LE).
- Обязательный Linux compatibility patch: `"ignorePrematureDisconnects": 0`.
- Автозапуск ACCWeb через systemd (под Xvfb).
- Настройка UFW (игровые порты + порт панели).
- Безопасное повторное выполнение (повторный `install` не ломает существующую установку).
- Полное удаление одной командой.

## Требования

- Ubuntu **22.04 LTS** или **24.04 LTS**
- Архитектура **x86_64 (amd64)**
- Права **root** (запуск через `sudo`)
- Свободное место на диске: **≥ 15 ГБ** (рекомендуется 20+ ГБ)
- Оперативная память: **≥ 2 ГБ** (рекомендуется 4+ ГБ)
- Доступ в интернет (для apt, SteamCMD и GitHub)
- Аккаунт Steam, владеющий ACC (для загрузки Dedicated Server)

## Поддерживаемые ОС

| ОС               | Архитектура | Статус        |
| ---------------- | ----------- | ------------- |
| Ubuntu 22.04 LTS | x86_64      | Поддерживается |
| Ubuntu 24.04 LTS | x86_64      | Поддерживается |

## Структура проекта

```
acc-server-autoinstaller/
├── install.sh          # точка входа для установки
├── uninstall.sh        # точка входа для удаления
├── lib/                # модули (общие функции, проверки, зависимости, ...)
│   ├── common.sh
│   ├── checks.sh
│   ├── deps.sh
│   ├── user.sh
│   ├── wine.sh
│   ├── steam.sh
│   ├── accweb.sh
│   ├── config.sh
│   ├── firewall.sh
│   ├── systemd.sh
│   └── report.sh
├── templates/          # шаблоны конфигураций
│   ├── config.yml.tpl
│   ├── accweb.service.tpl
│   ├── event.json
│   ├── eventRules.json
│   ├── entrylist.json
│   ├── bop.json
│   └── assistRules.json
├── README.md           # документация (русский)
├── README.en.md        # документация (English)
└── LICENSE
```

## Установка

```bash
# 1. Склонируйте репозиторий
git clone https://github.com/<ваш-аккаунт>/acc-server-autoinstaller.git
cd acc-server-autoinstaller

# 2. Запустите установщик
sudo ./install.sh
```

Установщик по очереди запросит:

- имя сервера (по умолчанию `ACC Dedicated Server`);
- игровой TCP-порт (по умолчанию `9600`);
- игровой UDP-порт (по умолчанию `9600`);
- порт панели ACCWeb (по умолчанию `8080`);
- пароль администратора ACCWeb;
- Steam Login / Steam Password / Steam Guard (если включён).

Все параметры можно передать заранее через переменные окружения (удобно для
автоматизации):

```bash
sudo \
  SERVER_NAME="My Server" \
  TCP_PORT=9600 \
  UDP_PORT=9600 \
  WEB_PORT=8080 \
  ADMIN_PASSWORD="secret" \
  STEAM_USER="username" \
  STEAM_PASS="password" \
  ./install.sh
```

> Steam Guard-код одноразовый и действует недолго, поэтому он запрашивается
> непосредственно перед загрузкой сервера.

### Что делает установщик

1. Проверяет ОС, архитектуру, свободное место, RAM и наличие прав root.
2. Устанавливает зависимости: Wine, SteamCMD, Xvfb, winbind, unzip, curl, wget, jq, ufw, iconv.
3. Создаёт пользователя `acc` (если отсутствует).
4. Создаёт и инициализирует Wine prefix.
5. Выполняет авторизацию Steam и скачивает ACC Dedicated Server (Steam app id `1430110`).
6. Скачивает последнюю стабильную версию ACCWeb из GitHub Releases.
7. Генерирует `config.yml` ACCWeb с путём к Dedicated Server.
8. Создаёт конфигурацию Dedicated Server (`configuration.json`, `settings.json` и др.) в UTF-16LE.
9. Добавляет `"ignorePrematureDisconnects": 0` (Linux compatibility patch).
10. Проверяет валидность всех JSON.
11. Открывает игровые порты и порт панели в UFW.
12. Создаёт и запускает systemd-сервис `accweb`.
13. Проверяет, что ACCWeb отвечает по HTTP и что Dedicated Server запускается.

По завершении выводится отчёт с URL панели, логином, паролем и игровыми портами.

## Использование

После установки:

- Панель: `http://<IP-сервера>:8080/`
- Логин: `username` (вводится только пароль)
- Пароль: тот, что вы задали при установке

Управление сервисом:

```bash
sudo systemctl status accweb
sudo systemctl restart accweb
sudo journalctl -u accweb -f
```

## Удаление

```bash
sudo ./uninstall.sh
```

Удаление:

1. выводит предупреждение и запрашивает подтверждение (`yes`);
2. останавливает и удаляет systemd-сервис ACCWeb;
3. удаляет правила UFW, созданные установщиком;
4. удаляет ACCWeb, Dedicated Server и Wine prefix;
5. удаляет SteamCMD (по желанию — можно сохранить в `/opt/steamcmd`);
6. удаляет пользователя `acc` и его домашнюю директорию;
7. выполняет `systemctl daemon-reload`.

Повторный запуск `uninstall.sh` безопасен (не завершается ошибкой).

## FAQ

### Нужен ли мне аккаунт Steam для установки?
Да. Dedicated Server скачивается через SteamCMD с использованием вашего Steam
аккаунта, владеющего ACC. Логин/пароль используются только один раз для загрузки.

### Почему Dedicated Server работает под Wine?
Официальный ACC Dedicated Server распространяется только для Windows.
Wine позволяет запускать его на Linux, а Xvfb предоставляет виртуальный дисплей.

### Какие порты нужно открыть?
По умолчанию игровой TCP `9600`, игровой UDP `9600` и порт панели `8080`.
Установщик открывает их в UFW автоматически. Не забудьте также пробросить эти
порты на вашем облачном провайдере / роутере, если сервер за NAT.

### Что такое `ignorePrematureDisconnects`?
Обязательный для Linux параметр `"ignorePrematureDisconnects": 0` в
`settings.json`. Без него сервер некорректно работает под Wine. Установщик
добавляет его автоматически и не создаёт дубликатов.

### Можно ли запустить установщик повторно?
Да. Установщик идемпотентен: он не затирает уже созданные конфигурации и
корректно пропускает уже выполненные шаги.

### Как обновить ACCWeb или Dedicated Server?
- ACCWeb: замените каталог ACCWeb новой версией либо переустановите.
- Dedicated Server: повторная загрузка через SteamCMD (`app_update 1430110 validate`).

## Troubleshooting

### ACCWeb не отвечает по HTTP
```bash
sudo systemctl status accweb
sudo journalctl -u accweb -e
```
Убедитесь, что порт панели свободен и открыт в UFW.

### Dedicated Server не запускается
1. Проверьте логи ACCWeb:
   ```bash
   sudo journalctl -u accweb -f
   ```
2. Проверьте, что файлы `configuration.json` и `settings.json` валидны и лежат
   в каталоге экземпляра (`/home/acc/accweb/config/default/`).
3. Проверьте, что `ignorePrematureDisconnects` присутствует в `settings.json`.

### Ошибка авторизации Steam
- Проверьте правильность Steam Login/Password.
- Если включён Steam Guard — укажите актуальный код (он одноразовый и
  действителен ограниченное время).
- После нескольких неудачных попыток Steam может временно заблокировать вход —
  подождите и попробуйте снова.

### Не хватает места на диске
Освободите место и повторно запустите установщик. Минимальное требование —
15 ГБ, рекомендуется 20+ ГБ (контент ACC с DLC занимает несколько гигабайт).

### UFW отключён
Если UFW не активен, установщик добавит правила, но они вступят в силу только
после включения:
```bash
sudo ufw enable
```
Не забудьте предварительно разрешить SSH: `sudo ufw allow OpenSSH`.

## Лицензия

[MIT](./LICENSE)

## Сторонние компоненты

- [ACCWeb](https://github.com/assetto-corsa-web/accweb) — MIT
- Assetto Corsa Competizione Dedicated Server — проприетарное ПО Kunos Simulazioni
- SteamCMD — Valve Corporation

