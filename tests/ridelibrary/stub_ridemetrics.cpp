// The live ride's numbers are not part of these tests: a RideMetrics that is never connected.
#include "ridemetrics.h"

RideMetrics::RideMetrics(bluetooth *bl, QObject *parent) : QObject(parent), m_bluetooth(bl) {}
void RideMetrics::refresh() {}
void RideMetrics::reset() {}
int RideMetrics::powerZone(double) const { return 1; }
