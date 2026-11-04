#include "ridelibrary.h"
#include "qfit.h"
#include "qzsettings.h"
#include "ridemetrics.h"
#include "ridestats.h"

#include <QCoreApplication>
#include <QDateTime>
#include <QElapsedTimer>
#include <QDebug>
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QHash>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QPair>
#include <QSet>
#include <QSettings>
#include <QSqlDatabase>
#include <QSqlError>
#include <QSqlQuery>
#include <QStandardPaths>
#include <QTextStream>
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
                                           "tss, kj, kcal, avg_hr, max_hr, avg_cadence, title, sport, spark, records, "
                                           "parts, part_ids, gap_s, end_ms, prev_gap_s, power_estimated");

// A ride that counts: a minute at least, with the pedals turning or watts. A heart rate alone, or
// a few seconds of a test, is not a ride: it stays in the list, marked, and counts toward no goal,
// streak, total, curve or record. rideMap() tells the same with ridesCounts().
const QString countedRides = QStringLiteral(" AND duration_s >= 60 AND (COALESCE(avg_cadence, 0) > 0 "
                                            "OR COALESCE(avg_power, 0) > 0 OR COALESCE(max_power, 0) > 0)");
bool rideCounts(int seconds, double avgPower, double maxPower, double avgCadence) {
    return seconds >= 60 && (avgCadence > 0 || avgPower > 0 || maxPower > 0);
}

// PRAGMA user_version of the tables below. 0 is the first library, with one ride per .fit file;
// 3 adds the power source of every part and ride and keeps other sports out.
const int schemaVersion = 3;

// the sports of a .fit file the library keeps: bike rides and files with no sport. Runs, rows,
// ellipticals and the like (QZ records those too) are skipped.
bool bikeSport(int sport) {
    return sport == FIT_SPORT_GENERIC || sport == FIT_SPORT_CYCLING || sport == FIT_SPORT_E_BIKING ||
           sport == FIT_SPORT_INVALID;
}
const QString bikeSports = QStringLiteral("(0, 2, 21, 255)");

// parts.power_source: what made the watts of a part, NULL when not known (a file read from disk)
const int powerMeasured = 1;
const int powerEstimated = 2;

// the setting with the longest pause, in minutes, after which a ride saved again is a ride of its own
const QString mergeGapKey = QStringLiteral("ui2/mergeGapMinutes");
const int defaultMergeGapMinutes = 10;

// a ride can be merged by hand with the ride before it when that one ended at most this long before
const qint64 manualMergeGapSeconds = 3 * 3600;

// the unfinished ride: the time of the newest backup the rider recovered or let go (backups up to it
// are not offered again), how far back a backup is still offered, and how long it must be
const QString recoveryKey = QStringLiteral("ui2/recoveryDismissedMs");
const qint64 recoveryMaxAgeMs = qint64(7) * 24 * 3600 * 1000;
const int recoveryMinSeconds = 60;

// rides: one per ride, with everything the lists and the summary of a ride show. Its id is the
// id of its first part, its file_path the file of that part.
//   power_zone_s, hr_zone_s: json arrays of seconds in the 7 power and 5 heart rate zones
//   spark: json array of at most 48 power averages
//   best: json object {"seconds": watts} of the power curve of the ride
//   records: json array of the durations whose best was the highest of all earlier rides
//   parts, part_ids: how many parts the ride has and their ids (json array) in start order
//   gap_s: seconds of pause between the parts, left out of duration_s
//   end_ms: end of the last part. prev_gap_s: seconds from the end of the ride before, NULL for the first
//   power_estimated: 1 when a part worked its watts out (no power meter), 0 when every part measured
//   them, NULL when not known
// parts.power_source: see powerMeasured and powerEstimated, NULL when not known
// parts: one per .fit file. ride_id is the ride it belongs to, end_ms the end of its last second,
//   lap_starts a json array of the sample where each lap after the first starts.
// laps: one row per lap of a ride; every part after the first starts a lap.
// samples: the 1 Hz samples of one part, format in ridestats.cpp. Its ride_id column holds the id of
//   the part (the name is from before rides had parts; a ride and its first part share their id).
// merge_links: what the rider chose for a part: mode 1 joins it to the part before it, 0 keeps it apart.
// skipped: .fit files without samples, so they are not read again at every start.
const QStringList tableStatements = {
    QStringLiteral("CREATE TABLE IF NOT EXISTS rides ("
                   "id INTEGER PRIMARY KEY AUTOINCREMENT, file_path TEXT UNIQUE NOT NULL, file_size INTEGER, "
                   "file_mtime INTEGER, start_ms INTEGER, duration_s INTEGER, distance_km REAL, avg_power REAL, "
                   "max_power REAL, np REAL, intensity REAL, tss REAL, kj REAL, kcal REAL, avg_hr REAL, "
                   "max_hr REAL, avg_cadence REAL, title TEXT, sport INTEGER, ftp_used REAL, max_hr_used REAL, "
                   "power_zone_s TEXT, hr_zone_s TEXT, spark TEXT, best TEXT, records TEXT, parts INTEGER DEFAULT 1, "
                   "part_ids TEXT, gap_s INTEGER DEFAULT 0, end_ms INTEGER, prev_gap_s INTEGER, power_estimated INTEGER)"),
    QStringLiteral("CREATE INDEX IF NOT EXISTS rides_start ON rides(start_ms)"),
    QStringLiteral("CREATE TABLE IF NOT EXISTS parts (id INTEGER PRIMARY KEY AUTOINCREMENT, ride_id INTEGER, "
                   "file_path TEXT UNIQUE NOT NULL, file_size INTEGER, file_mtime INTEGER, start_ms INTEGER, "
                   "end_ms INTEGER, duration_s INTEGER, distance_km REAL, kcal REAL, title TEXT, sport INTEGER, "
                   "lap_starts TEXT, power_source INTEGER)"),
    QStringLiteral("CREATE INDEX IF NOT EXISTS parts_ride ON parts(ride_id)"),
    QStringLiteral("CREATE TABLE IF NOT EXISTS laps (ride_id INTEGER, idx INTEGER, start_s INTEGER, "
                   "duration_s INTEGER, distance_km REAL, avg_power REAL, max_power REAL, avg_hr REAL, "
                   "max_hr REAL, avg_cadence REAL, PRIMARY KEY (ride_id, idx))"),
    QStringLiteral("CREATE TABLE IF NOT EXISTS samples (ride_id INTEGER PRIMARY KEY, data BLOB)"),
    QStringLiteral("CREATE TABLE IF NOT EXISTS merge_links (file_path TEXT PRIMARY KEY, mode INTEGER)"),
    QStringLiteral("CREATE TABLE IF NOT EXISTS skipped (file_path TEXT PRIMARY KEY, file_size INTEGER, "
                   "file_mtime INTEGER)")};

bool execAll(QSqlQuery &query, const QStringList &statements) {
    for (const QString &statement : statements) {
        if (!query.exec(statement)) {
            qDebug() << "ride library:" << statement << query.lastError().text();
            return false;
        }
    }
    return true;
}

