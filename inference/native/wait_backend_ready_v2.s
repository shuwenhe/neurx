package neurx.inference.native



func main() {
    string host = "127.0.0.1"
    int port = 18083
    int max_attempts = 300
    int attempt = 0
    print("[HealthCheck] Waiting for backend...\n")
    while attempt < max_attempts {
        attempt = attempt + 1

        int sock = __sys_socket(2, 1, 6)
        if sock < 0 {

            int wait = 0
            while wait < 50000 { wait = wait + 1 }
            continue
        }

        int result = __sys_connect(sock, host, port, 2)
        _ = __sys_close(sock)
        if result == 0 {

            print("[HealthCheck] ✅ Backend ready on attempt ")
            print_number(attempt)
            print("\n")
            print("[HealthCheck] Success! Backend ready\n")
            return
        }

        int wait = 0
        while wait < 50000 { wait = wait + 1 }

        if attempt % 50 == 0 || attempt <= 5 {
            print("[HealthCheck] Attempt ")
            print_number(attempt)
            print("\n")
        }
    }

    print("[HealthCheck] Timeout after ")
    print_number(max_attempts)
    print(" attempts\n")
}

func print_number(int n) {
    if n < 10 {
        if n == 0 { print("0") }
        if n == 1 { print("1") }
        if n == 2 { print("2") }
        if n == 3 { print("3") }
        if n == 4 { print("4") }
        if n == 5 { print("5") }
        if n == 6 { print("6") }
        if n == 7 { print("7") }
        if n == 8 { print("8") }
        if n == 9 { print("9") }
    } else if n < 100 {
        print_number(n / 10)
        print_number(n % 10)
    } else if n < 1000 {
        print_number(n / 100)
        print_number(n % 100)
    } else {
        print("?")
    }
}
