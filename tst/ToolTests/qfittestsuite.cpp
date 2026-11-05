#include "qfittestsuite.h"
#include "../../src/qfit.h"
#include "../../src/fitdatabaseprocessor.h"
#include "../../src/workoutmodel.h"
#include <QTemporaryDir>
#include <QDateTime>
#include <QFile>
#include <QDir>
#include <QDebug>
#include <QEventLoop>
#include <QTimer>
#include <QSettings>
#include <QSqlDatabase>
#include <QSqlQuery>
#include "../../src/qzsettings.h"
#include "../../src/fit-sdk/fit_decode.hpp"
#include "../../src/fit-sdk/fit_record_mesg.hpp"
#include "../../src/fit-sdk/fit_session_mesg.hpp"
#include "../../src/fit-sdk/fit_encode.hpp"
#include "../../src/fit-sdk/fit_file_id_mesg.hpp"
#include <fstream>
#include <vector>

QFitTestSuite::QFitTestSuite() : tempDir(nullptr) {
}

QFitTestSuite::~QFitTestSuite() {
    if (tempDir) {
        delete tempDir;
        tempDir = nullptr;
    }
}

void QFitTestSuite::SetUp() {
    tempDir = new QTemporaryDir();
    ASSERT_TRUE(tempDir->isValid()) << "Failed to create temporary directory";
}

void QFitTestSuite::TearDown() {
    if (tempDir) {
        delete tempDir;
        tempDir = nullptr;
    }
}

QList<SessionLine> QFitTestSuite::createTestSession() {
    QList<SessionLine> session;
    QDateTime startTime = QDateTime::currentDateTime();

    // Create a simple 10-minute workout session
    for (int i = 0; i < 600; i += 5) {  // 5 second intervals for 10 minutes
        SessionLine line;
        line.time = startTime.addSecs(i);
        line.elapsedTime = i;
        line.distance = i * 0.05;  // 3 km/h = 0.05 km per 5 seconds
        line.speed = 3.0;  // 3 km/h
        line.cadence = 60;
        line.heart = 120 + (i % 30);  // Varying HR between 120-150
        line.calories = i / 10;
        line.watt = 100;

        session.append(line);
    }

    return session;
}

QString QFitTestSuite::createNewFormatFitFile() {
    QString filename = tempDir->filePath("test_new_format.fit");
    QList<SessionLine> session = createTestSession();

    // Create a FIT file with developer fields
    qfit::save(filename, session, BIKE, QFIT_PROCESS_NONE, FIT_SPORT_CYCLING,
               "Test Workout Title",
               "Test Device",
               "PELOTON",
               "test_workout_id_123",
               "https://peloton.com/workout/123",
               "/path/to/training.zwo");

    return filename;
}

bool QFitTestSuite::verifyDeveloperFields(const QString& workoutName, const QString& workoutSource,
                                          const QString& pelotonWorkoutId, const QString& pelotonUrl,
                                          const QString& trainingProgramFile) {
    bool allCorrect = true;

    if (workoutName != "Test Workout Title") {
        qDebug() << "Workout name mismatch. Expected: 'Test Workout Title', Got:" << workoutName;
        allCorrect = false;
    }

    if (workoutSource != "PELOTON") {
        qDebug() << "Workout source mismatch. Expected: 'PELOTON', Got:" << workoutSource;
        allCorrect = false;
    }

    if (pelotonWorkoutId != "test_workout_id_123") {
        qDebug() << "Peloton workout ID mismatch. Expected: 'test_workout_id_123', Got:" << pelotonWorkoutId;
        allCorrect = false;
    }

    if (pelotonUrl != "https://peloton.com/workout/123") {
        qDebug() << "Peloton URL mismatch. Expected: 'https://peloton.com/workout/123', Got:" << pelotonUrl;
        allCorrect = false;
    }

    if (trainingProgramFile != "/path/to/training.zwo") {
        qDebug() << "Training program file mismatch. Expected: '/path/to/training.zwo', Got:" << trainingProgramFile;
        allCorrect = false;
    }

    return allCorrect;
}