// From the first library (one ride per .fit file, user_version 0): every ride becomes a ride of one
// part with the same id, so its laps and samples rows stay as they are. The end of a part is not in
// the old tables: it is taken as its start plus its duration, which can only make a pause look longer.
bool migrateFromFirstVersion(QSqlDatabase &db) {
    QSqlQuery query(db);
    const QStringList statements = {
        QStringLiteral("ALTER TABLE rides ADD COLUMN parts INTEGER DEFAULT 1"),
        QStringLiteral("ALTER TABLE rides ADD COLUMN part_ids TEXT"),
        QStringLiteral("ALTER TABLE rides ADD COLUMN gap_s INTEGER DEFAULT 0"),
        QStringLiteral("ALTER TABLE rides ADD COLUMN end_ms INTEGER"),
        QStringLiteral("ALTER TABLE rides ADD COLUMN prev_gap_s INTEGER"),
        QStringLiteral("UPDATE rides SET parts = 1, part_ids = '[' || id || ']', gap_s = 0, "
                       "end_ms = start_ms + duration_s * 1000"),
        QStringLiteral("INSERT INTO parts (id, ride_id, file_path, file_size, file_mtime, start_ms, end_ms, duration_s, "
                       "distance_km, kcal, title, sport, lap_starts) SELECT id, id, file_path, file_size, file_mtime, "
                       "start_ms, end_ms, duration_s, distance_km, kcal, title, sport, '[]' FROM rides")};
    if (!execAll(query, statements))
        return false;

    // the laps after the first of every ride, as the lap starts of its one part
    QHash<int, QJsonArray> lapStarts;
    if (!query.exec(QStringLiteral("SELECT ride_id, start_s FROM laps WHERE idx > 0 ORDER BY ride_id, idx")))
        return false;
    while (query.next())
        lapStarts[query.value(0).toInt()].append(query.value(1).toInt());
    query.finish();
    for (auto it = lapStarts.constBegin(); it != lapStarts.constEnd(); ++it) {
        QSqlQuery update(db);
        update.prepare(QStringLiteral("UPDATE parts SET lap_starts = :starts WHERE id = :id"));
        update.bindValue(QStringLiteral(":starts"),
                         QString::fromUtf8(QJsonDocument(it.value()).toJson(QJsonDocument::Compact)));
        update.bindValue(QStringLiteral(":id"), it.key());
        if (!update.exec())
            return false;
    }
    return true;
}

// To schema 3: the power source columns (parts has it already when it was made just now, from the
// first library), the parts of other sports go (a scan finds their files again and skips them), and
// every ride is worked out again: power curves that no longer span the break between parts, and the
// zones and FTP of the rider now.
bool migrateToThree(QSqlDatabase &db, bool partsHadNoSource) {
    QSqlQuery query(db);
    QStringList statements = {QStringLiteral("ALTER TABLE rides ADD COLUMN power_estimated INTEGER")};
    if (partsHadNoSource)
        statements << QStringLiteral("ALTER TABLE parts ADD COLUMN power_source INTEGER");
    statements << QStringLiteral("DELETE FROM samples WHERE ride_id IN (SELECT id FROM parts WHERE sport NOT IN ") +
                      bikeSports + QStringLiteral(")")
               << QStringLiteral("DELETE FROM parts WHERE sport NOT IN ") + bikeSports
               << QStringLiteral("UPDATE rides SET part_ids = NULL");
    return execAll(query, statements);
}

bool createTables(QSqlDatabase &db) {
    QSqlQuery query(db);
    if (query.exec(QStringLiteral("PRAGMA journal_mode=WAL")) && query.next())
        qDebug() << "ride library: journal mode" << query.value(0).toString();
    query.exec(QStringLiteral("PRAGMA busy_timeout=5000"));

    int version = 0;
    if (query.exec(QStringLiteral("PRAGMA user_version")) && query.next())
        version = query.value(0).toInt();
    // a newer library (from a later Bikemodo) is not read: RideLibrary starts a new one
    if (version > schemaVersion)
        return false;
    if (version == schemaVersion)
        return execAll(query, tableStatements);

    // a rides table before any version is the first library
    bool firstVersion = false;
    if (version == 0 &&
        query.exec(QStringLiteral("SELECT COUNT(*) FROM sqlite_master WHERE type = 'table' AND name = 'rides'")) &&
        query.next())
        firstVersion = query.value(0).toInt() > 0;
    query.finish();

    db.transaction();
    bool ok = execAll(query, tableStatements);
    if (ok && firstVersion)
        ok = migrateFromFirstVersion(db);
    if (ok && (firstVersion || version == 2))
        ok = migrateToThree(db, version == 2);
    if (ok)
        ok = query.exec(QStringLiteral("PRAGMA user_version = ") + QString::number(schemaVersion));
    if (ok && db.commit()) {
        if (firstVersion || version > 0)
            qDebug() << "ride library: moved to schema" << schemaVersion;
        return true;
    }
    qDebug() << "ride library: cannot set up the tables" << query.lastError().text() << db.lastError().text();
    db.rollback();
    return false;
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
    ride[QStringLiteral("parts")] = qMax(1, query.value(18).toInt());
    ride[QStringLiteral("partIds")] = jsonList(query.value(19).toString());
    ride[QStringLiteral("gapSeconds")] = query.value(20).toInt();
    ride[QStringLiteral("end")] = query.value(21).toLongLong();
    const QVariant previousGap = query.value(22);
    // a ride that overlaps the one before it is another recording, not a part of it
    ride[QStringLiteral("canMergePrevious")] = !previousGap.isNull() && previousGap.toLongLong() >= -1 &&
                                               previousGap.toLongLong() <= manualMergeGapSeconds;
    // true when the watts were worked out, false when measured or not known
    ride[QStringLiteral("powerEstimated")] = query.value(23).toInt() == 1;
    ride[QStringLiteral("powerKnown")] = !query.value(23).isNull();
    // see countedRides
    ride[QStringLiteral("counted")] = rideCounts(query.value(2).toInt(), query.value(4).toDouble(),
                                                 query.value(5).toDouble(), query.value(13).toDouble());
    return ride;
}

// The part of a ride regroup() reads, without its samples.
struct Part {
    int id = 0;
    QString path;
    qint64 size = 0;
    qint64 mtime = 0;
    qint64 start = 0;
    qint64 end = 0;
    double distance = 0;
    double kcal = 0;
    QString title;
    int sport = 0;
    QVariantList lapStarts;
    QVariant powerSource;
};

// the zones of the rider now
struct RiderZones {
    double ftp = 200;
    double maxHr = 190;
    double hrZonePercent[4] = {0, 0, 0, 0};
};

RiderZones riderZones() {
    QSettings settings;
    RiderZones zones;
    zones.ftp = settings.value(QZSettings::ftp, QZSettings::default_ftp).toDouble();
    if (zones.ftp <= 0)
        zones.ftp = 200;
    zones.maxHr = 220.0 - settings.value(QZSettings::age, QZSettings::default_age).toDouble();
    if (settings.value(QZSettings::heart_max_override_enable, QZSettings::default_heart_max_override_enable).toBool())
        zones.maxHr = settings.value(QZSettings::heart_max_override_value, QZSettings::default_heart_max_override_value)
                          .toDouble();
    if (zones.maxHr <= 0)
        zones.maxHr = 190;
    zones.hrZonePercent[0] = settings.value(QZSettings::heart_rate_zone1, QZSettings::default_heart_rate_zone1).toDouble();
    zones.hrZonePercent[1] = settings.value(QZSettings::heart_rate_zone2, QZSettings::default_heart_rate_zone2).toDouble();
    zones.hrZonePercent[2] = settings.value(QZSettings::heart_rate_zone3, QZSettings::default_heart_rate_zone3).toDouble();
    zones.hrZonePercent[3] = settings.value(QZSettings::heart_rate_zone4, QZSettings::default_heart_rate_zone4).toDouble();
    return zones;
}

