// The ride library from the outside, as the app uses it: rides read in from the fit folder, parts
// joined after a short pause, a split kept apart, a copy of a ride read once, other sports left
// out, and a damaged database read again from the files.
#include "ridelibrary.h"

#include <QCoreApplication>
#include <QDateTime>
#include <QDir>
#include <QFile>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QSettings>
#include <QStandardPaths>
#include <QTemporaryDir>
#include <QtTest>

class TestRideLibrary : public QObject {
    Q_OBJECT

  private:
    QTemporaryDir *dir = nullptr;
    QString appDir;

    // a ride file of seconds seconds at watts, starting at start (ms)
    void writeRide(const QString &name, qint64 start, int seconds, int watts, int sport = 2, int cadence = 90) {
        QJsonArray list;
        for (int i = 0; i < seconds; i++)
            list.append(QJsonObject{{"w", watts}, {"hr", 140}, {"cad", cadence}});
        QJsonObject o{{"sport", sport}, {"title", ""}, {"start", double(start)}, {"seconds", list}, {"laps", QJsonArray{0}}};
        QFile file(appDir + QStringLiteral("fit/") + name);
        QVERIFY(file.open(QIODevice::WriteOnly));
        file.write(QJsonDocument(o).toJson(QJsonDocument::Compact));
    }

    // waits until the library has read everything there is
    bool settle(RideLibrary &library, int rides) {
        QElapsedTimer t;
        t.start();
        while (t.elapsed() < 20000) {
            QCoreApplication::processEvents(QEventLoop::AllEvents, 50);
            if (!library.busy() && library.rideCount() == rides)
                return true;
            QThread::msleep(20);
        }
        qWarning() << "rides" << library.rideCount() << "busy" << library.busy();
        return false;
    }

    qint64 day(int daysAgo, int hour) {
        QDateTime d(QDate::currentDate().addDays(-daysAgo), QTime(hour, 0));
        return d.toMSecsSinceEpoch();
    }

  private slots:
    void initTestCase() {
        QStandardPaths::setTestModeEnabled(true);
        QCoreApplication::setOrganizationName(QStringLiteral("BikemodoTests"));
        QCoreApplication::setApplicationName(QStringLiteral("ridelibrary"));
    }

    void init() {
        QSettings().clear();
        delete dir;
        dir = new QTemporaryDir();
        QVERIFY(dir->isValid());
        appDir = dir->path() + QStringLiteral("/");
        QVERIFY(QDir().mkpath(appDir + QStringLiteral("fit")));
    }

    void cleanup() {
        delete dir;
        dir = nullptr;
    }

    void readsRidesFromTheFolder() {
        writeRide(QStringLiteral("a.fit"), day(3, 8), 1800, 200);
        writeRide(QStringLiteral("b.fit"), day(1, 18), 1200, 150);
        RideLibrary library(appDir);
        library.rescan();
        QVERIFY(settle(library, 2));
        const QVariantMap totals = library.totals(0, 0);
        QCOMPARE(totals.value(QStringLiteral("rides")).toInt(), 2);
        QVERIFY(qAbs(totals.value(QStringLiteral("seconds")).toInt() - 3000) <= 4);
        // newest first
        const QVariantList rides = library.rides(0, 10);
        QCOMPARE(rides.size(), 2);
        QVERIFY(rides.at(0).toMap().value(QStringLiteral("start")).toLongLong() >
                rides.at(1).toMap().value(QStringLiteral("start")).toLongLong());
        QVERIFY(qAbs(rides.at(1).toMap().value(QStringLiteral("avgPower")).toDouble() - 200) < 1);
    }

    void joinsPartsAfterAShortPause() {
        // 20 min, a 5 min pause, 20 min more: one ride of two parts
        const qint64 start = day(2, 9);
        writeRide(QStringLiteral("p1.fit"), start, 1200, 180);
        writeRide(QStringLiteral("p2.fit"), start + (1200 + 300) * 1000LL, 1200, 180);
        RideLibrary library(appDir);
        library.rescan();
        QVERIFY(settle(library, 1));
        const QVariantMap ride = library.rides(0, 1).at(0).toMap();
        QCOMPARE(ride.value(QStringLiteral("parts")).toInt(), 2);
    }

    void keepsASplitApartAndMergesItBack() {
        const qint64 start = day(2, 9);
        writeRide(QStringLiteral("p1.fit"), start, 1200, 180);
        writeRide(QStringLiteral("p2.fit"), start + (1200 + 300) * 1000LL, 1200, 180);
        RideLibrary library(appDir);
        library.rescan();
        QVERIFY(settle(library, 1));
        const int id = library.rides(0, 1).at(0).toMap().value(QStringLiteral("id")).toInt();
        QVERIFY(library.splitRide(id));
        QVERIFY(settle(library, 2));
        // a rescan keeps them apart
        library.rescan();
        QVERIFY(settle(library, 2));
        const int later = library.rides(0, 1).at(0).toMap().value(QStringLiteral("id")).toInt();
        QVERIFY(library.mergeWithPrevious(later));
        QVERIFY(settle(library, 1));
    }