void QFitTestSuite::test_newFormatDeveloperFields() {
    // Create a FIT file with new format
    QString filename = createNewFormatFitFile();
    ASSERT_TRUE(QFile::exists(filename)) << "Failed to create FIT file";

    // Copy to test-artifacts directory for download
    QDir artifactsDir("test-artifacts");
    if (!artifactsDir.exists()) {
        artifactsDir.mkpath(".");
    }
    QString artifactPath = "test-artifacts/test_new_format.fit";
    QFile::remove(artifactPath);
    QFile::copy(filename, artifactPath);
    qDebug() << "FIT file saved to:" << artifactPath;

    // Read the file back
    QList<SessionLine> session;
    FIT_SPORT sport = FIT_SPORT_INVALID;
    QString workoutName;
    QString workoutSource;
    QString pelotonWorkoutId;
    QString pelotonUrl;
    QString trainingProgramFile;

    qfit::open(filename, &session, &sport, &workoutName, &workoutSource,
               &pelotonWorkoutId, &pelotonUrl, &trainingProgramFile);

    // Verify basic data was read
    EXPECT_FALSE(session.isEmpty()) << "Session should not be empty";
    EXPECT_EQ(sport, FIT_SPORT_CYCLING) << "Sport should be cycling";

    // Verify all developer fields were read correctly from WorkoutMesg
    EXPECT_TRUE(verifyDeveloperFields(workoutName, workoutSource, pelotonWorkoutId,
                                      pelotonUrl, trainingProgramFile))
        << "Developer fields should be read correctly from WorkoutMesg";

    qDebug() << "✓ New format developer fields test passed";
}

void QFitTestSuite::test_databaseReadability() {
    // Create a FIT file with new format
    QString filename = createNewFormatFitFile();
    ASSERT_TRUE(QFile::exists(filename)) << "Failed to create FIT file";

    // Copy to test-artifacts directory for download
    QDir artifactsDir("test-artifacts");
    if (!artifactsDir.exists()) {
        artifactsDir.mkpath(".");
    }
    QString artifactPath = "test-artifacts/test_database_readability.fit";
    QFile::remove(artifactPath);
    QFile::copy(filename, artifactPath);
    qDebug() << "FIT file saved to:" << artifactPath;

    // Create a temporary database path
    QString dbPath = tempDir->filePath("test_db.sqlite");

    // Create a FIT database processor with the database path
    FitDatabaseProcessor processor(dbPath);

    // Setup event loop to wait for async processing
    QEventLoop loop;
    QTimer timeout;
    timeout.setSingleShot(true);
    timeout.setInterval(5000);  // 5 second timeout

    // Process the FIT file
    bool processed = false;
    QObject::connect(&processor, &FitDatabaseProcessor::fileProcessed,
                     [&processed, &loop](const QString&) {
                         processed = true;
                         loop.quit();
                     });

    bool error = false;
    QString errorMsg;
    QObject::connect(&processor, &FitDatabaseProcessor::error,
                     [&error, &errorMsg, &loop](const QString& msg) {
                         qDebug() << "Database processor error:" << msg;
                         error = true;
                         errorMsg = msg;
                         loop.quit();
                     });

    QObject::connect(&timeout, &QTimer::timeout, &loop, &QEventLoop::quit);

    processor.processFile(filename);
    timeout.start();

    // Wait for processing to complete or timeout
    loop.exec();
    timeout.stop();

    EXPECT_TRUE(processed) << "FIT file should be processed successfully by database";
    EXPECT_FALSE(error) << "No errors should occur during database processing. Error: "
                        << errorMsg.toStdString();

    // Copy database file to test-artifacts directory for download
    if (QFile::exists(dbPath)) {
        QString dbArtifactPath = "test-artifacts/test_database.sqlite";
        QFile::remove(dbArtifactPath);
        QFile::copy(dbPath, dbArtifactPath);
        qDebug() << "Database file saved to:" << dbArtifactPath;
    }

    qDebug() << "✓ Database readability test passed";
}

