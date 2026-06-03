# Claude Skills System Implementation in NeurX

## Overview

This document describes the complete implementation of Claude's Skills system in NeurX, providing a powerful system for extending agent capabilities through modular, discoverable skills.

## Architecture

```
ClaudeSkillManager (Main orchestrator)
├── SkillDiscoveryEngine (File scanning & YAML parsing)
├── SkillEnvironmentManager (Env var collection & validation)
└── Skill Registry (In-memory cache & indexing)
```

## Core Components

### 1. Type Definitions (`ClaudeSkillTypes.h`)

Key types for the skills system:

- **ClaudeSkillMetadata**: Metadata from SKILL.md frontmatter
- **ClaudeSkill**: Complete skill with content
- **SkillListingItem**: Tier 1 (lightweight)
- **SkillViewItem**: Tier 2 (full metadata)
- **EnvironmentVariableDef**: Environment variable requirements
- **SkillExecutionRequest/Result**: Execution tracking

### 2. Discovery System (`SkillDiscoveryEngine`)

Discovers and loads skills from the filesystem:

- Recursive directory scanning for `SKILL.md` files
- YAML frontmatter parsing
- Platform compatibility filtering
- Change detection and hot-reloading
- Caching for performance

**Usage:**
```cpp
auto discoveryEngine = std::make_unique<DefaultSkillDiscoveryEngine>();
discoveryEngine->discoverSkills(
    "/path/to/skills",
    Platform::macOS,
    true,  // recursive
    [](const QVector<ClaudeSkill> &skills, const QString &error) {
        qDebug() << "Found" << skills.count() << "skills";
    }
);
```

### 3. Environment Manager (`SkillEnvironmentManager`)

Manages environment variables for skills:

- Collect required environment variables
- Validate against patterns/constraints
- Store securely in ~/.hermes/.env
- Prompt user for missing values

**Usage:**
```cpp
auto envManager = std::make_unique<DefaultSkillEnvironmentManager>();
envManager->collectEnvironmentVariables(
    skill,
    [](const QString &prompt, const QString &help) -> QString {
        // Show UI prompt to user
        return userProvidedValue;
    },
    [](const QString &prompt) -> QString {
        // Prompt for secret (password field)
        return userProvidedSecret;
    },
    [](bool success, const QString &error) {
        // Callback when collection complete
    }
);
```

### 4. Skill Manager (`ClaudeSkillManager`)

Main orchestration layer providing all skill operations:

- Discovery and loading
- Tier-based context generation for LLM
- Availability checking
- Environment variable management
- Execution tracking

## Skill File Format

Skills are defined as `SKILL.md` files with YAML frontmatter:

```yaml
---
name: spotify-control
description: Control Spotify playback, adjust volume, and view currently playing track
version: 1.0.0
author: your-name
category: media
platforms: [macos, linux, windows]
tags: [spotify, music, audio]

required_environment_variables:
  - name: SPOTIFY_CLIENT_ID
    prompt: "Enter your Spotify Client ID"
    help: "Get from https://developer.spotify.com/dashboard"
    required: true
  
  - name: SPOTIFY_CLIENT_SECRET
    prompt: "Enter your Spotify Client Secret"
    help: "Available in Developer Dashboard"
    required: true
    secret: true

prerequisites:
  - type: command
    name: curl
    help: "Install via: brew install curl"

related_skills: [audio-settings, music-search]
---

# Spotify Control Skill

This skill allows you to control Spotify playback...

## How to Use

To use this skill, the agent will:
1. Authenticate with Spotify using your Client ID and Secret
2. Execute commands via the Spotify Web API
3. Return results about playback state

## Examples

### Play a specific track
```bash
spotify play "track:3n3Ppam7vgaVa1iaRUc9Lp"
```

### Get current track
```bash
spotify current
```
```

## Usage in NeurX

### Initialization

```cpp
// In main application startup
auto skillManager = std::make_unique<ClaudeSkillManager>();
QString error = skillManager->initialize("~/.hermes/skills");
if (!error.isEmpty()) {
    qWarning() << "Skills initialization failed:" << error;
}

skillManager->setPlatform(Platform::macOS);
```

### Querying Skills

