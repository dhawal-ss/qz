#include "ridelibrary.h"
#include "qfit.h"
#include "qzsettings.h"
#include "ridestats.h"

#include <QDateTime>
#include <QDebug>
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QHash>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QSet>
#include <QSettings>
#include <QSqlDatabase>
#include <QSqlError>
#include <QSqlQuery>
#include <QStandardPaths>
#include <QTimer>
#include <QtMath>
#include <algorithm>
#include <limits>

namespace {

const QString uiConnection = QStringLiteral("BikemodoLibrary");
const QString workerConnection = QStringLiteral("BikemodoLibraryWorker");
const QString databaseName = QStringLiteral("bikemodo-library.sqlite");

// the columns rides() and ride() share, in the order rideMap() reads them
const QString rideColumns = QStringLiteral("id, start_ms, duration_s, distance_km, avg_power, max_power, np, intensity, "
                                           "tss, kj, kcal, avg_hr, max_hr, avg_cadence, title, sport, spark, records");

// rides: one per .fit file, with everything the lists and the summary of a ride show.
//   power_zone_s, hr_zone_s: json arrays of seconds in the 7 power and 5 heart rate zones
//   spark: json array of at most 48 power averages
//   best: json object {"seconds": watts} of the power curve of the ride
//   records: json array of the durations whose best was the highest of all earlier rides
// laps: one row per lap of a ride. samples: the 1 Hz samples, format in ridestats.cpp.
// skipped: .fit files without samples, so they are not read again at every start.
bool createTables(QSqlDatabase &db) {
    QSqlQuery query(db);
    if (query.exec(QStringLiteral("PRAGMA journal_mode=WAL")) && query.next())
        qDebug() << "ride library: journal mode" << query.value(0).toString();
    query.exec(QStringLiteral("PRAGMA busy_timeout=5000"));
    const QStringList statements = {
        QStringLiteral("CREATE TABLE IF NOT EXISTS rides ("
                       "id INTEGER PRIMARY KEY AUTOINCREMENT, file_path TEXT UNIQUE NOT NULL, file_size INTEGER, "
                       "file_mtime INTEGER, start_ms INTEGER, duration_s INTEGER, distance_km REAL, avg_power REAL, "
                       "max_power REAL, np REAL, intensity REAL, tss REAL, kj REAL, kcal REAL, avg_hr REAL, "
                       "max_hr REAL, avg_cadence REAL, title TEXT, sport INTEGER, ftp_used REAL, max_hr_used REAL, "
                       "power_zone_s TEXT, hr_zone_s TEXT, spark TEXT, best TEXT, records TEXT)"),
        QStringLiteral("CREATE INDEX IF NOT EXISTS rides_start ON rides(start_ms)"),
        QStringLiteral("CREATE TABLE IF NOT EXISTS laps (ride_id INTEGER, idx INTEGER, start_s INTEGER, "
                       "duration_s INTEGER, distance_km REAL, avg_power REAL, max_power REAL, avg_hr REAL, "
                       "max_hr REAL, avg_cadence REAL, PRIMARY KEY (ride_id, idx))"),
        QStringLiteral("CREATE TABLE IF NOT EXISTS samples (ride_id INTEGER PRIMARY KEY, data BLOB)"),
        QStringLiteral("CREATE TABLE IF NOT EXISTS skipped (file_path TEXT PRIMARY KEY, file_size INTEGER, "
                       "file_mtime INTEGER)")};
    for (const QString &statement : statements) {
        if (!query.exec(statement)) {
            qDebug() << "ride library:" << query.lastError().text();
            return false;
        }
    }
    return true;
}

QString toJson(const QJsonArray &array) {
    return QString::fromUtf8(QJsonDocument(array).toJson(QJsonDocument::Compact));
}

QString toJson(const QJsonObject &object) {
    return QString::fromUtf8(QJsonDocument(object).toJson(QJsonDocument::Compact));
}

QVariantList jsonList(const QString &json) {
    return QJsonDocument::fromJson(json.toUtf8()).array().toVariantList();
}

QJsonObject jsonObject(const QString &json) {
    return QJsonDocument::fromJson(json.toUtf8()).object();
}

double oneDecimal(double value) {
    return qRound(value * 10.0) / 10.0;
}

QVariantList toVariantList(const QVector<double> &values) {
    QVariantList out;
    for (double v : values)
        out.append(v);
    return out;
}

// reads the columns of rideColumns
QVariantMap rideMap(const QSqlQuery &query) {
    QVariantMap ride;
    ride[QStringLiteral("id")] = query.value(0).toInt();
    ride[QStringLiteral("start")] = query.value(1).toLongLong();
    ride[QStringLiteral("duration")] = query.value(2).toInt();
    ride[QStringLiteral("distance")] = query.value(3).toDouble();
    ride[QStringLiteral("avgPower")] = query.value(4).toDouble();
    ride[QStringLiteral("maxPower")] = query.value(5).toDouble();
    ride[QStringLiteral("np")] = query.value(6).toDouble();
    ride[QStringLiteral("intensity")] = query.value(7).toDouble();
    ride[QStringLiteral("tss")] = query.value(8).toDouble();
    ride[QStringLiteral("kj")] = query.value(9).toDouble();
    ride[QStringLiteral("kcal")] = query.value(10).toDouble();
    ride[QStringLiteral("avgHr")] = query.value(11).toDouble();
    ride[QStringLiteral("maxHr")] = query.value(12).toDouble();
    ride[QStringLiteral("avgCadence")] = query.value(13).toDouble();
    ride[QStringLiteral("title")] = query.value(14).toString();
    ride[QStringLiteral("sport")] = query.value(15).toInt();
    ride[QStringLiteral("spark")] = jsonList(query.value(16).toString());
    ride[QStringLiteral("records")] = jsonList(query.value(17).toString());
    return ride;
}

// "start_ms >= from AND start_ms < to", with 0 meaning no bound
void bindRange(QSqlQuery &query, qint64 fromMs, qint64 toMs) {
    query.bindValue(QStringLiteral(":from"), fromMs > 0 ? fromMs : std::numeric_limits<qint64>::min());
    query.bindValue(QStringLiteral(":to"), toMs > 0 ? toMs : std::numeric_limits<qint64>::max());
}

// a FIT field that was not written reads back as its "invalid" value: those become 0
RideSample toSample(const SessionLine &line, const RideSample &previous) {
    RideSample s;
    s.power = line.watt == 0xFFFF ? 0 : line.watt;
    s.heart = line.heart == 0xFF ? 0 : line.heart;
    s.cadence = line.cadence == 0xFF ? 0 : line.cadence;
    s.speed = qIsNaN(line.speed) || line.speed < 0 ? 0 : line.speed;
    s.resistance = line.resistance == 0xFF || line.resistance < 0 ? 0 : line.resistance;
    s.distance = qIsNaN(line.distance) || line.distance < 0 ? previous.distance : line.distance;
    s.calories = line.calories == 0xFFFF || qIsNaN(line.calories) ? previous.calories : line.calories;
    s.second = int(line.elapsedTime);
    return s;
}

} // namespace

