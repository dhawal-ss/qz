// qfit::open for the tests: a "ride file" is JSON, not FIT:
//   { "sport": 2, "title": "...", "start": <ms>, "seconds": [ { "w": 200, "hr": 140, "cad": 90 }, ... ],
//     "laps": [ 0, 600 ] }
// One entry a second from start. A file that is not JSON gives no lines, as a damaged FIT would.
#include "qfit.h"

#include <QFile>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>

static void read(const QString &filename, QList<SessionLine> *output, FIT_SPORT *sport, QString *title, QList<int> *laps) {
    QFile file(filename);
    if (!file.open(QIODevice::ReadOnly))
        return;
    const QJsonObject o = QJsonDocument::fromJson(file.readAll()).object();
    if (o.isEmpty())
        return;
    if (sport)
        *sport = FIT_SPORT(o.value(QStringLiteral("sport")).toInt(2));
    if (title)
        *title = o.value(QStringLiteral("title")).toString();
    if (laps)
        for (const QJsonValue &v : o.value(QStringLiteral("laps")).toArray())
            laps->append(v.toInt());
    const qint64 start = qint64(o.value(QStringLiteral("start")).toDouble());
    const QJsonArray seconds = o.value(QStringLiteral("seconds")).toArray();
    double km = 0;
    for (int i = 0; i < seconds.size(); i++) {
        const QJsonObject s = seconds.at(i).toObject();
        SessionLine line;
        line.watt = uint16_t(s.value(QStringLiteral("w")).toInt());
        line.heart = uint8_t(s.value(QStringLiteral("hr")).toInt());
        line.cadence = uint8_t(s.value(QStringLiteral("cad")).toInt());
        line.speed = 30;
        km += 30.0 / 3600.0;
        line.distance = km;
        line.calories = i * 0.2;
        line.resistance = 10;
        line.elapsedTime = uint32_t(i);
        line.time = QDateTime::fromMSecsSinceEpoch(start + qint64(i) * 1000);
        output->append(line);
    }
}

void qfit::open(const QString &filename, QList<SessionLine> *output, FIT_SPORT *sport) {
    read(filename, output, sport, nullptr, nullptr);
}

void qfit::open(const QString &filename, QList<SessionLine> *output, FIT_SPORT *sport, QString *workoutName,
                QString *, QString *, QString *, QString *, QList<int> *lapStarts) {
    read(filename, output, sport, workoutName, lapStarts);
}
