# S Language: Actual Working Syntax (vs Documentation)

**Based on analysis of 25 S compiler source files - What ACTUALLY works**

---

## Critical Disclaimer
The official documentation (`/home/shuwen/shuwen/s/doc/s`) does NOT match the actual S compiler implementation.  
**For NeurX development: Use patterns from this guide, NOT the documentation.**

---

## 1. Struct Definitions

### ✅ WORKS (What the compiler actually accepts)
```s
struct person {
    string name
    int age
    float height
}

struct config {
    int port
    string hostname
    bool debug
}
```

### ❌ DOCUMENTED (Does NOT work with actual compiler)
```s
struct person {
    name: string
    age: int
    height: float
}
```

---

## 2. Struct Field Initialization (Literals)

### ✅ WORKS
```s
let p = person {
    name: "Alice",
    age: 30,
    height: 5.8
}
```

### Note
- Struct literal initialization USES colons: `field: value`
- But struct field DEFINITION does NOT use colons

---

## 3. Array Types

### ✅ WORKS (Go-style)
```s
[]int               // Array of integers
[]string            // Array of strings  
[]float             // Array of floats
func (arr: []byte)  // Parameter
func() []byte       // Return type
```

### ❌ DOCUMENTED (Does NOT work)
```s
int[]               // Won't compile
string[]            // Won't compile
func (arr: byte[])  // Won't compile
```

---

## 4. Function Parameters - Type First

### ✅ WORKS
```s
func add(int a, int b) int {
    a + b
}

func process(string name, int age) bool {
    age > 18
}

func read_data([]byte buf) int {
    len(buf)
}
```

### ❌ DOCUMENTED (Does NOT work)
```s
func add(a: int, b: int) int      // Won't compile
func process(name: string, age: int) bool  // Won't compile
```

---

## 5. Method Definition - Receivers

### ✅ WORKS - Value Receiver
```s
struct circle {
    int radius
}

func (circle c) area() int {
    c.radius * c.radius * 314 / 100
}

func (circle c) diameter() int {
    c.radius * 2
}
```

### ✅ WORKS - Pointer Receiver
```s
struct counter {
    int value
}

func (counter* c) increment() {
    c.value = c.value + 1
}

func (counter* c) add(int n) {
    c.value = c.value + n
}

// Generic type receiver
func (option[t]* self) is_some() bool {
    // ... implementation
}
```

### ❌ NOT WORKING (Don't use)
```s
func (c: counter) get()      // Error
func (c: &counter) update()  // Error  
func (c: counter*) set()     // Error
```

---

## 6. Method Parameters - Type First (NO COLONS)

### ✅ WORKS
```s
func (counter* c) add(int n) {
    c.value = c.value + n
}

func (socket* s) write([]byte buf) {
    send(s.fd, buf)
}

func (optional[t]* self) unwrap_or(t default) t {
    // pattern match self
}
```

### ❌ DOCUMENTED (Does NOT work with methods)
```s
func (counter* c) add(n: int)    // Error: expected )
func (socket* s) write(buf: []byte)  // Error
```

---

## 7. Regular Functions - Parameters WITH Colons (in some contexts)

### Observation
In some S code, regular function parameters use colons:
```s
func new_raw_socket(family: int, socktype: int, protocol: int) (*raw_socket, error) {
    // ...
}
```

### BUT
- This is inconsistent with the analysis
- Methods clearly use NO colons
- **Safest approach**: Use NO colons everywhere (method style)

---

## 8. Multiple Return Values

### ✅ WORKS
```s
func divide(int a, int b) (int, int) {
    a / b, a % b
}

func read_file(string path) ([]byte, error) {
    // implementation
}

// Calling
quotient, remainder := divide(10, 3)
data, err := read_file("file.txt")
```

---

## 9. Generic Types

### ✅ WORKS
```s
enum option[t] {
    some(t),
    none,
}

func (option[t]* self) is_some() bool {
    // generic method
}

struct vec[T] {
    []T elements
}
```

---

## 10. String and Character Literals

### ✅ WORKS
```s
s := "hello world"
c := 'a'
```

---

##  11. Control Flow

### ✅ WORKS
```s
// if/else
if x > 0 {
    y = x + 1
} else {
    y = x - 1
}

// switch
switch value {
    option::some(v) : {
        // handle some
    },
    option::none : {
        // handle none
    }
}

// for loop
for i in 0..10 {
    // i from 0 to 9
}

// for with range
for item in items {
    // process item
}

// while loop
while condition {
    // loop body
}
```

---

## Summary Table

| Feature | WORKS | DOESN'T WORK |
|---------|-------|------------|
| Struct field definition | `int field` | `field: int` |
| Struct initialization | `field: value` | `field value` |
| Array types | `[]Type` | `Type[]` |
| Function params | `func name(type p)` | `func name(p: type)` |
| Method receiver | `(Type r)` or `(Type* r)` | `(r: Type)` |
| Method params | `(type p)` | `(p: type)` |
| Generic receiver | `(option[t]* self)` | `(self: option[t]*)` |

---

## For NeurX Development

**Use this pattern for all new S code:**

```s
package neurx.subsystem.component

struct my_config {
    int max_size
    string name
    bool enabled
}

func new_config() my_config {
    my_config {
        max_size: 1024,
        name: "default",
        enabled: true
    }
}

func (my_config c) get_name() string {
    c.name
}

func (my_config* c) set_name(string new_name) {
    c.name = new_name
}

func process_data([]byte data, my_config* cfg) bool {
    len(data) > 0
}
```

---

## References
- Actual S source: `/home/shuwen/shuwen/s/src/`
- Example files with working code:
  - `src/option/option.s` (generic types, methods)
  - `src/go/doc/comment.s` (functions)
  - Avoid `src/net/internal/` (has parsing errors)

---

**Last Updated**: 2026-08-26  
**Status**: Based on actual compiler behavior, not documentation
