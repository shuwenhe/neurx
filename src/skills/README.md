# NeurX Claude Skills System

This directory implements the complete Claude-style skill system for NeurX, providing a powerful, extensible system for agent capabilities.

## System Components

### Core Classes

1. **ClaudeSkillTypes.h** - Type definitions
   - `ClaudeSkill`, `ClaudeSkillMetadata`
   - `SkillListingItem` (Tier 1)
   - `SkillViewItem` (Tier 2)
   - Environment variable definitions
   - Execution request/result types

2. **SkillDiscoveryEngine.h/cpp** - File-based skill discovery
   - Recursive SKILL.md scanning
   - YAML frontmatter parsing
   - Platform compatibility filtering
   - Change detection and caching
   - Default implementation included

3. **SkillEnvironmentManager.h/cpp** - Environment variable management
   - Variable collection and validation
   - Secure storage in ~/.hermes/.env
   - Pattern matching and validation
   - User prompting callbacks
   - Default implementation included

4. **ClaudeSkillManager.h/cpp** - Main orchestration
   - Skill discovery and loading
   - Tier-based LLM context generation
   - Availability checking
   - Complete skill lifecycle management

## Quick Start

### 1. Initialize Manager

```cpp
#include "ClaudeSkillManager.h"

auto skillManager = std::make_unique<ClaudeSkillManager>();
QString error = skillManager->initialize("~/.hermes/skills");

skillManager->setPlatform(Platform::macOS);
```

### 2. Query Skills (Tier 1)

```cpp
skillManager->getSkillsList([](const QVector<SkillListingItem> &items) {
    for (const auto &item : items) {
        qDebug() << item.name << ":" << item.description;
    }
});
```

### 3. Get Full Skill Info (Tier 2)

```cpp
skillManager->getSkillView("spotify-playback", 
    [](const SkillViewItem &view) {
        qDebug() << "Version:" << view.version;
        qDebug() << "Author:" << view.author;
    }
);
```

### 4. Generate LLM Context

```cpp
// Use Tier 1 by default (most efficient)
QString context = skillManager->getSkillsContextMarkdown(1, 15);
```

## Skill File Format

Skills are Markdown files with YAML frontmatter:

```yaml
---
name: skill-id                          # Required, ≤64 chars
description: What this skill does       # Required, ≤1024 chars
version: 1.0.0                         # Required, semantic versioning
author: Your Name                       # Optional
category: integration                   # Optional
platforms: [macos, linux, windows]     # Optional, default: any
tags: [tag1, tag2]                     # Optional

required_environment_variables:
  - name: API_KEY
    prompt: "Enter your API key"
    help: "Get from https://..."
    required: true
    secret: true

prerequisites:
  - type: command
    name: curl
    checkCommand: "curl --version"

related_skills: [other-skill-id]
---

# Skill Documentation

Full markdown content with usage examples, edge cases, and integration details...
```

See `example-SKILL.md` for a complete example.

## Tier-Based Context System

### Tier 1: Discovery (~50 tokens)
Lightweight listing with names and descriptions only. Best for initial exploration.

```
# Available Skills

- **spotify-playback**: Control Spotify playback...
- **git-integration**: Git operations...
```

### Tier 2: Planning (~500 tokens)
Full metadata including version, author, environment requirements.

```
# Skills Reference

## spotify-playback

**Description**: Control Spotify playback...
**Version**: 1.0.0
**Author**: NeurX Team

**Environment Variables**:
- SPOTIFY_CLIENT_ID: Your application ID
- SPOTIFY_CLIENT_SECRET: Your application secret
```

### Tier 3: Execution (~1500 tokens)
Complete markdown with examples, edge cases, troubleshooting.

```
[Full SKILL.md content with all details]
```

Use Tier 1 by default, upgrade to Tier 2/3 only when needed.

## Environment Variables

Skills declare required environment variables in frontmatter:

```yaml
required_environment_variables:
  - name: SPOTIFY_CLIENT_ID
    prompt: "Enter your Spotify Client ID"
    help: "Get from https://developer.spotify.com/dashboard"
    required: true
    secret: false
  
  - name: SPOTIFY_CLIENT_SECRET
    prompt: "Enter your Spotify Client Secret"
    required: true
    secret: true  # Will use password input
```

Manager handles:
- Automatic collection from user
- Validation against patterns
- Secure storage (secrets only in memory)
- Automatic system environment fallback

## Platform Support

Skills declare platform compatibility:

