#include "ridestats.h"

#include <QtMath>
#include <algorithm>

namespace {

// zone starts as a share of FTP, the same as src/ui2/Theme.qml and RideMetrics
const double powerZoneStarts[] = {0.555, 0.755, 0.905, 1.055, 1.205, 1.505};

int powerZone(double watts, double ftp) {
    int zone = 0;
    for (int i = 0; i < 6; i++) {
        if (watts >= qRound(ftp * powerZoneStarts[i]))
            zone = i + 1;
    }
    return zone;
}

// the same thresholds as the heart tile of homeform: below zone1 % is zone 1, ... above zone4 % is zone 5
int hrZone(double heart, double maxHr, const double hrZonePercent[4]) {
    double percent = heart * 100.0 / maxHr;
    for (int i = 0; i < 4; i++) {
        if (percent < hrZonePercent[i])
            return i;
    }
    return 4;
}

quint32 clampTo(double value, double max) {
    if (!(value > 0)) // also catches NaN
        return 0;
    if (value > max)
        return quint32(max);
    return quint32(qRound64(value));
}

void putLittleEndian(QByteArray &out, quint32 value, int bytes) {
    for (int i = 0; i < bytes; i++)
        out.append(char((value >> (8 * i)) & 0xFF));
}

quint32 getLittleEndian(const uchar *in, int bytes) {
    quint32 value = 0;
    for (int i = 0; i < bytes; i++)
        value |= quint32(in[i]) << (8 * i);
    return value;
}

const int bytesPerSample = 12;

} // namespace

