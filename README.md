# arabellity

Эмулятор терминала для Wayland на чистом x86-64 ассемблере (NASM), Linux, без libc и внешних библиотек.

## Зависимости

```sh
sudo pacman -S nasm make gdb
```

## Сборка и запуск

```sh
make        # собрать -> build/arabellity
make run    # собрать и запустить
make debug  # открыть в gdb
make clean  # удалить build/
```