// the samples of one part
QVector<RideSample> partSamples(QSqlDatabase &db, int partId) {
    QSqlQuery query(db);
    query.prepare(QStringLiteral("SELECT data FROM samples WHERE ride_id = :id"));
    query.bindValue(QStringLiteral(":id"), partId);
    if (query.exec() && query.next())
        return RideStatsCalc::decodeSamples(query.value(0).toByteArray());
    return QVector<RideSample>();
}

// Works out the ride made of these parts (in start order) and stores it, with its laps, under the
// id of its first part. Records are left empty for updateRecords(). Called inside a transaction.
bool storeRide(QSqlDatabase &db, const QList<Part> &parts, const RiderZones &zones) {
    QList<QVector<RideSample>> pieces;
    for (const Part &part : parts)
        pieces.append(partSamples(db, part.id));
    QList<int> partStarts;
    const QVector<RideSample> samples = RideStatsCalc::joinParts(pieces, &partStarts);

    // every part after the first starts a lap, and its own laps follow at their place in the ride
    QList<int> lapStarts;
    double distance = 0;
    double kcal = 0;
    qint64 gapMs = 0;
    QJsonArray partIds;
    for (int k = 0; k < parts.size(); k++) {
        const Part &part = parts.at(k);
        if (k > 0) {
            lapStarts.append(partStarts.at(k));
            gapMs += qMax<qint64>(0, part.start - parts.at(k - 1).end);
        }
        for (const QVariant &lapStart : part.lapStarts)
            lapStarts.append(partStarts.at(k) + lapStart.toInt());
        // the totals of the .fit files: the samples keep the distance in meters and no calories
        distance += part.distance;
        kcal += part.kcal;
        partIds.append(part.id);
    }
    RideStats stats = RideStatsCalc::compute(samples, lapStarts, zones.ftp, zones.maxHr, zones.hrZonePercent, partStarts);
    stats.distance = distance;
    stats.kcal = kcal;

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

    // estimated when any part worked its watts out, measured when every part says so
    bool anyEstimated = false;
    bool allKnown = true;
    for (const Part &part : parts) {
        if (part.powerSource.isNull())
            allKnown = false;
        else if (part.powerSource.toInt() == powerEstimated)
            anyEstimated = true;
    }
    const QVariant rideEstimated = anyEstimated ? QVariant(1) : (allKnown ? QVariant(0) : QVariant());

    const Part &first = parts.first();
    for (const QString &statement :
         {QStringLiteral("DELETE FROM rides WHERE id = :id"), QStringLiteral("DELETE FROM laps WHERE ride_id = :id")}) {
        QSqlQuery remove(db);
        remove.prepare(statement);
        remove.bindValue(QStringLiteral(":id"), first.id);
        remove.exec();
    }

    QSqlQuery query(db);
    query.prepare(QStringLiteral(
        "INSERT INTO rides (id, file_path, file_size, file_mtime, start_ms, duration_s, distance_km, avg_power, "
        "max_power, np, intensity, tss, kj, kcal, avg_hr, max_hr, avg_cadence, title, sport, ftp_used, max_hr_used, "
        "power_zone_s, hr_zone_s, spark, best, records, parts, part_ids, gap_s, end_ms, power_estimated) VALUES (:id, "
        ":path, :size, :mtime, :start, :duration, :distance, :avgPower, :maxPower, :np, :intensity, :tss, :kj, :kcal, "
        ":avgHr, :maxHr, :avgCadence, :title, :sport, :ftp, :maxHrUsed, :powerZones, :hrZones, :spark, :best, '[]', "
        ":parts, :partIds, :gap, :end, :powerEstimated)"));
    query.bindValue(QStringLiteral(":id"), first.id);
    query.bindValue(QStringLiteral(":path"), first.path);
    query.bindValue(QStringLiteral(":size"), first.size);
    query.bindValue(QStringLiteral(":mtime"), first.mtime);
    query.bindValue(QStringLiteral(":start"), first.start);
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
    query.bindValue(QStringLiteral(":title"), first.title);
    query.bindValue(QStringLiteral(":sport"), first.sport);
    query.bindValue(QStringLiteral(":ftp"), zones.ftp);
    query.bindValue(QStringLiteral(":maxHrUsed"), zones.maxHr);
    query.bindValue(QStringLiteral(":powerZones"), toJson(powerZones));
    query.bindValue(QStringLiteral(":hrZones"), toJson(hrZones));
    query.bindValue(QStringLiteral(":spark"), toJson(spark));
    query.bindValue(QStringLiteral(":best"), toJson(best));
    query.bindValue(QStringLiteral(":parts"), parts.size());
    query.bindValue(QStringLiteral(":partIds"), toJson(partIds));
    query.bindValue(QStringLiteral(":gap"), gapMs / 1000);
    query.bindValue(QStringLiteral(":end"), parts.last().end);
    query.bindValue(QStringLiteral(":powerEstimated"), rideEstimated);
    if (!query.exec()) {
        qDebug() << "ride library: cannot store the ride of" << first.path << query.lastError().text();
        return false;
    }

    for (const RideLap &lap : stats.laps) {
        QSqlQuery lapQuery(db);
        lapQuery.prepare(QStringLiteral(
            "INSERT INTO laps (ride_id, idx, start_s, duration_s, distance_km, avg_power, max_power, avg_hr, max_hr, "
            "avg_cadence) VALUES (:id, :idx, :start, :duration, :distance, :avgPower, :maxPower, :avgHr, :maxHr, "
            ":avgCadence)"));
        lapQuery.bindValue(QStringLiteral(":id"), first.id);
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

    for (const Part &part : parts) {
        QSqlQuery update(db);
        update.prepare(QStringLiteral("UPDATE parts SET ride_id = :ride WHERE id = :id"));
        update.bindValue(QStringLiteral(":ride"), first.id);
        update.bindValue(QStringLiteral(":id"), part.id);
        update.exec();
    }
    return true;
}

// the rides of a power group (see RideLibrary::powerGroup) as more of a WHERE clause; rides whose
// power source is not known go with the measured ones
QString powerGroupClause(int group) {
    if (group == 1)
        return QStringLiteral(" AND power_estimated = 1");
    if (group == 0)
        return QStringLiteral(" AND COALESCE(power_estimated, 0) = 0");
    return QString();
}

// "start_ms >= from AND start_ms < to", with 0 meaning no bound
void bindRange(QSqlQuery &query, qint64 fromMs, qint64 toMs) {
    query.bindValue(QStringLiteral(":from"), fromMs > 0 ? fromMs : std::numeric_limits<qint64>::min());
    query.bindValue(QStringLiteral(":to"), toMs > 0 ? toMs : std::numeric_limits<qint64>::max());
}

// The fit folder moved (Documents/QZ to Documents/Bikemodo, homeform::getWritableAppDir): every
// file the library knows that is now in the new folder under the same name gets its new path, in
// every table, so its ride, merges and splits stay as they were.
void relocate(QSqlDatabase &db, const QString &fitDir) {
    QSqlQuery query(db);
    if (!query.exec(QStringLiteral("SELECT file_path FROM parts UNION SELECT file_path FROM skipped "
                                   "UNION SELECT file_path FROM merge_links")))
        return;
    const QString prefix = QDir(fitDir).absolutePath() + QStringLiteral("/");
    QList<QPair<QString, QString>> moves;
    while (query.next()) {
        const QString old = query.value(0).toString();
        if (old.startsWith(prefix))
            continue;
        const QString moved = prefix + QFileInfo(old).fileName();
        if (QFile::exists(moved))
            moves.append(qMakePair(old, moved));
    }
    if (moves.isEmpty())
        return;
    db.transaction();
    for (const auto &m : moves) {
        for (const QString &table : {QStringLiteral("rides"), QStringLiteral("parts"), QStringLiteral("merge_links"),
                                     QStringLiteral("skipped")}) {
            QSqlQuery update(db);
            update.prepare(QStringLiteral("UPDATE ") + table + QStringLiteral(" SET file_path = :moved WHERE file_path = :old"));
            update.bindValue(QStringLiteral(":moved"), m.second);
            update.bindValue(QStringLiteral(":old"), m.first);
            update.exec();
        }
    }
    db.commit();
    qDebug() << "ride library:" << moves.size() << "files found in the new fit folder";
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
    const qint64 startedAt = QDateTime::currentMSecsSinceEpoch();
    m_appDir = appDir;
    m_fitDir = appDir + QStringLiteral("fit");
    m_dbPath = databasePath(appDir);
    qDebug() << "ride library:" << m_dbPath;

    // the tables exist before the first read from QML
    QSqlDatabase db = QSqlDatabase::addDatabase(QStringLiteral("QSQLITE"), uiConnection);
    db.setDatabaseName(m_dbPath);
    bool ready = db.open() && createTables(db);
    if (!ready) {
        // damaged, or made by a newer Bikemodo: it is put aside as .bad and the rides are read again
        // from the .fit files (merges and splits made by hand are lost with it)
        qDebug() << "ride library: starting again, cannot use" << m_dbPath << db.lastError().text();
        db.close();
        for (const QString &suffix : {QString(), QStringLiteral("-wal"), QStringLiteral("-shm")}) {
            QFile::remove(m_dbPath + suffix + QStringLiteral(".bad"));
            QFile::rename(m_dbPath + suffix, m_dbPath + suffix + QStringLiteral(".bad"));
        }
        ready = db.open() && createTables(db);
    }
    if (ready) {
        relocate(db, m_fitDir);
        onInserted();
    } else {
        qDebug() << "ride library: cannot open" << m_dbPath << db.lastError().text();
    }

    m_worker = new RideLibraryWorker(m_dbPath);
    m_worker->moveToThread(&m_thread);
    connect(m_worker, &RideLibraryWorker::progress, this, &RideLibrary::onProgress);
    connect(m_worker, &RideLibraryWorker::inserted, this, &RideLibrary::onInserted);
    connect(m_worker, &RideLibraryWorker::jobDone, this, &RideLibrary::jobDone);
    connect(m_worker, &RideLibraryWorker::unfinishedFound, this, &RideLibrary::onUnfinishedFound);
    m_thread.start(QThread::LowPriority);
    // homeform, which owns the library, is not deleted at quit: the worker stops here instead
    if (QCoreApplication::instance())
        connect(QCoreApplication::instance(), &QCoreApplication::aboutToQuit, this, &RideLibrary::shutdown);

    // after homeform has moved the old .fit files into the fit folder; the backups are looked at
    // once the rides are read, so a backup of a ride that was saved is not offered
    QTimer::singleShot(0, this, [this, startedAt]() {
        rescan();
        RideLibraryWorker *worker = m_worker;
        const QString dir = m_appDir;
        const qint64 dismissedUntil = QSettings().value(recoveryKey, 0).toLongLong();
        QMetaObject::invokeMethod(
            m_worker, [worker, dir, startedAt, dismissedUntil]() { worker->findUnfinished(dir, startedAt, dismissedUntil); },
            Qt::QueuedConnection);
    });
}

RideLibrary::~RideLibrary() {
    shutdown();
    delete m_worker;
    QSqlDatabase::removeDatabase(workerConnection);
    QSqlDatabase::database(uiConnection, false).close();
    QSqlDatabase::removeDatabase(uiConnection);
}

// the job running finishes its file (a scan stops before the next one), the others are dropped
void RideLibrary::shutdown() {
    if (m_stopped)
        return;
    m_stopped = true;
    m_worker->stopRequested.storeRelease(1);
    m_thread.quit();
    m_thread.wait();
}

void RideLibrary::setPowerGroup(int group) {
    if (group == m_powerGroup)
        return;
    m_powerGroup = group;
    emit changed();
}

// Next to ddb.sqlite. On Android 14+ a file left in Documents/QZ by a previous install can be
// neither opened nor replaced (see homeform::historyDatabasePath): the library is only a copy of
// what the .fit files hold, so it then goes to the private folder of the app.
QString RideLibrary::databasePath(const QString &appDir) {
    const QString path = appDir + databaseName;
    const QString privatePath = QStandardPaths::writableLocation(QStandardPaths::AppDataLocation) + QStringLiteral("/") +
                                databaseName;
    // a library kept in the private folder stays there when the folder of the rides has none (a new
    // folder, Documents/Bikemodo): it holds the rider's merges and splits
    if (!QFile::exists(path) && QFile::exists(privatePath))
        return privatePath;
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

void RideLibrary::onUnfinishedFound(const QVariantMap &ride) {
    m_unfinished = ride;
    emit unfinishedChanged();
}

void RideLibrary::forgetUnfinished() {
    QSettings().setValue(recoveryKey, m_unfinished.value(QStringLiteral("mtime")).toLongLong());
    m_unfinished.clear();
    emit unfinishedChanged();
}

// The backup goes into the fit folder under the name homeform gives a saved ride, from its start.
void RideLibrary::recoverUnfinished() {
    if (m_unfinished.isEmpty())
        return;
    const QString source = m_unfinished.value(QStringLiteral("path")).toString();
    const QString name = QDateTime::fromMSecsSinceEpoch(m_unfinished.value(QStringLiteral("start")).toLongLong())
                             .toString()
                             .replace(QStringLiteral(":"), QStringLiteral("_"));
    QDir().mkpath(m_fitDir);
    QString target = m_fitDir + QStringLiteral("/") + name + QStringLiteral(".fit");
    for (int i = 2; QFile::exists(target); i++)
        target = m_fitDir + QStringLiteral("/") + name + QStringLiteral(" (") + QString::number(i) + QStringLiteral(").fit");
    // which bike recorded it is not known any more
    if (QFile::copy(source, target))
        import(target, 0);
    else
        qDebug() << "ride library: cannot recover" << source << "to" << target;
    forgetUnfinished();
}

void RideLibrary::dismissUnfinished() {
    if (!m_unfinished.isEmpty())
        forgetUnfinished();
}

void RideLibrary::rebuild() {
    if (m_stopped)
        return;
    jobStarted();
    RideLibraryWorker *worker = m_worker;
    QMetaObject::invokeMethod(m_worker, [worker]() { worker->rebuild(); }, Qt::QueuedConnection);
}

void RideLibrary::assignUnknownPower(bool estimated) {
    if (m_stopped)
        return;
    jobStarted();
    RideLibraryWorker *worker = m_worker;
    const int source = estimated ? powerEstimated : powerMeasured;
    QMetaObject::invokeMethod(m_worker, [worker, source]() { worker->rebuild(source); }, Qt::QueuedConnection);
}

void RideLibrary::rescan() {
    jobStarted();
    RideLibraryWorker *worker = m_worker;
    const QString fitDir = m_fitDir;
    QMetaObject::invokeMethod(m_worker, [worker, fitDir]() { worker->scan(fitDir); }, Qt::QueuedConnection);
}

// homeform saves a ride while its bike is still connected: rideMetrics knows its power then
void RideLibrary::importFile(const QString &path) {
    int source = 0;
    if (m_metrics && m_metrics->connected())
        source = m_metrics->powerEstimated() ? powerEstimated : powerMeasured;
    import(path, source);
}

void RideLibrary::import(const QString &path, int powerSource) {
    if (m_stopped)
        return;
    jobStarted();
    RideLibraryWorker *worker = m_worker;
    QMetaObject::invokeMethod(m_worker, [worker, path, powerSource]() { worker->importFile(path, powerSource); },
                              Qt::QueuedConnection);
}

bool RideLibrary::mergeWithPrevious(int id) {
    QSqlDatabase db = QSqlDatabase::database(uiConnection);
    QSqlQuery query(db);
    query.prepare(QStringLiteral("SELECT prev_gap_s, part_ids FROM rides WHERE id = :id"));
    query.bindValue(QStringLiteral(":id"), id);
    if (!query.exec() || !query.next())
        return false;
    if (query.value(0).isNull() || query.value(0).toLongLong() < -1 ||
        query.value(0).toLongLong() > manualMergeGapSeconds)
        return false;
    const int firstPart = jsonList(query.value(1).toString()).value(0).toInt();
    QSqlQuery part(db);
    part.prepare(QStringLiteral("SELECT file_path FROM parts WHERE id = :id"));
    part.bindValue(QStringLiteral(":id"), firstPart);
    if (!part.exec() || !part.next())
        return false;
    setLinks(QStringList() << part.value(0).toString(), 1);
    return true;
}

bool RideLibrary::splitRide(int id) {
    QSqlDatabase db = QSqlDatabase::database(uiConnection);
    QSqlQuery query(db);
    query.prepare(QStringLiteral("SELECT part_ids FROM rides WHERE id = :id"));
    query.bindValue(QStringLiteral(":id"), id);
    if (!query.exec() || !query.next())
        return false;
    const QVariantList partIds = jsonList(query.value(0).toString());
    QStringList paths;
    for (int i = 1; i < partIds.size(); i++) {
        QSqlQuery part(db);
        part.prepare(QStringLiteral("SELECT file_path FROM parts WHERE id = :id"));
        part.bindValue(QStringLiteral(":id"), partIds.at(i).toInt());
        if (part.exec() && part.next())
            paths.append(part.value(0).toString());
    }
    if (paths.isEmpty())
        return false;
    setLinks(paths, 0);
    return true;
}

// the database is written by the worker only: the choice joins its queue
void RideLibrary::setLinks(const QStringList &paths, int mode) {
    jobStarted();
    RideLibraryWorker *worker = m_worker;
    QMetaObject::invokeMethod(m_worker, [worker, paths, mode]() { worker->setLinks(paths, mode); },
                              Qt::QueuedConnection);
}

QVariantList RideLibrary::rides(int offset, int limit, bool all) {
    QVariantList out;
    QSqlQuery query(QSqlDatabase::database(uiConnection));
    query.prepare(QStringLiteral("SELECT ") + rideColumns + QStringLiteral(" FROM rides WHERE 1") +
                  (all ? QString() : countedRides) +
                  QStringLiteral(" ORDER BY start_ms DESC, id DESC LIMIT :limit OFFSET :offset"));
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
    const QJsonObject bestObject = jsonObject(query.value(24).toString());
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
    ride[QStringLiteral("powerZones")] = jsonList(query.value(25).toString());
    ride[QStringLiteral("hrZones")] = jsonList(query.value(26).toString());
    ride[QStringLiteral("ftp")] = query.value(27).toDouble();
    // maxHr stays the highest heart rate of the ride, this is the one the zones were cut with
    ride[QStringLiteral("zoneMaxHr")] = query.value(28).toDouble();
    ride[QStringLiteral("filePath")] = query.value(29).toString();

    // the ride this one would join with mergeWithPrevious(), 0 when there is none
    int previousId = 0;
    if (ride.value(QStringLiteral("canMergePrevious")).toBool()) {
        QSqlQuery previous(db);
        previous.prepare(QStringLiteral("SELECT id FROM rides WHERE start_ms < :before OR (start_ms = :start AND id < :id) "
                                        "ORDER BY start_ms DESC, id DESC LIMIT 1"));
        previous.bindValue(QStringLiteral(":before"), ride.value(QStringLiteral("start")).toLongLong());
        previous.bindValue(QStringLiteral(":start"), ride.value(QStringLiteral("start")).toLongLong());
        previous.bindValue(QStringLiteral(":id"), id);
        if (previous.exec() && previous.next())
            previousId = previous.value(0).toInt();
    }
    ride[QStringLiteral("previousId")] = previousId;

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
    query.prepare(QStringLiteral("SELECT parts.start_ms, samples.data FROM parts JOIN samples ON samples.ride_id = "
                                 "parts.id WHERE parts.ride_id = :id ORDER BY parts.start_ms, parts.id"));
    query.bindValue(QStringLiteral(":id"), id);
    QList<QVector<RideSample>> pieces;
    QList<qint64> pieceStarts;
    if (query.exec()) {
        while (query.next()) {
            pieceStarts.append(query.value(0).toLongLong());
            pieces.append(RideStatsCalc::decodeSamples(query.value(1).toByteArray()));
        }
    }
    QList<int> partStarts;
    const QVector<RideSample> samples = RideStatsCalc::joinParts(pieces, &partStarts);

    // seconds counts the riding time only; elapsed is the time since the start, pauses included
    QVector<double> elapsed;
    for (int k = 0; k < pieces.size(); k++) {
        const double offset = (pieceStarts.at(k) - pieceStarts.first()) / 1000.0;
        for (int i = 0; i < pieces.at(k).size(); i++)
            elapsed.append(offset + i);
    }
    QVariantList partStartList;
    for (int start : partStarts)
        partStartList.append(start);

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
    out[QStringLiteral("elapsed")] = toVariantList(RideStatsCalc::bucketAverage(elapsed, maxPoints));
    // the second (as in seconds, before any bucketing) where each part starts
    out[QStringLiteral("partStarts")] = partStartList;
    return out;
}

QVariantList RideLibrary::powerCurve(qint64 fromMs, qint64 toMs, int group) {
    const QVector<int> &durations = RideStatsCalc::curveDurations();
    QVector<double> bestWatts(durations.size(), 0);
    QVector<int> bestRide(durations.size(), 0);
    QVector<qint64> bestStart(durations.size(), 0);

    QSqlQuery query(QSqlDatabase::database(uiConnection));
    query.prepare(QStringLiteral("SELECT id, start_ms, best FROM rides WHERE start_ms >= :from AND start_ms < :to") +
                  countedRides + powerGroupClause(group == -2 ? m_powerGroup : group));
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
                                 "FROM rides WHERE start_ms >= :from AND start_ms < :to") + countedRides);
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
                                 "WHERE start_ms >= :from AND start_ms < :to") + countedRides +
                  QStringLiteral(" ORDER BY start_ms"));
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

