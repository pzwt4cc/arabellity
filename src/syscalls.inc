%define SYS_READ            0
%define SYS_WRITE           1
%define SYS_OPEN            2
%define SYS_CLOSE           3
%define SYS_POLL            7
%define SYS_MMAP            9
%define SYS_MUNMAP          11
%define SYS_IOCTL           16
%define SYS_PIPE            22
%define SYS_DUP2            33
%define SYS_SOCKET          41
%define SYS_CONNECT         42
%define SYS_SENDMSG         46
%define SYS_FORK            57
%define SYS_EXECVE          59
%define SYS_EXIT            60
%define SYS_WAIT4           61
%define SYS_FTRUNCATE       77
%define SYS_SETSID          112
%define SYS_TIMERFD_CREATE  283
%define SYS_TIMERFD_SETTIME 286
%define SYS_PIPE2           293
%define SYS_MEMFD_CREATE    319

%define CLOCK_MONOTONIC     1
%define TFD_CLOEXEC         0x80000
%define TFD_NONBLOCK        0x800

%define STDIN               0
%define STDOUT              1
%define STDERR              2

%define EINTR               4

%define O_RDWR              0x2
%define O_NOCTTY            0x100
%define O_CLOEXEC           0x80000

%define TCGETS              0x5401
%define TCSETS              0x5402
%define TIOCSCTTY           0x540E
%define TIOCGWINSZ          0x5413
%define TIOCSWINSZ          0x5414
%define TIOCGPTPEER         0x5441
%define TIOCSPTLCK          0x40045431

%define POLLIN              0x1
%define POLLERR             0x8
%define POLLHUP             0x10

%define AF_UNIX             1
%define SOCK_STREAM         1
%define SOCK_CLOEXEC        0x80000
%define SOL_SOCKET          1
%define SCM_RIGHTS          1

%define MFD_CLOEXEC         1
%define PROT_READ           1
%define PROT_WRITE          2
%define MAP_SHARED          1
