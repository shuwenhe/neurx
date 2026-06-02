#include "tools/ReminderTool.h"
#include <QDateTime>
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QSaveFile>
#include <QStandardPaths>
#include <QUuid>
#include <QDebug>

namespace {

QDateTime parseUtcDateTime(const QString &text)
{
    QDateTime dt = QDateTime::fromString(text, Qt::ISODateWithMs);
    if (!dt.isValid())
        dt = QDateTime::fromString(text, Qt::ISODate);
    if (dt.isValid())
        return dt.toUTC();
    return {};
}

} // namespace

ReminderTool::ReminderTool(const QString &workspaceRoot, QObject *parent)
    : BaseTool(parent)
    , m_workspaceRoot(workspaceRoot)
{
    m_timer.setInterval(5000);
    m_timer.setSingleShot(false);
    connect(&m_timer, &QTimer::timeout, this, &ReminderTool::checkDueReminders);
    load();
    m_timer.start();
}

QString ReminderTool::description() const
{
    return QStringLiteral(
        "Create workspace-scoped reminders and recurring scheduled tasks. "
        "Actions: create, list, cancel. "
        "Use due_at (ISO 8601) or due_in_minutes for one-off reminders, and repeat_minutes for recurring tasks.");
}

QJsonObject ReminderTool::parametersSchema() const
{
    return QJsonObject{
        {"type", "object"},
        {"properties", QJsonObject{
            {"action", QJsonObject{
                {"type", "string"},
                {"enum", QJsonArray{"create","list","cancel"}},
                {"description", "Operation to perform."},
            }},
            {"title", QJsonObject{{"type", "string"}, {"description", "Reminder title."}}},
            {"due_at", QJsonObject{{"type", "string"}, {"description", "ISO 8601 UTC time for the reminder."}}},
            {"due_in_minutes", QJsonObject{{"type", "integer"}, {"description", "Relative delay in minutes."}}},
            {"repeat_minutes", QJsonObject{{"type", "integer"}, {"description", "Repeat interval in minutes for recurring reminders."}}},
            {"id", QJsonObject{{"type", "string"}, {"description", "Reminder id for cancel."}}},
        }},
        {"required", QJsonArray{"action"}},
    };
}

QString ReminderTool::summary(const QJsonObject &args) const
{
    const QString action = args.value("action").toString();
    if (action == "create") {
        return QStringLiteral("schedule %1").arg(args.value("title").toString());
    }
    if (action == "cancel") {
        return QStringLiteral("cancel reminder %1").arg(args.value("id").toString());
    }
    return QStringLiteral("schedule %1").arg(action);
}

QVariantList ReminderTool::reminders() const
{
    QVariantList list;
    for (const auto &item : m_items)
        list.append(toVariantMap(item));
    return list;
}

QString ReminderTool::storePath() const
{
    if (m_workspaceRoot.trimmed().isEmpty())
        return {};
    return QDir(m_workspaceRoot).filePath(QStringLiteral(".neurx/reminders.json"));
}

QString ReminderTool::formatDue(const QDateTime &dt) const
{
    return dt.isValid() ? dt.toUTC().toString(Qt::ISODateWithMs) : QString{};
}

void ReminderTool::setWorkspaceRoot(const QString &workspaceRoot)
{
    if (m_workspaceRoot == workspaceRoot)
        return;
    m_workspaceRoot = workspaceRoot;
    load();
    emit remindersChanged();
}

QVariantMap ReminderTool::toVariantMap(const ReminderItem &item) const
{
    QVariantMap map;
    map["id"] = item.id;
    map["title"] = item.title;
    map["dueAtUtc"] = formatDue(item.dueAtUtc);
    map["repeatMinutes"] = item.repeatMinutes;
    map["status"] = item.status;
    map["createdAtUtc"] = formatDue(item.createdAtUtc);
    map["triggeredAtUtc"] = formatDue(item.triggeredAtUtc);
    return map;
}

ReminderTool::ReminderItem ReminderTool::fromVariantMap(const QVariantMap &map) const
{
    ReminderItem item;
    item.id = map.value("id").toString();
    item.title = map.value("title").toString();
    item.dueAtUtc = parseUtcDateTime(map.value("dueAtUtc").toString());
    item.repeatMinutes = map.value("repeatMinutes").toInt();
    item.status = map.value("status").toString();
    if (item.status.isEmpty())
        item.status = QStringLiteral("pending");
    item.createdAtUtc = parseUtcDateTime(map.value("createdAtUtc").toString());
    item.triggeredAtUtc = parseUtcDateTime(map.value("triggeredAtUtc").toString());
    if (item.id.isEmpty())
        item.id = QUuid::createUuid().toString(QUuid::WithoutBraces);
    if (!item.createdAtUtc.isValid())
        item.createdAtUtc = QDateTime::currentDateTimeUtc();
    if (item.status.isEmpty())
        item.status = QStringLiteral("pending");
    return item;
}

ReminderTool::ReminderItem *ReminderTool::findReminder(const QString &id)
{
    for (auto &item : m_items) {
        if (item.id == id)
            return &item;
    }
    return nullptr;
}

const ReminderTool::ReminderItem *ReminderTool::findReminder(const QString &id) const
{
    for (const auto &item : m_items) {
        if (item.id == id)
            return &item;
    }
    return nullptr;
}

