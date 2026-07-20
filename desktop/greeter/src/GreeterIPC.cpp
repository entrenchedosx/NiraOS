#include "GreeterIPC.h"

#include <QDebug>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QLocalSocket>

#include <cstring>

static const QString FALLBACK_SOCKET_PATH = QStringLiteral("/run/greetd.sock");

GreeterIPC::GreeterIPC(QObject *parent)
    : QObject(parent)
{
    socket_ = new QLocalSocket(this);
    socketPath_ = qEnvironmentVariable("GREETD_SOCK");
    if (socketPath_.isEmpty())
        socketPath_ = FALLBACK_SOCKET_PATH;

    connect(socket_, &QLocalSocket::connected, this, &GreeterIPC::sendCreateSession);
    connect(socket_, &QLocalSocket::readyRead, this, &GreeterIPC::onReadyRead);
    connect(socket_, &QLocalSocket::errorOccurred, this, &GreeterIPC::onError);
    qInfo() << "GreeterIPC: using greetd socket" << socketPath_;
}

bool GreeterIPC::busy() const
{
    return phase_ == Phase::CreatingSession
        || (phase_ == Phase::Authenticating && !awaitingResponse_)
        || phase_ == Phase::StartingSession;
}

void GreeterIPC::startAuth(const QString &username, const QString &password)
{
    const QString requestedUser = username.trimmed();
    if (requestedUser.isEmpty()) {
        statusMessage_ = QStringLiteral("Username cannot be empty.");
        emit statusChanged();
        emit authFailed(statusMessage_);
        return;
    }

    // Reconnecting cancels any incomplete PAM conversation from a previous
    // attempt. Do this before changing phase so an abort cannot surface as a
    // new-attempt connection error.
    if (socket_->state() != QLocalSocket::UnconnectedState)
        socket_->abort();

    readBuffer_.clear();
    currentUser_ = requestedUser;
    pendingPassword_ = password;
    credentialSubmitted_ = false;
    awaitingResponse_ = false;
    authenticated_ = false;
    phase_ = Phase::CreatingSession;
    statusMessage_ = QStringLiteral("Connecting...");
    emit statusChanged();

    // QLocalSocket connection is asynchronous so a missing greetd service
    // never freezes the Qt render thread.
    socket_->connectToServer(socketPath_);
}

void GreeterIPC::sendCreateSession()
{
    if (phase_ != Phase::CreatingSession)
        return;

    QJsonObject request;
    request[QStringLiteral("type")] = QStringLiteral("create_session");
    request[QStringLiteral("username")] = currentUser_;
    sendJson(request);

    statusMessage_ = QStringLiteral("Authenticating...");
    emit statusChanged();
}

void GreeterIPC::submitPassword(const QString &password)
{
    if (phase_ != Phase::CreatingSession && phase_ != Phase::Authenticating)
        return;

    phase_ = Phase::Authenticating;
    credentialSubmitted_ = true;
    awaitingResponse_ = false;

    QJsonObject request;
    request[QStringLiteral("type")] = QStringLiteral("post_auth_message_response");
    request[QStringLiteral("response")] = password;
    sendJson(request);
}

void GreeterIPC::startSession()
{
    if (phase_ != Phase::Authenticated)
        return;

    phase_ = Phase::StartingSession;
    statusMessage_ = QStringLiteral("Starting session...");
    emit statusChanged();

    QJsonObject request;
    request[QStringLiteral("type")] = QStringLiteral("start_session");
    QJsonArray command;
    command.append(QStringLiteral("/usr/bin/start-nira-session"));
    request[QStringLiteral("cmd")] = command;
    request[QStringLiteral("env")] = QJsonArray();
    sendJson(request);
}

