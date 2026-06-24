#include <stdio.h>
#include <stdlib.h>

#include "../../s/src/cmd/compile/seed/error/error.h"
#include "../../s/src/cmd/compile/seed/runtime/memory.h"

static void print_compile_error(const compile_error *err) {
    if (!err || !error_is_set(err)) {
        return;
    }
    fprintf(stderr, "error[%d] at %zu:%zu: %s\n",
            (int)err->code, err->line, err->column, err->message);
}

int main(int argc, char **argv) {
    compile_error err;
    long ret = 0;
    const char *ir_path = NULL;
    const char *entry = "main";

    error_clear(&err);

    if (argc < 2 || argc > 3) {
        fprintf(stderr, "usage: %s <input.ir> [entry]\n", argv[0]);
        return 2;
    }

    ir_path = argv[1];
    if (argc == 3) {
        entry = argv[2];
    }

    if (!runtime_execute_file(ir_path, entry, &ret, &err)) {
        print_compile_error(&err);
        return 1;
    }

    return (int)ret;
}
