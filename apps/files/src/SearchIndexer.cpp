#include "SearchIndexer.h"

#include <QDirIterator>
#include <QFileInfo>
#include <QMimeDatabase>
#include <QDateTime>
#include <QtConcurrent>

using namespace Qt::StringLiterals;

SearchIndexer::SearchIndexer(QObject *parent)
    : QObject(parent)
{
    watcher_ = new QFutureWatcher<QVariantList>(this);
    connect(watcher_, &QFutureWatcher<QVariantList>::finished,
            this, [this]() {
                if (watcher_->isCanceled()) {
                    emit searchFinished(true);
                } else {
                    emit resultsFound(watcher_->result());
                    emit searchFinished(false);
                }
            });
}

void SearchIndexer::search(const QString &rootPath, const QString &query)
{
    cancel();

    if (query.trimmed().isEmpty()) {
        emit resultsFound({});
        emit searchFinished(false);
        return;
    }

    QFuture<QVariantList> future = QtConcurrent::run(performSearch, rootPath, query.trimmed());
    watcher_->setFuture(future);
}

void SearchIndexer::cancel()
{
    if (watcher_->isRunning()) {
        watcher_->cancel();
        watcher_->waitForFinished();
    }
}

QVariantList SearchIndexer::performSearch(const QString &rootPath, const QString &query)
{
    QVariantList results;
    QDirIterator it(rootPath, QDir::AllEntries | QDir::NoDotAndDotDot,
                    QDirIterator::Subdirectories);

    QMimeDatabase mimeDb;
    QString lowerQuery = query.toLower();
    int maxResults = 500;

    while (it.hasNext() && results.size() < maxResults) {
        it.next();
        QFileInfo fi = it.fileInfo();

        if (fi.fileName().contains(lowerQuery, Qt::CaseInsensitive)) {
            if (!fi.isReadable())
                continue;

            QVariantMap entry;
            entry["name"_L1]         = fi.fileName();
            entry["path"_L1]         = fi.absoluteFilePath();
            entry["type"_L1]         = fi.isDir() ? "directory"_L1 : "file"_L1;
            entry["mimeType"_L1]     = mimeDb.mimeTypeForFile(fi).name();
            entry["size"_L1]         = fi.size();
            entry["sizeHuman"_L1]    = humanSize(fi.size());
            entry["modified"_L1]     = fi.lastModified();
            entry["isDir"_L1]        = fi.isDir();
            entry["isHidden"_L1]     = fi.isHidden();
            results.append(entry);
        }
    }

    return results;
}

QString SearchIndexer::humanSize(qint64 bytes)
{
    if (bytes < 1024)
        return QString::number(bytes) + " B"_L1;
    double kb = bytes / 1024.0;
    if (kb < 1024)
        return QString::number(kb, 'f', 1) + " KB"_L1;
    double mb = kb / 1024.0;
    if (mb < 1024)
        return QString::number(mb, 'f', 1) + " MB"_L1;
    double gb = mb / 1024.0;
    return QString::number(gb, 'f', 2) + " GB"_L1;
}
