#ifndef RIDELIBRARY_H
#define RIDELIBRARY_H

#include <QAtomicInt>
#include <QObject>
#include <QString>
#include <QThread>
#include <QVariantList>
#include <QVariantMap>

class RideLibraryWorker;

// The finished rides of the Pulse interface (src/ui2): one row per .fit file of the fit folder,
// with its numbers, laps and samples worked out once and kept in bikemodo-library.sqlite.
// The .fit files stay the source: the database can be deleted and is filled again from them.
// Reading happens on the UI thread, parsing and writing in a worker thread.
class RideLibrary : public QObject {
    Q_OBJECT
    Q_PROPERTY(int rideCount READ rideCount NOTIFY changed)
    Q_PROPERTY(bool busy READ busy NOTIFY busyChanged)
    Q_PROPERTY(int indexed READ indexed NOTIFY progressChanged)
    Q_PROPERTY(int toIndex READ toIndex NOTIFY progressChanged)

  public:
    // appDir is homeform::getWritableAppDir(): the .fit files are in its fit folder
    explicit RideLibrary(const QString &appDir, QObject *parent = nullptr);
    ~RideLibrary();

    int rideCount() const { return m_rideCount; }
    bool busy() const { return m_pendingJobs > 0; }
    int indexed() const { return m_indexed; }
    int toIndex() const { return m_toIndex; }

    // adds a .fit file that was just saved
    void importFile(const QString &path);

    // times are ms since epoch, durations seconds; 0 for fromMs or toMs means no bound
    Q_INVOKABLE QVariantList rides(int offset, int limit);
    Q_INVOKABLE QVariantMap ride(int id);
    Q_INVOKABLE QVariantMap samples(int id, int maxPoints);
    Q_INVOKABLE QVariantList powerCurve(qint64 fromMs, qint64 toMs);
    Q_INVOKABLE QVariantMap totals(qint64 fromMs, qint64 toMs);
    Q_INVOKABLE QVariantList days(qint64 fromMs, qint64 toMs);
    Q_INVOKABLE void rescan();

  signals:
    void changed();
    void busyChanged();
    void progressChanged();

  private:
    static QString databasePath(const QString &appDir);
    void jobStarted();
    void jobDone();
    void onInserted();
    void onProgress(int indexed, int toIndex);

    QString m_fitDir;
    QString m_dbPath;
    QThread m_thread;
    RideLibraryWorker *m_worker = nullptr;
    int m_rideCount = 0;
    int m_pendingJobs = 0;
    int m_indexed = 0;
    int m_toIndex = 0;
};

// Lives in the thread of RideLibrary: reads .fit files and writes the database, one job at a time.
class RideLibraryWorker : public QObject {
    Q_OBJECT

  public:
    explicit RideLibraryWorker(const QString &dbPath) : m_dbPath(dbPath) {}

    void scan(const QString &fitDir);
    void importFile(const QString &path);

    QAtomicInt stopRequested;

  signals:
    void progress(int indexed, int toIndex);
    void inserted();
    void jobDone();

  private:
    bool openDatabase();
    bool indexFile(const QString &path);
    void removeFile(const QString &path);
    void updateRecords();

    QString m_dbPath;
    bool m_open = false;
};

#endif // RIDELIBRARY_H