    void readsACopyOfARideOnce() {
        writeRide(QStringLiteral("ride.fit"), day(1, 7), 1800, 200);
        QFile::copy(appDir + QStringLiteral("fit/ride.fit"), appDir + QStringLiteral("fit/ride_1.fit"));
        RideLibrary library(appDir);
        library.rescan();
        QVERIFY(settle(library, 1));
    }

    void leavesOtherSportsOut() {
        writeRide(QStringLiteral("bike.fit"), day(4, 7), 1800, 200, 2);
        writeRide(QStringLiteral("run.fit"), day(3, 7), 1800, 0, 1);
        RideLibrary library(appDir);
        library.rescan();
        QVERIFY(settle(library, 1));
    }

    void readsADamagedDatabaseAgain() {
        writeRide(QStringLiteral("a.fit"), day(3, 8), 1800, 200);
        {
            RideLibrary library(appDir);
            library.rescan();
            QVERIFY(settle(library, 1));
        }
        // the database is broken while the app is closed
        // the library keeps its database next to the fit folder (ridelibrary.cpp, databaseName)
        const QString db = appDir + QStringLiteral("bikemodo-library.sqlite");
        QFile::remove(db + QStringLiteral("-wal"));
        QFile::remove(db + QStringLiteral("-shm"));
        QFile file(db);
        QVERIFY(file.open(QIODevice::WriteOnly | QIODevice::Truncate));
        file.write("this is not a database");
        file.close();
        RideLibrary library(appDir);
        library.rescan();
        QVERIFY(settle(library, 1));
    }

    void keepsASplitWhenTheFolderMoves() {
        // a split ride in one folder; the files and the library then go to another folder, as
        // Documents/QZ to Documents/Bikemodo
        const qint64 start = day(2, 9);
        writeRide(QStringLiteral("p1.fit"), start, 1200, 180);
        writeRide(QStringLiteral("p2.fit"), start + (1200 + 300) * 1000LL, 1200, 180);
        {
            RideLibrary library(appDir);
            library.rescan();
            QVERIFY(settle(library, 1));
            QVERIFY(library.splitRide(library.rides(0, 1).at(0).toMap().value(QStringLiteral("id")).toInt()));
            QVERIFY(settle(library, 2));
        }
        QTemporaryDir other;
        const QString moved = other.path() + QStringLiteral("/");
        QVERIFY(QDir().mkpath(moved + QStringLiteral("fit")));
        for (const QString &name : {QStringLiteral("p1.fit"), QStringLiteral("p2.fit")})
            QVERIFY(QFile::copy(appDir + QStringLiteral("fit/") + name, moved + QStringLiteral("fit/") + name));
        for (const QString &suffix : {QString(), QStringLiteral("-wal"), QStringLiteral("-shm")})
            QFile::copy(appDir + QStringLiteral("bikemodo-library.sqlite") + suffix, moved + QStringLiteral("bikemodo-library.sqlite") + suffix);
        RideLibrary library(moved);
        library.rescan();
        QVERIFY(settle(library, 2));
    }

    void leavesRidesWithoutPedalingUncounted() {
        // a real ride, a heart rate with no pedaling, and 30 seconds of a test
        writeRide(QStringLiteral("real.fit"), day(3, 8), 1800, 200);
        writeRide(QStringLiteral("heart.fit"), day(2, 8), 600, 0, 2, 0);
        writeRide(QStringLiteral("short.fit"), day(1, 8), 30, 150);
        RideLibrary library(appDir);
        library.rescan();
        QVERIFY(settle(library, 3));
        QCOMPARE(library.totals(0, 0).value(QStringLiteral("rides")).toInt(), 1);
        QCOMPARE(library.rides(0, 10).size(), 1);
        const QVariantList all = library.rides(0, 10, true);
        QCOMPARE(all.size(), 3);
        int uncounted = 0;
        for (const QVariant &r : all)
            uncounted += r.toMap().value(QStringLiteral("counted")).toBool() ? 0 : 1;
        QCOMPARE(uncounted, 2);
        QCOMPARE(library.days(0, 0).size(), 1);
    }

    void exportsEveryRideAsCsv() {
        writeRide(QStringLiteral("a.fit"), day(3, 8), 1800, 200);
        writeRide(QStringLiteral("b.fit"), day(1, 18), 1200, 150);
        RideLibrary library(appDir);
        library.rescan();
        QVERIFY(settle(library, 2));
        const QString path = library.exportCsv(appDir);
        QVERIFY(!path.isEmpty());
        QFile file(path);
        QVERIFY(file.open(QIODevice::ReadOnly));
        const QList<QByteArray> lines = file.readAll().trimmed().split('\n');
        QCOMPARE(lines.size(), 3);
        QVERIFY(lines.at(0).startsWith("date,start,duration_min"));
    }
};

QTEST_GUILESS_MAIN(TestRideLibrary)
#include "tst_ridelibrary.moc"