RideLibrary::RideLibrary(const QString &appDir, QObject *parent) : QObject(parent) {
    m_fitDir = appDir + QStringLiteral("fit");
    m_dbPath = databasePath(appDir);
    qDebug() << "ride library:" << m_dbPath;

    // the tables exist before the first read from QML
    QSqlDatabase db = QSqlDatabase::addDatabase(QStringLiteral("QSQLITE"), uiConnection);
    db.setDatabaseName(m_dbPath);
    if (!db.open())
        qDebug() << "ride library: cannot open" << m_dbPath << db.lastError().text();
    else if (createTables(db))
        onInserted();

    m_worker = new RideLibraryWorker(m_dbPath);
    m_worker->moveToThread(&m_thread);
    connect(m_worker, &RideLibraryWorker::progress, this, &RideLibrary::onProgress);
    connect(m_worker, &RideLibraryWorker::inserted, this, &RideLibrary::onInserted);
    connect(m_worker, &RideLibraryWorker::jobDone, this, &RideLibrary::jobDone);
    m_thread.start(QThread::LowPriority);

    // after homeform has moved the old .fit files into the fit folder
    QTimer::singleShot(0, this, &RideLibrary::rescan);
}

RideLibrary::~RideLibrary() {
    m_worker->stopRequested.storeRelease(1);
    m_thread.quit();
    m_thread.wait();
    delete m_worker;
    QSqlDatabase::removeDatabase(workerConnection);
    QSqlDatabase::database(uiConnection, false).close();
    QSqlDatabase::removeDatabase(uiConnection);
}

// Next to ddb.sqlite. On Android 14+ a file left in Documents/QZ by a previous install can be
// neither opened nor replaced (see homeform::historyDatabasePath): the library is only a copy of
// what the .fit files hold, so it then goes to the private folder of the app.
QString RideLibrary::databasePath(const QString &appDir) {
    const QString path = appDir + databaseName;
    bool usable = true;
    for (const QString &suffix : {QString(), QStringLiteral("-wal"), QStringLiteral("-shm")}) {
        QFile file(path + suffix);
        if (!suffix.isEmpty() && !file.exists())
            continue;
        if (file.open(QIODevice::ReadWrite))
            file.close();
        else
            usable = false;
    }
    if (usable)
        return path;
    const QString privateDir = QStandardPaths::writableLocation(QStandardPaths::AppDataLocation);
    QDir().mkpath(privateDir);
    return privateDir + QStringLiteral("/") + databaseName;
}

