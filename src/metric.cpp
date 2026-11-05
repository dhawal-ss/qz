#include "metric.h"
#include "qdebugfixup.h"
#include "qzsettings.h"
#include <QSettings>
#include <cmath>

#ifdef TEST
static uint32_t random_value_uint32 = 0;
static uint8_t random_value_uint8 = 0;
#endif

metric::metric() {}

void metric::setType(_metric_type t, BLUETOOTH_TYPE bt) {
    m_type = t;
    m_bluetooth_type = bt;
}

double metric::capWatt(double value, double maxWatt) {
    return maxWatt > 0.0 ? qMin(value, maxWatt) : value;
}

// watt and speed gain and offset, watt cap: read on every value, so a changed setting applies at once
double metric::applySettings(double v, bool applyGainAndOffset) {
    QSettings settings;
    // these special cases are also in the valueRaw
    if (applyGainAndOffset) {
        if (m_type == METRIC_WATT) {
            if (v > 0) {
                double maxGain = (m_bluetooth_type == ROWING) ? 5.00 : 2.00;
                if (settings.value(QZSettings::watt_gain, QZSettings::default_watt_gain).toDouble() <= maxGain) {
                    if (settings.value(QZSettings::watt_gain, QZSettings::default_watt_gain).toDouble() != 1.0) {
                        qDebug() << QStringLiteral("watt value was ") << v
                                 << QStringLiteral("but it will be transformed to")
                                 << v * settings.value(QZSettings::watt_gain, QZSettings::default_watt_gain).toDouble();
                    }
                    v *= settings.value(QZSettings::watt_gain, QZSettings::default_watt_gain).toDouble();
                }
                if (settings.value(QZSettings::watt_offset, QZSettings::default_watt_offset).toDouble() != 0.0) {
                    qDebug()
                        << QStringLiteral("watt value was ") << v << QStringLiteral("but it will be transformed to")
                        << v + settings.value(QZSettings::watt_offset, QZSettings::default_watt_offset).toDouble();
                    v += settings.value(QZSettings::watt_offset, QZSettings::default_watt_offset).toDouble();
                }
            }
        } else if (m_type == METRIC_SPEED) {
            if (v > 0) {
                v *= settings.value(QZSettings::speed_gain, QZSettings::default_speed_gain).toDouble();
                v += settings.value(QZSettings::speed_offset, QZSettings::default_speed_offset).toDouble();
            }
        }
    }

    if (m_type == METRIC_WATT) {
        const double maxWatt = settings.value(QZSettings::watt_max, QZSettings::default_watt_max).toDouble();
        const double cappedWatt = capWatt(v, maxWatt);
        if (cappedWatt != v) {
            qDebug() << QStringLiteral("watt value was ") << v
                     << QStringLiteral("but it will be capped to") << cappedWatt;
            v = cappedWatt;
        }
    }
    return v;
}

void metric::setValue(double v, bool applyGainAndOffset, bool includeZeroInStats) {
    // QSettings only for the types that read it: setValue runs for every value of every metric
    if (m_type == METRIC_WATT || m_type == METRIC_SPEED)
        v = applySettings(v, applyGainAndOffset);

    // UTC: no local-time conversion on every value; callers only use differences (msecsTo/secsTo) and epoch
    QDateTime now = QDateTime::currentDateTimeUtc();
    if (v != m_value && v != INFINITY) {
        m_valueChanged = now;
        if (m_last5.count() > 1) {
            double diff = v - m_value;
            double diffFromLastValue = qAbs(now.msecsTo(m_lastChanged));
            if (diffFromLastValue > 0)
                m_rateAtSec = diff * (1000.0 / diffFromLastValue);
            else
                m_rateAtSec = 0;
        }
    }

    // it has to be here, even if the value is the same, due to https://github.com/cagnulein/qdomyos-zwift/issues/1325
    m_lastChanged = now;
    ++m_updateSequence;

    m_value = v;

    if (paused) {
        return;
    }

    if ((value() != 0 || includeZeroInStats) && value() != INFINITY) {
        m_countValue++;
        m_lapCountValue++;
        m_totValue += value();
        m_lapTotValue += value();
        m_last3.append(value());
        m_last5.append(value());
        m_last20.append(value());

        if (m_last3.count() > 3)
            m_last3.removeAt(0);

        if (m_last5.count() > 5)
            m_last5.removeAt(0);

        if (m_last20.count() > 20)
            m_last20.removeAt(0);

        if (value() < m_min) {
            m_min = value();
        }

        if (value() < m_lapMin) {
            m_lapMin = value();
        }

        if (value() > m_max) {
            m_max = value();
        }

        if (value() > m_lapMax) {
            m_lapMax = value();
        }
    }
}