QVariantList RideLibrary::recordHistory(int seconds, int group) {
    QVariantList out;
    QSqlQuery query(QSqlDatabase::database(uiConnection));
    const QString where = powerGroupClause(group == -2 ? m_powerGroup : group);
    if (!query.exec(QStringLiteral("SELECT id, start_ms, best FROM rides WHERE 1") + countedRides + where +
                    QStringLiteral(" ORDER BY start_ms, id")))
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
    if (!query.exec(QStringLiteral("SELECT id, start_ms, duration_s, kj, distance_km FROM rides WHERE 1") + countedRides +
                    QStringLiteral(" ORDER BY start_ms, id")))
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
    query.exec(QStringLiteral("SELECT file_path, file_size, file_mtime FROM parts UNION ALL "
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
            // the choice of the rider goes with the file; a file read again keeps it
            QSqlQuery forget(db);
            forget.prepare(QStringLiteral("DELETE FROM merge_links WHERE file_path = :path"));
            forget.bindValue(QStringLiteral(":path"), path);
            forget.exec();
            changed = true;
        }
    }

    // a long first scan (years of QZ rides) groups the parts every 50 files, not after each one,
    // and tells the screens at most every 2 s, so they do not read the whole library again and again
    emit progress(0, toRead.size());
    QElapsedTimer sinceShown;
    sinceShown.start();
    int sinceGrouped = 0;
    for (int i = 0; i < toRead.size() && !stopRequested.loadAcquire(); i++) {
        if (indexFile(toRead.at(i))) {
            changed = true;
            sinceGrouped++;
        }
        if (sinceGrouped >= 50 || (sinceGrouped > 0 && i + 1 == toRead.size())) {
            regroup();
            sinceGrouped = 0;
            if (sinceShown.elapsed() >= 2000) {
                emit inserted();
                sinceShown.restart();
            }
        }
        emit progress(i + 1, toRead.size());
    }
    // also when nothing was read: the pause that joins rides may have changed
    if (regroup())
        changed = true;
    if (changed) {
        updateRecords();
        emit inserted();
    }
    emit jobDone();
}

