#include "AppModel.h"

#include <QDebug>
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QIcon>
#include <QProcess>
#include <QRegularExpression>
#include <QStandardPaths>
#include <QTextStream>

// ── Ctor ────────────────────────────────────────────────────────────────

AppModel::AppModel(QObject *parent)
    : QAbstractListModel(parent)
{
    scanDirectories();

    std::sort(allApps_.begin(), allApps_.end(),
              [](const AppEntry &a, const AppEntry &b) {
                  return a.name.compare(b.name, Qt::CaseInsensitive) < 0;
              });

    qInfo() << "AppModel: loaded" << allApps_.size() << "applications";
}

// ── Model API ──────────────────────────────────────────────────────────

int AppModel::rowCount(const QModelIndex &parent) const
{
    return parent.isValid() ? 0 : allApps_.size();
}

QVariant AppModel::data(const QModelIndex &index, int role) const
{
    if (!index.isValid() || index.row() >= allApps_.size())
        return {};

    const auto &app = allApps_.at(index.row());
    switch (role) {
    case NameRole:        return app.name;
    case IconNameRole:    return app.iconName;
    case ExecRole:        return app.exec;
    case GenericNameRole: return app.genericName;
    case AppIdRole:       return app.appId;
    default:              return {};
    }
}

QHash<int, QByteArray> AppModel::roleNames() const
{
    return {
        { NameRole,        "name" },
        { IconNameRole,    "iconName" },
        { ExecRole,        "exec" },
        { GenericNameRole, "genericName" },
        { AppIdRole,       "appId" },
    };
}

QString AppModel::execAt(int row) const
{
    if (row < 0 || row >= allApps_.size())
        return {};
    return allApps_.at(row).exec;
}

// ── Directory scanning ─────────────────────────────────────────────────

void AppModel::scanDirectories()
{
    // standardLocations returns the directories themselves — unlike
    // locateAll("") which would match nothing.
    const QStringList dataDirs =
        QStandardPaths::standardLocations(QStandardPaths::ApplicationsLocation);

    QSet<QString> seen;
    for (const auto &dirPath : dataDirs) {
        QDir dir(dirPath);
        if (!dir.exists())
            continue;
        const auto entries = dir.entryInfoList({"*.desktop"}, QDir::Files | QDir::Readable);
        for (const auto &fi : entries) {
            const QString absPath = fi.absoluteFilePath();
            if (!seen.contains(absPath)) {
                seen.insert(absPath);
                parseDesktopFile(absPath);
            }
        }
    }

    // Also scan user-local applications (may not be in standardLocations
    // if the directory doesn't exist yet).
    const QString userDir = QDir::homePath() + QStringLiteral("/.local/share/applications");
    QDir ud(userDir);
    if (ud.exists()) {
        const auto userEntries = ud.entryInfoList({"*.desktop"}, QDir::Files | QDir::Readable);
        for (const auto &fi : userEntries) {
            const QString absPath = fi.absoluteFilePath();
            if (!seen.contains(absPath)) {
                seen.insert(absPath);
                parseDesktopFile(absPath);
            }
        }
    }
}

// ── Manual .desktop parser ─────────────────────────────────────────────
// QSettings::IniFormat treats ; as a comment delimiter, which silently
// truncates Exec, Name, Categories and other multi-value fields.
// We parse line-by-line instead.

void AppModel::parseDesktopFile(const QString &path)
{
    QFile file(path);
    if (!file.open(QIODevice::ReadOnly | QIODevice::Text))
        return;

    QTextStream in(&file);
    in.setEncoding(QStringConverter::Utf8);

    bool inDesktopEntry = false;
    QString type, name, genericName, iconName, rawExec, categories;
    QString noDisplay, hidden, terminal, tryExec, onlyShowIn, notShowIn;

    while (!in.atEnd()) {
        QString line = in.readLine();

        // Track which section we are in — stop when a new section starts.
        if (line.startsWith('[')) {
            if (inDesktopEntry)
                break;                     // left [Desktop Entry]
            if (line.startsWith("[Desktop Entry]")) {
                inDesktopEntry = true;
            }
            continue;
        }

        if (!inDesktopEntry)
            continue;

        // Skip comment lines.
        if (line.trimmed().startsWith('#'))
            continue;

        // Extract key=value  (first = is the separator).
        int eqPos = line.indexOf('=');
        if (eqPos < 0)
            continue;

        QString key = line.left(eqPos).trimmed();
        QString val = line.mid(eqPos + 1).trimmed();

        if (key == QStringLiteral("Type"))
            type = val;
        else if (key == QStringLiteral("Name"))
            name = val;
        else if (key == QStringLiteral("GenericName"))
            genericName = val;
        else if (key == QStringLiteral("Icon"))
            iconName = val;
        else if (key == QStringLiteral("Exec"))
            rawExec = val;
        else if (key == QStringLiteral("Categories"))
            categories = val;
        else if (key == QStringLiteral("NoDisplay"))
            noDisplay = val;
        else if (key == QStringLiteral("Hidden"))
            hidden = val;
        else if (key == QStringLiteral("Terminal"))
            terminal = val;
        else if (key == QStringLiteral("TryExec"))
            tryExec = val;
        else if (key == QStringLiteral("OnlyShowIn"))
            onlyShowIn = val;
        else if (key == QStringLiteral("NotShowIn"))
            notShowIn = val;
    }

    file.close();

    // Validation.
    if (type != QStringLiteral("Application"))
        return;
    if (noDisplay.compare(QStringLiteral("true"), Qt::CaseInsensitive) == 0
        || hidden.compare(QStringLiteral("true"), Qt::CaseInsensitive) == 0)
        return;

    const QStringList onlyDesktops = onlyShowIn.split(';', Qt::SkipEmptyParts);
    if (!onlyDesktops.isEmpty() && !onlyDesktops.contains(QStringLiteral("NiraOS")))
        return;
    if (notShowIn.split(';', Qt::SkipEmptyParts).contains(QStringLiteral("NiraOS")))
        return;

    if (!tryExec.isEmpty()) {
        const QStringList tryParts = QProcess::splitCommand(tryExec);
        if (tryParts.isEmpty() || QStandardPaths::findExecutable(tryParts.first()).isEmpty())
            return;
    }

    const QString exec = stripExecFieldCodes(rawExec);
    if (exec.isEmpty())
        return;

    AppEntry entry;
    QFileInfo fi(path);
    entry.appId       = fi.completeBaseName();
    entry.name        = name.isEmpty() ? fi.completeBaseName() : name;
    entry.genericName = genericName;
    entry.iconName    = iconName;
    entry.exec        = terminal.compare(QStringLiteral("true"), Qt::CaseInsensitive) == 0
        ? QStringLiteral("qterminal -e ") + exec
        : exec;
    entry.categories  = categories.split(';', Qt::SkipEmptyParts);

    allApps_.append(entry);
}

// ── Strip field codes from Exec ────────────────────────────────────────

QString AppModel::stripExecFieldCodes(const QString &raw)
{
    static const QRegularExpression re(QStringLiteral(
        R"((?:%[uUfFdDnNvmick] ?)|(?:%%))"
    ));
    QString cleaned = raw;
    cleaned.replace(re, QString());
    return cleaned.trimmed();
}
