# NeurX Code 自动滚动问题 - 故障排查方案

## 问题描述
"Agent 现在不能自动滚动屏幕了"

## 可能的原因

### 1. **Agent 无法生成回复**（最可能）
如果 Agent 没有生成新消息，就不会有滚动。
- 检查 Agent 是否正确初始化
- 查看是否有工具相关的错误
- 验证 LLM 连接是否正常

### 2. **autoFollowLatest 被意外设置为 false**
- 应用启动时应为 `true`
- 只有手动向上滚动时才变为 `false`
- 点击"↓"按钮应恢复为 `true`

### 3. **消息模型没有被正确更新**
- ChatModel 可能没有收到新消息
- ListView 可能没有更新行数

### 4. **与最近修改的关系**（低概率）
虽然工具注册修改不应直接影响滚动，但可能存在以下间接影响：
- 工具注册延迟导致 Agent 初始化问题
- 信号连接顺序改变

## 快速测试步骤

### 第1步：验证消息是否被添加
1. 打开应用
2. 打开工作空间
3. 在 Agent 中输入一个简单的请求："Hello"
4. **预期结果**：应该看到 Agent 的回复并自动滚动到底部

### 第2步：检查 autoFollowLatest 状态
1. 打开开发者工具（如果可用）
2. 检查 ChatPanel.autoFollowLatest 的值
3. **预期结果**：默认应为 `true`

### 第3步：手动滚动测试
1. 手动向上滚动列表
2. 观察右下角是否出现"↓"按钮
3. 点击"↓"按钮
4. **预期结果**：列表应滚动到底部，autoFollowLatest 应变为 `true`

### 第4步：检查应用日志
```bash
# 运行应用并查看调试输出
QT_LOGGING_RULES='*=true' \
  /Users/feifei/agent/neurx-code/build/neurx-codeApp.app/Contents/MacOS/neurx-codeApp \
  2>&1 | grep -E "scrollToBottom|autoFollowLatest|onBusyChanged|onStreamingTextChanged"
```

查找以下关键日志：
- `[ChatPanel] scrollToBottom called`
- `[ChatPanel] onBusyChanged`
- `[ChatPanel] onStreamingTextChanged`
- `[ChatModel] append()`

## 可能的解决方案

### 方案 A：重新编译（推荐）
```bash
cd /Users/feifei/agent/neurx-code/build
make clean
make -j4
```

### 方案 B：检查 QML 编译错误
确保没有 QML 编译或绑定错误。

### 方案 C：回滚最近的修改
如果确认问题由最近修改引起，可以回滚：
```bash
git revert b71d984  # 工具注册修复 commit
```

### 方案 D：调试信号连接
在 ChatPanel.qml 中添加临时的调试日志：
```qml
onBusyChanged: {
    console.log("ChatPanel: busy changed to", root.busy)
    if (root.busy && root.autoFollowLatest)
        root.scrollToBottom()
}

onStreamingTextChanged: {
    console.log("ChatPanel: streamingText changed, length =", root.streamingText.length)
    if (root.autoFollowLatest && (root.busy || root.streamingText.length > 0))
        root.scrollToBottom()
}
```

## 关键代码位置

### ChatPanel.qml (滚动逻辑)
- 第 832 行：`scrollToBottom()` 函数
- 第 887-893 行：`onBusyChanged` 和 `onStreamingTextChanged` 信号处理

### AgentController.cpp (消息处理)
- 第 4270 行：`onMessageAdded()` 函数
- 第 880 行：`ChatModel::append()` 函数

## 验证修复

完成修复后，验证以下：
1. ✅ 新消息时，列表自动滚动到底部
2. ✅ Agent 生成回复时，列表自动滚动
3. ✅ 手动滚动后，能通过"↓"按钮回到底部
4. ✅ 再次 Agent 回复时，自动跟随恢复正常

## 提交反馈

请提供以下信息以便进一步诊断：
1. 具体现象（新消息不滚动/Agent 回复不滚动/两者都不滚动）
2. 应用启动时是否有错误消息
3. 上述测试步骤的结果
4. 日志输出中是否有相关错误信息
5. 最近是否有其他修改或环境变化

---

**最后更新**: 2026-06-04
**诊断版本**: 1.0