void metric::clear(bool accumulator) {
    if (accumulator) {
        m_offset = m_value;
    }
    m_max = 0;
    m_totValue = 0;
    m_countValue = 0;
    m_min = 999999999;
    m_last3.clear();
    m_last5.clear();
    m_last20.clear();
    clearLap(accumulator);
#ifdef TEST
    random_value_uint8 = 0;
    random_value_uint32 = 0;
#endif
}

double metric::valueRaw() {
    double v = m_value;
    if (m_type != METRIC_WATT && m_type != METRIC_SPEED)
        return v;
    QSettings settings;

    if (m_type == METRIC_WATT) {
        if (v > 0) {
            double maxGain = (m_bluetooth_type == ROWING) ? 5.00 : 2.00;
            if (settings.value(QZSettings::watt_gain, QZSettings::default_watt_gain).toDouble() <= maxGain) {
                v /= settings.value(QZSettings::watt_gain, QZSettings::default_watt_gain).toDouble();
            }
            if (settings.value(QZSettings::watt_offset, QZSettings::default_watt_offset).toDouble() != 0.0) {
                v -= settings.value(QZSettings::watt_offset, QZSettings::default_watt_offset).toDouble();
            }
        }
    } else if (m_type == METRIC_SPEED) {
        if (v > 0) {
            v /= settings.value(QZSettings::speed_gain, QZSettings::default_speed_gain).toDouble();
            v -= settings.value(QZSettings::speed_offset, QZSettings::default_speed_offset).toDouble();
        }
    }
    return v;
}

double metric::value() {
#ifdef TEST
    if (m_type != METRIC_ELAPSED) {
        return (double)(rand() % 256);
    } else {
        return (double)(random_value_uint32++);
    }

#endif
    return m_value - m_offset;
}

double metric::lapValue() { return m_value - m_lapOffset; }

double metric::average() {
    if (m_countValue == 0) {
        return 0;
    } else {
        return (m_totValue / m_countValue);
    }
}

double metric::lapAverage() {
    if (m_lapCountValue == 0) {
        return 0;
    } else {
        return (m_lapTotValue / m_lapCountValue);
    }
}

double metric::average5s() {
    if (m_last5.count() == 0)
        return 0;
    else {
        double sum = 0;
        uint8_t c = 0;
        QMutableListIterator<double> i(m_last5);
        while (i.hasNext()) {
            double b = i.next();
            sum += b;
            c++;
        }

        if (c > 0)
            return (sum / c);
        else
            return 0;
    }
}

double metric::average5sHarmonic() {
    // If current value is 0, return 0 immediately (user stopped pedaling)
    if (m_value == 0.0)
        return 0.0;

    if (m_last5.count() == 0)
        return 0;
    else {
        double reciprocalSum = 0;
        uint8_t c = 0;
        QMutableListIterator<double> i(m_last5);
        while (i.hasNext()) {
            double b = i.next();
            // If any value in buffer is 0, return 0 immediately
            if (b == 0.0)
                return 0.0;
            reciprocalSum += (1.0 / b);
            c++;
        }

        if (c > 0)
            return (c / reciprocalSum);  // Harmonic mean: n / (1/x1 + 1/x2 + ... + 1/xn)
        else
            return 0;
    }
}