void ReminderTool::load()
{
    m_items.clear();
    m_storePath = storePath();
    if (m_storePath.isEmpty())
        return;

    QFile f(m_storePath);
    if (!f.exists() || !f.open(QIODevice::ReadOnly | QIODevice::Text))
        return;

    const QJsonDocument doc = QJsonDocument::fromJson(f.readAll());
    f.close();
    if (!doc.isObject())
        return;

    const auto arr = doc.object().value("reminders").toArray();
    for (const auto &v : arr) {
        if (v.isObject())
            m_items.append(fromVariantMap(v.toObject().toVariantMap()));
    }
}

void ReminderTool::save() const
{
    if (m_storePath.isEmpty())
        return;
    QDir().mkpath(QFileInfo(m_storePath).absolutePath());

    QJsonArray arr;
    for (const auto &item : m_items)
        arr.append(QJsonObject::fromVariantMap(toVariantMap(item)));

    QSaveFile f(m_storePath);
    if (!f.open(QIODevice::WriteOnly | QIODevice::Text))
        return;
    f.write(QJsonDocument(QJsonObject{{"reminders", arr}}).toJson(QJsonDocument::Indented));
    f.commit();
}

bool ReminderTool::createReminder(const QString &title, const QDateTime &dueAtUtc,
                                  int repeatMinutes, QString *error)
{
    if (!dueAtUtc.isValid()) {
        if (error) *error = QStringLiteral("due_at is invalid.");
        return false;
    }
    if (title.trimmed().isEmpty()) {
        if (error) *error = QStringLiteral("title is required.");
        return false;
    }
    if (repeatMinutes < 0) {
        if (error) *error = QStringLiteral("repeat minutes cannot be negative.");
        return false;
    }

    ReminderItem item;
    item.id = QUuid::createUuid().toString(QUuid::WithoutBraces);
    item.title = title.trimmed();
    item.dueAtUtc = dueAtUtc.toUTC();
    item.repeatMinutes = repeatMinutes;
    item.status = QStringLiteral("pending");
    item.createdAtUtc = QDateTime::currentDateTimeUtc();

    m_items.append(item);
    save();
    emit remindersChanged();
    return true;
}

bool ReminderTool::cancelReminder(const QString &id, QString *error)
{
    ReminderItem *item = findReminder(id.trimmed());
    if (!item) {
        if (error) *error = QStringLiteral("Reminder not found: %1").arg(id);
        return false;
    }
    item->status = QStringLiteral("cancelled");
    item->triggeredAtUtc = QDateTime::currentDateTimeUtc();
    save();
    emit remindersChanged();
    return true;
}

ToolResult ReminderTool::execute(const QString &callId, const QJsonObject &args)
{
    const QString action = args.value("action").toString().trimmed();
    if (action == "list") {
        const QVariantList items = reminders();
        if (items.isEmpty())
            return {callId, name(), false, QStringLiteral("No reminders scheduled.")};

        QStringList lines;
        for (const auto &value : items) {
            const auto map = value.toMap();
            lines << QStringLiteral("- [%1] %2 | due %3 | repeat %4 min | %5")
                         .arg(map.value("id").toString(),
                              map.value("title").toString(),
                              map.value("dueAtUtc").toString())
                         .arg(map.value("repeatMinutes").toInt())
                         .arg(map.value("status").toString());
        }
        return {callId, name(), false, lines.join("\n")};
    }

    if (action == "create") {
        const QString title = args.value("title").toString();
        const int repeatMinutes = args.value("repeat_minutes").toInt(0);
        QDateTime dueAt = parseUtcDateTime(args.value("due_at").toString());
        if (!dueAt.isValid()) {
            const int dueInMinutes = args.value("due_in_minutes").toInt(-1);
            if (dueInMinutes >= 0)
                dueAt = QDateTime::currentDateTimeUtc().addSecs(dueInMinutes * 60);
        }
        QString error;
        if (!createReminder(title, dueAt, repeatMinutes, &error))
            return {callId, name(), true, error};
        return {callId, name(), false,
                QStringLiteral("Scheduled reminder: %1 at %2")
                    .arg(title.trimmed(), dueAt.toUTC().toString(Qt::ISODateWithMs))};
    }

    if (action == "cancel") {
        const QString id = args.value("id").toString();
        QString error;
        if (!cancelReminder(id, &error))
            return {callId, name(), true, error};
        return {callId, name(), false, QStringLiteral("Cancelled reminder: %1").arg(id)};
    }

    return {callId, name(), true, QStringLiteral("Unknown action: %1").arg(action)};
}

void ReminderTool::checkDueReminders()
{
    if (m_items.isEmpty())
        return;

    const QDateTime now = QDateTime::currentDateTimeUtc();
    bool changed = false;
    for (auto &item : m_items) {
        if (item.status != "pending" || !item.dueAtUtc.isValid() || item.dueAtUtc > now)
            continue;

        QVariantMap map = toVariantMap(item);
        emit reminderTriggered(map);

        if (item.repeatMinutes > 0) {
            item.dueAtUtc = now.addSecs(item.repeatMinutes * 60);
        } else {
            item.status = QStringLiteral("triggered");
            item.triggeredAtUtc = now;
        }
        changed = true;
    }

    if (changed) {
        save();
        emit remindersChanged();
    }
}