TEST(QFitExport, HalfCadenceSessionStatistics) {
    QTemporaryDir tempDir;
    ASSERT_TRUE(tempDir.isValid());

    QList<SessionLine> workout;
    const QDateTime start = QDateTime::currentDateTime();
    const std::vector<FIT_UINT8> originalCadences = {150, 151, 160, 164};
    for (int i = 0; i < static_cast<int>(originalCadences.size()); ++i) {
        SessionLine line;
        line.time = start.addSecs(i);
        line.elapsedTime = i;
        line.speed = 8.0;
        line.distance = i * 0.01;
        line.cadence = originalCadences[i];
        line.heart = 120;
        line.watt = 100;
        workout.append(line);
    }

    struct CadenceReader : fit::MesgListener {
        std::vector<FIT_UINT8> records;
        FIT_UINT8 average = 0;
        FIT_UINT8 maximum = 0;
        bool hasSession = false;

        void OnMesg(fit::Mesg &mesg) override {
            if (mesg.GetNum() == FIT_MESG_NUM_RECORD) {
                records.push_back(fit::RecordMesg(mesg).GetCadence());
            } else if (mesg.GetNum() == FIT_MESG_NUM_SESSION) {
                fit::SessionMesg summary(mesg);
                average = summary.GetAvgCadence();
                maximum = summary.GetMaxCadence();
                hasSession = true;
            }
        }
    };

    QSettings settings;
    const QString key = QZSettings::powr_sensor_running_cadence_half_on_strava;
    const bool existed = settings.contains(key);
    const QVariant previous = settings.value(key);

    const auto verify = [&](BLUETOOTH_TYPE device, FIT_SPORT sport, bool half, const QString &name) {
        settings.setValue(key, half);
        settings.sync();
        const QString path = tempDir.filePath(name);
        qfit::save(path, workout, device, QFIT_PROCESS_NONE, sport);

        std::ifstream file(path.toStdString(), std::ios::binary);
        ASSERT_TRUE(file.is_open()) << "Missing FIT file: " << path.toStdString();

        fit::Decode decoder;
        CadenceReader reader;
        ASSERT_TRUE(decoder.Read(file, reader));
        ASSERT_TRUE(reader.hasSession);
        const std::vector<FIT_UINT8> expected = half
            ? std::vector<FIT_UINT8>{75, 75, 80, 82}
            : originalCadences;
        EXPECT_EQ(expected, reader.records);
        EXPECT_EQ(half ? 78 : 156, reader.average);
        EXPECT_EQ(half ? 82 : 164, reader.maximum);
    };

    verify(TREADMILL, FIT_SPORT_RUNNING, false, "running_full.fit");
    verify(TREADMILL, FIT_SPORT_RUNNING, true, "running_half.fit");
    verify(BIKE, FIT_SPORT_CYCLING, false, "cycling_full.fit");
    verify(BIKE, FIT_SPORT_CYCLING, true, "cycling_half.fit");

    if (existed)
        settings.setValue(key, previous);
    else
        settings.remove(key);
    settings.sync();
}