double metric::average3sHarmonic() {
    // If current value is 0, return 0 immediately (user stopped pedaling)
    if (m_value == 0.0)
        return 0.0;

    if (m_last3.count() == 0)
        return 0;
    else {
        double reciprocalSum = 0;
        uint8_t c = 0;
        QMutableListIterator<double> i(m_last3);
        while (i.hasNext()) {
            double b = i.next();
            // If any value in buffer is 0, return 0 immediately
            if (b == 0.0)
                return 0.0;
            reciprocalSum += (1.0 / b);
            c++;
        }

        if (c > 0)
            return (c / reciprocalSum);  // Harmonic mean: n / (1/x1 + 1/x2 + ... + 1/xn)
        else
            return 0;
    }
}

double metric::average20s() {
    if (m_last20.count() == 0)
        return 0;
    else {
        double sum = 0;
        uint8_t c = 0;
        QMutableListIterator<double> i(m_last20);
        while (i.hasNext()) {
            double b = i.next();
            sum += b;
            c++;
        }

        if (c > 0)
            return (sum / c);
        else
            return 0;
    }
}


void metric::operator=(double v) { setValue(v); }

void metric::operator+=(double v) { setValue(m_value + v); }

double metric::min() { return m_min; }

double metric::max() { return m_max; }

double metric::lapMin() { return m_lapMin; }

double metric::lapMax() { return m_lapMax; }

void metric::setPaused(bool p) { paused = p; }

void metric::clearLap(bool accumulator) {
    if (accumulator) {
        m_lapOffset = m_value;
    }
    m_lapMax = 0;
    m_lapTotValue = 0;
    m_lapCountValue = 0;
    m_lapMin = 999999999;
}

void metric::setLap(bool accumulator) { clearLap(accumulator); }

double metric::calculateMaxSpeedFromPower(double power, double inclination) {
    QSettings settings;
    double rolling_resistance =
        settings.value(QZSettings::rolling_resistance, QZSettings::default_rolling_resistance).toFloat();
    double twt = 9.8 * (settings.value(QZSettings::weight, QZSettings::default_weight).toFloat() +
                        settings.value(QZSettings::bike_weight, QZSettings::default_bike_weight).toFloat());
    double aero = 0.22691607640851885;
    double hw = 0; // wind speed
    double tr = twt * ((inclination / 100.0) + rolling_resistance);
    double tran = 0.95;
    double p = power;
    double vel = 20;        // Initial guess
    const uint8_t MAX = 10; // maximum iterations
    double TOL = 0.05;      // tolerance
    for (int i = 1; i < MAX; i++) {
        double tv = vel + hw;
        double aeroEff = (tv > 0.0) ? aero : -aero;           // wind in face, must reverse effect
        double f = vel * (aeroEff * tv * tv + tr) - tran * p; // the function
        double fp = aeroEff * (3.0 * vel + hw) * tv + tr;     // the derivative
        double vNew = vel - f / fp;
        if (qAbs(vNew - vel) < TOL) {
            if (vNew < 0)
                return 0;
            else if (vNew > 19) // 19 m/s == 70 km/h
                return 70;
            return vNew * 3.6;
        } // success
        vel = vNew;
    }
    return 0.0; // failed to converge
}

double metric::calculatePowerFromSpeed(double speed, double inclination) {
    QSettings settings;
    double rolling_resistance =
        settings.value(QZSettings::rolling_resistance, QZSettings::default_rolling_resistance).toFloat();
    double v = speed / 3.6; // converted to m/s;
    double tv = v + 0;
    double tran = 0.95;
    const double aero = 0.22691607640851885;
    double A2Eff = (tv > 0.0) ? aero : -aero; // wind in face, must reverse effect
    double twt = 9.8 * (settings.value(QZSettings::weight, QZSettings::default_weight).toFloat() +
                        settings.value(QZSettings::bike_weight, QZSettings::default_bike_weight).toFloat());
    double tr = twt * ((inclination / 100.0) + rolling_resistance);
    return (v * tr + v * tv * tv * A2Eff) / tran;
}