```yaml
platforms: [macos, linux, windows]  # or "any" for universal
```

Manager automatically filters incompatible skills:

```cpp
skillManager->setPlatform(Platform::Linux);  // Only Linux skills shown
```

## File Structure

```
~/.hermes/skills/
├── media/
│   └── SKILL.md          (spotify-playback)
├── development/
│   ├── SKILL.md          (git-integration)
│   └── SKILL.md          (code-review)
└── analysis/
    └── SKILL.md          (error-analysis)
```

Each file is named SKILL.md and discovered recursively.

## Integration Guide

See `CLAUDE_SKILLS_SYSTEM.md` for complete integration documentation including:
- Architecture overview
- Component descriptions
- Usage patterns
- LLM integration examples
- Best practices
- Troubleshooting guide

## API Reference

### ClaudeSkillManager

**Discovery:**
- `initialize(directory)` - Load skills from directory
- `refresh(callback)` - Reload skills from disk
- `setPlatform(platform)` - Set current platform

**Querying:**
- `getSkillsList(callback)` - Get all skills (Tier 1)
- `searchSkills(query, tags, maxResults, callback)` - Search skills
- `getSkillView(skillId, callback)` - Get full metadata (Tier 2)
- `getSkillWithContent(skillId)` - Get complete skill (Tier 3)

**Availability:**
- `checkSkillAvailability(skillId)` - Check platform/env compatibility
- `areEnvironmentVariablesReady(skillId)` - Check env vars set
- `getAvailableSkills()` - Get all available skills

**LLM Integration:**
- `generateSkillContextForLLM(tier, maxSkills, context, callback)` - Generate LLM context
- `getSkillsContextMarkdown(tier, maxSkills)` - Get markdown directly

**Environment:**
- `collectEnvironmentVariables(skillId, promptCb, secretCb, resultCb)` - Collect missing vars

**Utility:**
- `getSkillCount()` - Number of skills
- `getStatistics()` - Manager statistics

## Example: Complete Integration

```cpp
auto skillMgr = std::make_unique<ClaudeSkillManager>();
skillMgr->initialize("~/.hermes/skills");
skillMgr->setPlatform(Platform::macOS);

// Generate LLM context
QString prompt = "You are helpful. Here are available skills:\n\n";
prompt += skillMgr->getSkillsContextMarkdown(1, 15);
prompt += "\n\nUser: help me control spotify";

// Send prompt to LLM...
// When user requests a skill, ensure env vars are ready:
if (!skillMgr->areEnvironmentVariablesReady("spotify-playback")) {
    skillMgr->collectEnvironmentVariables(
        "spotify-playback",
        [](auto p, auto h) { return getUserInput(p, h); },
        [](auto p) { return getUserSecret(p); },
        [](bool ok, auto err) { /* handle result */ }
    );
}
```

## Creating a Skill

1. Create `~/.hermes/skills/category/SKILL.md`
2. Add YAML frontmatter with metadata
3. Add markdown content with examples
4. Test with skill manager
5. Share or publish

Minimal example:

```yaml
---
name: my-skill
description: Does something useful
version: 1.0.0
platforms: [macos, linux, windows]
---

# My Skill

This skill does X, Y, and Z.

## Usage

`skill exec my-skill -- command`

## Examples

```

## Best Practices

- **Tier Selection**: Use Tier 1 for efficiency, upgrade only when needed
- **Environment Handling**: Always collect before execution
- **Platform Support**: Include all applicable platforms or explicitly exclude
- **Documentation**: Provide clear examples and edge case handling
- **Error Messages**: Include helpful troubleshooting guidance

## Performance

- Discovery caching: Only re-parses modified files
- Async support: Long operations don't block UI
- Memory efficient: Lazy-loads markdown content (Tier 3)
- Token aware: Tier system optimizes LLM context size

## Roadmap

- [ ] Skill marketplace and online discovery
- [ ] Skill dependency management
- [ ] Multiple skill versions
- [ ] Skill analytics and telemetry
- [ ] Skill testing framework
- [ ] Custom skill templates/generator
- [ ] Skill performance profiling

## References

- [CLAUDE_SKILLS_SYSTEM.md](CLAUDE_SKILLS_SYSTEM.md) - Complete system documentation
- [example-SKILL.md](example-SKILL.md) - Example skill file
- [Codex Skills](https://github.com/codex-dev/skills) - Original inspiration
- [Hermes Skills](https://github.com/hermes-ai/skills) - Related implementation
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
