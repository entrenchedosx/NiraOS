#include "ContextExporter.h"

#include <QPointer>
#include <QDebug>
#include <QDir>
#include <QSaveFile>
#include <QJsonDocument>
#include <QJsonObject>
#include <QtConcurrent/QtConcurrentRun>

// ── Helpers ────────────────────────────────────────────────────────────

static QString defaultRuntimeDir()
{
    QString d = qEnvironmentVariable("XDG_RUNTIME_DIR");
    return d.isEmpty() ? QDir::tempPath() : d;
}

// ── Ctor ───────────────────────────────────────────────────────────────

ContextExporter::ContextExporter(QObject *parent)
    : QObject(parent)
    , filePath_(defaultRuntimeDir() + QStringLiteral("/nira-active-window.json"))
    , seatName_(QStringLiteral("default"))
    , pendingFlush_(0)
{
    flushTimer_.setSingleShot(true);
    flushTimer_.setInterval(100);          // 100 ms debounce
    connect(&flushTimer_, &QTimer::timeout, this, &ContextExporter::onFlushTimer);

    qInfo() << "ContextExporter writes to" << filePath_;
}

// ── Setters (GUI thread only — just update memory + restart timer) ─────

void ContextExporter::setActiveAppId(const QString &appId)
{
    if (activeAppId_ == appId)
        return;
    activeAppId_ = appId;
    emit activeWindowChanged();
    flushTimer_.start();
}

void ContextExporter::setActiveTitle(const QString &title)
{
    if (activeTitle_ == title)
        return;
    activeTitle_ = title;
    emit activeWindowChanged();
    flushTimer_.start();
}

// ── Flush timer callback ───────────────────────────────────────────────
// Runs on the GUI (main) thread.  Captures the current string state then
// hands the actual I/O to a background thread.

void ContextExporter::onFlushTimer()
{
    if (pendingFlush_.loadRelaxed() != 0)
        return;                     // a flush is already in flight

    pendingFlush_.storeRelaxed(1);  // prevent stacking

    const QString path = filePath_;
    const QString appId = activeAppId_;
    const QString title = activeTitle_;
    const QString seat = seatName_;

    QPointer<ContextExporter> guard(this);
    QtConcurrent::run([path, appId, title, seat]() {
        writeToDisk(path, appId, title, seat);
    }).then(this, [guard]() {
        if (guard)
            guard->pendingFlush_.storeRelaxed(0);
    });
}

// ── Immediate flush (used on shutdown; still offloaded) ────────────────

void ContextExporter::flush()
{
    // Cancel any pending debounce timer and write immediately.
    flushTimer_.stop();
    onFlushTimer();
}

// ── Background I/O (off the GUI thread entirely) ───────────────────────

void ContextExporter::writeToDisk(const QString &path,
                                  const QString &appId,
                                  const QString &title,
                                  const QString &seat)
{
    QJsonObject obj;
    obj[QStringLiteral("app_id")] = appId;
    obj[QStringLiteral("title")]  = title;
    obj[QStringLiteral("seat")]   = seat;

    const QByteArray data = QJsonDocument(obj).toJson(QJsonDocument::Compact);

    // QSaveFile handles the atomic overwrite internally:
    //   writes to a temporary file, fsyncs, then atomically renames
    //   the temp over the destination (overwriting if it exists).
    // Unlike QFile::rename, QSaveFile::commit() DOES overwrite an
    // existing destination — this is the correct POSIX rename(2)
    // behaviour that Qt's QFile::rename inexplicably omits.
    QSaveFile file(path);
    if (!file.open(QIODevice::WriteOnly)) {
        qWarning().noquote() << "ContextExporter: cannot open" << path << file.errorString();
        return;
    }
    file.write(data);
    file.write("\n");
    if (!file.commit()) {
        qWarning().noquote() << "ContextExporter: commit failed for" << path;
    }
}
