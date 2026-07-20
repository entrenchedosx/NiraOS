#pragma once

#include <QObject>
#include <QString>

/// Reads /sys/class/power_supply to expose battery state to the system tray.
/// On a desktop machine (no battery) `present` is false and QML shows no
/// battery icon — there is no fake "100%" hard-coded value.
class PowerStatus : public QObject
{
    Q_OBJECT
    Q_PROPERTY(bool present READ present NOTIFY presentChanged)
    Q_PROPERTY(int percent READ percent NOTIFY percentChanged)
    Q_PROPERTY(QString status READ status NOTIFY statusChanged)
    Q_PROPERTY(bool charging READ charging NOTIFY statusChanged)

public:
    explicit PowerStatus(QObject *parent = nullptr);

    bool present() const { return present_; }
    int percent() const { return percent_; }
    QString status() const { return status_; }
    bool charging() const { return status_ == QStringLiteral("Charging"); }

public slots:
    void refresh();

signals:
    void presentChanged();
    void percentChanged();
    void statusChanged();

private:
    void scan();

    QString batteryDir_;
    bool present_ = false;
    int percent_ = 0;
    QString status_ = QStringLiteral("Unknown");
};