```cpp
// Get all available skills (Tier 1 - lightweight)
skillManager->getSkillsList([](const QVector<SkillListingItem> &items) {
    for (const auto &item : items) {
        qDebug() << item.name << ":" << item.description;
    }
});

// Search skills
skillManager->searchSkills(
    "spotify",
    {"music", "audio"},  // tags
    10,  // max results
    [](const SkillSearchResult &result) {
        qDebug() << "Found" << result.matchedCount << "skills";
    }
);

// Get complete skill information
skillManager->getSkillView(
    "spotify-control",
    [](const SkillViewItem &view) {
        qDebug() << "Version:" << view.version;
        qDebug() << "Author:" << view.author;
    }
);
```

### Environment Variable Handling

```cpp
// Check if skill is ready
if (!skillManager->areEnvironmentVariablesReady("spotify-control")) {
    // Collect missing variables
    skillManager->collectEnvironmentVariables(
        "spotify-control",
        [](const QString &prompt, const QString &help) {
            // Show prompt dialog
            return userInput;
        },
        [](const QString &prompt) {
            // Show password field
            return userSecret;
        },
        [](bool success, const QString &error) {
            if (success) {
                qDebug() << "Variables collected successfully";
            } else {
                qWarning() << "Error:" << error;
            }
        }
    );
}
```

### Availability Checking

```cpp
// Check if skill works on current platform/config
SkillAvailabilityCheck check = skillManager->checkSkillAvailability("spotify-control");

if (!check.platformSupported) {
    qDebug() << "Not supported:" << check.platformReason;
}

if (!check.environmentReady) {
    qDebug() << "Missing vars:" << check.missingEnvironmentVariables;
}

if (!check.prerequisitesMet) {
    qDebug() << "Missing:" << check.unsatisfiedPrerequisites;
}
```

### LLM Context Generation

The skills system provides tiered context generation optimized for LLM consumption:

```cpp
// Tier 1: Lightweight (~50 tokens)
// Just names, descriptions, and categories
skillManager->generateSkillContextForLLM(
    1,     // tier
    10,    // max skills
    QVariantMap(),
    [](const SkillContextForLLM &context) {
        qDebug() << "Tier 1 context:" << context.tier1Context;
        qDebug() << "Approx tokens:" << context.totalTokens;
    }
);

// Tier 2: Full Metadata (~500 tokens)
// Includes version, author, environment requirements
skillManager->generateSkillContextForLLM(2, 10, QVariantMap(), callback);

// Tier 3: Complete with Examples (~1500 tokens)
// Full markdown content with usage examples
skillManager->generateSkillContextForLLM(3, 10, QVariantMap(), callback);

// Or get markdown directly
QString contextMd = skillManager->getSkillsContextMarkdown(1, 10);
```

### Integration with Agent

In your agent's LLM prompt generation:

```cpp
// Before making LLM request
QString prompt = "You are a helpful assistant.\n\n";

// Add available skills (tier 1 is usually best for efficiency)
prompt += skillManager->getSkillsContextMarkdown(1, 15);

// Add user query
prompt += "\nUser: " + userQuery;

// Send to LLM...
```

## Tier-Based Context System

### Tier 1: Discovery Phase (~50 tokens)
```markdown
# Available Skills

- **spotify-control**: Control Spotify playback, adjust volume, and view currently playing track
- **git-integration**: Git operations including commit, push, pull, and branch management
- **web-search**: Search the web and fetch pages
```

When to use: Initial skill discovery, when token budget is tight, or when you need fast decision-making.

### Tier 2: Planning Phase (~500 tokens)
```markdown
# Skills Reference

## spotify-control

**Description**: Control Spotify playback, adjust volume, and view currently playing track

**Version**: 1.0.0

**Author**: your-name

**Environment Variables**:
- `SPOTIFY_CLIENT_ID`: Your Spotify application ID
- `SPOTIFY_CLIENT_SECRET`: Your Spotify application secret
```

When to use: When planning which skills to use, or when need more details before execution.

### Tier 3: Execution Phase (~1500 tokens)
Includes complete markdown body with examples, edge cases, and detailed instructions.

When to use: When actually executing the skill or debugging failures.

## Platform Compatibility

Skills declare their platform support:

```yaml
platforms: [macos, linux, windows]  # or "any" for universal
```

The system automatically filters skills based on the current platform:

