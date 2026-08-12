package neurx.autograd.eqn
use neurx.strings
struct ir_eqn {
    string primitive
    []string params
    []string inputs
    []string outputs
}

func copy_eqn(ir_eqn eqn) ir_eqn {
    ir_eqn {
        primitive: eqn.primitive,
        params: copy_strings(eqn.params),
        inputs: copy_strings(eqn.inputs),
        outputs: copy_strings(eqn.outputs),
    }
}

func copy_eqns([]ir_eqn values) []ir_eqn {
    []ir_eqn out = []ir_eqn{cap: len(values)}
    int i = 0
    while i < len(values) {
        out[i] = copy_eqn(values[i])
        i = i + 1
    }
    out
}

