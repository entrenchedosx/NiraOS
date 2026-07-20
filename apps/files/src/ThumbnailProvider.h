#pragma once

#include <QQuickImageProvider>
#include <QCache>
#include <QImage>
#include <QMutex>
#include <QThread>

class ThumbnailProvider : public QQuickImageProvider
{
public:
    ThumbnailProvider();

    QImage requestImage(const QString &id, QSize *size,
                        const QSize &requestedSize) override;

private:
    QImage generateThumbnail(const QString &filePath, const QSize &requestedSize);
    QImage generateIconThumbnail(const QString &iconName, const QSize &size);
    QImage scaleAndCache(const QString &key, const QImage &image);

    QCache<QString, QImage> cache_;
    QMutex cacheMutex_;
};