void RideLibrary::jobStarted() {
    m_pendingJobs++;
    if (m_pendingJobs == 1)
        emit busyChanged();
}

void RideLibrary::jobDone() {
    m_pendingJobs--;
    if (m_pendingJobs == 0)
        emit busyChanged();
}

void RideLibrary::onInserted() {
    QSqlQuery query(QSqlDatabase::database(uiConnection));
    if (query.exec(QStringLiteral("SELECT COUNT(*) FROM rides")) && query.next())
        m_rideCount = query.value(0).toInt();
    emit changed();
}

void RideLibrary::onProgress(int indexed, int toIndex) {
    m_indexed = indexed;
    m_toIndex = toIndex;
    emit progressChanged();
}

void RideLibrary::rescan() {
    jobStarted();
    RideLibraryWorker *worker = m_worker;
    const QString fitDir = m_fitDir;
    QMetaObject::invokeMethod(m_worker, [worker, fitDir]() { worker->scan(fitDir); }, Qt::QueuedConnection);
}

void RideLibrary::importFile(const QString &path) {
    jobStarted();
    RideLibraryWorker *worker = m_worker;
    QMetaObject::invokeMethod(m_worker, [worker, path]() { worker->importFile(path); }, Qt::QueuedConnection);
}

QVariantList RideLibrary::rides(int offset, int limit) {
    QVariantList out;
    QSqlQuery query(QSqlDatabase::database(uiConnection));
    query.prepare(QStringLiteral("SELECT ") + rideColumns +
                  QStringLiteral(" FROM rides ORDER BY start_ms DESC, id DESC LIMIT :limit OFFSET :offset"));
    query.bindValue(QStringLiteral(":limit"), limit);
    query.bindValue(QStringLiteral(":offset"), offset);
    if (!query.exec())
        return out;
    while (query.next())
        out.append(rideMap(query));
    return out;
}

QVariantMap RideLibrary::ride(int id) {
    QSqlDatabase db = QSqlDatabase::database(uiConnection);
    QSqlQuery query(db);
    query.prepare(QStringLiteral("SELECT ") + rideColumns +
                  QStringLiteral(", best, power_zone_s, hr_zone_s, ftp_used, max_hr_used, file_path "
                                 "FROM rides WHERE id = :id"));
    query.bindValue(QStringLiteral(":id"), id);
    if (!query.exec() || !query.next())
        return QVariantMap();
    QVariantMap ride = rideMap(query);

    // json object keys come back sorted as text ("10" before "2"): sort them as numbers
    const QJsonObject bestObject = jsonObject(query.value(18).toString());
    QList<int> durations;
    for (const QString &key : bestObject.keys())
        durations.append(key.toInt());
    std::sort(durations.begin(), durations.end());
    QVariantList best;
    for (int seconds : durations) {
        QVariantMap point;
        point[QStringLiteral("seconds")] = seconds;
        point[QStringLiteral("watts")] = bestObject.value(QString::number(seconds)).toDouble();
        best.append(point);
    }
    ride[QStringLiteral("best")] = best;
    ride[QStringLiteral("powerZones")] = jsonList(query.value(19).toString());
    ride[QStringLiteral("hrZones")] = jsonList(query.value(20).toString());
    ride[QStringLiteral("ftp")] = query.value(21).toDouble();
    // maxHr stays the highest heart rate of the ride, this is the one the zones were cut with
    ride[QStringLiteral("zoneMaxHr")] = query.value(22).toDouble();
    ride[QStringLiteral("filePath")] = query.value(23).toString();

    QSqlQuery lapQuery(db);
    lapQuery.prepare(QStringLiteral("SELECT idx, start_s, duration_s, distance_km, avg_power, max_power, avg_hr, "
                                    "max_hr, avg_cadence FROM laps WHERE ride_id = :id ORDER BY idx"));
    lapQuery.bindValue(QStringLiteral(":id"), id);
    QVariantList laps;
    if (lapQuery.exec()) {
        while (lapQuery.next()) {
            QVariantMap lap;
            lap[QStringLiteral("index")] = lapQuery.value(0).toInt();
            lap[QStringLiteral("start")] = lapQuery.value(1).toInt();
            lap[QStringLiteral("duration")] = lapQuery.value(2).toInt();
            lap[QStringLiteral("distance")] = lapQuery.value(3).toDouble();
            lap[QStringLiteral("avgPower")] = lapQuery.value(4).toDouble();
            lap[QStringLiteral("maxPower")] = lapQuery.value(5).toDouble();
            lap[QStringLiteral("avgHr")] = lapQuery.value(6).toDouble();
            lap[QStringLiteral("maxHr")] = lapQuery.value(7).toDouble();
            lap[QStringLiteral("avgCadence")] = lapQuery.value(8).toDouble();
            laps.append(lap);
        }
    }
    ride[QStringLiteral("laps")] = laps;
    return ride;
}

