#include "AiClient.h"

#include <QDebug>
#include <QMetaObject>
#include <QPointer>
#include <QThread>

AiClient::AiClient(QObject *parent)
    : QObject(parent)
    , channel_(grpc::CreateChannel("unix:/run/niraos/ai.sock", grpc::InsecureChannelCredentials()))
    , stub_(niraos::ai::v1::AIService::NewStub(channel_))
{
    statusTimer_ = new QTimer(this);
    connect(statusTimer_, &QTimer::timeout, this, &AiClient::pollStatus);
    statusTimer_->start(5000);

    shellInactivityTimer_ = new QTimer(this);
    shellInactivityTimer_->setSingleShot(true);
    connect(shellInactivityTimer_, &QTimer::timeout, this, [this]() {
        if (!panelOpen_) {
            emit unloadSuggested();
        }
    });

    QTimer::singleShot(0, this, &AiClient::pollStatus);
}

AiClient::~AiClient()
{
    workerStop_.store(true);
    {
        QMutexLocker lock(&contextMutex_);
        if (activeContext_) {
            activeContext_->TryCancel();
            activeContext_.reset();
        }
    }
    if (workerThread_.joinable())
        workerThread_.join();
}

void AiClient::streamGenerate(const QString &prompt, double temperature, int maxTokens)
{
    const QString trimmed = prompt.trimmed();
    if (trimmed.isEmpty()) {
        emit errorOccurred("Enter a prompt before sending.");
        return;
    }
    if (trimmed.toUtf8().size() > 32 * 1024) {
        emit errorOccurred("The prompt exceeds the 32 KiB request limit.");
        return;
    }

    // Cancel any in-flight generation before starting a new one.
    {
        QMutexLocker lock(&contextMutex_);
        if (activeContext_) {
            activeContext_->TryCancel();
            activeContext_.reset();
        }
    }

    // Wait for previous worker to finish
    if (workerThread_.joinable())
        workerThread_.join();

    generationActive_.store(true);

    // Copy data for the worker thread
    const QString promptCopy = trimmed;
    const double tempCopy = temperature;
    const int tokensCopy = maxTokens;
    const auto stubCopy = stub_;

    workerThread_ = std::thread([this, stubCopy, promptCopy, tempCopy, tokensCopy]() {
        runGeneration(promptCopy, tempCopy, tokensCopy);
    });
}

void AiClient::runGeneration(const QString &prompt, double temperature, int maxTokens)
{
    const QPointer<AiClient> receiver(this);

    auto context = std::make_unique<grpc::ClientContext>();
    // The server opens the stream immediately and performs any cold model
    // load inside the stream (see ai-daemon grpc/mod.rs), so this deadline
    // only needs to cover the load + generation, not a blocking pre-load.
    // 180 s is generous for a cold load on slow hardware plus a 256-token
    // generation; the server also sends HTTP/2 keepalive PINGs every 30 s.
    context->set_deadline(std::chrono::system_clock::now() + std::chrono::seconds(180));

    // Register the context so cancellation works across threads
    {
        QMutexLocker lock(&contextMutex_);
        if (workerStop_.load()) return;
        activeContext_ = std::move(context);
    }

    grpc::ClientContext *activeCtx = nullptr;
    {
        QMutexLocker lock(&contextMutex_);
        if (!activeContext_) return;
        activeCtx = activeContext_.get();
    }

    niraos::ai::v1::GenerateRequest request;
    request.set_prompt(prompt.toStdString());
    request.set_temperature(static_cast<float>(temperature));
    request.set_max_tokens(maxTokens);
    request.set_context_id("active");

    auto reader = stub_->StreamGenerate(activeCtx, request);
    if (!reader) {
        QMutexLocker lock(&contextMutex_);
        activeContext_.reset();
        if (receiver) {
            QMetaObject::invokeMethod(receiver, [receiver]() {
                if (receiver) emit receiver->errorOccurred("Failed to initiate AI stream.");
            }, Qt::QueuedConnection);
        }
        generationActive_.store(false);
        return;
    }

    niraos::ai::v1::AIResponse response;
    while (reader->Read(&response)) {
        if (!receiver || workerStop_.load()) {
            reader->Finish();
            QMutexLocker lock(&contextMutex_);
            activeContext_.reset();
            generationActive_.store(false);
            return;
        }

        const QString text = QString::fromStdString(response.text());

        if (response.is_finished()) {
            QMetaObject::invokeMethod(receiver, [receiver]() {
                if (receiver) emit receiver->generationFinished();
            }, Qt::QueuedConnection);
            break;
        }

        if (!text.isEmpty()) {
            QMetaObject::invokeMethod(receiver, [receiver, text]() {
                if (receiver) emit receiver->tokenReceived(text);
            }, Qt::QueuedConnection);
        }
    }

    const grpc::Status status = reader->Finish();
    {
        QMutexLocker lock(&contextMutex_);
        activeContext_.reset();
    }

    if (!status.ok() && !receiver.isNull()
        && status.error_code() != grpc::StatusCode::CANCELLED
        && !workerStop_.load())
    {
        const QString msg = QString::fromStdString(status.error_message());
        QMetaObject::invokeMethod(receiver, [receiver, msg]() {
            if (receiver) emit receiver->errorOccurred(msg);
        }, Qt::QueuedConnection);
    }

    generationActive_.store(false);
}

