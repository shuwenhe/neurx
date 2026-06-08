#include "FileService.h"
#include <QFile>
#include <QFileInfo>
#include <QDir>
#include <QDirIterator>
#include <QFileSystemWatcher>
#include <QStandardPaths>
#include <QJsonDocument>
#include <QJsonObject>
#include <QJsonArray>
#include <QStringConverter>

namespace {

QString normalizedEncoding(const QString& encoding) {
    if (encoding.isEmpty()) {
        return QStringLiteral("UTF-8");
    }
    return encoding.trimmed().toUpper();
}

QString decodeText(const QByteArray& content, const QString& encoding) {
    const QString enc = normalizedEncoding(encoding);

    if (enc == QStringLiteral("UTF-16LE")) {
        QStringDecoder decoder(QStringConverter::Utf16LE);
        return decoder.decode(content);
    }
    if (enc == QStringLiteral("UTF-16BE")) {
        QStringDecoder decoder(QStringConverter::Utf16BE);
        return decoder.decode(content);
    }
    if (enc == QStringLiteral("LATIN1") || enc == QStringLiteral("ISO-8859-1")) {
        QStringDecoder decoder(QStringConverter::Latin1);
        return decoder.decode(content);
    }

    QStringDecoder decoder(QStringConverter::Utf8);
    return decoder.decode(content);
}

QByteArray encodeText(const QString& content, const QString& encoding) {
    const QString enc = normalizedEncoding(encoding);

    if (enc == QStringLiteral("UTF-16LE")) {
        QStringEncoder encoder(QStringConverter::Utf16LE);
        return encoder.encode(content);
    }
    if (enc == QStringLiteral("UTF-16BE")) {
        QStringEncoder encoder(QStringConverter::Utf16BE);
        return encoder.encode(content);
    }
    if (enc == QStringLiteral("LATIN1") || enc == QStringLiteral("ISO-8859-1")) {
        QStringEncoder encoder(QStringConverter::Latin1);
        return encoder.encode(content);
    }

    return content.toUtf8();
}

}  // namespace

class FileService::Impl {
public:
    QFileSystemWatcher watcher;
    QStringList recentFiles;
    static constexpr int MAX_RECENT = 50;
    
    QString detectEncodingInternal(const QByteArray& data) {
        // Simple encoding detection - BOM check
        if (data.startsWith("\xEF\xBB\xBF")) {
            return "UTF-8 BOM";
        } else if (data.startsWith("\xFF\xFE")) {
            return "UTF-16LE";
        } else if (data.startsWith("\xFE\xFF")) {
            return "UTF-16BE";
        }
        
        // Default to UTF-8
        return "UTF-8";
    }
};

FileService* FileService::instance() {
    static FileService s_instance;
    return &s_instance;
}

FileService::FileService()
    : m_impl(std::make_unique<Impl>()) {
    connect(&m_impl->watcher, &QFileSystemWatcher::fileChanged,
            this, [this](const QString& path) {
                emit fileChanged(path);
            });
}

FileService::~FileService() = default;

bool FileService::exists(const QString& path) const {
    return QFileInfo::exists(path);
}

FileInfo FileService::getFileInfo(const QString& path) const {
    QFileInfo fileInfo(path);
    
    FileInfo info;
    info.path = fileInfo.absoluteFilePath();
    info.name = fileInfo.fileName();
    info.extension = fileInfo.suffix();
    info.size = fileInfo.size();
    info.modified = fileInfo.lastModified().toMSecsSinceEpoch();
    info.isDirectory = fileInfo.isDir();
    info.isSymlink = fileInfo.isSymLink();
    info.encoding = "UTF-8";
    
    return info;
}

QByteArray FileService::readFile(const QString& path) {
    QFile file(path);
    if (!file.open(QIODevice::ReadOnly)) {
        return QByteArray();
    }
    
    QByteArray content = file.readAll();
    file.close();
    
    return content;
}

bool FileService::writeFile(const QString& path, const QByteArray& content) {
    QFile file(path);
    if (!file.open(QIODevice::WriteOnly | QIODevice::Truncate)) {
        return false;
    }
    
    file.write(content);
    file.close();
    
    return true;
}