void RideLibraryWorker::importFile(const QString &path, int powerSource) {
    // also when the file has no samples (any more): its part is gone and so may be its ride
    if (openDatabase()) {
        const QString absolute = QFileInfo(path).absoluteFilePath();
        if (indexFile(absolute) && powerSource > 0) {
            QSqlQuery query(QSqlDatabase::database(workerConnection));
            query.prepare(QStringLiteral("UPDATE parts SET power_source = :source WHERE file_path = :path"));
            query.bindValue(QStringLiteral(":source"), powerSource);
            query.bindValue(QStringLiteral(":path"), absolute);
            query.exec();
        }
        regroup();
        updateRecords();
        emit inserted();
    }
    emit jobDone();
}

// regroup() works out again every ride whose stored parts differ: forgetting them all does it for all
void RideLibraryWorker::rebuild(int powerSource) {
    if (openDatabase()) {
        QSqlQuery query(QSqlDatabase::database(workerConnection));
        if (powerSource > 0) {
            query.prepare(QStringLiteral("UPDATE parts SET power_source = :source WHERE power_source IS NULL"));
            query.bindValue(QStringLiteral(":source"), powerSource);
            query.exec();
        }
        query.exec(QStringLiteral("UPDATE rides SET part_ids = NULL"));
        regroup();
        updateRecords();
        emit inserted();
    }
    emit jobDone();
}

