#ifndef MONOTONICCLOCK_H
#define MONOTONICCLOCK_H

#include <QElapsedTimer>
#include <QtGlobal>
#if defined(Q_OS_LINUX) || defined(Q_OS_ANDROID) || defined(Q_OS_DARWIN)
#include <time.h>
#endif

// Milliseconds from an arbitrary start, on a clock that never jumps (an NTP sync or a manual time
// change does not move it) and that keeps counting while the phone sleeps. QElapsedTimer stops in
// suspend on Android (CLOCK_MONOTONIC) and iOS (mach_absolute_time): a ride on a locked phone then
// looked like on-time ticks and lost the seconds the phone slept.
inline qint64 monotonicMsecsIncludingSleep() {
#if defined(Q_OS_LINUX) || defined(Q_OS_ANDROID)
    struct timespec ts;
    if (clock_gettime(CLOCK_BOOTTIME, &ts) == 0)
        return qint64(ts.tv_sec) * 1000 + ts.tv_nsec / 1000000;
#elif defined(Q_OS_DARWIN)
    // on Darwin CLOCK_MONOTONIC counts the time asleep (CLOCK_UPTIME_RAW is the one that does not)
    struct timespec ts;
    if (clock_gettime(CLOCK_MONOTONIC, &ts) == 0)
        return qint64(ts.tv_sec) * 1000 + ts.tv_nsec / 1000000;
#endif
    static const QElapsedTimer timer = [] {
        QElapsedTimer t;
        t.start();
        return t;
    }();
    return timer.elapsed();
}

#endif // MONOTONICCLOCK_H
