; Linux x86-64: номера системных вызовов и константы

%define SYS_READ        0
%define SYS_WRITE       1
%define SYS_OPEN        2
%define SYS_CLOSE       3
%define SYS_POLL        7
%define SYS_IOCTL       16
%define SYS_DUP2        33
%define SYS_FORK        57
%define SYS_EXECVE      59
%define SYS_EXIT        60
%define SYS_WAIT4       61
%define SYS_SETSID      112

%define STDIN           0
%define STDOUT          1
%define STDERR          2

%define EINTR           4

; open()
%define O_RDWR          0x2
%define O_NOCTTY        0x100
%define O_CLOEXEC       0x80000

; ioctl()
%define TCGETS          0x5401
%define TCSETS          0x5402
%define TIOCSCTTY       0x540E
%define TIOCGWINSZ      0x5413
%define TIOCSWINSZ      0x5414
%define TIOCGPTPEER     0x5441
%define TIOCSPTLCK      0x40045431

; poll()
%define POLLIN          0x1
%define POLLERR         0x8
%define POLLHUP         0x10
