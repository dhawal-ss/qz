#include "ridemetrics.h"
#include "bluetooth.h"
#include "qzsettings.h"

#include <QSettings>
#include <QtMath>

namespace {
const int trailLength = 60;
const int zoneSeconds = 30;

void pushCapped(QVariantList &list, double value, int keep) {
    list.append(value);
    while (list.size() > keep)
        list.removeFirst();
}
} // namespace

RideMetrics::RideMetrics(bluetooth *bl, QObject *parent) : QObject(parent), m_bluetooth(bl) {
    connect(&m_timer, &QTimer::timeout, this, &RideMetrics::refresh);
    m_timer.start(1000);
    refresh();
}

void RideMetrics::reset() {
    m_powerTrail.clear();
    m_heartTrail.clear();
    m_cadenceTrail.clear();
    m_zoneHistory.clear();
    m_rolling.clear();
    m_fourthSum = 0;
    m_fourthCount = 0;
}

int RideMetrics::powerZone(double watts) const {
    // zone starts as a share of FTP, the same as src/ui2/Theme.qml
    const double starts[] = {0.555, 0.755, 0.905, 1.055, 1.205, 1.505};
    int zone = 1;
    for (int i = 0; i < 6; i++) {
        if (watts >= qRound(m_ftp * starts[i]))
            zone = i + 2;
    }
    return zone;
}

void RideMetrics::refresh() {
    QSettings settings;
    m_ftp = settings.value(QZSettings::ftp, QZSettings::default_ftp).toDouble();
    if (m_ftp <= 0)
        m_ftp = 200;
    m_maxHeartRate = 220.0 - settings.value(QZSettings::age, QZSettings::default_age).toDouble();
    if (settings.value(QZSettings::heart_max_override_enable, QZSettings::default_heart_max_override_enable).toBool())
        m_maxHeartRate =
            settings.value(QZSettings::heart_max_override_value, QZSettings::default_heart_max_override_value).toDouble();
    if (m_maxHeartRate <= 0)
        m_maxHeartRate = 190;
    m_miles = settings.value(QZSettings::miles_unit, QZSettings::default_miles_unit).toBool();

    bluetoothdevice *dev = m_bluetooth ? m_bluetooth->device() : nullptr;
    m_connected = dev && dev->connected();
    if (!dev) {
        m_deviceName.clear();
        emit updated();
        return;
    }

    m_deviceName = dev->bluetoothDevice.name();
    // a bike without its own power meter computes watts from level and cadence
    QString powerSensor = settings.value(QZSettings::power_sensor_name, QZSettings::default_power_sensor_name).toString();
    bool hasPowerSensor = !powerSensor.isEmpty() && !powerSensor.startsWith(QStringLiteral("Disabled"));
    QString className = QString::fromLatin1(dev->metaObject()->className());
    m_powerEstimated = !hasPowerSensor && className.startsWith(QStringLiteral("echelon"));

    double unit = m_miles ? 0.621371 : 1.0;
    m_power = dev->wattsMetricforUI();
    m_heartRate = dev->currentHeart().value();
    m_cadence = dev->currentCadence().value();
    m_level = qRound(dev->currentResistance().value());
    m_levelMax = dev->maxResistance() > 0 ? dev->maxResistance() : 32;
    m_calories = dev->calories().value();
    m_distance = dev->odometer() * unit;
    m_speed = dev->currentSpeed().value() * unit;
    m_avgPower = dev->wattsMetric().average();
    m_kilojoules = dev->jouls().value() / 1000.0;

    QTime time = dev->elapsedTime();
    m_elapsed = time.hour() * 3600 + time.minute() * 60 + time.second();

    // a new ride starts the trails over
    if (m_elapsed < m_lastElapsed)
        reset();

    // one sample per new second of ride time, nothing while paused
    if (m_elapsed > m_lastElapsed && m_elapsed > 0) {
        pushCapped(m_powerTrail, m_power, trailLength);
        pushCapped(m_heartTrail, m_heartRate, trailLength);
        pushCapped(m_cadenceTrail, m_cadence, trailLength);

        m_rolling.append(m_power);
        while (m_rolling.size() > 30)
            m_rolling.removeFirst();
        double mean = 0;
        for (double w : m_rolling)
            mean += w;
        mean /= m_rolling.size();
        m_fourthSum += qPow(mean, 4);
        m_fourthCount++;
        m_normalizedPower = qPow(m_fourthSum / m_fourthCount, 0.25);
        double intensity = m_normalizedPower / m_ftp;
        m_tss = m_elapsed * m_normalizedPower * intensity / (m_ftp * 3600.0) * 100.0;

        if (m_lastElapsed >= 0 && m_elapsed / zoneSeconds > m_lastElapsed / zoneSeconds)
            m_zoneHistory.append(powerZone(m_power));
    }
    m_lastElapsed = m_elapsed;

    emit updated();
}