bool FileService::deleteFile(const QString& path) {
    return QFile::remove(path);
}

bool FileService::moveFile(const QString& source, const QString& destination) {
    return QFile::rename(source, destination);
}

bool FileService::copyFile(const QString& source, const QString& destination) {
    return QFile::copy(source, destination);
}

bool FileService::createDirectory(const QString& path) {
    return QDir().mkpath(path);
}

QList<FileInfo> FileService::listDirectory(const QString& path, bool recursive) {
    QList<FileInfo> results;
    
    QDir dir(path);
    if (!dir.exists()) {
        return results;
    }
    
    QStringList filters = QStringList() << "*";
    dir.setFilter(QDir::Files | QDir::Dirs | QDir::NoDotAndDotDot);
    
    QFileInfoList entries = dir.entryInfoList();
    for (const auto& entry : entries) {
        FileInfo info;
        info.path = entry.absoluteFilePath();
        info.name = entry.fileName();
        info.extension = entry.suffix();
        info.size = entry.size();
        info.modified = entry.lastModified().toMSecsSinceEpoch();
        info.isDirectory = entry.isDir();
        info.isSymlink = entry.isSymLink();
        
        results.append(info);
        
        if (recursive && entry.isDir() && !entry.isSymLink()) {
            auto subResults = listDirectory(entry.absoluteFilePath(), true);
            results.append(subResults);
        }
    }
    
    return results;
}

QStringList FileService::findFiles(const QString& directory, const QString& pattern) {
    QStringList results;
    
    QDir dir(directory);
    if (!dir.exists()) {
        return results;
    }
    
    QDirIterator it(directory,
                    QStringList(pattern),
                    QDir::Files,
                    QDirIterator::Subdirectories);
    while (it.hasNext()) {
        results.append(it.next());
    }
    
    return results;
}

QString FileService::detectEncoding(const QString& path) {
    QFile file(path);
    if (!file.open(QIODevice::ReadOnly)) {
        return "UTF-8";
    }
    
    QByteArray data = file.read(4096);  // Read first 4KB
    file.close();
    
    return m_impl->detectEncodingInternal(data);
}

QString FileService::readFileAsText(const QString& path, const QString& encoding) {
    QByteArray content = readFile(path);
    if (content.isEmpty()) {
        return QString();
    }

    return decodeText(content, encoding);
}

bool FileService::writeFileAsText(const QString& path, const QString& content,
                                 const QString& encoding) {
    return writeFile(path, encodeText(content, encoding));
}

void FileService::watchFile(const QString& path) {
    if (!m_impl->watcher.files().contains(path)) {
        m_impl->watcher.addPath(path);
        emit fileWatched(path);
    }
}

void FileService::unwatchFile(const QString& path) {
    if (m_impl->watcher.files().contains(path)) {
        m_impl->watcher.removePath(path);
        emit fileUnwatched(path);
    }
}

bool FileService::isWatching(const QString& path) const {
    return m_impl->watcher.files().contains(path);
}

QStringList FileService::getRecentFiles(int maxCount) {
    return m_impl->recentFiles.mid(
        qMax(0, m_impl->recentFiles.size() - maxCount)
    );
}

void FileService::addRecentFile(const QString& path) {
    // Remove duplicate if exists
    m_impl->recentFiles.removeAll(path);
    
    // Add to end
    m_impl->recentFiles.append(path);
    
    // Trim if too large
    if (m_impl->recentFiles.size() > m_impl->MAX_RECENT) {
        m_impl->recentFiles.removeFirst();
    }
}

void FileService::clearRecentFiles() {
    m_impl->recentFiles.clear();
}

qint64 FileService::getFileSize(const QString& path) const {
    return QFileInfo(path).size();
}

QString FileService::getFileExtension(const QString& path) const {
    return QFileInfo(path).suffix();
}

QString FileService::getFileName(const QString& path) const {
    return QFileInfo(path).fileName();
}
