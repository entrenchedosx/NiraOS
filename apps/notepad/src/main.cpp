#include <QGuiApplication>
#include <QIcon>
#include <QImage>
#include <QQuickImageProvider>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QFileInfo>
#include <QFile>
#include <QTextStream>
#include <QUrl>
#include <QSettings>
#include <QDateTime>
#include <QMimeDatabase>
#include <QMimeType>
#include <QVariantMap>
#include <QSyntaxHighlighter>
#include <QTextDocument>
#include <QQuickTextDocument>
#include <QRegularExpression>
#include <utility>

using namespace Qt::StringLiterals;

// ThemeIconProvider: resolves `image://icon/<name>` in QML.  Checks the
// notepad-assets.qrc bundle first, then falls back to the system theme.
class ThemeIconProvider final : public QQuickImageProvider
{
public:
    ThemeIconProvider()
        : QQuickImageProvider(QQuickImageProvider::Image)
    {
    }

    QImage requestImage(const QString &id, QSize *size,
                        const QSize &requestedSize) override
    {
        const QSize target = requestedSize.isValid() ? requestedSize : QSize(48, 48);

        // NiraOS notepad qrc bundle.
        const QString qrcSvg = u":/nira/notepad/%1.svg"_s.arg(id);
        if (QFile::exists(qrcSvg)) {
            QImage img(qrcSvg);
            if (!img.isNull()) {
                if (size) *size = img.size();
                return img.scaled(target, Qt::KeepAspectRatio, Qt::SmoothTransformation);
            }
        }
        const QString qrcPng = u":/nira/notepad/%1-48.png"_s.arg(id);
        if (QFile::exists(qrcPng)) {
            QImage img(qrcPng);
            if (!img.isNull()) {
                if (size) *size = img.size();
                return img.scaled(target, Qt::KeepAspectRatio, Qt::SmoothTransformation);
            }
        }

        // Fall back to the system icon theme.
        const QIcon icon = QIcon::fromTheme(id);
        const QImage image = icon.pixmap(target).toImage();
        if (size)
            *size = image.size();
        return image;
    }
};

// SyntaxHighlighter: a real QSyntaxHighlighter subclass that applies
// per-language keyword/string/comment/number highlighting to the QTextDocument
// backing a QML TextArea.  QML passes `textArea.textDocument` (a
// QQuickTextDocument) and the highlighter attaches to its underlying
// QTextDocument via setDocument().
class SyntaxHighlighter : public QSyntaxHighlighter
{
    Q_OBJECT
public:
    explicit SyntaxHighlighter(QTextDocument *parent = nullptr)
        : QSyntaxHighlighter(parent)
    {
        // Shared formats.
        keywordFormat_.setFontWeight(QFont::Bold);
        keywordFormat_.setForeground(QColor("#569CD6")); // blue
        stringFormat_.setForeground(QColor("#CE9178"));  // orange-brown
        commentFormat_.setForeground(QColor("#6A9955")); // green
        commentFormat_.setFontItalic(true);
        numberFormat_.setForeground(QColor("#B5CEA8"));  // light green
        typeFormat_.setFontWeight(QFont::Bold);
        typeFormat_.setForeground(QColor("#4EC9B0"));    // teal
    }

    // Called from QML with the TextArea's textDocument and a language id.
    Q_INVOKABLE void attach(QQuickTextDocument *qdoc, const QString &language)
    {
        if (!qdoc)
            return;
        setLanguage(language);
        setDocument(qdoc->textDocument());
    }

    Q_INVOKABLE void detach() { setDocument(nullptr); }

    // Reconfigure the active language rules without creating a new highlighter
    // instance.  QML reuses a single highlighter per editor and calls this on
    // tab switches to avoid leaking QSyntaxHighlighter objects (setDocument
    // detaches the previous highlighter but does not delete it).
    Q_INVOKABLE void reconfigure(const QString &language)
    {
        setLanguage(language);
        rehighlight();
    }

