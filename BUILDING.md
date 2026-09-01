# 构建和编译指南

## 编译产物说明

### ❌ 不应该提交的文件

| 文件类型 | 说明 | 例子 |
|---------|------|------|
| `.o` | 目标文件（对象代码） | `tensor_runtime.o` |
| `.a` | 静态库 | `libneural.a` |
| `.so` | 共享库 | `libneurx.so` |
| `*.elf` | 可执行文件 | `model.elf` |
| `build/` | 构建目录 | 所有中间产物 |

**为什么不提交：**
- 📦 **大小**：每个 `.o` 文件通常 100KB-1MB，仓库会变得很大
- 🔧 **不可移植**：`.o` 文件依赖特定的编译器版本、优化标志、平台架构
- 🔄 **冗余**：可以通过源代码重新生成
- 👥 **合并冲突**：不同开发者编译生成的 `.o` 文件二进制不同

### ✅ 应该提交的文件

```
✓ .s 源代码
✓ Makefile / 构建脚本
✓ .gitignore 规则
✓ 文档和配置
✓ 预编译的 release 二进制（可选）
```

## 构建流程

### 第一次克隆后

```bash
cd neurx
make clean        # 清除任何旧的构建
make build        # 从源代码编译所有内容
make test         # 运行测试
```

### 日常开发

```bash
make rebuild      # 重新编译改动的文件
make run          # 编译并运行
make clean        # 删除所有编译产物
```

## .gitignore 规则

项目中已配置 `.gitignore`，会自动忽略：

```
# 编译产物
*.o *.a *.so
build/ dist/ target/

# 编译输出
*.elf *.bin *.hex

# 缓存
__pycache__/ .pytest_cache/

# IDE
.vscode/ .idea/

# 环境
.env venv/
```

**如果不小心提交了 `.o` 文件**，使用：

```bash
# 删除 Git 缓存中的文件（不删除本地）
git rm --cached artifact/build/**/*.o

# 或强制清理历史
git filter-branch --tree-filter 'rm -f *.o' HEAD
```

## 分发二进制

对于发布版本，可以：

1. **构建 release**
   ```bash
   make release    # 生成 dist/neurx-release.tar.gz
   ```

2. **上传预编译二进制**
   ```
   releases/
   ├── neurx-v1.0-linux-x86_64.tar.gz
   ├── neurx-v1.0-linux-arm64.tar.gz
   └── neurx-v1.0-macos-x86_64.tar.gz
   ```

3. **使用版本标签**
   ```bash
   git tag -a v1.0 -m "Release version 1.0"
   git push origin v1.0
   ```

## 常见问题

### Q: 我的构建很慢，能否提交 `.so` 文件来加速？
**A:** ❌ 不建议。改为：
- 使用增量构建：`make` 只重新编译改动的文件
- 使用 ccache：`ccache make`
- 在 CI/CD 中缓存构建产物

### Q: 我克隆后没有可执行文件？
**A:** 正常的。运行 `make build` 来编译源代码。

### Q: 如何清理本地构建但保留源代码？
**A:** 运行 `make clean`

---

**更新日期**: 2026-09-01  
**维护**: NeurX 构建系统
