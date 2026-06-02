# Neurx Skills System Example

This directory contains examples of how to register and use skills in the Neurx agent.

## Built-in Skills

The following categories of skills are available:

### 1. Analysis Skills (`org.neurx.skill.analysis.*`)
- `code-review` - Review code for issues
- `error-analysis` - Analyze error messages
- `performance-analysis` - Analyze performance metrics
- `security-analysis` - Security vulnerability analysis

### 2. Writing Skills (`org.neurx.skill.writing.*`)
- `document-writer` - Create technical documentation
- `code-commenter` - Add comments to code
- `test-case-writer` - Generate test cases
- `changelog-writer` - Generate changelog entries

### 3. Coding Skills (`org.neurx.skill.coding.*`)
- `code-generator` - Generate code from specifications
- `refactor-code` - Suggest code refactoring
- `bug-fixer` - Analyze and suggest fixes
- `test-generator` - Generate unit tests

### 4. Integration Skills (`org.neurx.skill.integration.*`)
- `git-integration` - Git operations
- `file-operations` - File system operations
- `web-scraping` - Web page analysis
- `api-caller` - Call external APIs

## Registering Custom Skills

```cpp
// Create skill capability
SkillCapability skill;
skill.skillId = "org.neurx.skill.custom.my-skill";
skill.name = "My Custom Skill";
skill.description = "Does something useful";

// Define input parameters
SkillParameter param;
param.name = "input_text";
param.description = "Text to process";
param.type = "string";
param.required = true;

skill.input.parameters.append(param);
skill.output.description = "Processed result";
skill.output.type = "object";

// Register with skill manager
skillManager->registerSkill(skill, [](bool success) {
    if (success) {
        qDebug() << "Skill registered successfully";
    }
});
```

## Using Skills

```cpp
// Invoke a skill
SkillInvocation invocation;
invocation.skillId = "org.neurx.skill.analysis.code-review";
invocation.parameters["code"] = "// Code to review";
invocation.invocationId = QUuid::createUuid().toString();

skillManager->invokeSkill(invocation, [](const SkillResult &result) {
    if (result.success) {
        qDebug() << "Result:" << result.output;
    }
});
```

## LLM Context Integration

Skills are automatically suggested in LLM context based on relevance:

```cpp
// Get relevant skills for a user query
auto skills = skillManager->getRelevantSkills(
    "review this code",
    context,
    5  // max 5 skills
);

// Render for LLM context
auto mentions = skillManager->getSkillsForLLMContext(context);
QString skillText = skillManager->renderSkillsForLLM(mentions);
// Include skillText in LLM prompt
```

## Skill Availability

Skills can be disabled or hidden from the LLM:

```cpp
// Disable a skill
skillManager->setSkillEnabled("org.neurx.skill.analysis.code-review", false);

// Set skill policy
skillManager->setSkillPolicy(
    "org.neurx.skill.custom.experimental",
    SkillPolicy::OnDemand  // Only suggest explicitly
);
```

## Monitoring

Track skill usage and performance:

```cpp
// Get skill statistics
auto stats = skillManager->getSkillStats("org.neurx.skill.analysis.code-review");
qDebug() << "Invocations:" << stats["invocationCount"];
qDebug() << "Success rate:" << (stats["successCount"].toInt() / stats["invocationCount"].toDouble());

// Get invocation history
auto history = skillManager->getSkillHistory("org.neurx.skill.analysis.code-review", 10);
for (const auto &result : history) {
    qDebug() << "Result at" << result.completedAt << ":" << result.success;
}
```
