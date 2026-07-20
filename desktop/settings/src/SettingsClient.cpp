#include "SettingsClient.h"

#include <QDebug>
#include <QMetaObject>
#include <QPointer>
#include <QThread>

using niraos::settings::v1::GetSettingRequest;
using niraos::settings::v1::GetSettingResponse;
using niraos::settings::v1::SetSettingRequest;
using niraos::settings::v1::SetSettingResponse;

SettingsClient::SettingsClient(QObject *parent)
    : QObject(parent)
    , channel_(grpc::CreateChannel("unix:/run/niraos/settings.sock", grpc::InsecureChannelCredentials()))
    , stub_(niraos::settings::v1::SettingsService::NewStub(channel_))
{
}

void SettingsClient::getSetting(const QString &key)
{
    const QPointer<SettingsClient> receiver(this);
    const auto stub = stub_.get();

    QThread *thread = QThread::create([receiver, stub, key]() {
        GetSettingRequest request;
        request.set_key(key.toStdString());

        grpc::ClientContext context;
        context.set_deadline(std::chrono::system_clock::now() + std::chrono::seconds(5));

        GetSettingResponse response;
        grpc::Status status = stub->GetSetting(&context, request, &response);

        if (!receiver) return;

        if (status.ok()) {
            const QString value = QString::fromStdString(response.value());
            const bool exists = response.exists();
            QMetaObject::invokeMethod(receiver, [receiver, key, value, exists]() {
                if (receiver)
                    emit receiver->settingValueReceived(key, value, exists);
            }, Qt::QueuedConnection);
        } else {
            QMetaObject::invokeMethod(receiver, [receiver, key]() {
                if (receiver)
                    emit receiver->settingValueReceived(key, QString(), false);
            }, Qt::QueuedConnection);
        }
    });

    connect(thread, &QThread::finished, thread, &QThread::deleteLater);
    thread->start();
}

void SettingsClient::setSetting(const QString &key, const QString &value)
{
    const QPointer<SettingsClient> receiver(this);
    const auto stub = stub_.get();

    QThread *thread = QThread::create([receiver, stub, key, value]() {
        SetSettingRequest request;
        request.set_key(key.toStdString());
        request.set_value(value.toStdString());

        grpc::ClientContext context;
        context.set_deadline(std::chrono::system_clock::now() + std::chrono::seconds(5));

        SetSettingResponse response;
        grpc::Status status = stub->SetSetting(&context, request, &response);

        if (!receiver) return;

        if (status.ok()) {
            QMetaObject::invokeMethod(receiver, [receiver, key, response]() {
                if (receiver)
                    emit receiver->settingSaved(key, response.success(),
                        QString::fromStdString(response.error()));
            }, Qt::QueuedConnection);
        } else {
            QMetaObject::invokeMethod(receiver, [receiver, key]() {
                if (receiver)
                    emit receiver->settingSaved(key, false,
                        QStringLiteral("gRPC call failed"));
            }, Qt::QueuedConnection);
        }
    });

    connect(thread, &QThread::finished, thread, &QThread::deleteLater);
    thread->start();
}
