#ifndef METRIC_H
#define METRIC_H

#include "bluetoothdevicetype.h"
#include "qdebugfixup.h"
#include "sessionline.h"
#include <QDateTime>
#include <math.h>

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
    // Intensity Factor = NP / FTP. 0 when FTP is not set.
    static double intensityFactor(double normalizedPower, double ftp);
    // Training Stress Score = seconds * NP * IF / (FTP * 3600) * 100. 0 when FTP is not set.
    static double trainingStressScore(double seconds, double normalizedPower, double ftp);
    
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
