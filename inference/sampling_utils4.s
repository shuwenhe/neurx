package neurx.inference.sampling










func sample_from_distribution([]float probs, uint64 rng_state) int {
    if len(probs) == 0 { return -1 }


    float r = random_float_01(advance_rng(rng_state))


    float cumsum = 0.0

    for i in 0..len(probs) {
        cumsum = cumsum + probs[i]
        if r < cumsum {
            return i
        }
    }


    len(probs) - 1
}






func sample_from_softmax(
    []float logits,
    float temperature,
    uint64 rng_state
) (int, uint64) {
    []float scaled = apply_temperature(logits, temperature)
    []float probs = softmax(scaled)

    int idx = sample_from_distribution(probs, rng_state)

    (idx, advance_rng(rng_state))
}
