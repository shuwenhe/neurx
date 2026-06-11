#include "neurx_bridge.h"
#include <stdio.h>

void neurx_init() {
    // initialize S runtime, allocators, device contexts
    printf("neurx: init\n");
}

void neurx_shutdown() {
    // cleanup
    printf("neurx: shutdown\n");
}
