# Claude Skills System - Quick Start Guide

## Overview

The Claude Skills System provides NeurX with a powerful, extensible framework for managing agent capabilities through modular, discoverable skills. This guide gets you up and running in 5 minutes.

## Installation

The skill system is integrated into NeurX. No additional installation needed, but you need to:

1. **Set up skills directory**:
   ```bash
   mkdir -p ~/.hermes/skills
   ```

2. **Add to your NeurX code** (during agent initialization):
   ```cpp
   #include "skills/ClaudeSkillManager.h"
   
   auto skillManager = std::make_unique<ClaudeSkillManager>();
   skillManager->initialize("~/.hermes/skills");
   skillManager->setPlatform(Platform::macOS);  // or Linux, Windows
   ```

3. **Build with updated CMakeLists.txt** (includes new source files)

## Create Your First Skill

1. Create `~/.hermes/skills/SKILL.md`:

```yaml
---
name: hello-world
description: A simple hello world skill
version: 1.0.0
author: Your Name
platforms: [macos, linux, windows]
tags: [demo, greeting]
---

# Hello World Skill

This is a simple demonstration skill.

## Usage

```bash
skill exec hello-world -- greet "World"
```

## Examples

- `skill exec hello-world -- greet "Alice"`
- `skill exec hello-world -- greet "Bob"`

## Integration

You can call this skill from the agent:

```
Agent: I'll use the hello-world skill to greet the user.
```
```

2. Test discovery:
   ```cpp
   skillManager->getSkillsList([](const auto &items) {
       for (const auto &item : items) {
           qDebug() << "Found skill:" << item.name;
       }
   });
   ```

## Basic Usage Patterns

### 1. List All Available Skills

```cpp
skillManager->getSkillsList([](const QVector<SkillListingItem> &items) {
    qDebug() << "Available skills:";
    for (const auto &item : items) {
        qDebug() << "  -" << item.name << ":" << item.description;
    }
});
```

### 2. Search for Skills

```cpp
skillManager->searchSkills(
    "music",                                    // query
    {"audio", "media"},                         // tags
    10,                                         // max results
    [](const SkillSearchResult &result) {
        qDebug() << "Found" << result.matchedCount << "matching skills";
    }
);
```

### 3. Get Complete Skill Information

```cpp
skillManager->getSkillView(
    "spotify-playback",
    [](const SkillViewItem &view) {
        qDebug() << "Skill:" << view.basicInfo.name;
        qDebug() << "Version:" << view.version;
        qDebug() << "Author:" << view.author;
    }
);
```

### 4. Generate LLM Context (Most Important!)

```cpp
// Tier 1 (most efficient, ~50 tokens)
QString context = skillManager->getSkillsContextMarkdown(1, 15);

// Add to LLM prompt before making request
QString prompt = "You are a helpful assistant.\n\n";
prompt += context;
prompt += "\n\nUser: " + userRequest;

// Send to LLM model...
```

### 5. Check if Skill is Available

```cpp
SkillAvailabilityCheck check = skillManager->checkSkillAvailability("spotify-playback");

if (check.platformSupported && check.environmentReady) {
    qDebug() << "Skill is available!";
} else {
    if (!check.platformSupported) {
        qDebug() << "Not supported on this platform:" << check.platformReason;
    }
    if (!check.environmentReady) {
        qDebug() << "Missing vars:" << check.missingEnvironmentVariables;
    }
}
```

### 6. Collect Environment Variables

```cpp
if (!skillManager->areEnvironmentVariablesReady("spotify-playback")) {
    skillManager->collectEnvironmentVariables(
        "spotify-playback",
        // Prompt for regular variable
        [](const QString &prompt, const QString &help) -> QString {
            return showPromptDialog(prompt, help);
        },
        // Prompt for secret (password field)
        [](const QString &prompt) -> QString {
            return showPasswordDialog(prompt);
        },
        // Result callback
        [](bool success, const QString &error) {
            if (success) {
                qDebug() << "Environment ready!";
            } else {
                qWarning() << "Error:" << error;
            }
        }
    );
}
```

## Complete Integration Example

```cpp
#include "skills/ClaudeSkillManager.h"

class MyAgent {
private:
    std::unique_ptr<ClaudeSkillManager> m_skills;
    
public:
    MyAgent() {
        // Initialize skills system
        m_skills = std::make_unique<ClaudeSkillManager>();
        QString error = m_skills->initialize("~/.hermes/skills");
        if (!error.isEmpty()) {
            qWarning() << "Skills failed:" << error;
            return;
        }
        
        m_skills->setPlatform(Platform::macOS);
        qDebug() << "Discovered" << m_skills->getSkillCount() << "skills";
    }
    
    void processUserRequest(const QString &request) {
        // Generate LLM prompt with available skills
        QString prompt = buildLLMPrompt(request);
        
        // Send to LLM (e.g., Claude API)
        sendToLLM(prompt, [this](const QString &response) {
            // Process LLM response and execute skills if requested
            handleLLMResponse(response);
        });
    }
    
private:
    QString buildLLMPrompt(const QString &userRequest) {
        QString prompt = "You are a helpful assistant with access to the following tools:\n\n";
        
        // Add available skills (Tier 1 is most efficient)
        prompt += m_skills->getSkillsContextMarkdown(1, 20);
        
        prompt += "\n\nUser request: " + userRequest;
        return prompt;
    }
    
    void handleLLMResponse(const QString &response) {
        // Parse if LLM is calling a skill...
        if (response.contains("skill exec")) {
            // Extract and execute skill
            QString skillId = extractSkillId(response);
            executeSkill(skillId);
        }
    }
    
    void executeSkill(const QString &skillId) {
        // Ensure environment is ready first
        if (!m_skills->areEnvironmentVariablesReady(skillId)) {
            m_skills->collectEnvironmentVariables(
                skillId,
                [this](auto p, auto h) { return promptUser(p, h); },
                [this](auto p) { return promptSecret(p); },
                [this, skillId](bool ok, auto err) {
                    if (ok) executeSkillNow(skillId);
                }
            );
        } else {
            executeSkillNow(skillId);
        }
    }
    
    void executeSkillNow(const QString &skillId) {
        // Get full skill information
        ClaudeSkill skill = m_skills->getSkillWithContent(skillId);
        
        // Execute skill (implementation depends on your system)
        qDebug() << "Executing:" << skill.metadata.name;
        // ... your execution logic here
    }
};
```

