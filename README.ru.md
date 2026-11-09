<p align="center">
  <img src="assets/icons/arabellity.svg" width="128" height="128" alt="Логотип Arabellity" />
</p>

<h1 align="center">Arabellity</h1>

<p align="center">
  <b>Быстрый, легковесный и полностью автономный эмулятор терминала для Wayland, написанный на чистом x86-64 ассемблере (NASM).</b>
</p>

<p align="center">
  <a href="README.md">English</a> •
  <a href="README.ru.md">Русский</a>
</p>

---

## Обзор

**Arabellity** — это современный эмулятор терминала, созданный с нуля специально для Wayland-композиторов без использования C runtime библиотек (`libc`) и сторонних фреймворков.

- **100% Static & Standalone**: Прямые системные вызовы ядра Linux (`syscall`). Нулевая зависимость от `libc`, `libwayland`, `libxkbcommon`, `cairo` или любых других разделяемых библиотек.
- **Wayland Native**: Прямое взаимодействие через UNIX domain socket с реализацией протоколов Wayland (`wl_compositor`, `wl_shm`, `xdg_wm_base`, `wl_seat`, `wl_data_device`).
- **Kitty Graphics Protocol**: Поддержка отображения встроенных изображений (PNG и прямой RGBA) в консольных утилитах, таких как `fastfetch`, `yazi`, `chafa` и `ranger`.
- **Шрифтовые лигатуры**: Встроенный бинарный атлас JetBrains Mono с поддержкой популярных лигатур программирования (`===`, `==`, `=>`, `->`, `!=`, `!==`, `<=`, `>=`, `:=`, `::`, `<-`).
- **Цвета и Темы**: TrueColor (24-bit RGB), таблица 256 цветов ANSI, OSC-последовательности палитры 4/10/11/12, автоподключение тем оформления Kitty (`include themes/...`).
- **Максимальная производительность**: Мгновенный запуск, минимальное потребление оперативной памяти и субмиллисекундный отклик.

---

## Установка

### Универсальный установщик (любой дистрибутив Linux)

Скрипт автоматически соберёт статический бинарник (если он ещё не собран) и установит исполняемый файл, `.desktop`-ярлык, системные иконки всех размеров и дефолтный конфиг:

```sh
# Установка для текущего пользователя в ~/.local (без прав root/sudo):
./install.sh --user

# Или установка общесистемно в /usr/local:
sudo ./install.sh
```

Для удаления:
```sh
# Если ставили с флагом --user:
./uninstall.sh --user

# Если ставили общесистемно:
sudo ./uninstall.sh
```

### Arch Linux (makepkg / pacman)

Сборка и установка через штатный пакетный менеджер Arch:

```sh
# Сборка и установка пакета:
cd packaging/arch
makepkg -si

# Чистое удаление через pacman:
sudo pacman -R arabellity
```

---

## Сборка из исходников

### Необходимые инструменты

Для компиляции требуются только NASM и GNU Binutils (`ld`):
- **Arch / Manjaro**: `sudo pacman -S nasm binutils`
- **Debian / Ubuntu**: `sudo apt install nasm binutils`
- **Fedora**: `sudo dnf install nasm binutils`

### Цели Makefile

```sh
make         # Собрать оптимизированный статический бинарник -> build/arabellity
make test    # Запустить автотесты (проверка чистоты системных вызовов и зависимостей)
make dist    # Сформировать релизный архив arabellity-*-linux-x86_64.tar.gz
make run     # Собрать и запустить терминал
make clean   # Очистить артефакты сборки
```

---

## Конфигурация

Arabellity загружает конфигурацию из файла `~/.config/arabellity/arabellity.conf`. Если файл отсутствует, он автоматически создаётся при первом запуске или установке.

Поддерживаются параметры:
- Размеры окна (`width`, `height`)
- Внутренние отступы (`padding_x`, `padding_y`)
- Прозрачность фона (`opacity 0.0` - `1.0`)
- Параметры отрисовки шрифта
- Подключение цветовых схем Kitty (`include themes/Everforest_Dark_Hard.conf`)

---

## Структура проекта

```
arabellity/
├── assets/
│   ├── arabellity.desktop        # Десктоп-ярлык для системных лаунчеров
│   ├── fonts/
│   │   └── nerd_font.bin         # Пререндеренный бинарный атлас JetBrains Mono
│   └── icons/                    # Векторный SVG и PNG-иконки разных разрешений
├── packaging/
│   └── arch/                     # PKGBUILD для Arch Linux / AUR
├── scripts/
│   └── gen_font.rs               # Генератор шрифтового атласа и лигатур на Rust/FreeType
├── src/                          # Исходный код на чистом NASM x86-64
│   ├── main.asm                  # Точка входа _start, цикл epoll, обработчики сигналов
│   ├── wl.asm, wl.inc            # Клиент Wayland и сериализация сокета UNIX
│   ├── window.asm                # wl_shm пиксельные буферы и отрисовка кадров
│   ├── term_screen.asm           # Парсер VT100/XTerm, сетка текста, сканер лигатур
│   ├── kitty_gfx.asm             # Обработчик Kitty Graphics Protocol
│   ├── png_decode.asm            # Автономный декодер изображений PNG
│   ├── tinflate.asm              # Декомпрессор Deflate/zlib
│   ├── pty.asm                   # Аллокация псевдотерминала и запуск шелла
│   ├── kbd.asm                   # Раскладка Wayland и трансляция клавиш XKB
│   ├── config.asm                # Парсер конфигурационного файла
│   └── font.asm                  # Блиттер глифов из атласа
├── arabellity.conf               # Стандартная конфигурация
├── install.sh                    # Универсальный скрипт установки
├── uninstall.sh                  # Скрипт удаления
└── Makefile                      # Сценарий сборки
```

---

## Лицензия

[MIT](LICENSE)
