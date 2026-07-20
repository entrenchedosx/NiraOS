#pragma once

#include <QObject>
#include <QString>
#include <QHash>
#include <QSet>
#include <QStringList>
#include <QDBusConnection>
#include <QDBusMessage>

/// D-Bus service that lets the shell (running in a separate process)
/// query and control the compositor's window stack.
///
/// D-Bus interface  io.niraos.Compositor.WindowManager
/// Path             /WindowManager
/// Service name     io.niraos.Compositor
///
/// QML side calls registerWindow / unregisterWindow / updateWindowState.
/// The shell calls ActivateWindow / MinimizeWindow / CloseWindow, which
/// cause C++ signals that the QML side handles to perform the actual
/// geometry / visibility changes.
class WindowManagerDBus : public QObject
{
    Q_OBJECT

    Q_CLASSINFO("D-Bus Interface", "io.niraos.Compositor.WindowManager")

public:
    explicit WindowManagerDBus(QObject *parent = nullptr);

    // ── Called from QML chrome instances ───────────────────────────────
    Q_INVOKABLE void registerWindow(const QString &id, const QString &title, const QString &appId);
    Q_INVOKABLE void unregisterWindow(const QString &id);
    Q_INVOKABLE void updateWindowState(const QString &id, bool minimized, bool focused);
    Q_INVOKABLE void updateWindowMetadata(const QString &id, const QString &title,
                                          const QString &appId);

    // ── Called by the shell over D-Bus ─────────────────────────────────
public slots:
    Q_SCRIPTABLE void ActivateWindow(const QString &id);
    Q_SCRIPTABLE void MinimizeWindow(const QString &id);
    Q_SCRIPTABLE void CloseWindow(const QString &id);
    Q_SCRIPTABLE QStringList ListWindowIds() const;
    Q_SCRIPTABLE QString WindowTitle(const QString &id) const;
    Q_SCRIPTABLE QString WindowAppId(const QString &id) const;
    Q_SCRIPTABLE bool WindowMinimized(const QString &id) const;
    Q_SCRIPTABLE bool WindowFocused(const QString &id) const;

    // ── Signals that QML handles for actual window ops ─────────────────
signals:
    void activateRequested(const QString &id);
    void minimizeRequested(const QString &id);
    void closeRequested(const QString &id);

    // Notify remote listeners (the shell) about window changes.
    void windowRegistered(const QString &id, const QString &title, const QString &appId);
    void windowUnregistered(const QString &id);
    void windowStateChanged(const QString &id, bool minimized, bool focused);
    void windowMetadataChanged(const QString &id, const QString &title,
                               const QString &appId);

private:
    static QString serviceName() { return QStringLiteral("io.niraos.Compositor"); }
    static QString objectPath()  { return QStringLiteral("/WindowManager"); }
    static QString interfaceName() { return QStringLiteral("io.niraos.Compositor.WindowManager"); }

    bool registered_;
    struct WindowRecord {
        QString title;
        QString appId;
        bool minimized = false;
        bool focused = false;
    };
    QHash<QString, WindowRecord> windows_;
};
