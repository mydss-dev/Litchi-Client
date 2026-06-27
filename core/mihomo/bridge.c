#include "bridge.h"

extern void (*litchi_protect_socket_func)(void *bridge, int fd);

void litchi_protect_socket(void *bridge, int fd) {
    if (litchi_protect_socket_func != 0) {
        litchi_protect_socket_func(bridge, fd);
    }
}

void (*litchi_protect_socket_func)(void *bridge, int fd);