void AiClient::setAiMode(const QString &mode)
{
    const auto stub = stub_;
    const QPointer<AiClient> receiver(this);
    std::thread t([receiver, stub, mode]() {
        niraos::ai::v1::SetModeRequest req;
        req.set_mode(mode.toStdString());
        grpc::ClientContext ctx;
        ctx.set_deadline(std::chrono::system_clock::now() + std::chrono::seconds(5));
        niraos::ai::v1::SetModeResponse resp;
        grpc::Status status = stub->SetMode(&ctx, req, &resp);
        if (receiver && status.ok() && resp.success()) {
            QMetaObject::invokeMethod(receiver, [receiver, mode]() {
                if (receiver) {
                    receiver->aiMode_ = mode;
                    emit receiver->statusChanged();
                }
            }, Qt::QueuedConnection);
        } else if (receiver) {
            QString err = QString::fromStdString(status.error_message());
            if (err.isEmpty()) err = QString::fromStdString(resp.error());
            QMetaObject::invokeMethod(receiver, [receiver, err]() {
                if (receiver) emit receiver->errorOccurred("Failed to set AI mode: " + err);
            }, Qt::QueuedConnection);
        }
    });
    t.detach();
}

void AiClient::setInactivityTimeout(int secs)
{
    const auto stub = stub_;
    const QPointer<AiClient> receiver(this);
    std::thread t([receiver, stub, secs]() {
        niraos::ai::v1::SetInactivityTimeoutRequest req;
        req.set_timeout_secs(secs);
        grpc::ClientContext ctx;
        ctx.set_deadline(std::chrono::system_clock::now() + std::chrono::seconds(5));
        niraos::ai::v1::SetInactivityTimeoutResponse resp;
        grpc::Status status = stub->SetInactivityTimeout(&ctx, req, &resp);
        if (!receiver) return;
        if (!status.ok() || !resp.success()) {
            QString err = QString::fromStdString(status.error_message());
            if (err.isEmpty()) err = QString::fromStdString(resp.error());
            QMetaObject::invokeMethod(receiver, [receiver, err]() {
                if (receiver) emit receiver->errorOccurred("Failed to set inactivity timeout: " + err);
            }, Qt::QueuedConnection);
        }
    });
    t.detach();
}

void AiClient::suggestUnload()
{
    // Sends unload suggestion to the QML layer via the unloadSuggested signal
    emit unloadSuggested();
}

void AiClient::pollStatus()
{
    const QPointer<AiClient> receiver(this);
    const auto stub = stub_;

    // Use a dedicated thread for status polling to avoid blocking
    std::thread t([receiver, stub]() {
        niraos::ai::v1::StatusRequest req;
        grpc::ClientContext ctx;
        ctx.set_deadline(std::chrono::system_clock::now() + std::chrono::seconds(3));

        niraos::ai::v1::AIStatus resp;
        grpc::Status status = stub->GetStatus(&ctx, req, &resp);

        if (!receiver) return;

        const QString model = QString::fromStdString(resp.active_model());
        const double vram = static_cast<double>(resp.vram_usage_mb());
        const bool loading = resp.is_loading();
        const QString mode = QString::fromStdString(resp.mode());
        const QString state = QString::fromStdString(resp.state());

        QMetaObject::invokeMethod(receiver, [receiver, model, vram, loading, mode, state]() {
            if (!receiver) return;
            bool changed = false;
            if (receiver->activeModel_ != model)  { receiver->activeModel_ = model;  changed = true; }
            if (qAbs(receiver->vramUsageMb_ - vram) > 0.1) { receiver->vramUsageMb_ = vram; changed = true; }
            if (receiver->isLoading_ != loading)  { receiver->isLoading_ = loading; changed = true; }
            if (receiver->aiMode_ != mode)  { receiver->aiMode_ = mode;  changed = true; }
            if (receiver->aiState_ != state)  { receiver->aiState_ = state;  changed = true; }
            if (changed) emit receiver->statusChanged();
        }, Qt::QueuedConnection);
    });
    t.detach();
}