#pragma once

#include <QObject>
#include <QString>
#include <QVariantList>
#include <QFutureWatcher>

class SearchIndexer : public QObject
{
    Q_OBJECT

public:
    explicit SearchIndexer(QObject *parent = nullptr);

    Q_INVOKABLE void search(const QString &rootPath, const QString &query);
    Q_INVOKABLE void cancel();

signals:
    void resultsFound(const QVariantList &results);
    void searchFinished(bool cancelled);

private:
    static QVariantList performSearch(const QString &rootPath, const QString &query);
    static QString humanSize(qint64 bytes);

    QFutureWatcher<QVariantList> *watcher_;
};