```cpp
skillManager->setPlatform(Platform::Linux);  // Only Linux-compatible skills shown
```

## File Structure

Typical skills directory layout:

```
~/.hermes/skills/
├── analysis/
│   ├── SKILL.md  (code-review)
│   └── SKILL.md  (error-analysis)
├── coding/
│   ├── SKILL.md  (refactor-code)
│   └── SKILL.md  (bug-fixer)
├── integration/
│   ├── SKILL.md  (spotify-control)
│   └── SKILL.md  (git-integration)
└── SKILL.md  (skill-marketplace)
```

Each directory can contain one or more SKILL.md files.

## Caching & Performance

The discovery engine implements intelligent caching:

- **Checksum-based change detection**: Files are reloaded only if modified
- **In-memory cache**: Loaded skills cached until modified
- **Async discovery**: Long-running discovery doesn't block UI
- **Statistics**: Monitor cache performance

```cpp
// Check cache stats
QVariantMap stats = skillManager->getStatistics();
qDebug() << "Total skills:" << stats["totalSkills"];
qDebug() << "Available:" << stats["availableSkills"];
```

## Error Handling

```cpp
skillManager->initialize("/path/to/skills");

skillManager->refresh([](int count, const QString &error) {
    if (!error.isEmpty()) {
        qWarning() << "Errors during discovery:" << error;
        // Show to user, but continue with successfully loaded skills
    }
});
```

## Best Practices

1. **Tier Selection**: Use Tier 1 by default, upgrade to Tier 2/3 only when needed
2. **Environment Variables**: Always collect before attempting skill execution
3. **Platform Checking**: Call `setPlatform()` early, let system filter incompatible skills
4. **Hot Reload**: Call `checkForModifications()` periodically to detect skill updates
5. **Caching**: Don't recreate managers unnecessarily; reuse instances

## Example: Complete Skill Manager Integration

```cpp
class MyAgent {
private:
    std::unique_ptr<ClaudeSkillManager> m_skillManager;
    
public:
    MyAgent() {
        m_skillManager = std::make_unique<ClaudeSkillManager>();
        QString error = m_skillManager->initialize("~/.hermes/skills");
        if (!error.isEmpty()) {
            qWarning() << "Skills setup failed:" << error;
        }
        
        m_skillManager->setPlatform(Platform::macOS);
    }
    
    void generateLLMPrompt(const QString &userQuery, QString &output) {
        output = "You are a helpful assistant. Here are the tools available:\n\n";
        
        // Add Tier 1 skills context
        output += m_skillManager->getSkillsContextMarkdown(1, 15);
        
        output += "\n\nUser Query: " + userQuery;
        
        // Send to LLM...
    }
    
    void onUserRequest(const QString &skillId) {
        // Ensure environment is ready
        if (!m_skillManager->areEnvironmentVariablesReady(skillId)) {
            m_skillManager->collectEnvironmentVariables(
                skillId,
                [this](const QString &p, const QString &h) { return promptUser(p, h); },
                [this](const QString &p) { return promptUserSecret(p); },
                [this, skillId](bool success, const QString &error) {
                    if (success) {
                        executeSkill(skillId);
                    }
                }
            );
        } else {
            executeSkill(skillId);
        }
    }
};
```

## Future Enhancements

- **Skill Marketplace**: Browse and install skills from online registry
- **Skill Dependency Management**: Handle skill-to-skill dependencies
- **Versioning**: Support multiple versions of the same skill
- **Skill Analytics**: Track skill usage and performance metrics
- **Custom Skill Templates**: Generator for creating new skills
- **Skill Testing Framework**: Built-in testing utilities
- **Skill Publishing**: One-command skill distribution

## Troubleshooting

### Skills Not Discovered
- Check directory exists and contains `SKILL.md` files
- Verify YAML frontmatter is valid (starts/ends with `---`)
- Check file permissions (readable by app)
- Look for parsing errors in error output

### Environment Variables Not Set
- Verify variable name matches exactly (case-sensitive)
- Check ~/.hermes/.env file exists and is readable
- Confirm pattern validation if specified
- Try manual `setEnvironmentVariable()` for testing

### Skills Marked Unavailable
- Check current platform: `skillManager->getPlatform()`
- Verify skill lists this platform in `platforms:` field
- Check prerequisites are installed
- Check environment variables are complete
