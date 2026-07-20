#pragma once

#include <QObject>
#include <QString>
#include <QLocalSocket>
#include <QJsonObject>

/// Communicates with greetd over its UNIX socket (/run/greetd.sock) using
/// the JSON request/response protocol.
///
/// Protocol:
///   1. CreateSession  →  AuthMessage  (password prompt)
///   2. PostAuthMessageResponse(password)  →  AuthMessage | Success | Failure
///   3. StartSession(cmd)  →  Success
class GreeterIPC : public QObject
{
    Q_OBJECT

    Q_PROPERTY(QString statusMessage READ statusMessage NOTIFY statusChanged)
    Q_PROPERTY(bool authenticated READ authenticated NOTIFY statusChanged)
    Q_PROPERTY(bool awaitingResponse READ awaitingResponse NOTIFY statusChanged)
    Q_PROPERTY(bool busy READ busy NOTIFY statusChanged)

public:
    explicit GreeterIPC(QObject *parent = nullptr);

    QString statusMessage() const { return statusMessage_; }
    bool authenticated() const { return authenticated_; }
    bool awaitingResponse() const { return awaitingResponse_; }
    bool busy() const;

    Q_INVOKABLE void startAuth(const QString &username, const QString &password);
    Q_INVOKABLE void submitPassword(const QString &password);
    Q_INVOKABLE void startSession();

signals:
    void statusChanged();
    void authSucceeded();
    void authFailed(const QString &reason);

private slots:
    void onReadyRead();
    void onError(QLocalSocket::LocalSocketError err);

private:
    enum class Phase {
        Idle,
        CreatingSession,
        Authenticating,
        Authenticated,
        StartingSession,
    };

    void sendCreateSession();
    void sendJson(const QJsonObject &obj);
    void handleMessage(const QJsonObject &msg);

    QLocalSocket *socket_ = nullptr;
    QString socketPath_;
    QString currentUser_;
    QString pendingPassword_;
    QString statusMessage_;
    bool authenticated_ = false;
    bool awaitingResponse_ = false;
    bool credentialSubmitted_ = false;
    Phase phase_ = Phase::Idle;
    QByteArray readBuffer_;
};