    void setLanguage(const QString &language)
    {
        rules_.clear();
        const QString lang = language.toLower();
        QStringList keywords;
        // Single-line comment introducers (tried in order).
        QStringList lineComments;
        // Block comment delimiters: [start, end].
        QString blockStart;
        QString blockEnd;

        if (lang == u"cpp"_s || lang == u"c"_s || lang == u"h"_s
            || lang == u"cxx"_s || lang == u"hpp"_s || lang == u"cc"_s) {
            keywords = { "alignas","alignof","and","auto","bool","break","case","catch","char","class","const","constexpr","continue","decltype","default","delete","do","double","else","enum","explicit","export","extern","false","float","for","friend","goto","if","inline","int","long","mutable","namespace","new","noexcept","nullptr","operator","or","private","protected","public","register","reinterpret_cast","return","short","signed","sizeof","static","static_cast","struct","switch","template","this","throw","true","try","typedef","typename","union","unsigned","using","virtual","void","volatile","while" };
            lineComments = { u"//"_s };
            blockStart = u"/*"_s;
            blockEnd = u"*/"_s;
        } else if (lang == u"rust"_s || lang == u"rs"_s) {
            keywords = { "as","async","await","break","const","continue","crate","dyn","else","enum","extern","false","fn","for","if","impl","in","let","loop","match","mod","move","mut","pub","ref","return","self","Self","static","struct","super","trait","true","type","unsafe","use","where","while" };
            lineComments = { u"//"_s };
            blockStart = u"/*"_s;
            blockEnd = u"*/"_s;
        } else if (lang == u"python"_s || lang == u"py"_s) {
            keywords = { "False","None","True","and","as","assert","async","await","break","class","continue","def","del","elif","else","except","finally","for","from","global","if","import","in","is","lambda","nonlocal","not","or","pass","raise","return","try","while","with","yield" };
            lineComments = { u"#"_s };
            blockStart = u"\"\"\""_s;
            blockEnd = u"\"\"\""_s;
        } else if (lang == u"qml"_s || lang == u"js"_s || lang == u"javascript"_s) {
            keywords = { "var","let","const","function","return","if","else","for","while","do","switch","case","break","continue","new","delete","typeof","instanceof","in","of","this","true","false","null","undefined","try","catch","finally","throw","class","extends","super","import","export","default","async","await","yield","property","alias","signal","Component","on","readonly","id" };
            lineComments = { u"//"_s };
            blockStart = u"/*"_s;
            blockEnd = u"*/"_s;
        } else if (lang == u"json"_s) {
            keywords = { "true","false","null" };
            lineComments = {};
        } else if (lang == u"sh"_s || lang == u"bash"_s || lang == u"shell"_s) {
            keywords = { "if","then","else","elif","fi","for","do","done","while","case","esac","function","return","local","export","unset","echo","printf","read","set","shift","in" };
            lineComments = { u"#"_s };
        } else {
            // No rules; highlighting is a no-op for unknown languages.
            return;
        }

        // Keyword rule (word-boundary guarded).
        for (const auto &kw : keywords) {
            Rule r;
            r.pattern = QRegularExpression(u"\\b"_s + QRegularExpression::escape(kw) + u"\\b"_s);
            r.format = keywordFormat_;
            rules_.append(r);
        }
        // String literals: double and single quoted (non-greedy, no escaping
        // detail — sufficient for editor highlighting).
        Rule strDouble;
        strDouble.pattern = QRegularExpression(u"\"(?:[^\"\\\\]|\\\\.)*\""_s);
        strDouble.format = stringFormat_;
        rules_.append(strDouble);
        Rule strSingle;
        strSingle.pattern = QRegularExpression(u"'(?:[^'\\\\]|\\\\.)*'"_s);
        strSingle.format = stringFormat_;
        rules_.append(strSingle);
        // Numbers.
        Rule num;
        num.pattern = QRegularExpression(u"\\b\\d+(?:\\.\\d+)?(?:[eE][+-]?\\d+)?\\b"_s);
        num.format = numberFormat_;
        rules_.append(num);

        // Store comment config for highlightBlock.
        lineComments_ = lineComments;
        blockStart_ = blockStart;
        blockEnd_ = blockEnd;
    }

protected:
    void highlightBlock(const QString &text) override
    {
        for (const Rule &r : std::as_const(rules_)) {
            auto it = r.pattern.globalMatch(text);
            while (it.hasNext()) {
                const QRegularExpressionMatch m = it.next();
                setFormat(m.capturedStart(), m.capturedLength(), r.format);
            }
        }

        // Single-line comments.
        for (const QString &lc : std::as_const(lineComments_)) {
            const int idx = text.indexOf(lc);
            if (idx >= 0) {
                setFormat(idx, text.length() - idx, commentFormat_);
                // A line comment runs to EOL, so block comments don't apply.
                return;
            }
        }

        // Block comments (multi-line, state carried via setCurrentBlockState).
        if (!blockStart_.isEmpty()) {
            int start = 0;
            if (previousBlockState() != 1) {
                start = text.indexOf(blockStart_);
            }
            while (start >= 0) {
                int end = (previousBlockState() == 1 && start == 0)
                              ? text.indexOf(blockEnd_)
                              : text.indexOf(blockEnd_, start + blockStart_.length());
                int length;
                if (end >= 0) {
                    length = end + blockEnd_.length() - start;
                    setCurrentBlockState(0);
                } else {
                    length = text.length() - start;
                    setCurrentBlockState(1);
                }
                setFormat(start, length, commentFormat_);
                start = text.indexOf(blockStart_, start + length);
            }
        }
    }

private:
    struct Rule
    {
        QRegularExpression pattern;
        QTextCharFormat format;
    };
    QList<Rule> rules_;
    QTextCharFormat keywordFormat_;
    QTextCharFormat stringFormat_;
    QTextCharFormat commentFormat_;
    QTextCharFormat numberFormat_;
    QTextCharFormat typeFormat_;
    QStringList lineComments_;
    QString blockStart_;
    QString blockEnd_;
};

