package neurx.ad.eqn

struct jaxpr_eqn {
    string primitive
    []string params
    []string inputs
    []string outputs
}

func _copy_strings([]string values) []string {
    []string out = []string{cap: len(values)}
    int i = 0
    while i < len(values) {
        out[i] = values[i]
        i = i + 1
    }
    out
}

func copy_eqn(jaxpr_eqn eqn) jaxpr_eqn {
    jaxpr_eqn {
        primitive: eqn.primitive,
        params: _copy_strings(eqn.params),
        inputs: _copy_strings(eqn.inputs),
        outputs: _copy_strings(eqn.outputs),
    }
}

func copy_eqns([]jaxpr_eqn values) []jaxpr_eqn {
    []jaxpr_eqn out = []jaxpr_eqn{cap: len(values)}
    int i = 0
    while i < len(values) {
        out[i] = copy_eqn(values[i])
        i = i + 1
    }
    out
}