void RideLibraryWorker::setLinks(const QStringList &paths, int mode) {
    if (openDatabase()) {
        QSqlDatabase db = QSqlDatabase::database(workerConnection);
        db.transaction();
        for (const QString &path : paths) {
            QSqlQuery query(db);
            query.prepare(QStringLiteral("INSERT OR REPLACE INTO merge_links (file_path, mode) VALUES (:path, :mode)"));
            query.bindValue(QStringLiteral(":path"), path);
            query.bindValue(QStringLiteral(":mode"), mode);
            query.exec();
        }
        db.commit();
        regroup();
        updateRecords();
        emit inserted();
    }
    emit jobDone();
}

// QZ writes the ride so far every minute, in turn to 0QZ-backup-<start of the app>.fit and
// 1QZ-backup-..., next to the fit folder, and keeps writing it after the ride ends until the next
// one starts. A backup no saved part covers for more than half of it is a ride the app never saved.
void RideLibraryWorker::findUnfinished(const QString &appDir, qint64 before, qint64 dismissedUntil) {
    QVariantMap found;
    if (openDatabase()) {
        QSqlDatabase db = QSqlDatabase::database(workerConnection);
        const QFileInfoList backups = QDir(appDir).entryInfoList(QStringList() << QStringLiteral("*QZ-backup-*.fit"),
                                                                 QDir::Files, QDir::Time);
        for (const QFileInfo &info : backups) {
            const qint64 mtime = info.lastModified().toMSecsSinceEpoch();
            // written since the app started, so not from a ride that was cut short
            if (mtime >= before)
                continue;
            // the newest first: from here on all are older than what the rider has seen
            if (mtime <= dismissedUntil || before - mtime > recoveryMaxAgeMs)
                break;

            QList<SessionLine> lines;
            FIT_SPORT sport = FIT_SPORT_INVALID;
            try {
                qfit::open(info.absoluteFilePath(), &lines, &sport);
            } catch (...) {
                lines.clear();
            }
            if (lines.size() < recoveryMinSeconds)
                continue;
            const qint64 start = lines.first().time.toMSecsSinceEpoch();
            const qint64 end = lines.last().time.toMSecsSinceEpoch() + 1000;

            bool covered = false;
            QSqlQuery query(db);
            query.prepare(QStringLiteral("SELECT start_ms, end_ms FROM parts WHERE start_ms < :end AND end_ms > :start"));
            query.bindValue(QStringLiteral(":start"), start);
            query.bindValue(QStringLiteral(":end"), end);
            if (query.exec()) {
                while (query.next() && !covered) {
                    const qint64 overlap = qMin(end, query.value(1).toLongLong()) - qMax(start, query.value(0).toLongLong());
                    covered = overlap * 2 > end - start;
                }
            }
            if (covered)
                continue;

            found.insert(QStringLiteral("path"), info.absoluteFilePath());
            found.insert(QStringLiteral("mtime"), mtime);
            found.insert(QStringLiteral("start"), start);
            found.insert(QStringLiteral("seconds"), lines.size());
            break;
        }
    }
    emit unfinishedFound(found);
}

// Forgets the part of a file. Its ride is fixed by regroup().
void RideLibraryWorker::removeFile(const QString &path) {
    QSqlDatabase db = QSqlDatabase::database(workerConnection);
    QSqlQuery query(db);
    query.prepare(QStringLiteral("SELECT id FROM parts WHERE file_path = :path"));
    query.bindValue(QStringLiteral(":path"), path);
    if (query.exec() && query.next()) {
        QSqlQuery remove(db);
        remove.prepare(QStringLiteral("DELETE FROM samples WHERE ride_id = :id"));
        remove.bindValue(QStringLiteral(":id"), query.value(0).toInt());
        remove.exec();
    }
    for (const QString &table : {QStringLiteral("parts"), QStringLiteral("skipped")}) {
        QSqlQuery remove(db);
        remove.prepare(QStringLiteral("DELETE FROM ") + table + QStringLiteral(" WHERE file_path = :path"));
        remove.bindValue(QStringLiteral(":path"), path);
        remove.exec();
    }
}