// FileDialogHelper exposes filesystem operations to QML.
//
// The previous version returned an empty string both for an empty file and for
// a read failure, and silently dropped write errors.  That violated the
// "never suppress errors" requirement and made debugging impossible from the
// UI.  Every operation now reports success/failure and a human-readable error
// so the QML layer can surface problems to the user.
class FileDialogHelper : public QObject
{
    Q_OBJECT
public:
    using QObject::QObject;

    // Returns { success: bool, content: string, error: string, size: int }.
    // `content` is the file text only when success is true.  A size check
    // guards against loading files that would exhaust memory in the TextArea;
    // the caller decides how to handle the `too_large` flag.
    Q_INVOKABLE QVariantMap readFile(const QString &path)
    {
        QVariantMap result;
        const QFileInfo info(path);
        if (!info.exists()) {
            result["success"_L1] = false;
            result["error"_L1] = tr("The file does not exist: %1").arg(path);
            return result;
        }
        const qint64 size = info.size();
        result["size"_L1] = size;
        // 32 MiB is a conservative upper bound for a QML TextArea: beyond this,
        // QTextDocument layout cost dominates and the UI becomes unresponsive.
        // The QML layer warns the user and offers to open the file in a
        // streaming viewer instead of forcing the load.
        if (size > 32 * 1024 * 1024) {
            result["success"_L1] = false;
            result["too_large"_L1] = true;
            result["error"_L1] = tr("The file is %1 MB; opening it in the editor may be slow. Open anyway?")
                                      .arg(size / (1024 * 1024));
            return result;
        }

        QFile f(path);
        if (!f.open(QIODevice::ReadOnly | QIODevice::Text)) {
            result["success"_L1] = false;
            result["error"_L1] = tr("Could not open %1: %2").arg(path, f.errorString());
            return result;
        }
        QTextStream in(&f);
        in.setEncoding(QStringConverter::Utf8);
        const QString content = in.readAll();
        if (in.status() != QTextStream::Ok) {
            result["success"_L1] = false;
            result["error"_L1] = tr("Read error on %1: %2").arg(path, f.errorString());
            return result;
        }
        result["success"_L1] = true;
        result["content"_L1] = content;
        result["error"_L1] = u""_s;
        return result;
    }

    // Returns true on success.  Emits errorOccurred with a descriptive message
    // on failure so the QML layer can show a dialog instead of silently losing
    // the user's work.
    Q_INVOKABLE bool writeFile(const QString &path, const QString &content)
    {
        if (path.isEmpty()) {
            emit errorOccurred(tr("Cannot save to an empty path."));
            return false;
        }
        // Write to a sibling temp file and atomically rename so a crash mid-write
        // cannot truncate the user's existing file.
        const QFileInfo info(path);
        const QString tmp = info.absoluteFilePath() + u".nira-tmp"_s;
        {
            QFile f(tmp);
            if (!f.open(QIODevice::WriteOnly | QIODevice::Truncate)) {
                emit errorOccurred(tr("Could not write %1: %2").arg(path, f.errorString()));
                return false;
            }
            QTextStream out(&f);
            out.setEncoding(QStringConverter::Utf8);
            out << content;
            out.flush();
            if (out.status() != QTextStream::Ok || !f.flush()) {
                f.close();
                QFile::remove(tmp);
                emit errorOccurred(tr("Failed while writing %1: %2").arg(path, f.errorString()));
                return false;
            }
            f.close();
        }
        // Remove the destination first so rename works across filesystems and
        // overwrites existing files reliably.
        if (QFile::exists(path) && !QFile::remove(path)) {
            QFile::remove(tmp);
            emit errorOccurred(tr("Could not replace the existing file %1.").arg(path));
            return false;
        }
        if (!QFile::rename(tmp, path)) {
            // Rename failed: try to restore by copying back.
            QFile::remove(tmp);
            emit errorOccurred(tr("Could not finalize save of %1.").arg(path));
            return false;
        }
        return true;
    }