QVariantMap RideLibrary::samples(int id, int maxPoints) {
    QSqlQuery query(QSqlDatabase::database(uiConnection));
    query.prepare(QStringLiteral("SELECT data FROM samples WHERE ride_id = :id"));
    query.bindValue(QStringLiteral(":id"), id);
    QVector<RideSample> samples;
    if (query.exec() && query.next())
        samples = RideStatsCalc::decodeSamples(query.value(0).toByteArray());

    QVector<double> seconds, power, heart, cadence, speed, level, distance;
    for (const RideSample &s : samples) {
        seconds.append(s.second);
        power.append(s.power);
        heart.append(s.heart);
        cadence.append(s.cadence);
        speed.append(s.speed);
        level.append(s.resistance);
        distance.append(s.distance);
    }
    // seconds are averaged as well: each point sits in the middle of its bucket
    QVariantMap out;
    out[QStringLiteral("seconds")] = toVariantList(RideStatsCalc::bucketAverage(seconds, maxPoints));
    out[QStringLiteral("power")] = toVariantList(RideStatsCalc::bucketAverage(power, maxPoints));
    out[QStringLiteral("heart")] = toVariantList(RideStatsCalc::bucketAverage(heart, maxPoints));
    out[QStringLiteral("cadence")] = toVariantList(RideStatsCalc::bucketAverage(cadence, maxPoints));
    out[QStringLiteral("speed")] = toVariantList(RideStatsCalc::bucketAverage(speed, maxPoints));
    out[QStringLiteral("level")] = toVariantList(RideStatsCalc::bucketAverage(level, maxPoints));
    out[QStringLiteral("distance")] = toVariantList(RideStatsCalc::bucketAverage(distance, maxPoints));
    return out;
}

QVariantList RideLibrary::powerCurve(qint64 fromMs, qint64 toMs) {
    const QVector<int> &durations = RideStatsCalc::curveDurations();
    QVector<double> bestWatts(durations.size(), 0);
    QVector<int> bestRide(durations.size(), 0);
    QVector<qint64> bestStart(durations.size(), 0);

    QSqlQuery query(QSqlDatabase::database(uiConnection));
    query.prepare(QStringLiteral("SELECT id, start_ms, best FROM rides WHERE start_ms >= :from AND start_ms < :to"));
    bindRange(query, fromMs, toMs);
    if (query.exec()) {
        while (query.next()) {
            const QJsonObject best = jsonObject(query.value(2).toString());
            for (int i = 0; i < durations.size(); i++) {
                double watts = best.value(QString::number(durations.at(i))).toDouble();
                if (watts > bestWatts.at(i)) {
                    bestWatts[i] = watts;
                    bestRide[i] = query.value(0).toInt();
                    bestStart[i] = query.value(1).toLongLong();
                }
            }
        }
    }

    QVariantList out;
    for (int i = 0; i < durations.size(); i++) {
        if (bestWatts.at(i) <= 0)
            continue;
        QVariantMap point;
        point[QStringLiteral("seconds")] = durations.at(i);
        point[QStringLiteral("watts")] = bestWatts.at(i);
        point[QStringLiteral("rideId")] = bestRide.at(i);
        point[QStringLiteral("start")] = bestStart.at(i);
        out.append(point);
    }
    return out;
}

QVariantMap RideLibrary::totals(qint64 fromMs, qint64 toMs) {
    QVariantMap out;
    QSqlQuery query(QSqlDatabase::database(uiConnection));
    query.prepare(QStringLiteral("SELECT COUNT(*), SUM(duration_s), SUM(distance_km), SUM(kj), SUM(kcal), SUM(tss) "
                                 "FROM rides WHERE start_ms >= :from AND start_ms < :to"));
    bindRange(query, fromMs, toMs);
    bool ok = query.exec() && query.next();
    out[QStringLiteral("rides")] = ok ? query.value(0).toInt() : 0;
    out[QStringLiteral("seconds")] = ok ? query.value(1).toLongLong() : 0;
    out[QStringLiteral("distance")] = ok ? query.value(2).toDouble() : 0.0;
    out[QStringLiteral("kj")] = ok ? query.value(3).toDouble() : 0.0;
    out[QStringLiteral("kcal")] = ok ? query.value(4).toDouble() : 0.0;
    out[QStringLiteral("tss")] = ok ? query.value(5).toDouble() : 0.0;
    return out;
}