namespace RideStatsCalc {

const QVector<int> &curveDurations() {
    static const QVector<int> durations = {1,   2,   3,   5,   10,  15,   20,   30,   45,   60,   90,   120,
                                           180, 240, 300, 420, 600, 900, 1200, 1800, 2700, 3600, 5400, 7200};
    return durations;
}

double normalizedPower(const QVector<double> &watts) {
    const int window = 30;
    if (watts.size() < window)
        return 0;
    double rolling = 0;
    double fourthSum = 0;
    int count = 0;
    for (int i = 0; i < watts.size(); i++) {
        rolling += watts.at(i);
        if (i >= window)
            rolling -= watts.at(i - window);
        if (i >= window - 1) {
            fourthSum += qPow(rolling / window, 4);
            count++;
        }
    }
    return qPow(fourthSum / count, 0.25);
}

double meanMax(const QVector<double> &prefixSums, int seconds) {
    // prefixSums[i] is the sum of the first i values, so it has one more entry than the ride
    int samples = prefixSums.size() - 1;
    if (seconds <= 0 || seconds > samples)
        return -1;
    double best = 0;
    for (int end = seconds; end <= samples; end++)
        best = qMax(best, prefixSums.at(end) - prefixSums.at(end - seconds));
    return best / seconds;
}

QVector<double> bucketAverage(const QVector<double> &values, int points) {
    if (points <= 0 || values.size() <= points)
        return values;
    QVector<double> out;
    out.reserve(points);
    for (int b = 0; b < points; b++) {
        int from = int(qint64(b) * values.size() / points);
        int to = int(qint64(b + 1) * values.size() / points);
        double sum = 0;
        for (int i = from; i < to; i++)
            sum += values.at(i);
        out.append(sum / (to - from));
    }
    return out;
}

RideStats compute(const QVector<RideSample> &samples, const QList<int> &lapStarts, double ftp, double maxHr,
                  const double hrZonePercent[4]) {
    RideStats stats;
    stats.powerZones = QVector<int>(7, 0);
    stats.hrZones = QVector<int>(5, 0);
    const int n = samples.size();
    if (n == 0)
        return stats;
    if (ftp <= 0)
        ftp = 200;
    if (maxHr <= 0)
        maxHr = 190;

    QVector<double> watts;
    watts.reserve(n);
    QVector<double> prefixSums;
    prefixSums.reserve(n + 1);
    prefixSums.append(0);
    double hrSum = 0;
    int hrCount = 0;
    double cadenceSum = 0;
    int cadenceCount = 0;
    for (const RideSample &s : samples) {
        watts.append(s.power);
        prefixSums.append(prefixSums.last() + s.power);
        stats.maxPower = qMax(stats.maxPower, s.power);
        stats.powerZones[powerZone(s.power, ftp)]++;
        if (s.heart > 0) {
            hrSum += s.heart;
            hrCount++;
            stats.maxHr = qMax(stats.maxHr, s.heart);
            stats.hrZones[hrZone(s.heart, maxHr, hrZonePercent)]++;
        }
        if (s.cadence > 0) {
            cadenceSum += s.cadence;
            cadenceCount++;
        }
    }

    stats.duration = n;
    stats.distance = samples.last().distance;
    stats.kcal = samples.last().calories;
    stats.kj = prefixSums.last() / 1000.0;
    stats.avgPower = prefixSums.last() / n;
    stats.avgHr = hrCount ? hrSum / hrCount : 0;
    stats.avgCadence = cadenceCount ? cadenceSum / cadenceCount : 0;
    stats.np = normalizedPower(watts);
    stats.intensity = stats.np / ftp;
    stats.tss = stats.duration * stats.np * stats.intensity / (ftp * 3600.0) * 100.0;
    stats.spark = bucketAverage(watts, 48);

    for (int seconds : curveDurations()) {
        double best = meanMax(prefixSums, seconds);
        if (best < 0)
            break;
        stats.bestSeconds.append(seconds);
        stats.bestWatts.append(best);
    }

    // a lap starts at the first sample at or after its start time; the first lap always starts at 0
    QVector<int> starts;
    starts.append(0);
    QList<int> sortedStarts = lapStarts;
    std::sort(sortedStarts.begin(), sortedStarts.end());
    for (int lapStart : sortedStarts) {
        int index = 0;
        while (index < n && samples.at(index).second < lapStart)
            index++;
        if (index < n && index > starts.last())
            starts.append(index);
    }
    for (int l = 0; l < starts.size(); l++) {
        int from = starts.at(l);
        int to = l + 1 < starts.size() ? starts.at(l + 1) : n;
        RideLap lap;
        lap.index = l;
        lap.start = from;
        lap.duration = to - from;
        lap.distance = samples.at(to - 1).distance - (from > 0 ? samples.at(from - 1).distance : 0);
        lap.avgPower = (prefixSums.at(to) - prefixSums.at(from)) / lap.duration;
        double lapHrSum = 0;
        int lapHrCount = 0;
        double lapCadenceSum = 0;
        int lapCadenceCount = 0;
        for (int i = from; i < to; i++) {
            const RideSample &s = samples.at(i);
            lap.maxPower = qMax(lap.maxPower, s.power);
            if (s.heart > 0) {
                lapHrSum += s.heart;
                lapHrCount++;
                lap.maxHr = qMax(lap.maxHr, s.heart);
            }
            if (s.cadence > 0) {
                lapCadenceSum += s.cadence;
                lapCadenceCount++;
            }
        }
        lap.avgHr = lapHrCount ? lapHrSum / lapHrCount : 0;
        lap.avgCadence = lapCadenceCount ? lapCadenceSum / lapCadenceCount : 0;
        stats.laps.append(lap);
    }
    return stats;
}

// Samples blob: 12 bytes per second, little endian, one record after the other:
//   power      u16  watts
//   heart      u8   bpm
//   cadence    u8   rpm
//   speed      u16  km/h * 10
//   resistance u16  level * 10
//   distance   u32  meters since the start
// Values out of range are clamped. Calories and timestamps are not kept: record i is second i.
QByteArray encodeSamples(const QVector<RideSample> &samples) {
    QByteArray out;
    out.reserve(samples.size() * bytesPerSample);
    for (const RideSample &s : samples) {
        putLittleEndian(out, clampTo(s.power, 65535), 2);
        putLittleEndian(out, clampTo(s.heart, 255), 1);
        putLittleEndian(out, clampTo(s.cadence, 255), 1);
        putLittleEndian(out, clampTo(s.speed * 10.0, 65535), 2);
        putLittleEndian(out, clampTo(s.resistance * 10.0, 65535), 2);
        putLittleEndian(out, clampTo(s.distance * 1000.0, 4294967295.0), 4);
    }
    return out;
}

QVector<RideSample> decodeSamples(const QByteArray &blob) {
    QVector<RideSample> samples;
    const int count = blob.size() / bytesPerSample;
    samples.reserve(count);
    const uchar *data = reinterpret_cast<const uchar *>(blob.constData());
    for (int i = 0; i < count; i++) {
        const uchar *record = data + i * bytesPerSample;
        RideSample s;
        s.power = getLittleEndian(record, 2);
        s.heart = getLittleEndian(record + 2, 1);
        s.cadence = getLittleEndian(record + 3, 1);
        s.speed = getLittleEndian(record + 4, 2) / 10.0;
        s.resistance = getLittleEndian(record + 6, 2) / 10.0;
        s.distance = getLittleEndian(record + 8, 4) / 1000.0;
        s.second = i;
        samples.append(s);
    }
    return samples;
}

} // namespace RideStatsCalc