## Skill File Best Practices

### Minimal Skill

```yaml
---
name: my-skill
description: Brief description
version: 1.0.0
---

# Documentation
```

### Complete Skill

```yaml
---
name: my-skill
description: What this does (≤1024 chars)
version: 1.0.0
author: Your Name
maintainer: Maintainer Name
category: integration
license: MIT
platforms: [macos, linux, windows]
tags: [tag1, tag2]
deprecated: false

required_environment_variables:
  - name: API_KEY
    prompt: "Enter your API key"
    help: "Get from https://example.com"
    required: true
    secret: true

prerequisites:
  - type: command
    name: curl
    checkCommand: "curl --version"
    installCommand: "brew install curl"

related_skills: [other-skill]
---

# Full Documentation

Complete markdown with examples, edge cases, troubleshooting...
```

## Tier Selection Guide

### When to Use Tier 1 (~50 tokens)
- Initial skill discovery
- Generating list of available tools
- When token budget is tight
- First request in a conversation
- Default choice for efficiency

### When to Use Tier 2 (~500 tokens)
- Showing more details about specific skills
- Planning which skills to use
- Checking environment requirements
- Detailed help text

### When to Use Tier 3 (~1500 tokens)
- Full skill documentation with examples
- Before executing complex skills
- Troubleshooting skill issues
- Teaching user how to use skills

```cpp
// Default - use Tier 1
QString context = skillManager->getSkillsContextMarkdown(1);

// More details
QString context = skillManager->getSkillsContextMarkdown(2);

// Full documentation
QString context = skillManager->getSkillsContextMarkdown(3);
```

## Common Workflows

### 1. Initialize on App Startup
```cpp
void initializeSkills() {
    auto skills = std::make_unique<ClaudeSkillManager>();
    skills->initialize("~/.hermes/skills");
    skills->setPlatform(getCurrentPlatform());
    
    // Global or member variable for later use
    g_skillManager = std::move(skills);
}
```

### 2. Check Skills on Platform Change
```cpp
void onPlatformChanged(Platform newPlatform) {
    g_skillManager->setPlatform(newPlatform);
    
    // Refresh availability
    g_skillManager->checkAllAvailability(
        [](const auto &checks) {
            for (const auto &check : checks) {
                qDebug() << check.skillId << "available:" << check.platformSupported;
            }
        }
    );
}
```

### 3. Periodically Check for Skill Updates
```cpp
void startSkillWatcher() {
    auto timer = new QTimer();
    connect(timer, &QTimer::timeout, [this]() {
        g_skillManager->checkForModifications();  // Auto-reloads changed skills
    });
    timer->start(5000);  // Check every 5 seconds
}
```

### 4. Build Agent Prompt with Skills
```cpp
QString buildAgentPrompt(const QString &userQuery) {
    QString prompt = R"(
You are Claude, a helpful AI assistant.

You have access to these tools:

)";
    
    prompt += g_skillManager->getSkillsContextMarkdown(1, 15);
    
    prompt += "\n\nUser: " + userQuery;
    
    return prompt;
}
```

## Troubleshooting

### Skills Not Discovered
```
Problem: getSkillCount() returns 0
Solution: Check ~/.hermes/skills/ exists and contains SKILL.md files
```

### "File not found" error
```
Problem: initialize() returns error
Solution: Create ~/.hermes/skills directory first: mkdir -p ~/.hermes/skills
```

### Environment variables not set
```
Problem: areEnvironmentVariablesReady() returns false
Solution: Call collectEnvironmentVariables() to prompt user
```

### Skills appearing unavailable
```
Problem: platformSupported is false
Solution: Check platforms: field in SKILL.md frontmatter includes current platform
```

## Next Steps

1. ✅ Create `~/.hermes/skills/` directory
2. ✅ Add first skill file with SKILL.md format
3. ✅ Initialize ClaudeSkillManager in your agent
4. ✅ Generate LLM context using getSkillsContextMarkdown()
5. ✅ Handle skill execution when LLM requests them
6. ✅ Create more skills for your use case

## Additional Resources

- [CLAUDE_SKILLS_SYSTEM.md](CLAUDE_SKILLS_SYSTEM.md) - Complete documentation
- [example-SKILL.md](example-SKILL.md) - Real skill example (Spotify)
- [README.md](README.md) - System overview
- API Reference: See class documentation in header files

## Support

For issues or questions:
- Check skill discovery: `skillManager->checkForModifications()`
- Review error messages: Check logs in console
- Test file permissions: Ensure SKILL.md files are readable
- Validate YAML: Check frontmatter syntax carefully