QVariantList RideLibrary::days(qint64 fromMs, qint64 toMs) {
    QVariantList out;
    QSqlQuery query(QSqlDatabase::database(uiConnection));
    query.prepare(QStringLiteral("SELECT start_ms, duration_s, distance_km, kj, tss FROM rides "
                                 "WHERE start_ms >= :from AND start_ms < :to ORDER BY start_ms"));
    bindRange(query, fromMs, toMs);
    if (!query.exec())
        return out;
    // rides come in start order, so the rides of one day follow each other
    QVariantMap day;
    QDate current;
    while (query.next()) {
        const QDate date = QDateTime::fromMSecsSinceEpoch(query.value(0).toLongLong()).date();
        if (date != current) {
            if (current.isValid())
                out.append(day);
            current = date;
            day.clear();
            day[QStringLiteral("day")] = QDateTime(date, QTime(0, 0)).toMSecsSinceEpoch();
            day[QStringLiteral("rides")] = 0;
            day[QStringLiteral("seconds")] = 0;
            day[QStringLiteral("distance")] = 0.0;
            day[QStringLiteral("kj")] = 0.0;
            day[QStringLiteral("tss")] = 0.0;
        }
        day[QStringLiteral("rides")] = day.value(QStringLiteral("rides")).toInt() + 1;
        day[QStringLiteral("seconds")] = day.value(QStringLiteral("seconds")).toInt() + query.value(1).toInt();
        day[QStringLiteral("distance")] = day.value(QStringLiteral("distance")).toDouble() + query.value(2).toDouble();
        day[QStringLiteral("kj")] = day.value(QStringLiteral("kj")).toDouble() + query.value(3).toDouble();
        day[QStringLiteral("tss")] = day.value(QStringLiteral("tss")).toDouble() + query.value(4).toDouble();
    }
    if (current.isValid())
        out.append(day);
    return out;
}

QVariantList RideLibrary::recordHistory(int seconds) {
    QVariantList out;
    QSqlQuery query(QSqlDatabase::database(uiConnection));
    if (!query.exec(QStringLiteral("SELECT id, start_ms, best FROM rides ORDER BY start_ms, id")))
        return out;
    const QString key = QString::number(seconds);
    QVector<double> watts;
    QVector<int> ids;
    QVector<qint64> starts;
    while (query.next()) {
        watts.append(jsonObject(query.value(2).toString()).value(key).toDouble());
        ids.append(query.value(0).toInt());
        starts.append(query.value(1).toLongLong());
    }
    for (int i : RideStatsCalc::recordSteps(watts)) {
        QVariantMap step;
        step[QStringLiteral("start")] = starts.at(i);
        step[QStringLiteral("watts")] = watts.at(i);
        step[QStringLiteral("rideId")] = ids.at(i);
        out.append(step);
    }
    return out;
}

QVariantList RideLibrary::rideRecords() {
    QVariantList out;
    QSqlQuery query(QSqlDatabase::database(uiConnection));
    if (!query.exec(QStringLiteral("SELECT id, start_ms, duration_s, kj, distance_km FROM rides ORDER BY start_ms, id")))
        return out;
    QVector<int> ids;
    QVector<qint64> starts;
    QVector<double> durations, kjs, distances;
    // weeks in start order, each with its time and its longest ride
    QVector<QDate> weeks;
    QVector<double> weekSeconds;
    QVector<int> weekRide;
    QVector<double> weekRideSeconds;
    while (query.next()) {
        const qint64 start = query.value(1).toLongLong();
        const double duration = query.value(2).toDouble();
        ids.append(query.value(0).toInt());
        starts.append(start);
        durations.append(duration);
        kjs.append(query.value(3).toDouble());
        distances.append(query.value(4).toDouble());
        const QDate monday = RideStatsCalc::weekMonday(QDateTime::fromMSecsSinceEpoch(start).date());
        if (weeks.isEmpty() || weeks.last() != monday) {
            weeks.append(monday);
            weekSeconds.append(0);
            weekRide.append(0);
            weekRideSeconds.append(-1);
        }
        weekSeconds.last() += duration;
        if (duration > weekRideSeconds.last()) {
            weekRideSeconds.last() = duration;
            weekRide.last() = ids.last();
        }
    }

    // one record: its history, and the last step of it is the record that stands
    auto addRecord = [&out](const QString &key, const QVector<double> &values, const QVector<qint64> &at,
                            const QVector<int> &rides) {
        QVariantList history;
        for (int i : RideStatsCalc::recordSteps(values)) {
            QVariantMap step;
            step[QStringLiteral("start")] = at.at(i);
            step[QStringLiteral("value")] = values.at(i);
            step[QStringLiteral("rideId")] = rides.at(i);
            history.append(step);
        }
        if (history.isEmpty())
            return;
        QVariantMap record = history.last().toMap();
        record[QStringLiteral("key")] = key;
        record[QStringLiteral("history")] = history;
        out.append(record);
    };
    addRecord(QStringLiteral("longest"), durations, starts, ids);
    addRecord(QStringLiteral("kj"), kjs, starts, ids);
    addRecord(QStringLiteral("distance"), distances, starts, ids);
    // a week starts at its local midnight, as the days of days(); its ride is its longest one
    QVector<qint64> weekStarts;
    for (const QDate &monday : weeks)
        weekStarts.append(QDateTime(monday, QTime(0, 0)).toMSecsSinceEpoch());
    addRecord(QStringLiteral("week"), weekSeconds, weekStarts, weekRide);
    return out;
}