// Reads one .fit file and stores it as a part (replacing an older copy of the same file), with no
// ride yet: regroup() makes it a ride or joins it to one. Returns true when a part was stored.
bool RideLibraryWorker::indexFile(const QString &path) {
    QList<SessionLine> lines;
    FIT_SPORT sport = FIT_SPORT_INVALID;
    QString title;
    QList<int> lapStarts;
    // the FIT decoder throws on a damaged file (a ride cut short by a crash) after it has handed
    // over the records it could read: those are kept, a file with none is skipped
    try {
        qfit::open(path, &lines, &sport, &title, nullptr, nullptr, nullptr, nullptr, &lapStarts);
    } catch (...) {
        qDebug() << "ride library: damaged" << path << "kept" << lines.size() << "records";
        lapStarts.clear();
    }
    // a run, a row or another sport QZ recorded is not a bike ride
    if (!bikeSport(int(sport)))
        lines.clear();

    const QFileInfo info(path);
    const qint64 size = info.size();
    const qint64 mtime = info.lastModified().toMSecsSinceEpoch();
    QSqlDatabase db = QSqlDatabase::database(workerConnection);
    db.transaction();
    // a file read again keeps the power source it was saved with
    QVariant powerSource;
    {
        QSqlQuery before(db);
        before.prepare(QStringLiteral("SELECT power_source FROM parts WHERE file_path = :path"));
        before.bindValue(QStringLiteral(":path"), path);
        if (before.exec() && before.next())
            powerSource = before.value(0);
    }
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

    // the laps as samples (the .fit file gives them in seconds, pauses inside the file included),
    // and the distance and calories, which the stored samples do not keep exactly
    const RiderZones zones = riderZones();
    const RideStats stats = RideStatsCalc::compute(samples, lapStarts, zones.ftp, zones.maxHr, zones.hrZonePercent);
    QJsonArray lapIndices;
    for (int l = 1; l < stats.laps.size(); l++)
        lapIndices.append(stats.laps.at(l).start);

    QSqlQuery query(db);
    query.prepare(QStringLiteral(
        "INSERT INTO parts (ride_id, file_path, file_size, file_mtime, start_ms, end_ms, duration_s, distance_km, kcal, "
        "title, sport, lap_starts, power_source) VALUES (0, :path, :size, :mtime, :start, :end, :duration, :distance, "
        ":kcal, :title, :sport, :lapStarts, :powerSource)"));
    query.bindValue(QStringLiteral(":path"), path);
    query.bindValue(QStringLiteral(":size"), size);
    query.bindValue(QStringLiteral(":mtime"), mtime);
    query.bindValue(QStringLiteral(":start"), lines.first().time.toMSecsSinceEpoch());
    // the end of the last second
    query.bindValue(QStringLiteral(":end"), lines.last().time.toMSecsSinceEpoch() + 1000);
    query.bindValue(QStringLiteral(":duration"), stats.duration);
    query.bindValue(QStringLiteral(":distance"), stats.distance);
    query.bindValue(QStringLiteral(":kcal"), stats.kcal);
    query.bindValue(QStringLiteral(":title"), title);
    query.bindValue(QStringLiteral(":sport"), int(sport));
    query.bindValue(QStringLiteral(":lapStarts"), toJson(lapIndices));
    query.bindValue(QStringLiteral(":powerSource"), powerSource);
    if (!query.exec()) {
        qDebug() << "ride library: cannot store" << path << query.lastError().text();
        db.rollback();
        return false;
    }
    const qint64 partId = query.lastInsertId().toLongLong();

    QSqlQuery sampleQuery(db);
    sampleQuery.prepare(QStringLiteral("INSERT INTO samples (ride_id, data) VALUES (:id, :data)"));
    sampleQuery.bindValue(QStringLiteral(":id"), partId);
    sampleQuery.bindValue(QStringLiteral(":data"), RideStatsCalc::encodeSamples(samples));
    sampleQuery.exec();

    if (!db.commit()) {
        qDebug() << "ride library: cannot store" << path << db.lastError().text();
        db.rollback();
        return false;
    }
    return true;
}

// Puts the parts together into rides, over the whole library in start order: a part joins the
// part before it when the rider merged them, or when it started within the merge pause of its
// end and the rider did not split them. Only the rides whose parts changed are worked out again.
// Returns true when a ride changed.
bool RideLibraryWorker::regroup() {
    QSqlDatabase db = QSqlDatabase::database(workerConnection);
    QSettings settings;
    const qint64 gapLimitMs = qint64(settings.value(mergeGapKey, defaultMergeGapMinutes).toInt()) * 60000;

    QList<Part> parts;
    QSqlQuery query(db);
    if (!query.exec(QStringLiteral("SELECT id, file_path, file_size, file_mtime, start_ms, end_ms, distance_km, kcal, "
                                   "title, sport, lap_starts, power_source FROM parts ORDER BY start_ms, id")))
        return false;
    while (query.next()) {
        Part part;
        part.id = query.value(0).toInt();
        part.path = query.value(1).toString();
        part.size = query.value(2).toLongLong();
        part.mtime = query.value(3).toLongLong();
        part.start = query.value(4).toLongLong();
        part.end = query.value(5).toLongLong();
        part.distance = query.value(6).toDouble();
        part.kcal = query.value(7).toDouble();
        part.title = query.value(8).toString();
        part.sport = query.value(9).toInt();
        part.lapStarts = jsonList(query.value(10).toString());
        part.powerSource = query.value(11);
        parts.append(part);
    }
    query.finish();

    QHash<QString, int> links;
    if (query.exec(QStringLiteral("SELECT file_path, mode FROM merge_links"))) {
        while (query.next())
            links.insert(query.value(0).toString(), query.value(1).toInt());
    }
    query.finish();

    // the same ride saved twice (saved again on quit, or a file copied in): a part that shares more
    // than half of the shorter one's time with the part before it is a copy, and only the longer of
    // the two counts. The copy stays in parts, so it is not read again at every start.
    QList<Part> kept;
    for (const Part &part : parts) {
        if (!kept.isEmpty()) {
            const Part &previous = kept.last();
            const qint64 overlap = qMin(previous.end, part.end) - part.start;
            const qint64 shorter = qMin(previous.end - previous.start, part.end - part.start);
            if (shorter > 0 && overlap * 2 > shorter) {
                if (part.end - part.start > previous.end - previous.start)
                    kept.last() = part;
                continue;
            }
        }
        kept.append(part);
    }
    parts = kept;

    QList<QList<Part>> groups;
    for (int i = 0; i < parts.size(); i++) {
        const Part &part = parts.at(i);
        bool join = false;
        if (i > 0) {
            const int mode = links.value(part.path, -1);
            // a part may start in the second the one before ended; more overlap is another recording
            const qint64 gap = part.start - parts.at(i - 1).end;
            // a merge by hand holds only while the part before is still close: when that one is gone,
            // the part does not jump to an older ride
            if (mode == 1)
                join = gap >= -1000 && gap <= manualMergeGapSeconds * 1000;
            else if (mode == -1)
                join = gapLimitMs > 0 && gap >= -1000 && gap <= gapLimitMs;
        }
        if (join)
            groups.last().append(part);
        else
            groups.append(QList<Part>() << part);
    }

    // what the rides table holds now: id -> part ids, and the pause from the ride before
    QHash<int, QString> storedParts;
    QHash<int, QVariant> storedPreviousGap;
    if (query.exec(QStringLiteral("SELECT id, part_ids, prev_gap_s FROM rides"))) {
        while (query.next()) {
            storedParts.insert(query.value(0).toInt(), query.value(1).toString());
            storedPreviousGap.insert(query.value(0).toInt(), query.value(2));
        }
    }
    query.finish();

    QSet<int> wanted;
    for (const QList<Part> &group : groups)
        wanted.insert(group.first().id);

    bool changed = false;
    const RiderZones zones = riderZones();
    db.transaction();
    // first the rides that are no more, so their file path is free for the ride that holds it now
    for (auto it = storedParts.constBegin(); it != storedParts.constEnd(); ++it) {
        if (wanted.contains(it.key()))
            continue;
        for (const QString &statement :
             {QStringLiteral("DELETE FROM rides WHERE id = :id"), QStringLiteral("DELETE FROM laps WHERE ride_id = :id")}) {
            QSqlQuery remove(db);
            remove.prepare(statement);
            remove.bindValue(QStringLiteral(":id"), it.key());
            remove.exec();
        }
        changed = true;
    }
    for (int g = 0; g < groups.size(); g++) {
        const QList<Part> &group = groups.at(g);
        const int id = group.first().id;
        QJsonArray ids;
        for (const Part &part : group)
            ids.append(part.id);
        bool rebuilt = false;
        if (storedParts.value(id) != toJson(ids)) {
            if (!storeRide(db, group, zones))
                continue;
            rebuilt = true;
            changed = true;
        }
        QVariant previousGap;
        if (g > 0)
            previousGap = (group.first().start - groups.at(g - 1).last().end) / 1000;
        const QVariant stored = storedPreviousGap.value(id);
        const bool sameGap = stored.isNull() == previousGap.isNull() && stored.toLongLong() == previousGap.toLongLong();
        if (rebuilt || !sameGap) {
            QSqlQuery update(db);
            update.prepare(QStringLiteral("UPDATE rides SET prev_gap_s = :gap WHERE id = :id"));
            update.bindValue(QStringLiteral(":gap"), previousGap);
            update.bindValue(QStringLiteral(":id"), id);
            update.exec();
            changed = true;
        }
    }
    db.commit();
    return changed;
}