void GreeterIPC::onReadyRead()
{
    readBuffer_.append(socket_->readAll());

    // greetd frames every UTF-8 JSON payload with a native-endian uint32
    // payload length. See greetd-ipc(7).
    while (true) {
        if (readBuffer_.size() < static_cast<int>(sizeof(quint32)))
            break;

        quint32 payloadLength = 0;
        std::memcpy(&payloadLength, readBuffer_.constData(), sizeof(payloadLength));
        constexpr quint32 MaxPayloadLength = 1024 * 1024;
        if (payloadLength == 0 || payloadLength > MaxPayloadLength) {
            statusMessage_ = QStringLiteral("Invalid response from the login service.");
            phase_ = Phase::Idle;
            authenticated_ = false;
            awaitingResponse_ = false;
            readBuffer_.clear();
            socket_->abort();
            emit statusChanged();
            emit authFailed(statusMessage_);
            return;
        }

        const qsizetype frameLength = sizeof(quint32) + payloadLength;
        if (readBuffer_.size() < frameLength)
            break;

        const QByteArray payload = readBuffer_.mid(sizeof(quint32), payloadLength);
        readBuffer_.remove(0, frameLength);

        QJsonParseError error;
        const QJsonDocument document = QJsonDocument::fromJson(payload, &error);
        if (error.error != QJsonParseError::NoError || !document.isObject()) {
            qWarning() << "GreeterIPC: invalid JSON from greetd:" << error.errorString();
            continue;
        }
        handleMessage(document.object());
    }
}

void GreeterIPC::onError(QLocalSocket::LocalSocketError error)
{
    Q_UNUSED(error)
    // greetd closes the greeter connection as it hands control to the user
    // session. That is expected after StartSession, not an authentication
    // failure to display over the transition.
    if (phase_ == Phase::StartingSession)
        return;

    statusMessage_ = QStringLiteral("Connection error: ") + socket_->errorString();
    phase_ = Phase::Idle;
    authenticated_ = false;
    awaitingResponse_ = false;
    pendingPassword_.clear();
    emit statusChanged();
    emit authFailed(statusMessage_);
}

void GreeterIPC::sendJson(const QJsonObject &object)
{
    if (socket_->state() != QLocalSocket::ConnectedState) {
        qWarning() << "GreeterIPC: refusing to write while disconnected";
        return;
    }

    const QByteArray payload = QJsonDocument(object).toJson(QJsonDocument::Compact);
    const quint32 payloadLength = static_cast<quint32>(payload.size());
    socket_->write(reinterpret_cast<const char *>(&payloadLength), sizeof(payloadLength));
    socket_->write(payload);
    socket_->flush();
}

void GreeterIPC::handleMessage(const QJsonObject &message)
{
    const QString type = message.value(QStringLiteral("type")).toString();

    if (type == QStringLiteral("auth_message")) {
        statusMessage_ = message.value(QStringLiteral("auth_message")).toString();
        if (statusMessage_.isEmpty())
            statusMessage_ = QStringLiteral("Password:");
        emit statusChanged();

        const QString messageType =
            message.value(QStringLiteral("auth_message_type")).toString();
        const bool requestsCredential = messageType.isEmpty()
            || messageType == QStringLiteral("secret")
            || messageType == QStringLiteral("visible");

        if (requestsCredential && !credentialSubmitted_) {
            const QString password = pendingPassword_;
            pendingPassword_.clear();
            submitPassword(password);
        } else if (requestsCredential) {
            awaitingResponse_ = true;
            emit statusChanged();
        } else if (messageType == QStringLiteral("info")
                   || messageType == QStringLiteral("error")) {
            QJsonObject response;
            response[QStringLiteral("type")] = QStringLiteral("post_auth_message_response");
            sendJson(response);
        }
        return;
    }

    if (type == QStringLiteral("success")) {
        if (phase_ == Phase::StartingSession) {
            statusMessage_ = QStringLiteral("Session started");
            emit statusChanged();
            return;
        }

        phase_ = Phase::Authenticated;
        authenticated_ = true;
        awaitingResponse_ = false;
        pendingPassword_.clear();
        statusMessage_ = QStringLiteral("Authentication successful");
        emit statusChanged();
        emit authSucceeded();
        return;
    }

    if (type == QStringLiteral("error")) {
        QString description = message.value(QStringLiteral("description")).toString();
        if (description.isEmpty())
            description = QStringLiteral("Authentication failed.");

        phase_ = Phase::Idle;
        authenticated_ = false;
        awaitingResponse_ = false;
        pendingPassword_.clear();
        statusMessage_ = description;
        emit statusChanged();
        emit authFailed(description);
        return;
    }

    qWarning() << "GreeterIPC: unknown message type:" << type;
}