bool RideLibraryWorker::openDatabase() {
    if (m_open)
        return true;
    QSqlDatabase db = QSqlDatabase::addDatabase(QStringLiteral("QSQLITE"), workerConnection);
    db.setDatabaseName(m_dbPath);
    if (!db.open()) {
        qDebug() << "ride library: worker cannot open" << m_dbPath << db.lastError().text();
        QSqlDatabase::removeDatabase(workerConnection);
        return false;
    }
    m_open = createTables(db);
    return m_open;
}

// Reads every .fit file of the fit folder (not its subfolders) that is new or changed since it
// was read, and forgets the files that are gone.
void RideLibraryWorker::scan(const QString &fitDir) {
    if (!openDatabase()) {
        emit jobDone();
        return;
    }
    QSqlDatabase db = QSqlDatabase::database(workerConnection);

    // path -> "size mtime" of every file read before, with or without a ride
    QHash<QString, QString> known;
    QSqlQuery query(db);
    query.exec(QStringLiteral("SELECT file_path, file_size, file_mtime FROM rides UNION ALL "
                              "SELECT file_path, file_size, file_mtime FROM skipped"));
    while (query.next())
        known.insert(query.value(0).toString(), query.value(1).toString() + QStringLiteral(" ") +
                                                    query.value(2).toString());
    query.finish();

    QStringList toRead;
    QSet<QString> present;
    const QFileInfoList files = QDir(fitDir).entryInfoList(QStringList() << QStringLiteral("*.fit"), QDir::Files);
    for (const QFileInfo &info : files) {
        const QString path = info.absoluteFilePath();
        present.insert(path);
        const QString stamp = QString::number(info.size()) + QStringLiteral(" ") +
                              QString::number(info.lastModified().toMSecsSinceEpoch());
        if (known.value(path) != stamp)
            toRead.append(path);
    }

    // a folder that cannot be read right now (storage not ready) does not empty the library
    bool changed = false;
    const bool folderReadable = QDir(fitDir).exists();
    for (const QString &path : known.keys()) {
        if (folderReadable && !present.contains(path)) {
            removeFile(path);
            changed = true;
        }
    }

    emit progress(0, toRead.size());
    for (int i = 0; i < toRead.size() && !stopRequested.loadAcquire(); i++) {
        if (indexFile(toRead.at(i))) {
            changed = true;
            emit inserted();
        }
        emit progress(i + 1, toRead.size());
    }
    if (changed) {
        updateRecords();
        emit inserted();
    }
    emit jobDone();
}

void RideLibraryWorker::importFile(const QString &path) {
    if (openDatabase() && indexFile(QFileInfo(path).absoluteFilePath())) {
        updateRecords();
        emit inserted();
    }
    emit jobDone();
}

void RideLibraryWorker::removeFile(const QString &path) {
    QSqlDatabase db = QSqlDatabase::database(workerConnection);
    QSqlQuery query(db);
    query.prepare(QStringLiteral("SELECT id FROM rides WHERE file_path = :path"));
    query.bindValue(QStringLiteral(":path"), path);
    if (query.exec() && query.next()) {
        const int id = query.value(0).toInt();
        for (const QString &table : {QStringLiteral("laps"), QStringLiteral("samples")}) {
            QSqlQuery remove(db);
            remove.prepare(QStringLiteral("DELETE FROM ") + table + QStringLiteral(" WHERE ride_id = :id"));
            remove.bindValue(QStringLiteral(":id"), id);
            remove.exec();
        }
    }
    for (const QString &table : {QStringLiteral("rides"), QStringLiteral("skipped")}) {
        QSqlQuery remove(db);
        remove.prepare(QStringLiteral("DELETE FROM ") + table + QStringLiteral(" WHERE file_path = :path"));
        remove.bindValue(QStringLiteral(":path"), path);
        remove.exec();
    }
}

