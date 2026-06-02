#include "ThreadId.h"
#include <QDebug>

ThreadId ThreadId::generate()
{
    // Generate UUID v7 (timestamp-based, sortable)
    // In Qt, QUuid::createUuid() generates v4 by default
    // For v7, we'd need custom implementation, but for now use v4
    return ThreadId(QUuid::createUuid());
}

ThreadId ThreadId::fromString(const QString &str)
{
    return ThreadId(str);
}

ThreadId ThreadId::fromUuid(const QUuid &uuid)
{
    return ThreadId(uuid);
}

ThreadId::ThreadId(const QString &uuidStr)
    : m_uuid(uuidStr)
{
}

ThreadId::ThreadId(const QUuid &uuid)
    : m_uuid(uuid)
{
}

QString ThreadId::toString() const
{
    return m_uuid.toString(QUuid::WithoutBraces);
}

QUuid ThreadId::toUuid() const
{
    return m_uuid;
}

QByteArray ThreadId::toByteArray() const
{
    return m_uuid.toByteArray();
}

bool ThreadId::operator==(const ThreadId &other) const
{
    return m_uuid == other.m_uuid;
}

bool ThreadId::operator!=(const ThreadId &other) const
{
    return m_uuid != other.m_uuid;
}

bool ThreadId::operator<(const ThreadId &other) const
{
    return m_uuid.toString() < other.m_uuid.toString();
}

bool ThreadId::isNull() const
{
    return m_uuid.isNull();
}