double metric::calculateSpeedFromPower(double power, double inclination, double speed, double deltaTimeSeconds,
                                       double speedLimit) {
    QSettings settings;
    double speed_gain = settings.value(QZSettings::speed_gain, QZSettings::default_speed_gain).toDouble();
    double speed_offset = settings.value(QZSettings::speed_offset, QZSettings::default_speed_offset).toDouble();
    if (inclination < -5)
        inclination = -5;
    if (speed_offset != QZSettings::default_speed_offset)
        speed -= speed_offset;
    if (speed_gain != QZSettings::default_speed_gain)
        speed /= speed_gain;

    double fullWeight = (settings.value(QZSettings::weight, QZSettings::default_weight).toFloat() +
                         settings.value(QZSettings::bike_weight, QZSettings::default_bike_weight).toFloat());
    double maxSpeed = calculateMaxSpeedFromPower(power, inclination);
    double maxPowerFromSpeed = calculatePowerFromSpeed(speed, inclination);
    double acceleration = (power - maxPowerFromSpeed) / fullWeight;
    double newSpeed = speed + (acceleration * 3.6 * deltaTimeSeconds);
    if (speedLimit > 0 && newSpeed > speedLimit)
        newSpeed = speedLimit;
    if (speedLimit > 0 && maxSpeed > speedLimit)
        maxSpeed = speedLimit;
    if (newSpeed < 0)
        newSpeed = 0;
    if (maxSpeed > newSpeed)
        return newSpeed;
    else if (maxSpeed < speed)
        return newSpeed;
    else
        return maxSpeed;
}

double metric::calculateWeightLoss(double kcal) {
    return kcal / 7716.1854; // comes from 1 lbs = 3500 kcal. Converted to kg
}

double metric::powerPeak(QList<SessionLine> *session, int seconds) {
    // The session has one sample per second (homeform fills timer gaps and drops extra samples,
    // and the FIT file writes record i at start + i), so a window of N samples is N seconds.
    // elapsedTime is not used: it follows the device clock, which can repeat or skip a second.
    // Before, a window ran from one elapsedTime to another and counted N+1 samples over N
    // seconds (a steady 300 W ride read 360 W as 5 s power).
    if (seconds <= 0 || session->count() < seconds)
        return -1; // ride is shorter than the window size!

    double total = 0.0; // power of the last `seconds` samples
    double best = 0.0;
    for (int i = 0; i < session->count(); i++) {
        total += session->at(i).watt;
        if (i >= seconds)
            total -= session->at(i - seconds).watt;
        if (i >= seconds - 1 && total / seconds > best)
            best = total / seconds;
    }
    return best;
}

// NP of 1 Hz power values: 30 s rolling average, fourth power, mean, fourth root
static double normalizedPowerOf(const QVector<double> &watts) {
    const int window = 30;
    double sum30 = 0.0; // sum of the last 30 samples
    double sum4 = 0.0;  // sum of the fourth powers of the 30 s averages
    int averages = 0;
    for (int i = 0; i < watts.count(); i++) {
        sum30 += watts.at(i);
        if (i >= window)
            sum30 -= watts.at(i - window);
        if (i >= window - 1) {
            double avg = sum30 / window;
            sum4 += avg * avg * avg * avg;
            averages++;
        }
    }
    if (averages == 0)
        return 0.0;
    return std::pow(sum4 / averages, 0.25);
}

double metric::normalizedPower(const QList<SessionLine> &session, int firstIndex) {
    if (firstIndex < 0)
        firstIndex = 0;
    QVector<double> watts;
    watts.reserve(qMax(0, session.count() - firstIndex));
    for (int i = firstIndex; i < session.count(); i++)
        watts.append(session.at(i).watt);
    return normalizedPowerOf(watts);
}

double metric::intensityFactor(double normalizedPower, double ftp) {
    if (ftp <= 0 || normalizedPower <= 0)
        return 0.0;
    return normalizedPower / ftp;
}

double metric::trainingStressScore(double seconds, double normalizedPower, double ftp) {
    if (ftp <= 0 || normalizedPower <= 0 || seconds <= 0)
        return 0.0;
    return (seconds * normalizedPower * intensityFactor(normalizedPower, ftp)) / (ftp * 3600.0) * 100.0;
}

