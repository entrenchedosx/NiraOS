#pragma once

#include <QObject>
#include <QString>
#include <QVariantMap>
#include <QFutureWatcher>

class FileOperations : public QObject
{
    Q_OBJECT

public:
    explicit FileOperations(QObject *parent = nullptr);

    Q_INVOKABLE void copy(const QString &source, const QString &dest);
    Q_INVOKABLE void move(const QString &source, const QString &dest);
    Q_INVOKABLE void rename(const QString &path, const QString &newName);
    Q_INVOKABLE void delete_(const QString &path, bool permanent = false);
    Q_INVOKABLE void createFolder(const QString &parentDir, const QString &name);
    Q_INVOKABLE void createFile(const QString &parentDir, const QString &name);
    Q_INVOKABLE void duplicate(const QString &path);
    Q_INVOKABLE QVariantMap getFileInfo(const QString &path);
    Q_INVOKABLE void openFile(const QString &path);
    Q_INVOKABLE void openInTerminal(const QString &path);
    Q_INVOKABLE void showProperties(const QString &path);

signals:
    void copyFinished(bool success, const QString &error);
    void moveFinished(bool success, const QString &error);
    void renameFinished(bool success, const QString &error);
    void deleteFinished(bool success, const QString &error);
    void createFolderFinished(bool success, const QString &error);
    void createFileFinished(bool success, const QString &error);
    void duplicateFinished(bool success, const QString &error);
    void operationProgress(const QString &message);

private:
    static bool performCopy(const QString &source, const QString &dest);
    static bool performMove(const QString &source, const QString &dest);
    static bool performDelete(const QString &path, bool permanent);
    static bool performRecursiveCopy(const QString &sourceDir, const QString &destDir);
    static bool performRecursiveDelete(const QString &path);
    static bool moveToTrash(const QString &path);
    static QString humanSize(qint64 bytes);
};
