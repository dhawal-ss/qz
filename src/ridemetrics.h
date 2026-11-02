#ifndef RIDEMETRICS_H
#define RIDEMETRICS_H

#include <QObject>
#include <QString>
#include <QTimer>
#include <QVariantList>

class bluetooth;

// The numbers of the ride as plain numbers, for the Pulse interface (src/ui2).
// The tiles of the classic interface carry formatted text, this carries values.
// Updated once a second from the connected device.
class RideMetrics : public QObject {
    Q_OBJECT
    Q_PROPERTY(double power READ power NOTIFY updated)
    Q_PROPERTY(double heartRate READ heartRate NOTIFY updated)
    Q_PROPERTY(double cadence READ cadence NOTIFY updated)
    Q_PROPERTY(int level READ level NOTIFY updated)
    Q_PROPERTY(int levelMax READ levelMax NOTIFY updated)
    Q_PROPERTY(int elapsed READ elapsed NOTIFY updated)
    Q_PROPERTY(double calories READ calories NOTIFY updated)
    Q_PROPERTY(double distance READ distance NOTIFY updated)
    Q_PROPERTY(double speed READ speed NOTIFY updated)
    Q_PROPERTY(double normalizedPower READ normalizedPower NOTIFY updated)
    Q_PROPERTY(double avgPower READ avgPower NOTIFY updated)
    Q_PROPERTY(double kilojoules READ kilojoules NOTIFY updated)
    Q_PROPERTY(double tss READ tss NOTIFY updated)
    Q_PROPERTY(double ftp READ ftp NOTIFY updated)
    Q_PROPERTY(double maxHeartRate READ maxHeartRate NOTIFY updated)
    Q_PROPERTY(bool miles READ miles NOTIFY updated)
    Q_PROPERTY(bool powerEstimated READ powerEstimated NOTIFY updated)
    Q_PROPERTY(bool connected READ connected NOTIFY updated)
    Q_PROPERTY(QString deviceName READ deviceName NOTIFY updated)
    Q_PROPERTY(QVariantList powerTrail READ powerTrail NOTIFY updated)
    Q_PROPERTY(QVariantList heartTrail READ heartTrail NOTIFY updated)
    Q_PROPERTY(QVariantList cadenceTrail READ cadenceTrail NOTIFY updated)
    Q_PROPERTY(QVariantList zoneHistory READ zoneHistory NOTIFY updated)

  public:
    explicit RideMetrics(bluetooth *bl, QObject *parent = nullptr);

    double power() const { return m_power; }
    double heartRate() const { return m_heartRate; }
    double cadence() const { return m_cadence; }
    int level() const { return m_level; }
    int levelMax() const { return m_levelMax; }
    int elapsed() const { return m_elapsed; }
    double calories() const { return m_calories; }
    double distance() const { return m_distance; }
    double speed() const { return m_speed; }
    double normalizedPower() const { return m_normalizedPower; }
    double avgPower() const { return m_avgPower; }
    double kilojoules() const { return m_kilojoules; }
    double tss() const { return m_tss; }
    double ftp() const { return m_ftp; }
    double maxHeartRate() const { return m_maxHeartRate; }
    bool miles() const { return m_miles; }
    bool powerEstimated() const { return m_powerEstimated; }
    bool connected() const { return m_connected; }
    QString deviceName() const { return m_deviceName; }
    QVariantList powerTrail() const { return m_powerTrail; }
    QVariantList heartTrail() const { return m_heartTrail; }
    QVariantList cadenceTrail() const { return m_cadenceTrail; }
    QVariantList zoneHistory() const { return m_zoneHistory; }

  signals:
    void updated();

  private slots:
    void refresh();

  private:
    void reset();
    int powerZone(double watts) const;

    bluetooth *m_bluetooth;
    QTimer m_timer;

    double m_power = 0;
    double m_heartRate = 0;
    double m_cadence = 0;
    int m_level = 0;
    int m_levelMax = 32;
    int m_elapsed = 0;
    double m_calories = 0;
    double m_distance = 0;
    double m_speed = 0;
    double m_normalizedPower = 0;
    double m_avgPower = 0;
    double m_kilojoules = 0;
    double m_tss = 0;
    double m_ftp = 200;
    double m_maxHeartRate = 190;
    bool m_miles = false;
    bool m_powerEstimated = false;
    bool m_connected = false;
    QString m_deviceName;
    QVariantList m_powerTrail;
    QVariantList m_heartTrail;
    QVariantList m_cadenceTrail;
    QVariantList m_zoneHistory;

    // normalized power: 30 s rolling average, raised to the fourth power, averaged, fourth root
    QList<double> m_rolling;
    double m_fourthSum = 0;
    int m_fourthCount = 0;
    int m_lastElapsed = -1;
};

#endif // RIDEMETRICS_H
