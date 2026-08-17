package neurx.examples.heap_sort

func heapify(vec[int] arr, int n, int i) {
    int largest = i
    int left = 2 * i + 1
    int right = 2 * i + 2
    
    if left < n && arr[left] > arr[largest] {
        largest = left
    }
    
    if right < n && arr[right] > arr[largest] {
        largest = right
    }
    
    if largest != i {
        int temp = arr[i]
        arr[i] = arr[largest]
        arr[largest] = temp
        
        heapify(arr, n, largest)
    }
}

func heap_sort(vec[int] arr) {
    int n = len(arr)
    if n <= 1 {
        return
    }
    
    int i = n / 2 - 1
    while i >= 0 {
        heapify(arr, n, i)
        i = i - 1
    }
    
    i = n - 1
    while i > 0 {
        int temp = arr[0]
        arr[0] = arr[i]
        arr[i] = temp
        
        heapify(arr, i, 0)
        i = i - 1
    }
}

func int_to_string(int val) string {
    if val == 0 {
        return "0"
    }
    string result = ""
    int num = val
    if num < 0 {
        result = "-"
        num = 0 - num
    }
    string digits = ""
    while num > 0 {
        int digit = num % 10
        if digit == 0 { digits = "0" + digits }
        else if digit == 1 { digits = "1" + digits }
        else if digit == 2 { digits = "2" + digits }
        else if digit == 3 { digits = "3" + digits }
        else if digit == 4 { digits = "4" + digits }
        else if digit == 5 { digits = "5" + digits }
        else if digit == 6 { digits = "6" + digits }
        else if digit == 7 { digits = "7" + digits }
        else if digit == 8 { digits = "8" + digits }
        else if digit == 9 { digits = "9" + digits }
        num = num / 10
    }
    return result + digits
}

func print_array(vec[int] arr) {
    print("[")
    int i = 0
    while i < len(arr) {
        if i > 0 {
            print(", ")
        }
        print(int_to_string(arr[i]))
        i = i + 1
    }
    print("]\n")
}

func main() {
    print("=== Heap Sort Implementation in S ===\n\n")
    
    vec[int] arr = vec[int]()
    arr.push(64)
    arr.push(34)
    arr.push(25)
    arr.push(12)
    arr.push(22)
    arr.push(11)
    arr.push(90)
    
    print("Original array: ")
    print_array(arr)
    
    heap_sort(arr)
    
    print("Sorted array: ")
    print_array(arr)
    
    print("\n=== Algorithm Explanation ===\n")
    print("1. Build max heap from input array\n")
    print("2. Repeatedly extract root (max) and move to end\n")
    print("3. Heapify remaining elements\n")
    print("4. Time Complexity: O(n log n)\n")
    print("5. Space Complexity: O(1)\n")
}