// Marks, for every ride, the durations where it beat all the rides before it with the same kind of
// watts: estimated watts race only estimated ones, measured (or not known) only those. Done over the
// whole library in start order, so a ride added later with an older date is placed right.
void RideLibraryWorker::updateRecords() {
    QSqlDatabase db = QSqlDatabase::database(workerConnection);
    QSqlQuery query(db);
    if (!query.exec(QStringLiteral("SELECT id, best, records, COALESCE(power_estimated, 0), duration_s, avg_power, "
                                   "max_power, avg_cadence FROM rides ORDER BY start_ms, id")))
        return;
    QHash<int, double> bestSoFar[2];
    QList<QPair<int, QString>> updates;
    while (query.next()) {
        // a ride that does not count sets no record (and loses one it had)
        const bool counts = rideCounts(query.value(4).toInt(), query.value(5).toDouble(), query.value(6).toDouble(),
                                       query.value(7).toDouble());
        const QJsonObject best = counts ? jsonObject(query.value(1).toString()) : QJsonObject();
        QHash<int, double> &groupBest = bestSoFar[query.value(3).toInt() == 1 ? 1 : 0];
        QList<int> records;
        for (const QString &key : best.keys()) {
            const int seconds = key.toInt();
            const double watts = best.value(key).toDouble();
            if (watts > 0 && watts > groupBest.value(seconds, 0)) {
                records.append(seconds);
                groupBest[seconds] = watts;
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

QString RideLibrary::exportCsv(const QString &folder) {
    QDir().mkpath(folder);
    const QString path = QDir(folder).filePath(QStringLiteral("bikemodo-rides.csv"));
    QFile file(path);
    if (!file.open(QIODevice::WriteOnly | QIODevice::Truncate | QIODevice::Text))
        return QString();
    QTextStream out(&file);
    out << "date,start,duration_min,distance_km,avg_power_w,np_w,max_power_w,power_estimated,avg_hr_bpm,max_hr_bpm,"
           "avg_cadence_rpm,kj,kcal,tss,intensity,title\n";
    // every ride in the file, the ones that do not count too
    const QVariantList list = rides(0, qMax(1, m_rideCount), true);
    auto number = [](const QVariant &v, int decimals) {
        const double d = v.toDouble();
        return d > 0 ? QString::number(d, 'f', decimals) : QString();
    };
    for (const QVariant &item : list) {
        const QVariantMap r = item.toMap();
        const QDateTime start = QDateTime::fromMSecsSinceEpoch(r.value(QStringLiteral("start")).toLongLong());
        QString title = r.value(QStringLiteral("title")).toString();
        title.replace(QLatin1Char('"'), QStringLiteral("\"\""));
        out << start.toString(QStringLiteral("yyyy-MM-dd")) << ',' << start.toString(QStringLiteral("HH:mm")) << ','
            << QString::number(r.value(QStringLiteral("duration")).toInt() / 60.0, 'f', 1) << ','
            << number(r.value(QStringLiteral("distance")), 2) << ',' << number(r.value(QStringLiteral("avgPower")), 0) << ','
            << number(r.value(QStringLiteral("np")), 0) << ',' << number(r.value(QStringLiteral("maxPower")), 0) << ','
            << (r.value(QStringLiteral("powerKnown")).toBool() ? (r.value(QStringLiteral("powerEstimated")).toBool() ? "yes" : "no") : "")
            << ',' << number(r.value(QStringLiteral("avgHr")), 0) << ',' << number(r.value(QStringLiteral("maxHr")), 0) << ','
            << number(r.value(QStringLiteral("avgCadence")), 0) << ',' << number(r.value(QStringLiteral("kj")), 0) << ','
            << number(r.value(QStringLiteral("kcal")), 0) << ',' << number(r.value(QStringLiteral("tss")), 0) << ','
            << number(r.value(QStringLiteral("intensity")), 2) << ",\"" << title << "\"\n";
    }
    file.close();
    return path;
}

QString RideLibrary::backup(const QString &folder) {
    const QString dirPath = QDir(folder).filePath(QStringLiteral("Bikemodo backup ") +
                                                  QDateTime::currentDateTime().toString(QStringLiteral("yyyy-MM-dd HH-mm")));
    if (!QDir().mkpath(dirPath))
        return QString();
    // a consistent copy of the database while it is open, then the settings file as it is
    QSqlQuery query(QSqlDatabase::database(uiConnection));
    const QString dbCopy = QDir(dirPath).filePath(QStringLiteral("bikemodo-library.sqlite"));
    if (!query.exec(QStringLiteral("VACUUM INTO '") + QString(dbCopy).replace(QLatin1Char('\''), QStringLiteral("''")) +
                    QStringLiteral("'"))) {
        qDebug() << "RideLibrary: backup of the library failed" << query.lastError().text();
        return QString();
    }
    // the settings, without anything that signs in somewhere: the backup sits in shared storage
    QSettings settings;
    QSettings copy(QDir(dirPath).filePath(QStringLiteral("bikemodo-settings.ini")), QSettings::IniFormat);
    const QStringList secret = {QStringLiteral("token"),  QStringLiteral("password"), QStringLiteral("secret"),
                                QStringLiteral("cookie"), QStringLiteral("refresh"),  QStringLiteral("code"),
                                QStringLiteral("session"), QStringLiteral("apikey"),  QStringLiteral("api_key"),
                                QStringLiteral("username"), QStringLiteral("email"),  QStringLiteral("athlete")};
    for (const QString &key : settings.allKeys()) {
        const QString lower = key.toLower();
        bool skip = false;
        for (const QString &word : secret)
            if (lower.contains(word))
                skip = true;
        if (!skip)
            copy.setValue(key, settings.value(key));
    }
    copy.sync();
    return dirPath;
}
