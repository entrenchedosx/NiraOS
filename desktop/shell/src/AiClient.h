#pragma once

#include <QObject>
#include <QString>
#include <QTimer>
#include <QMutex>
#include <QMutexLocker>
#include <memory>
#include <thread>
#include <atomic>

#include <grpcpp/grpcpp.h>
#include "v1/ai.grpc.pb.h"

/// Streaming gRPC client for the NiraOS AI daemon (niraos.ai.v1.AIService).
///
/// Uses a dedicated worker thread and shared stub ownership to avoid
/// use-after-free. Cancels any in-flight generation before starting a new one.
class AiClient : public QObject
{
    Q_OBJECT

    Q_PROPERTY(QString activeModel READ activeModel NOTIFY statusChanged)
    Q_PROPERTY(double vramUsageMb READ vramUsageMb NOTIFY statusChanged)
    Q_PROPERTY(bool isLoading READ isLoading NOTIFY statusChanged)
    Q_PROPERTY(QString aiMode READ aiMode NOTIFY statusChanged)
    Q_PROPERTY(QString aiState READ aiState NOTIFY statusChanged)

public:
    explicit AiClient(QObject *parent = nullptr);
    ~AiClient() override;

    QString activeModel() const { return activeModel_; }
    double vramUsageMb() const { return vramUsageMb_; }
    bool isLoading() const { return isLoading_; }
    QString aiMode() const { return aiMode_; }
    QString aiState() const { return aiState_; }

    Q_INVOKABLE void streamGenerate(const QString &prompt, double temperature = 0.7, int maxTokens = 256);
    Q_INVOKABLE void setAiMode(const QString &mode);
    Q_INVOKABLE void setInactivityTimeout(int secs);
    Q_INVOKABLE void suggestUnload();

signals:
    void tokenReceived(const QString &token);
    void generationFinished();
    void errorOccurred(const QString &errorMsg);
    void statusChanged();
    void unloadSuggested();

private slots:
    void pollStatus();

private:
    void runGeneration(const QString &prompt, double temperature, int maxTokens);

    std::shared_ptr<grpc::Channel> channel_;
    std::shared_ptr<niraos::ai::v1::AIService::Stub> stub_;

    // Dedicated worker thread for generation
    std::thread workerThread_;
    std::atomic<bool> workerStop_{false};
    std::atomic<bool> generationActive_{false};

    // Cancellation support for in-flight stream
    QMutex contextMutex_;
    std::unique_ptr<grpc::ClientContext> activeContext_;

    QString activeModel_;
    double vramUsageMb_ = 0;
    bool isLoading_ = false;
    QString aiMode_ = "ondemand";
    QString aiState_ = "unloaded";

    QTimer *statusTimer_ = nullptr;
    QTimer *shellInactivityTimer_ = nullptr;
    bool panelOpen_ = true;
};
