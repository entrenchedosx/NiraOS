#include "WindowManagerDBus.h"

#include <QDBusConnection>
#include <QDBusError>
#include <QDebug>
#include <QCoreApplication>

WindowManagerDBus::WindowManagerDBus(QObject *parent)
    : QObject(parent)
    , registered_(false)
{
    auto bus = QDBusConnection::sessionBus();

    // Register the service name.
    if (!bus.registerService(serviceName())) {
        qWarning() << "WindowManagerDBus: failed to register service"
                    << serviceName() << ":" << bus.lastError().message();
        return;
    }

    // Export both methods and signals. ExportAllSlots alone makes local Qt
    // signal connections work while silently hiding the window events from
    // the shell process on D-Bus.
    if (!bus.registerObject(objectPath(), this,
                            QDBusConnection::ExportAllSlots
                                | QDBusConnection::ExportAllSignals))
    {
        qWarning() << "WindowManagerDBus: failed to register object at"
                    << objectPath() << ":" << bus.lastError().message();
        bus.unregisterService(serviceName());
        return;
    }

    registered_ = true;
    qInfo() << "WindowManagerDBus: registered" << serviceName() << objectPath();
}

// ── QML interface ──────────────────────────────────────────────────────

void WindowManagerDBus::registerWindow(const QString &id, const QString &title, const QString &appId)
{
    windows_.insert(id, {title, appId, false, false});
    emit windowRegistered(id, title, appId);
}

void WindowManagerDBus::unregisterWindow(const QString &id)
{
    windows_.remove(id);
    emit windowUnregistered(id);
}

void WindowManagerDBus::updateWindowState(const QString &id, bool minimized, bool focused)
{
    if (auto it = windows_.find(id); it != windows_.end()) {
        if (it->minimized == minimized && it->focused == focused)
            return;
        it->minimized = minimized;
        it->focused = focused;
    }
    emit windowStateChanged(id, minimized, focused);
}

void WindowManagerDBus::updateWindowMetadata(const QString &id, const QString &title,
                                              const QString &appId)
{
    if (auto it = windows_.find(id); it != windows_.end()) {
        it->title = title;
        it->appId = appId;
    }
    emit windowMetadataChanged(id, title, appId);
}

// ── Shell-facing D-Bus slots ───────────────────────────────────────────
// These are called by the shell via D-Bus.  They forward to C++ signals
// that the QML side connects to for actual window manipulation.

void WindowManagerDBus::ActivateWindow(const QString &id)
{
    qInfo() << "WindowManagerDBus: ActivateWindow" << id;
    emit activateRequested(id);
}

void WindowManagerDBus::MinimizeWindow(const QString &id)
{
    qInfo() << "WindowManagerDBus: MinimizeWindow" << id;
    emit minimizeRequested(id);
}

void WindowManagerDBus::CloseWindow(const QString &id)
{
    qInfo() << "WindowManagerDBus: CloseWindow" << id;
    emit closeRequested(id);
}

QStringList WindowManagerDBus::ListWindowIds() const
{
    return windows_.keys();
}

QString WindowManagerDBus::WindowTitle(const QString &id) const
{
    return windows_.value(id).title;
}

QString WindowManagerDBus::WindowAppId(const QString &id) const
{
    return windows_.value(id).appId;
}

bool WindowManagerDBus::WindowMinimized(const QString &id) const
{
    return windows_.value(id).minimized;
}

bool WindowManagerDBus::WindowFocused(const QString &id) const
{
    return windows_.value(id).focused;
}
