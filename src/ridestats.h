#ifndef RIDESTATS_H
#define RIDESTATS_H

#include <QByteArray>
#include <QList>
#include <QVector>

// Numbers of a finished ride, computed from its 1 Hz samples. Plain functions with no QObject
// and no device code, so they can be tested on their own. Used by RideLibrary.

// One second of a ride, already cleaned of FIT "invalid" values.
struct RideSample {
    double power = 0;      // watts
    double heart = 0;      // bpm, 0 = no reading
    double cadence = 0;    // rpm, 0 = not pedaling or no reading
    double speed = 0;      // km/h
    double resistance = 0; // level
    double distance = 0;   // km since the start of the ride
    double calories = 0;   // kcal since the start of the ride
    int second = 0;        // seconds since the first sample, from the FIT timestamps
};

struct RideLap {
    int index = 0;
    int start = 0;    // first sample of the lap, seconds since the start
    int duration = 0; // seconds
    double distance = 0;
    double avgPower = 0;
    double maxPower = 0;
    double avgHr = 0;
    double maxHr = 0;
    double avgCadence = 0;
};

struct RideStats {
    int duration = 0; // seconds, one per sample
    double distance = 0;
    double avgPower = 0;
    double maxPower = 0;
    double np = 0;
    double intensity = 0;
    double tss = 0;
    double kj = 0;
    double kcal = 0;
    double avgHr = 0;
    double maxHr = 0;
    double avgCadence = 0;
    QVector<int> powerZones; // seconds in each of the 7 power zones
    QVector<int> hrZones;    // seconds in each of the 5 heart rate zones
    QVector<double> spark;   // power averaged into at most 48 points
    QVector<int> bestSeconds; // durations of the power curve reached by this ride
    QVector<double> bestWatts; // best average watts for each of bestSeconds
    QVector<RideLap> laps;
};

namespace RideStatsCalc {

// Durations of the power curve, in seconds.
const QVector<int> &curveDurations();

// Everything at once. lapStarts are seconds since the first sample (as RideSample::second);
// hrZonePercent are the starts of zones 2..5 as percent of maxHr.
RideStats compute(const QVector<RideSample> &samples, const QList<int> &lapStarts, double ftp, double maxHr,
                  const double hrZonePercent[4]);

// 30 s rolling average, raised to the fourth power, averaged, fourth root. 0 under 30 samples.
double normalizedPower(const QVector<double> &watts);

// Best average over every window of the given length, -1 when the ride is shorter.
double meanMax(const QVector<double> &prefixSums, int seconds);

// Averages consecutive values into at most points buckets.
QVector<double> bucketAverage(const QVector<double> &values, int points);

// The samples of a ride as stored in the database, see the format in ridestats.cpp.
QByteArray encodeSamples(const QVector<RideSample> &samples);
QVector<RideSample> decodeSamples(const QByteArray &blob);

} // namespace RideStatsCalc

#endif // RIDESTATS_H
