#include <gtest/gtest.h>

#include <QDateTime>

#include "Tools/testsettings.h"
#include "devices/bike.h"

// A BLE dropout stops the driver's update_metrics() calls (they run only while the link is up). On
// reconnect the whole gap arrives as one delta, with the power from before the dropout still in m_watt.

namespace {
class GapTestBike : public bike {
  public:
    // one update_metrics() call, secondsSinceLastCall after the previous one, reporting watts
    void tickAfter(double secondsSinceLastCall, double watts) {
        m_watt.setValue(watts, false);
        _lastTimeUpdate = QDateTime::currentDateTime().addMSecs(-qRound64(secondsSinceLastCall * 1000.0));
        _firstUpdate = false;
        update_metrics(false, watts);
    }
    double elapsedSeconds() { return elapsed.value(); }
};

class UpdateMetricsGapTest : public ::testing::Test {
  protected:
    TestSettings settings{QStringLiteral("QZTests"), QStringLiteral("UpdateMetricsGap")};
    void SetUp() override {
        settings.activate();
        settings.qsettings.clear();
    }
};
} // namespace

TEST_F(UpdateMetricsGapTest, RegularCallsCountAllTheirEnergy) {
    GapTestBike b;
    for (int i = 0; i < 10; i++)
        b.tickAfter(1.0, 200.0);
    EXPECT_NEAR(b.jouls().value(), 2000.0, 20.0);
    // a slow but live device (3 s between calls) loses nothing
    b.tickAfter(3.0, 200.0);
    EXPECT_NEAR(b.jouls().value(), 2600.0, 26.0);
}

TEST_F(UpdateMetricsGapTest, ReconnectCountsAtMostFiveSecondsOfStalePower) {
    GapTestBike b;
    b.tickAfter(1.0, 300.0);
    b.tickAfter(30.0, 300.0);
    // 1 s + at most 5 s of the stale 300 W, not 9.3 kJ
    EXPECT_LE(b.jouls().value(), 300.0 * 6.0 + 10.0);
    // the gap is still ride time
    EXPECT_NEAR(b.elapsedSeconds(), 31.0, 0.1);
}

TEST_F(UpdateMetricsGapTest, WallClockStepBackIsNotNegativeTimeOrEnergy) {
    GapTestBike b;
    b.tickAfter(1.0, 200.0);
    b.tickAfter(-600.0, 200.0);
    EXPECT_NEAR(b.jouls().value(), 200.0, 2.0);
    EXPECT_NEAR(b.elapsedSeconds(), 1.0, 0.1);
}
