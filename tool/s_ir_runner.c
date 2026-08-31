#include <stdio.h>
#include <stdlib.h>
#include "../../s/src/cmd/compile/seed/error/error.h"
#include "../../s/src/cmd/compile/seed/runtime/memory.h"
#include <signal.h>
#include <sys/prctl.h>

static void print_compile_error(const compile_error *err) {
    if (!err || !error_is_set(err)) {
        return;
    }
    fprintf(stderr, "error[%d] at %zu:%zu: %s\n",
            (int)err->code, err->line, err->column, err->message);
}

bool emit_native_from_ir_file(const char *input_ir_path, const char *output_binary_path, compile_error *err) {
    (void)input_ir_path;
    (void)output_binary_path;
    error_clear(err);
    error_set(err, ERR_SEMANTIC, 0, 0, "native emission is not available in the portable runner");
    return false;
}

bool seed_bootstrap_two_stage_check(const char *compiler_source_path, const char *output_dir, compile_error *err) {
    (void)compiler_source_path;
    (void)output_dir;
    error_clear(err);
    error_set(err, ERR_SEMANTIC, 0, 0, "bootstrap is not available in the portable runner");
    return false;
}

int main(int argc, char **argv) {
    compile_error err;
    long ret = 0;
    const char *ir_path = NULL;
    const char *entry = "main";

    const char *pdeath = getenv("S_IR_RUNNER_EXIT_ON_PARENT_DEATH");
    if (pdeath && pdeath[0] == '1') {
        prctl(PR_SET_PDEATHSIG, SIGTERM);

        signal(SIGINT, SIG_DFL);
        signal(SIGTERM, SIG_DFL);
    }
    setvbuf(stdout, NULL, _IOLBF, 0);
    setvbuf(stderr, NULL, _IONBF, 0);
    error_clear(&err);
    ir_path = getenv("S_IR_RUNNER_INPUT");
    if (!ir_path || ir_path[0] == '\0') {
        if (argc >= 2) {
            ir_path = argv[1];
        }
    }
    entry = getenv("S_IR_RUNNER_ENTRY");
    if (!entry || entry[0] == '\0') {
        entry = "main";
        if (argc >= 3) {
            entry = argv[2];
        }
    }
    if (!ir_path || ir_path[0] == '\0') {
        fprintf(stderr, "usage: %s <input.ir> [entry]\n", argv[0]);
        return 2;
    }
    if (!runtime_execute_file(ir_path, entry, &ret, &err)) {
        print_compile_error(&err);
        return 1;
    }
    return (int)ret;
}