// Reads one .fit file and stores its ride (replacing an older copy of the same file).
// Returns true when a ride was stored.
bool RideLibraryWorker::indexFile(const QString &path) {
    QList<SessionLine> lines;
    FIT_SPORT sport = FIT_SPORT_INVALID;
    QString title;
    QList<int> lapStarts;
    // the FIT decoder throws on a damaged file (a ride cut short by a crash): it is then skipped
    try {
        qfit::open(path, &lines, &sport, &title, nullptr, nullptr, nullptr, nullptr, &lapStarts);
    } catch (...) {
        qDebug() << "ride library: unreadable" << path;
        lines.clear();
        lapStarts.clear();
    }

    const QFileInfo info(path);
    const qint64 size = info.size();
    const qint64 mtime = info.lastModified().toMSecsSinceEpoch();
    QSqlDatabase db = QSqlDatabase::database(workerConnection);
    db.transaction();
    removeFile(path);

    if (lines.isEmpty()) {
        QSqlQuery query(db);
        query.prepare(QStringLiteral("INSERT INTO skipped (file_path, file_size, file_mtime) "
                                     "VALUES (:path, :size, :mtime)"));
        query.bindValue(QStringLiteral(":path"), path);
        query.bindValue(QStringLiteral(":size"), size);
        query.bindValue(QStringLiteral(":mtime"), mtime);
        query.exec();
        db.commit();
        return false;
    }

    QVector<RideSample> samples;
    samples.reserve(lines.size());
    RideSample previous;
    for (const SessionLine &line : lines) {
        previous = toSample(line, previous);
        samples.append(previous);
    }

    // the zones of the rider at the time the ride is read
    QSettings settings;
    double ftp = settings.value(QZSettings::ftp, QZSettings::default_ftp).toDouble();
    if (ftp <= 0)
        ftp = 200;
    double maxHr = 220.0 - settings.value(QZSettings::age, QZSettings::default_age).toDouble();
    if (settings.value(QZSettings::heart_max_override_enable, QZSettings::default_heart_max_override_enable).toBool())
        maxHr = settings.value(QZSettings::heart_max_override_value, QZSettings::default_heart_max_override_value)
                    .toDouble();
    if (maxHr <= 0)
        maxHr = 190;
    const double hrZonePercent[4] = {
        settings.value(QZSettings::heart_rate_zone1, QZSettings::default_heart_rate_zone1).toDouble(),
        settings.value(QZSettings::heart_rate_zone2, QZSettings::default_heart_rate_zone2).toDouble(),
        settings.value(QZSettings::heart_rate_zone3, QZSettings::default_heart_rate_zone3).toDouble(),
        settings.value(QZSettings::heart_rate_zone4, QZSettings::default_heart_rate_zone4).toDouble()};

    const RideStats stats = RideStatsCalc::compute(samples, lapStarts, ftp, maxHr, hrZonePercent);

    QJsonArray powerZones, hrZones, spark;
    for (int seconds : stats.powerZones)
        powerZones.append(seconds);
    for (int seconds : stats.hrZones)
        hrZones.append(seconds);
    for (double watts : stats.spark)
        spark.append(oneDecimal(watts));
    QJsonObject best;
    for (int i = 0; i < stats.bestSeconds.size(); i++)
        best.insert(QString::number(stats.bestSeconds.at(i)), oneDecimal(stats.bestWatts.at(i)));

    QSqlQuery query(db);
    query.prepare(QStringLiteral(
        "INSERT INTO rides (file_path, file_size, file_mtime, start_ms, duration_s, distance_km, avg_power, "
        "max_power, np, intensity, tss, kj, kcal, avg_hr, max_hr, avg_cadence, title, sport, ftp_used, max_hr_used, "
        "power_zone_s, hr_zone_s, spark, best, records) VALUES (:path, :size, :mtime, :start, :duration, "
        ":distance, :avgPower, :maxPower, :np, :intensity, :tss, :kj, :kcal, :avgHr, :maxHr, :avgCadence, :title, "
        ":sport, :ftp, :maxHrUsed, :powerZones, :hrZones, :spark, :best, '[]')"));
    query.bindValue(QStringLiteral(":path"), path);
    query.bindValue(QStringLiteral(":size"), size);
    query.bindValue(QStringLiteral(":mtime"), mtime);
    query.bindValue(QStringLiteral(":start"), lines.first().time.toMSecsSinceEpoch());
    query.bindValue(QStringLiteral(":duration"), stats.duration);
    query.bindValue(QStringLiteral(":distance"), stats.distance);
    query.bindValue(QStringLiteral(":avgPower"), stats.avgPower);
    query.bindValue(QStringLiteral(":maxPower"), stats.maxPower);
    query.bindValue(QStringLiteral(":np"), stats.np);
    query.bindValue(QStringLiteral(":intensity"), stats.intensity);
    query.bindValue(QStringLiteral(":tss"), stats.tss);
    query.bindValue(QStringLiteral(":kj"), stats.kj);
    query.bindValue(QStringLiteral(":kcal"), stats.kcal);
    query.bindValue(QStringLiteral(":avgHr"), stats.avgHr);
    query.bindValue(QStringLiteral(":maxHr"), stats.maxHr);
    query.bindValue(QStringLiteral(":avgCadence"), stats.avgCadence);
    query.bindValue(QStringLiteral(":title"), title);
    query.bindValue(QStringLiteral(":sport"), int(sport));
    query.bindValue(QStringLiteral(":ftp"), ftp);
    query.bindValue(QStringLiteral(":maxHrUsed"), maxHr);
    query.bindValue(QStringLiteral(":powerZones"), toJson(powerZones));
    query.bindValue(QStringLiteral(":hrZones"), toJson(hrZones));
    query.bindValue(QStringLiteral(":spark"), toJson(spark));
    query.bindValue(QStringLiteral(":best"), toJson(best));
    if (!query.exec()) {
        qDebug() << "ride library: cannot store" << path << query.lastError().text();
        db.rollback();
        return false;
    }
    const qint64 rideId = query.lastInsertId().toLongLong();

    for (const RideLap &lap : stats.laps) {
        QSqlQuery lapQuery(db);
        lapQuery.prepare(QStringLiteral(
            "INSERT INTO laps (ride_id, idx, start_s, duration_s, distance_km, avg_power, max_power, avg_hr, max_hr, "
            "avg_cadence) VALUES (:id, :idx, :start, :duration, :distance, :avgPower, :maxPower, :avgHr, :maxHr, "
            ":avgCadence)"));
        lapQuery.bindValue(QStringLiteral(":id"), rideId);
        lapQuery.bindValue(QStringLiteral(":idx"), lap.index);
        lapQuery.bindValue(QStringLiteral(":start"), lap.start);
        lapQuery.bindValue(QStringLiteral(":duration"), lap.duration);
        lapQuery.bindValue(QStringLiteral(":distance"), lap.distance);
        lapQuery.bindValue(QStringLiteral(":avgPower"), lap.avgPower);
        lapQuery.bindValue(QStringLiteral(":maxPower"), lap.maxPower);
        lapQuery.bindValue(QStringLiteral(":avgHr"), lap.avgHr);
        lapQuery.bindValue(QStringLiteral(":maxHr"), lap.maxHr);
        lapQuery.bindValue(QStringLiteral(":avgCadence"), lap.avgCadence);
        lapQuery.exec();
    }

    QSqlQuery sampleQuery(db);
    sampleQuery.prepare(QStringLiteral("INSERT INTO samples (ride_id, data) VALUES (:id, :data)"));
    sampleQuery.bindValue(QStringLiteral(":id"), rideId);
    sampleQuery.bindValue(QStringLiteral(":data"), RideStatsCalc::encodeSamples(samples));
    sampleQuery.exec();

    if (!db.commit()) {
        qDebug() << "ride library: cannot store" << path << db.lastError().text();
        db.rollback();
        return false;
    }
    return true;
}

