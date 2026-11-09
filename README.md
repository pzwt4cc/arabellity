# Arabellity

Быстрый и легковесный эмулятор терминала для Wayland, написанный на **чистом x86-64 ассемблере (NASM)**.

- **100% Static**: Прямые системные вызовы Linux (`syscall`), нулевая зависимость от `libc`, `libwayland`, `libxkbcommon` или любых других runtime-библиотек.
- **Wayland Native**: Прямая работа с протоколами Wayland (`wl_compositor`, `wl_shm`, `xdg_wm_base`, `wl_seat`) через UNIX domain socket.
- **Kitty Graphics Protocol**: Поддержка отображения изображений в Fastfetch, Yazi и других TUI-утилитах.
- **Шрифтовые лигатуры**: Встроенный атлас JetBrains Mono с поддержкой лигатур (`===`, `==`, `=>`, `->`, `!=`, `!==`, `<=`, `>=`, `:=`, `::`, `<-`).
- **Цвета и Темы**: TrueColor (24-bit RGB), 256 цветов ANSI, автоподхват тем Kitty (`include themes/...`), поддержка OSC 4, 10, 11, 12.

---

## Установка

### Универсальная установка (любой Linux)

Скрипт сам соберёт бинарник, установит `.desktop`-ярлык, иконку и конфиг:

```sh
# Установка для текущего пользователя в ~/.local (без sudo):
./install.sh --user

# Или установка в систему (/usr/local):
sudo ./install.sh
```

### Arch Linux (PKGBUILD)

```sh
cd packaging/arch
makepkg -si
```

---

## Сборка и тестирование

Для сборки из исходников требуются только `nasm` и `ld` (пакет `binutils`):

```sh
make         # Собрать статический бинарник -> build/arabellity
make test    # Запустить автоматические тесты (проверка зависимостей и кода)
make dist    # Собрать релизный тарбол arabellity-*-linux-x86_64.tar.gz
make run     # Собрать и запустить
make clean   # Очистить директорию сборки
```

---

## Структура проекта

```
arabellity/
├── assets/
│   ├── arabellity.desktop        # Ярлык для лаунчеров (Rofi, Wofi, меню)
│   ├── fonts/
│   │   └── nerd_font.bin         # Пререндеренный бинарный атлас шрифта
│   └── icons/                    # Векторная SVG и PNG-иконки разных разрешений
├── packaging/
│   └── arch/                     # PKGBUILD для Arch Linux / AUR
├── scripts/
│   └── gen_font.rs               # Генератор шрифтового атласа на Rust/FreeType
├── src/                          # Исходный код на NASM x86-64
│   ├── main.asm                  # Точка входа _start и цикл событий epoll
│   ├── wl.asm, wl.inc            # Клиент протокола Wayland
│   ├── window.asm                # Буферы shm и отрисовка окна
│   ├── term_screen.asm           # Парсер VT/ANSI, сетка текста, лигатуры
│   ├── kitty_gfx.asm             # Kitty Graphics Protocol
│   ├── png_decode.asm            # Декодер изображений PNG
│   ├── tinflate.asm              # Распаковщик Deflate/zlib
│   ├── pty.asm                   # Псевдотерминал и запуск шелла
│   ├── kbd.asm                   # XKB-раскладка и ввод клавиатуры
│   ├── config.asm                # Парсер конфигурации
│   └── font.asm                  # Отрисовка глифов из атласа
├── arabellity.conf               # Конфигурационный файл
├── install.sh                    # Универсальный скрипт установки
└── Makefile                      # Скрипт сборки
```

---

## Лицензия

MIT
