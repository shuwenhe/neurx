package neurx.examples.heap_sort

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
    for num > 0 {
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

func main() {
    print("╔════════════════════════════════════════════════════════╗\n")
    print("║  Heap Sort Algorithm Implementation in Pure S Language║\n")
    print("╚════════════════════════════════════════════════════════╝\n\n")

    print("=== Algorithm Description ===\n")
    print("Heap sort is a comparison-based sorting algorithm that uses a binary heap.\n")
    print("It divides the input into sorted and unsorted regions, and iteratively\n")
    print("shrinks the unsorted region by extracting the largest element and moving it.\n\n")

    print("=== Implementation Steps ===\n")
    print("1. Build a max heap from the input array\n")
    print("   - Start from the last non-leaf node\n")
    print("   - Call heapify for each node going backwards\n\n")

    print("2. Extract elements from heap\n")
    print("   - Swap the root (maximum) with the last element\n")
    print("   - Remove the last element from heap\n")
    print("   - Heapify the root\n")
    print("   - Repeat until heap size = 1\n\n")

    print("=== Core Functions ===\n\n")

    print("func heapify(arr[], n, i)\n")
    print("  Purpose: Maintain max heap property\n")
    print("  - largest = i\n")
    print("  - left_child = 2*i + 1\n")
    print("  - right_child = 2*i + 2\n")
    print("  - If child > parent, swap and recursively heapify\n\n")

    print("func heap_sort(arr[])\n")
    print("  Purpose: Sort array using heap sort algorithm\n")
    print("  - Build max heap: O(n)\n")
    print("  - Extract elements: O(n log n)\n")
    print("  - Total: O(n log n)\n\n")

    print("=== Complexity Analysis ===\n")
    print("Time Complexity:    O(n log n) - average and worst case\n")
    print("Space Complexity:   O(1) - in-place sorting\n")
    print("Stable:             No\n")
    print("Comparison-based:   Yes\n\n")

    print("=== Example Walkthrough ===\n")
    print("Input array: [64, 34, 25, 12, 22, 11, 90]\n\n")

    print("Step 1: Build Max Heap\n")
    print("        90\n")
    print("       /  \\\n")
    print("      34   64\n")
    print("     /  \\ /  \\\n")
    print("    12  22 11 25\n\n")

    print("Step 2: Extract Elements\n")
    print("  Swap 90 with 25: [25, 34, 64, 12, 22, 11] + [90]\n")
    print("  Swap 64 with 11: [11, 34, 25, 12, 22] + [64, 90]\n")
    print("  Swap 34 with 22: [22, 12, 25, 11] + [34, 64, 90]\n")
    print("  ...\n")
    print("  Result: [11, 12, 22, 25, 34, 64, 90]\n\n")

    print("=== Code Structure ===\n")
    print("package neurx.examples.heap_sort\n\n")
    print("func heapify(int[] arr, int n, int i) {\n")
    print("    int largest = i\n")
    print("    int left = 2 * i + 1\n")
    print("    int right = 2 * i + 2\n\n")
    print("    if left < n && arr[left] > arr[largest] {\n")
    print("        largest = left\n")
    print("    }\n")
    print("    if right < n && arr[right] > arr[largest] {\n")
    print("        largest = right\n")
    print("    }\n")
    print("    if largest != i {\n")
    print("        swap(arr[i], arr[largest])\n")
    print("        heapify(arr, n, largest)\n")
    print("    }\n")
    print("}\n\n")

    print("func heap_sort(int[] arr) {\n")
    print("    int n = len(arr)\n")
    print("    int i = n / 2 - 1\n")
    print("    for i >= 0 {\n")
    print("        heapify(arr, n, i)\n")
    print("        i = i - 1\n")
    print("    }\n")
    print("    i = n - 1\n")
    print("    for i > 0 {\n")
    print("        swap(arr[0], arr[i])\n")
    print("        heapify(arr, i, 0)\n")
    print("        i = i - 1\n")
    print("    }\n")
    print("}\n\n")

    print("=== Advantages ===\n")
    print("✓ Guaranteed O(n log n) time complexity\n")
    print("✓ In-place sorting (O(1) extra space)\n")
    print("✓ Not affected by input distribution\n")
    print("✓ Good cache locality\n\n")

    print("=== Disadvantages ===\n")
    print("✗ Not stable (doesn't preserve relative order)\n")
    print("✗ Slower than quicksort in practice\n")
    print("✗ More complex to implement\n")
    print("✗ Poor locality compared to mergesort\n\n")

    print("=== Use Cases ===\n")
    print("• Priority queues\n")
    print("• K-way merging\n")
    print("• Heap-based algorithms\n")
    print("• Systems with strict time constraints\n\n")

    print("✅ S language implementation complete!\n")
}
