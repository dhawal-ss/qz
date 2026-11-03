#ifndef RIDELIBRARY_H
#define RIDELIBRARY_H

#include <QAtomicInt>
#include <QObject>
#include <QString>
#include <QStringList>
#include <QThread>
#include <QVariantList>
#include <QVariantMap>

class RideLibraryWorker;

// The finished rides of the Pulse interface (src/ui2), with their numbers, laps and samples worked
// out once and kept in bikemodo-library.sqlite. A ride is made of one or more parts, one per .fit
// file: a ride saved again after a pause or a restart of the app joins the ride before it when it
// starts within ui2/mergeGapMinutes (default 10, 0 never) of its end, and the rider can merge or
// split rides by hand. Every method below speaks of whole rides.
// The .fit files stay the source: the database can be deleted and is filled again from them.
// Reading happens on the UI thread, parsing and writing in a worker thread.
class RideLibrary : public QObject {
    Q_OBJECT
    Q_PROPERTY(int rideCount READ rideCount NOTIFY changed)
    Q_PROPERTY(bool busy READ busy NOTIFY busyChanged)
    Q_PROPERTY(int indexed READ indexed NOTIFY progressChanged)
    Q_PROPERTY(int toIndex READ toIndex NOTIFY progressChanged)
    // a ride the app did not save because it was closed or killed during it, found in QZ's minute
    // backups: {path, start, seconds}, or empty
    Q_PROPERTY(QVariantMap unfinished READ unfinished NOTIFY unfinishedChanged)

  public:
    // appDir is homeform::getWritableAppDir(): the .fit files are in its fit folder
    explicit RideLibrary(const QString &appDir, QObject *parent = nullptr);
    ~RideLibrary();

    int rideCount() const { return m_rideCount; }
    bool busy() const { return m_pendingJobs > 0; }
    int indexed() const { return m_indexed; }
    int toIndex() const { return m_toIndex; }
    QVariantMap unfinished() const { return m_unfinished; }

    // adds a .fit file that was just saved
    void importFile(const QString &path);

    // times are ms since epoch, durations seconds; 0 for fromMs or toMs means no bound
    Q_INVOKABLE QVariantList rides(int offset, int limit);
    Q_INVOKABLE QVariantMap ride(int id);
    Q_INVOKABLE QVariantMap samples(int id, int maxPoints);
    Q_INVOKABLE QVariantList powerCurve(qint64 fromMs, qint64 toMs);
    Q_INVOKABLE QVariantMap totals(qint64 fromMs, qint64 toMs);
    Q_INVOKABLE QVariantList days(qint64 fromMs, qint64 toMs);
    // every time the best of a power curve duration was beaten: [{start, watts, rideId}] in start order
    Q_INVOKABLE QVariantList recordHistory(int seconds);
    // longest ride, most kJ, longest distance and biggest week by time:
    // [{key, value, start, rideId, history: [{start, value, rideId}]}]
    Q_INVOKABLE QVariantList rideRecords();
    Q_INVOKABLE void rescan();
    // joins a ride to the one before it (when that one ended at most 3 h before): the ride then
    // carries the id of the one before it. False when there is nothing to join.
    Q_INVOKABLE bool mergeWithPrevious(int id);
    // makes every part of a ride a ride of its own again, and keeps them apart from now on.
    // False when the ride has one part.
    Q_INVOKABLE bool splitRide(int id);
    // copies the unfinished ride into the fit folder as a ride of its own, or lets it go; either
    // way it, and every backup older than it, is not offered again
    Q_INVOKABLE void recoverUnfinished();
    Q_INVOKABLE void dismissUnfinished();

  signals:
    void changed();
    void busyChanged();
    void progressChanged();
    void unfinishedChanged();

  private:
    static QString databasePath(const QString &appDir);
    void jobStarted();
    void jobDone();
    void onInserted();
    void onProgress(int indexed, int toIndex);
    void onUnfinishedFound(const QVariantMap &ride);
    void setLinks(const QStringList &paths, int mode);
    void forgetUnfinished();

    QString m_appDir;
    QString m_fitDir;
    QString m_dbPath;
    QVariantMap m_unfinished;
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
    // mode 1 joins each of these parts to the part before it, 0 keeps them apart
    void setLinks(const QStringList &paths, int mode);
    // the newest backup in appDir written before the app started (before) and after the last one the
    // rider dismissed, that no saved ride covers: sends unfinishedFound, with an empty map when none
    void findUnfinished(const QString &appDir, qint64 before, qint64 dismissedUntil);

    QAtomicInt stopRequested;

  signals:
    void progress(int indexed, int toIndex);
    void inserted();
    void jobDone();
    void unfinishedFound(const QVariantMap &ride);

  private:
    bool openDatabase();
    bool indexFile(const QString &path);
    void removeFile(const QString &path);
    bool regroup();
    void updateRecords();

    QString m_dbPath;
    bool m_open = false;
};

#endif // RIDELIBRARY_H
