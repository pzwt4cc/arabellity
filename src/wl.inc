%define WL_DISPLAY_ID                   1

%define WL_DISPLAY_SYNC                 0
%define WL_DISPLAY_GET_REGISTRY         1
%define WL_DISPLAY_ERROR                0

%define WL_REGISTRY_BIND                0
%define WL_REGISTRY_GLOBAL              0

%define WL_CALLBACK_DONE                0

%define WL_COMPOSITOR_CREATE_SURFACE    0

%define WL_SHM_CREATE_POOL              0
%define WL_SHM_POOL_CREATE_BUFFER       0
%define WL_SHM_POOL_DESTROY             1
%define WL_SHM_FORMAT_ARGB8888          0
%define WL_SHM_FORMAT_XRGB8888          1

%define WL_BUFFER_DESTROY               0

%define WL_SURFACE_ATTACH               1
%define WL_SURFACE_DAMAGE               2
%define WL_SURFACE_COMMIT               6

%define WL_SEAT_GET_POINTER            0
%define WL_SEAT_GET_KEYBOARD           1
%define WL_SEAT_CAPABILITIES           0
%define WL_SEAT_CAP_POINTER            1
%define WL_SEAT_CAP_KEYBOARD           2

%define WL_KEYBOARD_KEYMAP              0
%define WL_KEYBOARD_ENTER               1
%define WL_KEYBOARD_LEAVE               2
%define WL_KEYBOARD_KEY                 3
%define WL_KEYBOARD_MODIFIERS           4
%define WL_KEYBOARD_REPEAT_INFO         5

%define WL_POINTER_ENTER                0
%define WL_POINTER_LEAVE                1
%define WL_POINTER_MOTION               2
%define WL_POINTER_BUTTON               3
%define WL_POINTER_AXIS                 4

%define XDG_WM_BASE_GET_XDG_SURFACE     2
%define XDG_WM_BASE_PONG                3
%define XDG_WM_BASE_PING                0

%define XDG_SURFACE_GET_TOPLEVEL        1
%define XDG_SURFACE_ACK_CONFIGURE       4
%define XDG_SURFACE_CONFIGURE           0

%define XDG_TOPLEVEL_SET_TITLE          2
%define XDG_TOPLEVEL_SET_APP_ID         3
%define XDG_TOPLEVEL_CONFIGURE          0
%define XDG_TOPLEVEL_CLOSE              1

%macro WL_BEGIN 2
    mov     edi, %1
    mov     esi, %2
    call    wl_begin
%endmacro

%macro WL_U32 1
    mov     edi, %1
    call    wl_u32
%endmacro

%macro WL_STR 1
    lea     rdi, [%1]
    call    wl_str
%endmacro

%macro WL_END 0
    call    wl_end
%endmacro
