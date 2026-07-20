#pragma once

#include <QObject>
#include <QString>
#include <QProcess>

/// Controls the system output volume via the PulseAudio/PipeWire command-line
/// tools (`pactl`).  This avoids a hard PipeWire or PulseAudio C-API link so
/// the shell builds and runs even when only one of them is installed.
///
/// All operations degrade gracefully: if `pactl` is missing the shell logs a
/// warning and keeps running with `available=false`, so the system tray
/// volume popup is hidden on minimal installs instead of presenting dead
/// controls.
class VolumeControl : public QObject
{
    Q_OBJECT
    Q_PROPERTY(bool available READ available NOTIFY availableChanged)
    Q_PROPERTY(int volume READ volume NOTIFY volumeChanged)
    Q_PROPERTY(bool muted READ muted NOTIFY mutedChanged)

public:
    explicit VolumeControl(QObject *parent = nullptr);

    bool available() const { return available_; }
    int volume() const { return volume_; }
    bool muted() const { return muted_; }

    /// Set volume in percent (0-100, clamped).  Triggers an async pactl call;
    /// volumeChanged is emitted once the change is reflected.
    Q_INVOKABLE void setVolume(int percent);
    Q_INVOKABLE void toggleMuted();
    Q_INVOKABLE void refresh();

signals:
    void availableChanged();
    void volumeChanged();
    void mutedChanged();

private:
    void probeAvailability();
    void readState();
    static QString pactlPath();

    bool available_ = false;
    int volume_ = 0;
    bool muted_ = false;
};
