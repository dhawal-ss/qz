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

TEST(MetricAveragePowerTest, CoastingCountsAsZero) {
    // 10 intervals of 60 s at 320 W and 60 s coasting: 160 W, as TrainingPeaks and Garmin show
    // it. The average of the non-zero seconds read 320 W, above NP.
    QList<uint16_t> watts;
    for (int interval = 0; interval < 10; interval++) {
        watts.append(repeatedWatts(320, 60));
        watts.append(repeatedWatts(0, 60));
    }
    QList<SessionLine> session = powerSession(watts);

    EXPECT_DOUBLE_EQ(metric::averagePower(session), 160.0);
    EXPECT_LT(metric::averagePower(session), metric::normalizedPower(session));
}

TEST(MetricAveragePowerTest, FirstIndexSkipsTheSamplesBeforeIt) {
    QList<uint16_t> watts = repeatedWatts(0, 40);
    watts.append(repeatedWatts(200, 300));
    QList<SessionLine> session = powerSession(watts);

    EXPECT_DOUBLE_EQ(metric::averagePower(session, 40), 200.0);
    EXPECT_DOUBLE_EQ(metric::averagePower(session), 60000.0 / 340.0);
    EXPECT_DOUBLE_EQ(metric::averagePower(session, -1), metric::averagePower(session));
}

