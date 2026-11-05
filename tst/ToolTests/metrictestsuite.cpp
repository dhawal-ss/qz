#include <gtest/gtest.h>

#include <QCoreApplication>
#include <QSettings>
#include <cmath>

#include "metric.h"
#include "qzsettings.h"

class MetricMaxWattTest : public testing::Test {
protected:
    void SetUp() override {
        originalOrganization = QCoreApplication::organizationName();
        originalApplication = QCoreApplication::applicationName();
        QCoreApplication::setOrganizationName(QStringLiteral("QDomyosZwiftMetricTests"));
        QCoreApplication::setApplicationName(QStringLiteral("MaxWatt"));

        QSettings settings;
        settings.clear();
        settings.sync();
    }

    void TearDown() override {
        QSettings settings;
        settings.clear();
        settings.sync();
        QCoreApplication::setOrganizationName(originalOrganization);
        QCoreApplication::setApplicationName(originalApplication);
    }

    QString originalOrganization;
    QString originalApplication;
};

TEST_F(MetricMaxWattTest, DefaultMaxWattCapsOutput) {
    metric watts;
    watts.setType(metric::METRIC_WATT, BIKE);

    watts.setValue(10000.0);

    EXPECT_DOUBLE_EQ(watts.value(), QZSettings::default_watt_max);
}

TEST_F(MetricMaxWattTest, ConfiguredMaxWattIsAppliedAfterGainAndOffset) {
    QSettings settings;
    settings.setValue(QZSettings::watt_gain, 2.0);
    settings.setValue(QZSettings::watt_offset, 100.0);
    settings.setValue(QZSettings::watt_max, 900.0);

    metric watts;
    watts.setType(metric::METRIC_WATT, BIKE);
    watts.setValue(500.0);

    EXPECT_DOUBLE_EQ(watts.value(), 900.0);
}

TEST_F(MetricMaxWattTest, ZeroMaxWattDisablesCap) {
    QSettings settings;
    settings.setValue(QZSettings::watt_max, 0.0);

    metric watts;
    watts.setType(metric::METRIC_WATT, BIKE);
    watts.setValue(20000.0);

    EXPECT_DOUBLE_EQ(watts.value(), 20000.0);
}

TEST(MetricMaxWattHelperTest, NonPositiveMaxWattLeavesValueUnchanged) {
    EXPECT_DOUBLE_EQ(metric::capWatt(2000.0, 0.0), 2000.0);
    EXPECT_DOUBLE_EQ(metric::capWatt(2000.0, -1.0), 2000.0);
}

TEST(MetricUpdateSequenceTest, CountsRepeatedHeartRateWrites) {
    metric heart;
    EXPECT_EQ(heart.updateSequence(), 0u);

    heart = 103.0;
    const quint64 healthKitWrite = heart.updateSequence();
    EXPECT_EQ(healthKitWrite, 1u);

    // A device reporting the same BPM must still count as a new source write.
    heart = 103.0;
    EXPECT_EQ(heart.updateSequence(), healthKitWrite + 1);
}

// 1 Hz samples, the first at elapsed time `start`
static QList<SessionLine> powerSession(const QList<uint16_t> &watts, uint32_t start = 0) {
    QList<SessionLine> session;
    for (int i = 0; i < watts.count(); i++) {
        SessionLine line;
        line.watt = watts.at(i);
        line.elapsedTime = start + i;
        session.append(line);
    }
    return session;
}

static QList<uint16_t> repeatedWatts(uint16_t watt, int seconds) {
    QList<uint16_t> watts;
    for (int i = 0; i < seconds; i++)
        watts.append(watt);
    return watts;
}

// The calculation qfit.cpp used before it called metric::normalizedPower
static double bruteForceNormalizedPower(const QList<uint16_t> &watts) {
    if (watts.count() < 30)
        return 0;
    double sum4 = 0;
    int count = 0;
    for (int idx = 29; idx < watts.count(); idx++) {
        double sum = 0;
        for (int j = idx - 29; j <= idx; j++)
            sum += watts.at(j);
        sum4 += std::pow(sum / 30.0, 4.0);
        count++;
    }
    return std::pow(sum4 / count, 0.25);
}

TEST(MetricPowerPeakTest, SteadyPowerGivesThatPowerForEveryWindow) {
    QList<SessionLine> session = powerSession(repeatedWatts(300, 1201));

    EXPECT_DOUBLE_EQ(metric::powerPeak(&session, 5), 300.0);
    EXPECT_DOUBLE_EQ(metric::powerPeak(&session, 60), 300.0);
    EXPECT_DOUBLE_EQ(metric::powerPeak(&session, 5 * 60), 300.0);
    EXPECT_DOUBLE_EQ(metric::powerPeak(&session, 20 * 60), 300.0);
}

