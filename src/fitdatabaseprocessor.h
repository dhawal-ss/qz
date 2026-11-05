#ifndef FITDATABASEPROCESSOR_H
#define FITDATABASEPROCESSOR_H

#include <QObject>
#include <QVector>
#include <QThread>
#include <QSqlDatabase>
#include <QString>
#include <QDir>
#include <QMutex>
#include <QAtomicInt>
#include "qfit.h"

class FitDatabaseProcessor : public QObject {
    Q_OBJECT

  public:
    explicit FitDatabaseProcessor(const QString& dbPath, QObject* parent = nullptr);
    ~FitDatabaseProcessor();

    void processDirectory(const QString& dirPath);
    void processFile(const QString& filePath);
    void stopProcessing();

    static const QString DB_CONNECTION_NAME;

    // TSS of a workout for the training load: bike rides only, with the FTP the rider had (the one
    // in the file, if it is a real FTP), else currentFtp. 0 when it cannot be known.
    static double workoutTss(const QList<SessionLine>& records, FIT_SPORT sport, double fileFtp, double currentFtp);
    // The windows of the power records, in seconds, and the column of each
    static const QVector<int> PEAK_SECONDS;
    static QString peakColumn(int seconds);
    // The best power of a bike ride over each of PEAK_SECONDS; -1 for a window longer than the ride, and
    // for every window of a workout that is not a bike ride
    static QVector<double> workoutPeaks(const QList<SessionLine>& records, FIT_SPORT sport);
    // Works out the TSS of up to maxRows workouts saved before the training load existed (tss NULL),
    // from their files, on its own connection; returns how many rows it wrote
    int backfillTss(int maxRows);

  public slots:
    // Adds the given .fit files to the history, in the worker thread (call it queued);
    // reports the outcome with importFinished().
    void importFiles(const QStringList& filePaths);

  signals:
    void importFinished(int added, int alreadyInHistory, int unreadable, bool databaseOpen);
    void processingStopped();
    void fileProcessed(const QString& filename);
    void progress(int processedFiles, int totalFiles);
    void error(const QString& errorMessage);
    // the one-time fill of the TSS of older workouts runs (true) or has ended (false)
    void tssBackfillRunning(bool running);

  private slots:
    void doWork();
    void backfillNextChunk();

  private:
    bool initializeDatabase();
    bool processFitFile(const QString& filePath);
    bool isFileProcessed(const QString& filePath);
    QString getFileHash(const QString& filePath);

    // Method for handling workout summary data
    bool saveWorkout(const QString& filePath,
                     const QList<SessionLine>& session,
                     FIT_SPORT sport,
                     const QString& workoutName,
                     int elapsedSeconds,
                     double tss,
                     qint64& workoutId,
                     const QString& workoutSource = "QZ",
                     const QString& pelotonWorkoutId = "",
                     const QString& pelotonUrl = "",
                     const QString& trainingProgramFile = "");

    // Helper methods for path handling
    QString makeRelativePath(const QString& absolutePath);
    QString makeAbsolutePath(const QString& relativePath);
    bool migrateOldPaths();

    QThread workerThread;
    QString dbPath;
    QString currentDirPath;
    QString basePath;  // Base directory for relative paths
    QAtomicInt stopRequested;
    QMutex mutex;
    QSqlDatabase db;
};

#endif // FITDATABASEPROCESSOR_H
