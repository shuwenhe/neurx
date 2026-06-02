#pragma once
#include <QString>
#include <QJsonObject>

// ── ToolCallRepair ────────────────────────────────────────────────────────────
//  Repairs common malformations in LLM-generated JSON tool arguments:
//   - Strips ```json ... ``` or ``` ... ``` code-block wrappers
//   - Removes trailing commas before } or ]
//   - Handles single-quoted string values
//  Returns the repaired string; the original is returned unchanged on success.

namespace ToolCallRepair {
QString repairJson(const QString &raw);
QJsonObject repairJsonObject(const QString &raw, bool *ok = nullptr);
} // namespace ToolCallRepair