// Average power counts every second from the first pedal stroke, coasting included, as Garmin
// Connect and TrainingPeaks do: the average of the non-zero seconds only read above NP.
TEST(QFitExport, AveragePowerCountsCoasting) {
    QTemporaryDir tempDir;
    ASSERT_TRUE(tempDir.isValid());

    // 10 s before the first pedal stroke, 60 s at 300 W, then 60 s coasting
    QList<SessionLine> workout;
    const QDateTime start(QDate(2026, 3, 1), QTime(8, 0));
    for (int i = 0; i < 130; ++i) {
        const bool pedaling = i >= 10 && i < 70;
        SessionLine line;
        line.time = start.addSecs(i);
        line.elapsedTime = i;
        line.speed = i < 10 ? 0.0 : 25.0;
        line.distance = i < 10 ? 0.0 : (i - 10) * 0.007;
        line.cadence = pedaling ? 90 : 0;
        line.watt = pedaling ? 300 : 0;
        workout.append(line);
    }

    struct PowerReader : fit::MesgListener {
        FIT_UINT16 average = 0;
        bool hasSession = false;

        void OnMesg(fit::Mesg &mesg) override {
            if (mesg.GetNum() == FIT_MESG_NUM_SESSION) {
                average = fit::SessionMesg(mesg).GetAvgPower();
                hasSession = true;
            }
        }
    };

    const QString path = tempDir.filePath("coasting.fit");
    qfit::save(path, workout, BIKE, QFIT_PROCESS_NONE, FIT_SPORT_INVALID);

    std::ifstream file(path.toStdString(), std::ios::binary);
    ASSERT_TRUE(file.is_open()) << "Missing FIT file: " << path.toStdString();
    fit::Decode decoder;
    PowerReader reader;
    ASSERT_TRUE(decoder.Read(file, reader));
    ASSERT_TRUE(reader.hasSession);
    EXPECT_EQ(reader.average, 150); // 18000 J over the 120 s from the first stroke; it read 300
}

// A ride recorded by another device without a power meter, an HR strap or a cadence sensor: its
// records have no power, heart rate, cadence or calories field, and Garmin-style enhanced_speed.
// Those fields read as FIT's "invalid" values (65535 W, 255 bpm...), which the history showed as
// the averages and maximums of the ride.
TEST(QFitImport, MissingRecordFieldsReadAsNoData) {
    QTemporaryDir tempDir;
    ASSERT_TRUE(tempDir.isValid());
    const QString path = tempDir.filePath("no_sensors.fit");

    const FIT_DATE_TIME start = 1100000000; // seconds since the FIT epoch
    {
        std::fstream file(path.toStdString(), std::ios::in | std::ios::out | std::ios::binary | std::ios::trunc);
        ASSERT_TRUE(file.is_open());
        fit::Encode encode(fit::ProtocolVersion::V20);
        encode.Open(file);
        fit::FileIdMesg fileId;
        fileId.SetType(FIT_FILE_ACTIVITY);
        fileId.SetTimeCreated(start);
        encode.Write(fileId);
        for (int i = 0; i < 5; i++) {
            fit::RecordMesg record;
            record.SetTimestamp(start + i);
            record.SetEnhancedSpeed(8.0f); // m/s
            if (i < 3)
                record.SetDistance(100.0f * (i + 1)); // the last two records have no distance
            encode.Write(record);
        }
        fit::SessionMesg session;
        session.SetTimestamp(start);
        session.SetSport(FIT_SPORT_CYCLING);
        encode.Write(session);
        ASSERT_TRUE(encode.Close());
    }

    QList<SessionLine> records;
    FIT_SPORT sport = FIT_SPORT_INVALID;
    qfit::open(path, &records, &sport);

    ASSERT_EQ(records.count(), 5);
    EXPECT_EQ(sport, FIT_SPORT_CYCLING);
    for (const SessionLine &line : records) {
        EXPECT_EQ(line.watt, 0);
        EXPECT_EQ(line.heart, 0);
        EXPECT_EQ(line.cadence, 0);
        EXPECT_EQ(line.resistance, 0);
        EXPECT_DOUBLE_EQ(line.calories, 0.0);
        EXPECT_NEAR(line.speed, 8.0 * 3.6, 1e-4); // from enhanced_speed
    }
    EXPECT_NEAR(records.at(2).distance, 0.3, 1e-6);
    EXPECT_NEAR(records.at(4).distance, 0.3, 1e-6); // a missing distance keeps the total
}

// Keeps the FTP setting of the test machine around a test
struct FtpSettingGuard {
    QSettings settings;
    const bool existed = settings.contains(QZSettings::ftp);
    const QVariant previous = settings.value(QZSettings::ftp);
    explicit FtpSettingGuard(double ftp) {
        settings.setValue(QZSettings::ftp, ftp);
        settings.sync();
    }
    void set(double ftp) {
        settings.setValue(QZSettings::ftp, ftp);
        settings.sync();
    }
    ~FtpSettingGuard() {
        if (existed)
            settings.setValue(QZSettings::ftp, previous);
        else
            settings.remove(QZSettings::ftp);
        settings.sync();
    }
};