// Marks, for every ride, the durations where it beat all the rides before it. Done over the
// whole library in start order, so a ride added later with an older date is placed right.
void RideLibraryWorker::updateRecords() {
    QSqlDatabase db = QSqlDatabase::database(workerConnection);
    QSqlQuery query(db);
    if (!query.exec(QStringLiteral("SELECT id, best, records FROM rides ORDER BY start_ms, id")))
        return;
    QHash<int, double> bestSoFar;
    QList<QPair<int, QString>> updates;
    while (query.next()) {
        const QJsonObject best = jsonObject(query.value(1).toString());
        QList<int> records;
        for (const QString &key : best.keys()) {
            const int seconds = key.toInt();
            const double watts = best.value(key).toDouble();
            if (watts > 0 && watts > bestSoFar.value(seconds, 0)) {
                records.append(seconds);
                bestSoFar[seconds] = watts;
            }
        }
        std::sort(records.begin(), records.end());
        QJsonArray array;
        for (int seconds : records)
            array.append(seconds);
        const QString json = toJson(array);
        if (json != query.value(2).toString())
            updates.append(qMakePair(query.value(0).toInt(), json));
    }
    query.finish();

    db.transaction();
    for (const auto &update : updates) {
        QSqlQuery write(db);
        write.prepare(QStringLiteral("UPDATE rides SET records = :records WHERE id = :id"));
        write.bindValue(QStringLiteral(":records"), update.second);
        write.bindValue(QStringLiteral(":id"), update.first);
        write.exec();
    }
    db.commit();
}
