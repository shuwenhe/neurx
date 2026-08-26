







## 9. 控制流

### if/else
```s
if condition {
    // 代码块
} else {
    // 代码块
}

if x > 0 {
    y = x + 1
} else if x == 0 {
    y = 0
} else {
    y = x - 1
}
```

### while 循环
```s
let mut i = 0
while i < 10 {
    // 循环体
    i = i + 1
}
```

### for 循环
```s
for i in 0..10 {
    // i 从 0 到 9
}

for item in array {
    // 遍历数组
}
```

### switch 表达式
```s
switch value {
    case1 : { block1 },
    case2 : { block2 },
    _ : { default_block }
}

// 示例
switch color {
    "red" : { print_red() },
    "blue" : { print_blue() },
    _ : { print_unknown() }
}
```

## 10. 变量声明

### 变量定义
```s
let x = 5                   // 不可变
let mut y = 10              // 可变
let z int = 15              // 显式类型
let mut w int = 20          // 显式类型，可变
```

### 赋值
```s
x = x + 1                   // 表达式赋值
arr[0] = 42                 // 数组赋值
struct_val.field = 100      // 结构体字段赋值
```

## 11. 包和导入

### 包声明
```s
package module.submodule.name
```

### 导入
```s
use std.array.array
use std.io.print
use neurx.inference.engine
```

## 12. 错误处理

### Result 类型
```s
result[T, E]                // 成功返回 T，失败返回 E

func divide(int a, int b) result[int, string] {
    if b == 0 {
        result::err("Division by zero")
    } else {
        result::ok(a / b)
    }
}
```

### 使用 result
```s
let res = divide(10, 0)
switch res {
    result::ok(value) : { /* 处理成功 */ },
    result::err(error) : { /* 处理错误 */ }
}
```

### Option 类型
```s
option[T]                   // 可能有值或无值

func find(int[] arr, int target) option[int] {
    for i in 0..len(arr) {
        if arr[i] == target {
            return option::some(i)
        }
    }
    option::none()
}
```

### 使用 option
```s
let opt = find([1, 2, 3], 2)
switch opt {
    option::some(index) : { print(index) },
    option::none : { print("Not found") }
}
```

## 13. 向量（动态数组）

```s
use std.vec.vec

let mut v = vec[int]()
v.push(10)
v.push(20)
let len = v.len()
let value = v[0]
```

## 14. 类型转换

```s
x as int                   // 类型转换
value as float
counter as string
```

## 15. 字符串操作

```s
string + string             // 字符串拼接
len(string_val)             // 获取长度
string_val[0]               // 获取字符
```

## 16. 常见模式

### Builder 模式
```s
struct http_request {
    string method
    string path
    string body
}

func (http_request* r) set_method(string m) {
    r.method = m
}

func (http_request* r) set_path(string p) {
    r.path = p
}

func (http_request* r) set_body(string b) {
    r.body = b
}
```

### 工厂模式
```s
func new_person(string name, int age) person {
    person { name: name, age: age }
}

func new_counter() counter {
    counter { value: 0 }
}
```

## 17. 完整示例

```s
package example.calculator

use std.io.print

struct calculator {
    float last_result
}

func new_calculator() calculator {
    calculator { last_result: 0.0 }
}

func (calculator* c) add(float a, float b) float {
    c.last_result = a + b
    c.last_result
}

func (calculator* c) subtract(float a, float b) float {
    c.last_result = a - b
    c.last_result
}

func (calculator* c) multiply(float a, float b) float {
    c.last_result = a * b
    c.last_result
}

func (calculator* c) divide(float a, float b) result[float, string] {
    if b == 0.0 {
        result::err("Division by zero")
    } else {
        c.last_result = a / b
        result::ok(c.last_result)
    }
}

func (calculator c) get_last_result() float {
    c.last_result
}
```

## 18. 语法规则总结

| 概念 | 语法 | 注意 |
|------|------|------|
| 结构体 | `struct name { fields }` | 无 type 关键字 |
| 函数 | `func name(params) return { }` | 隐式返回最后表达式 |
| 方法 | `func (recv type) name(params) ret { }` | 接收者在参数前 |
| 指针 | `Type*` | 用于可变参数 |
| 数组 | `Type[]` | 固定大小或动态 |
| 多返回 | `(Type1, Type2)` | 用元组返回多值 |
| 控制流 | if/else, while, for, switch | switch 用 case : { } |
| 包 | `package a.b.c` | 层级用点分隔 |
| 导入 | `use path.module` | 导入后可直接使用 |

---

**更新**: 2026-08-26  
**作者**: NeurX 团队  
**语言版本**: S 1.0+
