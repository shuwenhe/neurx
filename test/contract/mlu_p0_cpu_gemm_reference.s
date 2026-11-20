package main

import "neurx.platform.cpu.compute_backend."

func main() int {
    // Row-major A[2,3] times B[3,2] exercises a non-square K.
    float[] result = cpu_matmul(
        [1.0, 2.0, 3.0, 4.0, 5.0, 6.0],
        [7.0, 8.0, 9.0, 10.0, 11.0, 12.0],
        2, 3, 2
    )
    if len(result) != 4 { return 1 }
    if result[0] != 58.0 || result[1] != 64.0 || result[2] != 139.0 || result[3] != 154.0 {
        return 2
    }

    // Signed fractional inputs yield exact binary results for this fixture.
    float[] signed_result = cpu_matmul(
        [-0.5, 2.0, 0.0, -1.0],
        [2.0, 0.5, -1.0, 0.0, 1.5, 3.0],
        2, 2, 3
    )
    if len(signed_result) != 6 { return 3 }
    if signed_result[0] != -1.0 || signed_result[1] != 2.75 || signed_result[2] != 6.5 {
        return 4
    }
    if signed_result[3] != 0.0 || signed_result[4] != -1.5 || signed_result[5] != -3.0 {
        return 5
    }
    0
}
