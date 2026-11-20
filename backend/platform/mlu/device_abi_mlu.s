export "c:neurx_mlu_probe" func mlu_probe() int {
    // A loader observation cannot establish device availability.
    0
}

export "c:neurx_mlu_unavailable" func mlu_unavailable() int {
    -1
}

export "c:neurx_mlu_classify_loader" func mlu_classify_loader(int observation) int {
    if observation == 0 {
        return 0 // CNRT is missing or unloadable.
    }
    if observation == 1 {
        return 1 // CNRT is loadable and device execution is unvalidated.
    }
    if observation == 2 {
        return 2 // CNRT loaded and the loader reported a release failure.
    }
    -1
}

// The optional diagnostic reports observations separately from Device ABI
// availability. Enumeration alone does not validate the device lifecycle.
export "c:neurx_mlu_classify_cnrt" func mlu_classify_cnrt(int observation, int count) int {
    if observation >= 0 && observation <= 4 {
        return observation
    }
    if observation == 5 && count >= 0 && count <= 4294967295 {
        if count == 0 { return 5 }
        return 6
    }
    -1
}