// One hour at a steady power, one sample a second, pedaling from the first second
static QList<SessionLine> steadyRide(uint16_t watt) {
    QList<SessionLine> workout;
    const QDateTime start(QDate(2026, 3, 1), QTime(8, 0));
    for (int i = 0; i < 3600; ++i) {
        SessionLine line;
        line.time = start.addSecs(i);
        line.elapsedTime = i;
        line.speed = 30.0;
        line.distance = i * 30.0 / 3600.0;
        line.cadence = 90;
        line.heart = 0;
        line.watt = watt;
        line.calories = i * 0.2;
        workout.append(line);
    }
    return workout;
}

TEST(QFitTrainingLoad, WorkoutTssUsesTheFtpOfTheRide) {
    QList<SessionLine> records;
    for (const SessionLine &line : steadyRide(200))
        records.append(line);
    EXPECT_NEAR(FitDatabaseProcessor::workoutTss(records, FIT_SPORT_CYCLING, 250, 200), 64.0, 0.01);
    EXPECT_NEAR(FitDatabaseProcessor::workoutTss(records, FIT_SPORT_CYCLING, 0, 200), 100.0, 0.01);
    // not a real FTP: the current one is used
    EXPECT_NEAR(FitDatabaseProcessor::workoutTss(records, FIT_SPORT_CYCLING, 20, 200), 100.0, 0.01);
    EXPECT_NEAR(FitDatabaseProcessor::workoutTss(records, FIT_SPORT_CYCLING, 800, 200), 100.0, 0.01);
    // a cycling FTP says nothing about a run
    EXPECT_DOUBLE_EQ(FitDatabaseProcessor::workoutTss(records, FIT_SPORT_RUNNING, 250, 200), 0.0);
    EXPECT_DOUBLE_EQ(FitDatabaseProcessor::workoutTss(records, FIT_SPORT_CYCLING, 0, 0), 0.0);
}

TEST(QFitTrainingLoad, TheFileKeepsTheFtpOfTheRide) {
    QTemporaryDir tempDir;
    ASSERT_TRUE(tempDir.isValid());
    FtpSettingGuard ftp(250);
    const QString path = tempDir.filePath("ride.fit");
    qfit::save(path, steadyRide(200), BIKE, QFIT_PROCESS_NONE, FIT_SPORT_INVALID, QStringLiteral("Test ride"));
    ftp.set(200); // the rider changed FTP after the ride

    QList<SessionLine> records;
    FIT_SPORT sport = FIT_SPORT_INVALID;
    QString name;
    double rideFtp = 0;
    qfit::open(path, &records, &sport, &name, nullptr, nullptr, nullptr, nullptr, &rideFtp);
    EXPECT_DOUBLE_EQ(rideFtp, 250.0);
    EXPECT_EQ(sport, FIT_SPORT_CYCLING);
    EXPECT_EQ(records.count(), 3600);
    EXPECT_NEAR(FitDatabaseProcessor::workoutTss(records, sport, rideFtp, 200), 64.0, 0.1);
}

