package neurx.test_version

use neurx.version.{version}

func main() int {
    if version() == "" {
        println("version empty")
        return 1
    }
    println("version test passed")
    0
}