TEST(MetricPowerPeakTest, FindsAFiveSecondSprint) {
    QList<uint16_t> watts = repeatedWatts(200, 60);
    watts.append(repeatedWatts(800, 5));
    watts.append(repeatedWatts(200, 60));
    QList<SessionLine> session = powerSession(watts);

    // Was 840 W: the sample before the sprint was added to the 5 sprint seconds
    EXPECT_DOUBLE_EQ(metric::powerPeak(&session, 5), 800.0);
}

TEST(MetricPowerPeakTest, RideShorterThanTheWindowIsLeftOut) {
    QList<SessionLine> session = powerSession(repeatedWatts(250, 30));
    EXPECT_DOUBLE_EQ(metric::powerPeak(&session, 60), -1.0);

    QList<SessionLine> empty;
    EXPECT_DOUBLE_EQ(metric::powerPeak(&empty, 5), -1.0);
}

TEST(MetricPowerPeakTest, RepeatedDeviceSecondDoesNotStretchTheWindow) {
    // The device clock can repeat a second while homeform still records one sample per second:
    // the window must stay 5 samples long, or the sprint average falls apart
    QList<uint16_t> watts = repeatedWatts(200, 60);
    watts.append(repeatedWatts(800, 5));
    watts.append(repeatedWatts(200, 60));
    QList<SessionLine> session = powerSession(watts);
    for (int i = 10; i < session.count(); i++)
        session[i].elapsedTime -= 1; // sample 10 repeats second 9

    EXPECT_DOUBLE_EQ(metric::powerPeak(&session, 5), 800.0);
}

TEST(MetricPowerPeakTest, WindowAsLongAsTheRideGivesTheRideAverage) {
    // 20 minutes of samples whose elapsedTime starts at 1: the 20 minute power is the average,
    // not 0 (which printed "20 Minutes Power: 0W" and "Estimated FTP: 0W")
    QList<uint16_t> watts = repeatedWatts(180, 600);
    watts.append(repeatedWatts(220, 600));
    QList<SessionLine> session = powerSession(watts, 1);

    EXPECT_DOUBLE_EQ(metric::powerPeak(&session, 20 * 60), 200.0);
    EXPECT_DOUBLE_EQ(metric::powerPeak(&session, 20 * 60 + 1), -1.0);
}

TEST(MetricNormalizedPowerTest, SteadyPowerEqualsAveragePower) {
    QList<SessionLine> session = powerSession(repeatedWatts(250, 600));
    EXPECT_NEAR(metric::normalizedPower(session), 250.0, 1e-9);
}

TEST(MetricNormalizedPowerTest, FewerThanThirtySamplesGivesZero) {
    QList<SessionLine> session = powerSession(repeatedWatts(250, 29));
    EXPECT_DOUBLE_EQ(metric::normalizedPower(session), 0.0);
}

TEST(MetricNormalizedPowerTest, IntervalsMatchTheBruteForceCalculation) {
    QList<uint16_t> watts;
    for (int interval = 0; interval < 10; interval++) {
        watts.append(repeatedWatts(320, 60));
        watts.append(repeatedWatts(0, 60)); // coasting counts as zero power
    }
    QList<SessionLine> session = powerSession(watts);

    const double np = metric::normalizedPower(session);
    EXPECT_NEAR(np, bruteForceNormalizedPower(watts), 1e-9);
    // Hard surges cost more than their average: NP is well above the 160 W average
    EXPECT_GT(np, 200.0);
}

TEST(MetricNormalizedPowerTest, FirstIndexSkipsTheSamplesBeforeIt) {
    QList<uint16_t> watts = repeatedWatts(0, 40);
    watts.append(repeatedWatts(200, 300));
    QList<SessionLine> session = powerSession(watts);

    EXPECT_NEAR(metric::normalizedPower(session, 40), 200.0, 1e-9);
    EXPECT_LT(metric::normalizedPower(session), 200.0);
}

TEST(MetricTrainingStressTest, OneHourAtFtpIsOneHundred) {
    EXPECT_DOUBLE_EQ(metric::intensityFactor(250.0, 250.0), 1.0);
    EXPECT_NEAR(metric::trainingStressScore(3600.0, 250.0, 250.0), 100.0, 1e-9);
}

TEST(MetricTrainingStressTest, ScalesWithTimeAndTheSquareOfIntensity) {
    // 30 minutes at 80% of FTP: 0.5 h * 0.8^2 * 100
    EXPECT_NEAR(metric::intensityFactor(160.0, 200.0), 0.8, 1e-12);
    EXPECT_NEAR(metric::trainingStressScore(1800.0, 160.0, 200.0), 32.0, 1e-9);
}

TEST(MetricTrainingStressTest, MissingFtpOrPowerGivesZero) {
    EXPECT_DOUBLE_EQ(metric::intensityFactor(200.0, 0.0), 0.0);
    EXPECT_DOUBLE_EQ(metric::trainingStressScore(3600.0, 200.0, 0.0), 0.0);
    EXPECT_DOUBLE_EQ(metric::trainingStressScore(3600.0, 0.0, 200.0), 0.0);
    EXPECT_DOUBLE_EQ(metric::trainingStressScore(0.0, 200.0, 200.0), 0.0);
}