TEST(QFitTrainingLoad, NewRidesAreStoredAndOlderOnesFilledOnce) {
    QTemporaryDir tempDir;
    ASSERT_TRUE(tempDir.isValid());
    FtpSettingGuard ftp(250);
    const QString fitPath = tempDir.filePath("ride.fit");
    qfit::save(fitPath, steadyRide(200), BIKE, QFIT_PROCESS_NONE, FIT_SPORT_INVALID, QStringLiteral("Test ride"));
    ftp.set(200);

    const QString dbPath = tempDir.filePath("history.sqlite");
    FitDatabaseProcessor processor(dbPath);
    processor.processFile(fitPath); // a new ride gets its TSS when it is saved

    const QString connectionName = QStringLiteral("QFitTrainingLoadCheck");
    {
        QSqlDatabase check = QSqlDatabase::addDatabase("QSQLITE", connectionName);
        check.setDatabaseName(dbPath);
        ASSERT_TRUE(check.open());
        QSqlQuery query(check);
        ASSERT_TRUE(query.exec("SELECT tss FROM workouts"));
        ASSERT_TRUE(query.next());
        EXPECT_NEAR(query.value(0).toDouble(), 64.0, 0.5);
        query.finish();

        // as if the rows were saved before the training load existed, plus a run and a lost file
        ASSERT_TRUE(query.exec("UPDATE workouts SET tss = NULL"));
        ASSERT_TRUE(query.exec("INSERT INTO workouts (file_hash, file_path, sport_type, start_time) "
                               "VALUES ('run', 'fit/run.fit', 1, '2026-03-02T08:00:00')"));
        ASSERT_TRUE(query.exec("INSERT INTO workouts (file_hash, file_path, sport_type, start_time) "
                               "VALUES ('lost', 'fit/missing.fit', 2, '2026-03-03T08:00:00')"));
        query.finish();

        EXPECT_EQ(processor.backfillTss(20), 2); // the ride and the lost file; the run is set to 0 at once
        EXPECT_EQ(processor.backfillTss(20), 0); // each row is worked out once

        ASSERT_TRUE(query.exec("SELECT file_hash, tss FROM workouts ORDER BY id"));
        QMap<QString, QVariant> tss;
        while (query.next())
            tss[query.value(0).toString()] = query.value(1);
        query.finish();
        ASSERT_EQ(tss.count(), 3);
        EXPECT_FALSE(tss.value(QStringLiteral("run")).isNull());
        EXPECT_DOUBLE_EQ(tss.value(QStringLiteral("run")).toDouble(), 0.0);
        EXPECT_FALSE(tss.value(QStringLiteral("lost")).isNull());
        EXPECT_DOUBLE_EQ(tss.value(QStringLiteral("lost")).toDouble(), 0.0);
        tss.remove(QStringLiteral("run"));
        tss.remove(QStringLiteral("lost"));
        EXPECT_NEAR(tss.first().toDouble(), 64.0, 0.5); // the FTP of the ride, not today's
        check.close();
    }
    QSqlDatabase::removeDatabase(connectionName);
}

// Crash recovery (homeform::findRecoverableRide): a backup whose ride is in the history is no lost ride
TEST(QFitRecovery, ABackupOfASavedRideIsFoundInTheHistory) {
    QTemporaryDir tempDir;
    ASSERT_TRUE(tempDir.isValid());
    const QString fitPath = tempDir.filePath("ride.fit");
    qfit::save(fitPath, steadyRide(200), BIKE, QFIT_PROCESS_NONE, FIT_SPORT_INVALID, QStringLiteral("Test ride"));
    const QString dbPath = tempDir.filePath("history.sqlite");
    {
        FitDatabaseProcessor processor(dbPath);
        processor.processFile(fitPath);
    }
    // a backup of the same ride starts at the same first record
    QList<SessionLine> records;
    FIT_SPORT sport = FIT_SPORT_INVALID;
    qfit::open(fitPath, &records, &sport);
    ASSERT_FALSE(records.isEmpty());
    const QDateTime start = records.first().time;
    {
        WorkoutModel model(dbPath);
        const int duration = records.last().elapsedTime;
        EXPECT_TRUE(model.hasWorkoutCovering(start, duration, 120));
        EXPECT_TRUE(model.hasWorkoutCovering(start.addSecs(90), duration, 120));
        // the backup goes on after the saved ride (a "Save FIT" in the middle): lost
        EXPECT_FALSE(model.hasWorkoutCovering(start, duration + 600, 120));
        EXPECT_FALSE(model.hasWorkoutCovering(start.addSecs(600), duration, 120)); // another ride
        EXPECT_FALSE(model.hasWorkoutCovering(QDateTime(), duration, 120));
    }
}

