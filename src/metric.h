#ifndef METRIC_H
#define METRIC_H

#include "bluetoothdevicetype.h"
#include "qdebugfixup.h"
#include "sessionline.h"
#include <QDateTime>
#include <QList>
#include <QMap>
#include <QVector>
#include <math.h>

// A ride of the history for the training load: local start and end time, and its TSS
struct TrainingLoadRide {
    QDateTime start;
    QDateTime end;
    double tss = 0;
};

// One day of the training load: that day's TSS, then Fitness and Fatigue after that day's rides
struct TrainingLoadDay {
    QDate date;
    double tss = 0;
    double fitness = 0;
    double fatigue = 0;
};

class metric {

  public:
    typedef enum _metric_type {

        METRIC_OTHER = 0,
        METRIC_WATT = 1,
        METRIC_SPEED = 2,
        METRIC_ELAPSED = 3,
    } _metric_type;

    metric();
    void setType(_metric_type t, BLUETOOTH_TYPE bt = UNKNOWN);
    void setValue(double value, bool applyGainAndOffset = true, bool includeZeroInStats = false);
    static double capWatt(double value, double maxWatt);
    double value();
    double valueRaw();
    QDateTime lastChanged() { return m_lastChanged; }
    quint64 updateSequence() const { return m_updateSequence; }
    QDateTime valueChanged() { return m_valueChanged; }
    double average();
    double average5s();
    double average5sHarmonic();
    double average3sHarmonic();
    double average20s();

    // rate of the current metric in a second, useful to know how many Kcal i will burn in a
    // minute if i keep the current pace
    double rate1s() { return m_rateAtSec; }

    double min();
    double max();
    double lapValue();
    double lapAverage();
    double lapMin();
    double lapMax();
    void clearLap(bool accumulator);
    void clear(bool accumulator);
    void operator=(double);
    void operator+=(double);
    void setPaused(bool p);
    void setLap(bool accumulator);

    static double calculateMaxSpeedFromPower(double power, double inclination);
    static double calculatePowerFromSpeed(double speed, double inclination);
    static double calculateSpeedFromPower(double power, double inclination, double speed, double deltaTimeSeconds,
                                          double speedLimit);
    static double calculateWeightLoss(double kcal);
    static double calculateVO2Max(QList<SessionLine> *session);
    static double calculateKCalfromHR(double HR_AVG, double elapsed);
    static double calculateBMR();
    static double calculateActiveKCal(double totalKCal, double elapsed);

    static double powerPeak(QList<SessionLine> *session, int seconds);

    // Coggan Normalized Power of 1 Hz power samples, from firstIndex to the end: 30 s rolling
    // average, fourth power, mean, fourth root. 0 with fewer than 30 samples.
    static double normalizedPower(const QList<SessionLine> &session, int firstIndex = 0);
    // Average of 1 Hz power samples from firstIndex to the end, zeros (coasting) included as in
    // TrainingPeaks, WKO and Garmin: an average of the non-zero samples only can read above NP.
    // 0 without samples.
    static double averagePower(const QList<SessionLine> &session, int firstIndex = 0);
    // Intensity Factor = NP / FTP. 0 when FTP is not set.
    static double intensityFactor(double normalizedPower, double ftp);
    // Training Stress Score = seconds * NP * IF / (FTP * 3600) * 100. 0 when FTP is not set.
    static double trainingStressScore(double seconds, double normalizedPower, double ftp);

    // TSS of a recorded ride whose records may not be 1 s apart (FIT files of other devices):
    // a record's power holds until the next record, a gap over 30 s is a pause and counts as 1 s,
    // and of several records in the same second the last one is kept. Power of 3000 W or more (FIT
    // "no value", a broken sample) counts as 0. Then NP and TSS as above.
    static double rideTrainingStress(const QList<SessionLine> &records, double ftp);
    // TSS per local day of the rides, sorted by start. A ride that starts before the end of the
    // previous counted ride is the same ride recorded twice (QZ and a watch): the higher TSS is kept.
    static QMap<QDate, double> dailyTrainingStress(const QList<TrainingLoadRide> &ridesByStart);
    // Fitness (CTL) and Fatigue (ATL): daily TSS weighted over 42 and 7 days, TrainingPeaks'
    // recursion F_d = F_(d-1) + (TSS_d - F_(d-1)) / 42 (7 for Fatigue), both 0 before the first day.
    // One entry per day from the first day of dailyTss to lastDay; rest days count as 0, days after
    // lastDay are left out. Form (TSB) of a day is its Fitness minus its Fatigue.
    static QVector<TrainingLoadDay> trainingLoad(const QMap<QDate, double> &dailyTss, const QDate &lastDay);
    // Form zone limits for a Fitness: 20%, 5%, -10% and -30% of it (of 20 at least), like intervals.icu
    static QList<int> formZoneLimits(int fitness);
    // "break" (14 days or more since the last ride), "learning" (under 42 days of history), or the
    // Form zone: "fading", "fresh", "balanced", "building" or "tired"
    static QString trainingStatus(int fitness, int fatigue, int historyDays, int daysSinceLastRide);
    
  private:
    double m_value = 0;
    double m_totValue = 0;
    double m_countValue = 0;
    double m_min = 999999999;
    double m_max = 0;
    double m_offset = 0;
    QList<double> m_last3;
    QList<double> m_last5;
    QList<double> m_last20;

    double m_lapOffset = 0;
    double m_lapTotValue = 0;
    double m_lapCountValue = 0;
    double m_lapMin = 999999999;
    double m_lapMax = 0;

    QDateTime m_lastChanged = QDateTime::currentDateTimeUtc();
    quint64 m_updateSequence = 0;
    QDateTime m_valueChanged = QDateTime::currentDateTimeUtc();
    double m_rateAtSec = 0;

    _metric_type m_type = METRIC_OTHER;
    BLUETOOTH_TYPE m_bluetooth_type = UNKNOWN;

    bool paused = false;

    double applySettings(double v, bool applyGainAndOffset);
};

#endif // METRIC_H
