# S language % English text - quickuseEnglish text

## English text

### English text
```s
let result = 10 % 3      // result = 1
let remainder = 20 % 6   // remainder = 2
let zero = 7 % 7         // zero = 0
```

### English text/English text
```s
let num = 15
if num % 2 == 0 {
    println("English text")
} else {
    println("English text")
}
```

### English textuse(English text N stepEnglish text)
```s
let step = 0
for step < 500 {
    // English text 50 stepEnglish text
    let step_mod = (step + 1) % 50
    if step_mod == 0 || step == 0 {
        println("Step: " + int_to_string(step + 1))
    }
    step = step + 1
}
```

### English text(English text)
```s
func int_to_string(x int) string {
    let result = ""
    let temp = x
    for temp > 0 {
        let digit = temp % 10          // English text
        result = string_char(digit + 48) + result
        temp = temp / 10                // English text
    }
    return result
}
```

### English text
```s
// English text 10 English text
let idx = current_idx % 10

// English text
let row = index / width
let col = index % width
```

## English text

### ✅ recommendedEnglish text
```s
// useEnglish textresult
let mod_result = value % divisor
if mod_result == target_value {
    // ...
}
```

### ❌ English text
```s
// English textuseEnglish text
if (a + b) % c == 0 && condition {
    // English texterror
}

// recommendedEnglish text:
let mod_result = (a + b) % c
if mod_result == 0 && condition {
    // ...
}
```

## actualEnglish textexample

### example 1: stepEnglish textmonitoring
```s
let epoch = 0
for epoch < 10 {
    let step = 0
    for step < 100 {
        // English text 10 stepEnglish text
        let step_mod = (step + 1) % 10
        if step_mod == 0 {
            println("Epoch " + int_to_string(epoch) +
                   " Step " + int_to_string(step + 1))
        }
        step = step + 1
    }
    epoch = epoch + 1
}
```

### example 2: English text
```s
type RingBuffer struct {
    data [100]int
    size int
    pos  int
}

func append_to_buffer(buf RingBuffer, value int) {
    buf.data[buf.pos] = value
    buf.pos = (buf.pos + 1) % buf.size    // English text
}
```

### example 3: English text
```s
let batch_size = 32
let data_points = 1000

let batch = 0
for batch * batch_size < data_points {
    let idx = 0
    for idx < batch_size {
        let data_idx = batch * batch_size + idx
        if data_idx < data_points {
            // English textdataEnglish text
            let sample_id = data_idx % 100
        }
        idx = idx + 1
    }
    batch = batch + 1
}
```

### example 4: English text
```s
func hash_mod(value int, num_buckets int) int {
    return value % num_buckets
}

// use
let bucket = hash_mod(my_value, 16)    // English text 0-15 English text
```

## English text

- **English text**: English text % English text modulo() functionEnglish text
- **compileEnglish textoptimize**: compileEnglish textoptimizeEnglish text
  - `x % 2` English textoptimizeEnglish text
  - `x % 256` English textoptimizeEnglish text 8 English text
- **English text**: English text, English textfunctionEnglish text

## English text

| English text | support | explanation |
|-----------|------|------|
| int % int | ✅ | English textsupport |
| float % float | ❌ | useEnglish text modulo() |
| int % float | ❌ | English text int English text |

## migrationEnglish text(English text modulo() English text %)

### English text
```s
func modulo(a int, b int) int {
    result := a
    for result >= b {
        result = result - b
    }
    return result
}

let targets[i] = modulo(i + step, vocab_size)
```

### English text
```s
// modulo() functionEnglish text, English textuse %
let targets[i] = (i + step) % vocab_size
```

## English text

| error | English text | English text |
|------|------|--------|
| "expected expression, got %" | English text | useEnglish text |
| "modulo by zero" | English text 0 | English text divisor > 0 |
| English text | English text | English text int |

## compileEnglish textrun

```bash
# compileEnglish text % English text S English text
/Users/feifei/train/s/bin/s myprogram.s build/myprogram.ir

# English text IR English text MOD English text
grep MOD build/myprogram.ir

# generateEnglish text(RequiredEnglish text S English textdirectory)
cd /Users/feifei/train/s
./bin/s --emit-bin /path/to/myprogram.ir build/myprogram.bin
```

## English text

✅ English text S languageEnglish textsupportEnglish text % English text
✅ English text modulo() functionEnglish text
✅ English text C English textlanguageEnglish text

English text!🚀