// Power records: saved with a new ride, filled once for older ones without touching their TSS
TEST(QFitPowerRecords, SavedWithTheRideAndFilledForOlderOnes) {
    QTemporaryDir tempDir;
    ASSERT_TRUE(tempDir.isValid());
    const QString fitPath = tempDir.filePath("ride.fit");
    QList<SessionLine> ride = steadyRide(200);
    for (int i = 600; i < 900; i++)
        ride[i].watt = 300; // 5 minutes at 300 W
    qfit::save(fitPath, ride, BIKE, QFIT_PROCESS_NONE, FIT_SPORT_INVALID, QStringLiteral("Test ride"));

    const QString dbPath = tempDir.filePath("history.sqlite");
    FitDatabaseProcessor processor(dbPath);
    processor.processFile(fitPath);

    const QString connectionName = QStringLiteral("QFitPowerRecordsCheck");
    {
        QSqlDatabase check = QSqlDatabase::addDatabase("QSQLITE", connectionName);
        check.setDatabaseName(dbPath);
        ASSERT_TRUE(check.open());
        QSqlQuery query(check);
        ASSERT_TRUE(query.exec("SELECT peak_5s, peak_60s, peak_300s, peak_1200s FROM workouts"));
        ASSERT_TRUE(query.next());
        EXPECT_NEAR(query.value(0).toDouble(), 300.0, 0.5);
        EXPECT_NEAR(query.value(1).toDouble(), 300.0, 0.5);
        EXPECT_NEAR(query.value(2).toDouble(), 300.0, 0.5);
        EXPECT_NEAR(query.value(3).toDouble(), (300.0 * 300 + 200.0 * 900) / 1200, 0.5); // 225
        query.finish();

        // as if the ride were saved before the records existed, with a TSS of its own, plus a run
        ASSERT_TRUE(query.exec("UPDATE workouts SET peak_5s = NULL, peak_60s = NULL, peak_300s = NULL, "
                               "peak_1200s = NULL, tss = 99"));
        ASSERT_TRUE(query.exec("INSERT INTO workouts (file_hash, file_path, sport_type, start_time, tss) "
                               "VALUES ('run', 'fit/run.fit', 1, '2026-03-02T08:00:00', 0)"));
        query.finish();

        EXPECT_EQ(processor.backfillTss(20), 1); // the ride; the run gets no records at once
        EXPECT_EQ(processor.backfillTss(20), 0);

        ASSERT_TRUE(query.exec("SELECT file_hash, tss, peak_300s FROM workouts ORDER BY id"));
        QMap<QString, QPair<double, double>> rows;
        while (query.next())
            rows[query.value(0).toString()] = qMakePair(query.value(1).toDouble(), query.value(2).toDouble());
        query.finish();
        ASSERT_EQ(rows.count(), 2);
        EXPECT_DOUBLE_EQ(rows.value(QStringLiteral("run")).second, -1.0);
        rows.remove(QStringLiteral("run"));
        EXPECT_DOUBLE_EQ(rows.first().first, 99.0); // the TSS it had stays
        EXPECT_NEAR(rows.first().second, 300.0, 0.5);
        check.close();
    }
    QSqlDatabase::removeDatabase(connectionName);

    WorkoutModel model(dbPath);
    model.refreshTrainingLoad();
    const QVariantMap records = model.powerRecords();
    EXPECT_TRUE(records.value(QStringLiteral("available")).toBool());
    const QVariantList list = records.value(QStringLiteral("records")).toList();
    ASSERT_EQ(list.count(), 4);
    EXPECT_EQ(list.at(0).toMap().value(QStringLiteral("seconds")).toInt(), 5);
    EXPECT_EQ(list.at(0).toMap().value(QStringLiteral("watts")).toInt(), 300);
    EXPECT_EQ(list.at(3).toMap().value(QStringLiteral("watts")).toInt(), 225);
}
