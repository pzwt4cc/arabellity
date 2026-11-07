# noname

> Название — заглушка. Меняется в `Makefile` (`NAME := ...`).

Терминал на чистом x86-64 ассемблере (NASM), Linux, без libc.

## Зависимости

```sh
sudo pacman -S nasm make gdb
```

## Сборка и запуск

```sh
make        # собрать -> build/noname
make run    # собрать и запустить
make debug  # открыть в gdb
make clean  # удалить build/
```
