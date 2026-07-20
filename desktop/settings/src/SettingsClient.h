#pragma once

#include <QObject>
#include <QString>
#include <memory>

#include <grpcpp/grpcpp.h>
#include <v1/settings.pb.h>
#include <v1/settings.grpc.pb.h>

/// C++ gRPC client for the Rust settings-service (niraos.settings.v1).
/// Connects to localhost:50055 and exposes get/set to QML.
class SettingsClient : public QObject
{
    Q_OBJECT

public:
    explicit SettingsClient(QObject *parent = nullptr);

    Q_INVOKABLE void getSetting(const QString &key);
    Q_INVOKABLE void setSetting(const QString &key, const QString &value);

signals:
    void settingValueReceived(const QString &key, const QString &value, bool exists);
    void settingSaved(const QString &key, bool success, const QString &error);

private:
    std::shared_ptr<grpc::Channel> channel_;
    std::unique_ptr<niraos::settings::v1::SettingsService::Stub> stub_;
};