double metric::rideTrainingStress(const QList<SessionLine> &records, double ftp) {
    const int pauseSeconds = 30; // the pause cap qfit uses for TRIMP too
    QVector<double> watts;       // one value per second
    watts.reserve(records.count());
    for (int i = 0; i < records.count(); i++) {
        int seconds = 1;
        if (i + 1 < records.count()) {
            seconds = (int)records.at(i).time.secsTo(records.at(i + 1).time);
            if (seconds <= 0)
                continue; // the next record of the same second replaces this one
            if (seconds > pauseSeconds)
                seconds = 1; // paused or stopped, not riding time
        }
        const double watt = records.at(i).watt == 0xFFFF ? 0.0 : records.at(i).watt; // FIT "no value"
        for (int s = 0; s < seconds; s++)
            watts.append(watt);
    }
    return trainingStressScore(watts.count(), normalizedPowerOf(watts), ftp);
}

QMap<QDate, double> metric::dailyTrainingStress(const QList<TrainingLoadRide> &ridesByStart) {
    QMap<QDate, double> daily;
    bool counted = false; // a ride was counted already
    QDate countedDay;
    QDateTime countedEnd;
    double countedTss = 0;
    for (const TrainingLoadRide &ride : ridesByStart) {
        if (ride.tss <= 0 || !ride.start.isValid())
            continue;
        const QDateTime start = ride.start.toLocalTime();
        // an end more than a day after the start is a broken clock (a head unit that reset, or
        // FIT's "no value" timestamp): trusted, it would swallow every later ride as a duplicate
        const bool endUsable = ride.end.isValid() && ride.end > ride.start && ride.start.secsTo(ride.end) <= 86400;
        const QDateTime end = endUsable ? ride.end.toLocalTime() : start;
        if (counted && start < countedEnd) {
            // the same ride recorded twice: keep the higher TSS
            if (ride.tss > countedTss) {
                daily[countedDay] += ride.tss - countedTss;
                countedTss = ride.tss;
            }
            if (end > countedEnd)
                countedEnd = end;
            continue;
        }
        counted = true;
        countedDay = start.date(); // a ride across midnight counts on its start day
        countedEnd = end;
        countedTss = ride.tss;
        daily[countedDay] += ride.tss;
    }
    return daily;
}

QVector<TrainingLoadDay> metric::trainingLoad(const QMap<QDate, double> &dailyTss, const QDate &lastDay) {
    QVector<TrainingLoadDay> days;
    if (dailyTss.isEmpty() || !lastDay.isValid() || dailyTss.firstKey() > lastDay)
        return days;
    double fitness = 0;
    double fatigue = 0;
    // addDays, not seconds: a day is 23 or 25 hours when the clock changes
    for (QDate date = dailyTss.firstKey(); date <= lastDay; date = date.addDays(1)) {
        TrainingLoadDay day;
        day.date = date;
        day.tss = dailyTss.value(date, 0.0);
        fitness += (day.tss - fitness) / 42.0;
        fatigue += (day.tss - fatigue) / 7.0;
        day.fitness = fitness;
        day.fatigue = fatigue;
        days.append(day);
    }
    return days;
}

QList<int> metric::formZoneLimits(int fitness) {
    // a percentage of Fitness stays right with a wrong FTP; 20 at least, or a new rider at Fitness 3
    // would change zone with every point
    const double base = qMax(fitness, 20);
    return {qRound(0.20 * base), qRound(0.05 * base), qRound(-0.10 * base), qRound(-0.30 * base)};
}

QString metric::trainingStatus(int fitness, int fatigue, int historyDays, int daysSinceLastRide) {
    if (daysSinceLastRide >= 14)
        return QStringLiteral("break");
    if (historyDays < 42)
        return QStringLiteral("learning");
    const int form = fitness - fatigue;
    const QList<int> limits = formZoneLimits(fitness);
    if (form > limits.at(0))
        return QStringLiteral("fading");
    if (form > limits.at(1))
        return QStringLiteral("fresh");
    if (form >= limits.at(2))
        return QStringLiteral("balanced");
    if (form >= limits.at(3))
        return QStringLiteral("building");
    return QStringLiteral("tired");
}

