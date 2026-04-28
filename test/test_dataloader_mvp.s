package neurx.test_dataloader_mvp

use neurx.dataloader_mvp.{new_state, has_next, next_batch}

func main() int {
    let state = new_state([1, 2, 3, 4, 5, 6, 7], 2, 2)
    if !has_next(state) {
        println("dataloader has_next=false")
        return 1
    }

    let output = next_batch(state)
    println("input_ids: ", output.batch.input_ids)
    println("target_ids: ", output.batch.target_ids)
    println("valid_tokens: ", output.batch.valid_tokens)
    0
}