TEST(MetricAveragePowerTest, NoSamplesGivesZero) {
    EXPECT_DOUBLE_EQ(metric::averagePower(QList<SessionLine>()), 0.0);
    QList<SessionLine> session = powerSession(repeatedWatts(200, 10));
    EXPECT_DOUBLE_EQ(metric::averagePower(session, 10), 0.0);
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

// Records n seconds apart (FIT records of a ride), starting at a fixed time
static QList<SessionLine> recordsEvery(int seconds, int count, uint16_t watt) {
    const QDateTime start(QDate(2026, 3, 1), QTime(8, 0));
    QList<SessionLine> records;
    for (int i = 0; i < count; i++) {
        SessionLine line;
        line.watt = watt;
        line.time = start.addSecs((qint64)i * seconds);
        line.elapsedTime = i * seconds;
        records.append(line);
    }
    return records;
}

TEST(MetricRideTrainingStressTest, OneHourAtFtpIsOneHundred) {
    EXPECT_NEAR(metric::rideTrainingStress(recordsEvery(1, 3600, 250), 250.0), 100.0, 0.01);
}

TEST(MetricRideTrainingStressTest, SmartRecordingIsSpreadToEverySecond) {
    // 720 records 5 s apart: 3596 s of riding, not 720 (which gave TSS 20)
    EXPECT_NEAR(metric::rideTrainingStress(recordsEvery(5, 720, 250), 250.0), 100.0 * 3596.0 / 3600.0, 0.01);
}

TEST(MetricRideTrainingStressTest, APauseIsNotRidingTime) {
    QList<SessionLine> records = recordsEvery(1, 1500, 250);
    QList<SessionLine> after = recordsEvery(1, 1500, 250);
    for (SessionLine &line : after)
        line.time = line.time.addSecs(1500 + 600); // 10 minutes stopped
    records.append(after);
    EXPECT_NEAR(metric::rideTrainingStress(records, 250.0), 100.0 * 3000.0 / 3600.0, 0.01);
}

TEST(MetricRideTrainingStressTest, MissingPowerAndShortRidesCountNothing) {
    EXPECT_DOUBLE_EQ(metric::rideTrainingStress(recordsEvery(1, 3600, 0xFFFF), 250.0), 0.0);
    EXPECT_DOUBLE_EQ(metric::rideTrainingStress(recordsEvery(1, 20, 250), 250.0), 0.0);
    EXPECT_DOUBLE_EQ(metric::rideTrainingStress(recordsEvery(1, 3600, 250), 0.0), 0.0);
}

TEST(MetricRideTrainingStressTest, TheLastRecordOfASecondIsKept) {
    QList<SessionLine> records;
    for (const SessionLine &line : recordsEvery(1, 3600, 250)) {
        SessionLine first = line;
        first.watt = 1000;
        records.append(first); // replaced by the next record of the same second
        records.append(line);
    }
    EXPECT_NEAR(metric::rideTrainingStress(records, 250.0), 100.0, 0.01);
}

TEST(MetricRideTrainingStressTest, ImpossiblePowerCountsAsZero) {
    // a negative sint16 power read as uint16 (0xFFFD) gave this hour a TSS of about 870
    QList<SessionLine> records = recordsEvery(1, 3600, 250);
    records[100].watt = 0xFFFD;
    records[200].watt = 9999; // the watt_max cap
    records[300].watt = 3000;
    EXPECT_NEAR(metric::rideTrainingStress(records, 250.0), 100.0, 0.5);

    // a real sprint still counts
    records = recordsEvery(1, 3600, 250);
    records[100].watt = 2999;
    EXPECT_GT(metric::rideTrainingStress(records, 250.0), 100.5);
}

static QMap<QDate, double> everyDay(const QDate &first, int days, double tss) {
    QMap<QDate, double> daily;
    for (int i = 0; i < days; i++)
        daily[first.addDays(i)] = tss;
    return daily;
}

TEST(MetricTrainingLoadTest, OneRideAndTheRestDaysAfterIt) {
    const QDate d0(2026, 3, 1);
    QMap<QDate, double> daily;
    daily[d0] = 100;

    QVector<TrainingLoadDay> days = metric::trainingLoad(daily, d0);
    ASSERT_EQ(days.count(), 1);
    EXPECT_NEAR(days.last().fitness, 100.0 / 42.0, 0.001);
    EXPECT_NEAR(days.last().fatigue, 100.0 / 7.0, 0.001);

    // rest days still run through the recursion
    days = metric::trainingLoad(daily, d0.addDays(7));
    ASSERT_EQ(days.count(), 8);
    EXPECT_NEAR(days.last().fitness, 2.011, 0.001);
    EXPECT_NEAR(days.last().fatigue, 4.856, 0.001);
    EXPECT_DOUBLE_EQ(days.last().tss, 0.0);
}

TEST(MetricTrainingLoadTest, SteadyTrainingConverges) {
    const QDate d0(2026, 1, 1);
    QVector<TrainingLoadDay> days = metric::trainingLoad(everyDay(d0, 7, 100), d0.addDays(6));
    EXPECT_NEAR(days.last().fitness, 15.52, 0.01);
    EXPECT_NEAR(days.last().fatigue, 66.01, 0.01);

    days = metric::trainingLoad(everyDay(d0, 42, 100), d0.addDays(41));
    EXPECT_NEAR(days.last().fitness, 63.66, 0.01);
    EXPECT_NEAR(days.last().fatigue, 99.85, 0.01);

    days = metric::trainingLoad(everyDay(d0, 400, 100), d0.addDays(399));
    EXPECT_NEAR(days.last().fitness, 100.0, 0.1);
    EXPECT_NEAR(days.last().fatigue, 100.0, 0.1);
}

TEST(MetricTrainingLoadTest, DaysAfterTheLastDayAreLeftOut) {
    const QDate d0(2026, 3, 1);
    QMap<QDate, double> daily;
    daily[d0] = 100;
    daily[d0.addDays(5)] = 100;
    QVector<TrainingLoadDay> days = metric::trainingLoad(daily, d0.addDays(2));
    ASSERT_EQ(days.count(), 3);
    EXPECT_DOUBLE_EQ(days.last().tss, 0.0);

    QMap<QDate, double> future;
    future[d0.addDays(5)] = 100;
    EXPECT_TRUE(metric::trainingLoad(future, d0).isEmpty());
    EXPECT_TRUE(metric::trainingLoad(QMap<QDate, double>(), d0).isEmpty());
}

static TrainingLoadRide ride(const QDate &day, const QTime &start, const QTime &end, double tss, int endDayOffset = 0) {
    TrainingLoadRide r;
    r.start = QDateTime(day, start);
    r.end = QDateTime(day.addDays(endDayOffset), end);
    r.tss = tss;
    return r;
}

TEST(MetricDailyTrainingStressTest, RidesOfADayAddUp) {
    const QDate day(2026, 3, 1);
    QMap<QDate, double> daily = metric::dailyTrainingStress(
        {ride(day, QTime(8, 0), QTime(9, 0), 50), ride(day, QTime(18, 0), QTime(19, 0), 50)});
    EXPECT_DOUBLE_EQ(daily.value(day), 100.0);
}

TEST(MetricDailyTrainingStressTest, TheSameRideRecordedTwiceCountsOnce) {
    // QZ and a watch on the same ride, imported both: the higher TSS is kept
    const QDate day(2026, 3, 1);
    QMap<QDate, double> daily = metric::dailyTrainingStress(
        {ride(day, QTime(8, 0), QTime(9, 0), 60), ride(day, QTime(8, 5), QTime(9, 2), 70)});
    EXPECT_DOUBLE_EQ(daily.value(day), 70.0);

    // a ride that starts when the other ends is another ride
    daily = metric::dailyTrainingStress(
        {ride(day, QTime(8, 0), QTime(9, 0), 60), ride(day, QTime(9, 0), QTime(10, 0), 40)});
    EXPECT_DOUBLE_EQ(daily.value(day), 100.0);
}

TEST(MetricDailyTrainingStressTest, ARideAcrossMidnightCountsOnItsStartDay) {
    const QDate day(2026, 3, 1);
    QMap<QDate, double> daily = metric::dailyTrainingStress({ride(day, QTime(23, 30), QTime(0, 30), 80, 1)});
    EXPECT_DOUBLE_EQ(daily.value(day), 80.0);
    EXPECT_FALSE(daily.contains(day.addDays(1)));
}

TEST(MetricDailyTrainingStressTest, ABrokenEndTimeDoesNotSwallowLaterRides) {
    // a head unit whose clock reset: the ride ends 400 days after it starts
    const QDate day(2026, 3, 1);
    TrainingLoadRide broken = ride(day, QTime(8, 0), QTime(9, 0), 60);
    broken.end = broken.end.addDays(400);
    QMap<QDate, double> daily =
        metric::dailyTrainingStress({broken, ride(day.addDays(1), QTime(8, 0), QTime(9, 0), 50)});
    EXPECT_DOUBLE_EQ(daily.value(day), 60.0);
    EXPECT_DOUBLE_EQ(daily.value(day.addDays(1)), 50.0);
}

TEST(MetricFormZoneTest, LimitsArePercentagesOfFitness) {
    EXPECT_EQ(metric::formZoneLimits(100), QList<int>({20, 5, -10, -30}));
    EXPECT_EQ(metric::formZoneLimits(10), QList<int>({4, 1, -2, -6})); // fitness 20 at least
    EXPECT_EQ(metric::formZoneLimits(30), QList<int>({6, 2, -3, -9}));
}

TEST(MetricFormZoneTest, StatusFromFitnessAndFatigue) {
    EXPECT_EQ(metric::trainingStatus(60, 40, 100, 0), QStringLiteral("fading"));
    EXPECT_EQ(metric::trainingStatus(60, 55, 100, 0), QStringLiteral("fresh"));
    EXPECT_EQ(metric::trainingStatus(60, 57, 100, 0), QStringLiteral("balanced")); // +3 is not above 3
    EXPECT_EQ(metric::trainingStatus(60, 63, 100, 0), QStringLiteral("balanced"));
    EXPECT_EQ(metric::trainingStatus(60, 66, 100, 0), QStringLiteral("balanced"));
    EXPECT_EQ(metric::trainingStatus(60, 67, 100, 0), QStringLiteral("building"));
    EXPECT_EQ(metric::trainingStatus(60, 75, 100, 0), QStringLiteral("building"));
    EXPECT_EQ(metric::trainingStatus(60, 80, 100, 0), QStringLiteral("tired"));
    EXPECT_EQ(metric::trainingStatus(5, 11, 100, 0), QStringLiteral("building"));
    EXPECT_EQ(metric::trainingStatus(5, 12, 100, 0), QStringLiteral("tired"));
}

TEST(MetricFormZoneTest, LearningAndBreakComeFirst) {
    EXPECT_EQ(metric::trainingStatus(60, 40, 41, 0), QStringLiteral("learning"));
    EXPECT_EQ(metric::trainingStatus(60, 40, 42, 0), QStringLiteral("fading"));
    EXPECT_EQ(metric::trainingStatus(60, 40, 10, 14), QStringLiteral("break"));
    EXPECT_EQ(metric::trainingStatus(60, 40, 10, 13), QStringLiteral("learning"));
}