// VO2 (L/min) = 0.0108 x power (W) + 0.007 x body mass (kg)
// power = 5 min peak power for a specific ride
double metric::calculateVO2Max(QList<SessionLine> *session) {       
    double peak = powerPeak(session, 5*60);
    // -1: shorter than 5 min; 0: no power data or no full window. The formula would still give about 7
    if (peak <= 0)
        return 0;
    QSettings settings;
    return ((0.0108 * peak + 0.007 * settings.value(QZSettings::weight, QZSettings::default_weight).toFloat()) /
            settings.value(QZSettings::weight, QZSettings::default_weight).toFloat()) *
           1000.0;
}

double metric::calculateKCalfromHR(double HR_AVG, double elapsed) {
    /*
         * If VO2 max is unknown, the following formulas would apply:

Women:

    CB = T * (0.4472*H - 0.1263*W + 0.074*A - 20.4022) / 4.184

         Men:

        CB = T * (0.6309*H + 0.1988*W + 0.2017*A - 55.0969) / 4.184

             Where:

        CB is the number of calories burned;
    T is the duration of exercise in minutes;
    H is your average heart rate in beats per minute;
    W is your weight in kilograms; and
        A is your age in years.
            */

    QSettings settings;
    QString sex = settings.value(QZSettings::sex, QZSettings::default_sex).toString();
    double weight = settings.value(QZSettings::weight, QZSettings::default_weight).toFloat();
    double age = settings.value(QZSettings::age, QZSettings::default_age).toDouble();
    double T = elapsed / 60;
    double H = HR_AVG;
    double W = weight;
    double A = age;
    if (sex.toLower().contains("female")) {
        return (T * ((0.4472 * H) - (0.1263 * W) + (0.074 * A) - 20.4022) / 4.184);
    } else {
        return (T * ((0.6309 * H) + (0.1988 * W) + (0.2017 * A) - 55.0969) / 4.184);
    }
}

double metric::calculateBMR() {
    // Calculate Basal Metabolic Rate using Mifflin-St Jeor equation
    // BMR (kcal/day) for males: 10 * weight(kg) + 6.25 * height(cm) - 5 * age + 5
    // BMR (kcal/day) for females: 10 * weight(kg) + 6.25 * height(cm) - 5 * age - 161
    
    QSettings settings;
    QString sex = settings.value(QZSettings::sex, QZSettings::default_sex).toString();
    double weight = settings.value(QZSettings::weight, QZSettings::default_weight).toFloat();
    double age = settings.value(QZSettings::age, QZSettings::default_age).toDouble();
    double height = settings.value(QZSettings::height, QZSettings::default_height).toDouble();
    
    // Full Mifflin-St Jeor equation with height
    if (sex.toLower().contains("female")) {
        return (10 * weight) + (6.25 * height) - (5 * age) - 161;
    } else {
        return (10 * weight) + (6.25 * height) - (5 * age) + 5;
    }
}

double metric::calculateActiveKCal(double totalKCal, double elapsed) {
    QSettings settings;
    bool activeOnly = settings.value(QZSettings::calories_active_only, QZSettings::default_calories_active_only).toBool();
    
    if (!activeOnly) {
        return totalKCal; // Return total calories if active-only mode is disabled
    }
    
    // Calculate BMR in calories per second
    double bmrPerDay = calculateBMR();
    double bmrPerSecond = bmrPerDay / (24.0 * 60.0 * 60.0); // Convert from calories/day to calories/second
    
    // Calculate BMR calories for the elapsed time
    double bmrForElapsed = bmrPerSecond * elapsed;
    
    // Active calories = Total calories - BMR calories for the elapsed time
    double activeKCal = totalKCal - bmrForElapsed;
    
    // Ensure we don't return negative calories
    return activeKCal > 0 ? activeKCal : 0;
}
