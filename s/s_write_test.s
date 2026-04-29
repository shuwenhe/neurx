package test

func main() {
    var f = open_file_append("/tmp/s_write_test.log")
    f.write("hello\n")
    f.close()
}