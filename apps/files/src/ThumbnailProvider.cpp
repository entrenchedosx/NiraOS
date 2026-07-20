#include "ThumbnailProvider.h"

#include <QIcon>
#include <QImageReader>
#include <QPainter>
#include <QFileInfo>
#include <QMimeDatabase>
#include <QUrl>

using namespace Qt::StringLiterals;

ThumbnailProvider::ThumbnailProvider()
    : QQuickImageProvider(QQuickImageProvider::Image)
    , cache_(500)
{
}

QImage ThumbnailProvider::requestImage(const QString &id, QSize *size,
                                       const QSize &requestedSize)
{
    QSize target = requestedSize.isValid() ? requestedSize : QSize(128, 128);

    // id format: "file:///path/to/file" or "icon://iconname"
    if (id.startsWith("icon://"_L1)) {
        QString iconName = id.mid(7);
        return generateIconThumbnail(iconName, target);
    }

    QString filePath;
    if (id.startsWith("file://"_L1))
        filePath = QUrl(id).toLocalFile();
    else
        filePath = id;

    if (filePath.isEmpty())
        return generateIconThumbnail("unknown"_L1, target);

    // Check cache
    QString cacheKey = filePath + u'@' + QString::number(target.width()) + u'x' + QString::number(target.height());
    {
        QMutexLocker lock(&cacheMutex_);
        if (QImage *cached = cache_.object(cacheKey)) {
            if (size)
                *size = cached->size();
            return *cached;
        }
    }

    QImage thumb = generateThumbnail(filePath, target);
    if (thumb.isNull())
        thumb = generateIconThumbnail("unknown"_L1, target);

    {
        QMutexLocker lock(&cacheMutex_);
        cache_.insert(cacheKey, new QImage(thumb));
    }

    if (size)
        *size = thumb.size();
    return thumb;
}

QImage ThumbnailProvider::generateThumbnail(const QString &filePath, const QSize &requestedSize)
{
    QFileInfo fi(filePath);
    if (!fi.exists()) return {};

    QMimeDatabase mimeDb;
    QString mimeType = mimeDb.mimeTypeForFile(fi).name();

    // Images
    if (mimeType.startsWith("image/"_L1)) {
        QImageReader reader(filePath);
        reader.setAutoTransform(true);
        QSize imgSize = reader.size();
        if (!imgSize.isValid())
            return {};
        QSize scaled = imgSize.scaled(requestedSize, Qt::KeepAspectRatio);
        reader.setScaledSize(scaled);
        return reader.read();
    }

    // Videos
    if (mimeType.startsWith("video/"_L1))
        return generateIconThumbnail("video-x-generic"_L1, requestedSize);

    // PDFs / documents
    if (mimeType == "application/pdf"_L1)
        return generateIconThumbnail("application-pdf"_L1, requestedSize);

    // Text files
    if (mimeType.startsWith("text/"_L1))
        return generateIconThumbnail("text-x-generic"_L1, requestedSize);

    // Archives
    if (mimeType.contains("zip"_L1) || mimeType.contains("compressed"_L1) || mimeType.contains("archive"_L1))
        return generateIconThumbnail("application-x-archive"_L1, requestedSize);

    // Executables
    if (fi.isExecutable())
        return generateIconThumbnail("application-x-executable"_L1, requestedSize);

    // Directories
    if (fi.isDir())
        return generateIconThumbnail("folder"_L1, requestedSize);

    // Symlinks
    if (fi.isSymLink())
        return generateIconThumbnail("emblem-symbolic-link"_L1, requestedSize);

    return {};
}

QImage ThumbnailProvider::generateIconThumbnail(const QString &iconName, const QSize &size)
{
    QIcon icon = QIcon::fromTheme(iconName);
    if (icon.isNull())
        icon = QIcon::fromTheme("unknown"_L1);
    return icon.pixmap(size).toImage();
}