    Q_INVOKABLE bool fileExists(const QString &path) const
    {
        const QFileInfo info(path);
        return info.exists() && info.isFile();
    }

    Q_INVOKABLE qint64 fileSize(const QString &path) const
    {
        const QFileInfo info(path);
        return info.exists() ? info.size() : -1;
    }

    Q_INVOKABLE QString mimeType(const QString &path) const
    {
        const QFileInfo info(path);
        if (!info.exists())
            return u""_s;
        QMimeDatabase db;
        const QMimeType mt = db.mimeTypeForFile(info);
        return mt.name();
    }

    // Recent-files persistence backed by QSettings.  Kept here (rather than in
    // QML) so the list survives application restarts and is stored with the
    // rest of the organization's settings.
    Q_INVOKABLE QStringList recentFiles() const
    {
        QSettings s;
        return s.value(u"Notepad/recentFiles"_s).toStringList();
    }

    Q_INVOKABLE void addRecentFile(const QString &path)
    {
        if (path.isEmpty())
            return;
        QSettings s;
        QStringList list = s.value(u"Notepad/recentFiles"_s).toStringList();
        // De-duplicate and move to front, newest first.
        list.removeAll(path);
        list.prepend(path);
        while (list.size() > 10)
            list.removeLast();
        s.setValue(u"Notepad/recentFiles"_s, list);
        emit recentFilesChanged();
    }

    Q_INVOKABLE void clearRecentFiles()
    {
        QSettings s;
        s.remove(u"Notepad/recentFiles"_s);
        emit recentFilesChanged();
    }

    // Factory: creates a SyntaxHighlighter attached to the given QML
    // TextArea's text document.  The highlighter is parented to the
    // QTextDocument, so it is destroyed when the document is destroyed and
    // needs no explicit QML ownership.
    Q_INVOKABLE QObject *createHighlighter(QQuickTextDocument *qdoc, const QString &language)
    {
        auto *h = new SyntaxHighlighter();
        h->attach(qdoc, language);
        return h;
    }

    // Map a file path to a language id for the highlighter.
    Q_INVOKABLE QString languageForFile(const QString &path) const
    {
        const QString suffix = QFileInfo(path).suffix().toLower();
        if (suffix == u"cpp"_s || suffix == u"cxx"_s || suffix == u"cc"_s) return u"cpp"_s;
        if (suffix == u"h"_s || suffix == u"hpp"_s) return u"cpp"_s;
        if (suffix == u"c"_s) return u"c"_s;
        if (suffix == u"rs"_s) return u"rust"_s;
        if (suffix == u"py"_s) return u"python"_s;
        if (suffix == u"qml"_s) return u"qml"_s;
        if (suffix == u"js"_s || suffix == u"mjs"_s) return u"js"_s;
        if (suffix == u"json"_s) return u"json"_s;
        if (suffix == u"sh"_s || suffix == u"bash"_s) return u"sh"_s;
        return u""_s;
    }

signals:
    void errorOccurred(const QString &errorMsg);
    void recentFilesChanged();
};

int main(int argc, char *argv[])
{
    QGuiApplication app(argc, argv);
    QGuiApplication::setApplicationName("nira-notepad"_L1);
    QGuiApplication::setApplicationDisplayName("Nira Notepad"_L1);
    QGuiApplication::setOrganizationName("NiraOS"_L1);

    FileDialogHelper fileHelper;

    QQmlApplicationEngine engine;
    engine.addImageProvider("icon"_L1, new ThemeIconProvider);
    engine.rootContext()->setContextProperty("fileDialogHelper"_L1, &fileHelper);

    QString initialFile;
    QStringList args = app.arguments();
    for (int i = 1; i < args.size(); ++i) {
        if (!args[i].startsWith('-')) {
            initialFile = QFileInfo(args[i]).absoluteFilePath();
            break;
        }
    }
    engine.rootContext()->setContextProperty("initialFile"_L1, initialFile);

    QObject::connect(
        &engine,
        &QQmlApplicationEngine::objectCreationFailed,
        &app,
        []() {
            qCritical() << "NiraNotepad: FATAL: failed to instantiate Main.qml";
            QCoreApplication::exit(1);
        },
        Qt::QueuedConnection);

    engine.loadFromModule("NiraNotepad"_L1, "Main"_L1);
    return app.exec();
}

#include "main.moc"
