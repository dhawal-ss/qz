#include "bikemodobridge.h"
#include "ridelibrary.h"
#include "ridemetrics.h"

#include <QCoreApplication>
#include <QQmlApplicationEngine>
#include <QQmlContext>

#ifdef Q_OS_ANDROID
#include "keepawakehelper.h"
#include <QAndroidJniObject>
#include <QtAndroid>
#include <jni.h>
#endif

BikemodoBridge::BikemodoBridge(bluetooth *bl, QQmlApplicationEngine *engine, const QString &appDir, QObject *parent)
    : QObject(parent) {
    // the live numbers of the ride and the library of every ride, for src/ui2
    RideMetrics *metrics = new RideMetrics(bl, this);
    engine->rootContext()->setContextProperty(QStringLiteral("rideMetrics"), metrics);
    m_library = new RideLibrary(appDir, this);
    m_library->setMetrics(metrics);
    engine->rootContext()->setContextProperty(QStringLiteral("rideLibrary"), m_library);
    engine->rootContext()->setContextProperty(QStringLiteral("bikemodoBridge"), this);
}

void BikemodoBridge::fitSaved(const QString &filename) { m_library->importFile(filename); }

void BikemodoBridge::fitFolderChanged() { m_library->rescan(); }

// The Android calls of the interface (moved from homeform, the words keep homeform's translations)
void BikemodoBridge::showRideNotification(const QString &title, const QString &text, double startedAtMs, bool paused) {
#ifdef Q_OS_ANDROID
    QAndroidJniObject jTitle = QAndroidJniObject::fromString(title);
    QAndroidJniObject jText = QAndroidJniObject::fromString(text);
    QAndroidJniObject jToggle = QAndroidJniObject::fromString(paused ? QCoreApplication::translate("homeform", "Resume") : QCoreApplication::translate("homeform", "Pause"));
    QAndroidJniObject jLap = QAndroidJniObject::fromString(QCoreApplication::translate("homeform", "Lap"));
    QAndroidJniObject::callStaticMethod<void>(
        "org/cagnulen/qdomyoszwift/NotificationClient", "showRide",
        "(Landroid/content/Context;Ljava/lang/String;Ljava/lang/String;JZLjava/lang/String;Ljava/lang/String;)V",
        QtAndroid::androidContext().object(), jTitle.object<jstring>(), jText.object<jstring>(), (jlong)startedAtMs,
        (jboolean)paused, jToggle.object<jstring>(), jLap.object<jstring>());
#else
    Q_UNUSED(title);
    Q_UNUSED(text);
    Q_UNUSED(startedAtMs);
    Q_UNUSED(paused);
#endif
}

void BikemodoBridge::hideRideNotification() {
#ifdef Q_OS_ANDROID
    //: Android notification: title shown while QZ works in the background.
    QAndroidJniObject ready = QAndroidJniObject::fromString(QCoreApplication::translate("homeform", "Bikemodo is ready"));
    QAndroidJniObject::callStaticMethod<void>("org/cagnulen/qdomyoszwift/NotificationClient", "hideRide",
                                              "(Landroid/content/Context;Ljava/lang/String;)V",
                                              QtAndroid::androidContext().object(), ready.object<jstring>());
#endif
}

int BikemodoBridge::takeRideNotificationAction() {
#ifdef Q_OS_ANDROID
    return QAndroidJniObject::callStaticMethod<jint>("org/cagnulen/qdomyoszwift/NotificationClient", "takeAction",
                                                     "()I");
#else
    return 0;
#endif
}

void BikemodoBridge::setKeepScreenOn(bool on) {
#ifdef Q_OS_ANDROID
    KeepAwakeHelper::keepScreenOn(on);
#else
    Q_UNUSED(on);
#endif
}

void BikemodoBridge::cue(int kind) {
#ifdef Q_OS_ANDROID
    QAndroidJniObject::callStaticMethod<void>("org/cagnulen/qdomyoszwift/BikemodoCues", "cue",
                                              "(Landroid/content/Context;I)V", QtAndroid::androidContext().object(),
                                              (jint)kind);
#else
    Q_UNUSED(kind);
#endif
}

bool BikemodoBridge::healthAvailable() {
#ifdef Q_OS_ANDROID
    return QAndroidJniObject::callStaticMethod<jboolean>("org/cagnulen/qdomyoszwift/BikemodoHealth", "available",
                                                         "(Landroid/content/Context;)Z",
                                                         QtAndroid::androidContext().object());
#else
    return false;
#endif
}

void BikemodoBridge::healthRequestRead() {
#ifdef Q_OS_ANDROID
    QAndroidJniObject::callStaticMethod<void>("org/cagnulen/qdomyoszwift/BikemodoHealth", "requestRead",
                                              "(Landroid/content/Context;)V", QtAndroid::androidActivity().object());
#endif
}

void BikemodoBridge::healthRefresh() {
#ifdef Q_OS_ANDROID
    QAndroidJniObject::callStaticMethod<void>("org/cagnulen/qdomyoszwift/BikemodoHealth", "refresh",
                                              "(Landroid/content/Context;)V", QtAndroid::androidContext().object());
#endif
}

QString BikemodoBridge::healthTake() {
#ifdef Q_OS_ANDROID
    return QAndroidJniObject::callStaticObjectMethod<jstring>("org/cagnulen/qdomyoszwift/BikemodoHealth", "take").toString();
#else
    return QString();
#endif
}

void BikemodoBridge::updateWidget(const QString &value, const QString &detail, const QString &streak, const QString &weekKey,
                            const QString &recapTitle, const QString &recapText) {
#ifdef Q_OS_ANDROID
    QAndroidJniObject jValue = QAndroidJniObject::fromString(value);
    QAndroidJniObject jDetail = QAndroidJniObject::fromString(detail);
    QAndroidJniObject jStreak = QAndroidJniObject::fromString(streak);
    QAndroidJniObject jWeek = QAndroidJniObject::fromString(weekKey);
    QAndroidJniObject jTitle = QAndroidJniObject::fromString(recapTitle);
    QAndroidJniObject jText = QAndroidJniObject::fromString(recapText);
    QAndroidJniObject::callStaticMethod<void>(
        "org/cagnulen/qdomyoszwift/BikemodoWidget", "update",
        "(Landroid/content/Context;Ljava/lang/String;Ljava/lang/String;Ljava/lang/String;Ljava/lang/String;Ljava/lang/String;"
        "Ljava/lang/String;)V",
        QtAndroid::androidContext().object(), jValue.object<jstring>(), jDetail.object<jstring>(), jStreak.object<jstring>(),
        jWeek.object<jstring>(), jTitle.object<jstring>(), jText.object<jstring>());
#else
    Q_UNUSED(value);
    Q_UNUSED(detail);
    Q_UNUSED(streak);
    Q_UNUSED(weekKey);
    Q_UNUSED(recapTitle);
    Q_UNUSED(recapText);
#endif
}

void BikemodoBridge::updateWidgetBody(const QString &words) {
#ifdef Q_OS_ANDROID
    QAndroidJniObject jWords = QAndroidJniObject::fromString(words);
    QAndroidJniObject::callStaticMethod<void>("org/cagnulen/qdomyoszwift/BikemodoWidget", "updateBody",
                                              "(Landroid/content/Context;Ljava/lang/String;)V",
                                              QtAndroid::androidContext().object(), jWords.object<jstring>());
#else
    Q_UNUSED(words);
#endif
}

double BikemodoBridge::systemFontScale() {
#ifdef Q_OS_ANDROID
    return QAndroidJniObject::callStaticMethod<jfloat>("org/cagnulen/qdomyoszwift/BikemodoSystem", "fontScale",
                                                       "(Landroid/content/Context;)F", QtAndroid::androidContext().object());
#else
    return 1.0;
#endif
}

bool BikemodoBridge::systemAnimationsOff() {
#ifdef Q_OS_ANDROID
    return QAndroidJniObject::callStaticMethod<jboolean>("org/cagnulen/qdomyoszwift/BikemodoSystem", "animationsOff",
                                                         "(Landroid/content/Context;)Z", QtAndroid::androidContext().object());
#else
    return false;
#endif
}

bool BikemodoBridge::systemNightMode() {
#ifdef Q_OS_ANDROID
    return QAndroidJniObject::callStaticMethod<jboolean>("org/cagnulen/qdomyoszwift/BikemodoSystem", "nightMode",
                                                         "(Landroid/content/Context;)Z", QtAndroid::androidContext().object());
#else
    return true;
#endif
}

void BikemodoBridge::updateCheck() {
#ifdef Q_OS_ANDROID
    QAndroidJniObject::callStaticMethod<void>("org/cagnulen/qdomyoszwift/BikemodoUpdate", "check",
                                              "(Landroid/content/Context;)V", QtAndroid::androidContext().object());
#endif
}

void BikemodoBridge::updateStart() {
#ifdef Q_OS_ANDROID
    QAndroidJniObject::callStaticMethod<void>("org/cagnulen/qdomyoszwift/BikemodoUpdate", "start",
                                              "(Landroid/content/Context;)V", QtAndroid::androidActivity().object());
#endif
}

void BikemodoBridge::updateFinish() {
#ifdef Q_OS_ANDROID
    QAndroidJniObject::callStaticMethod<void>("org/cagnulen/qdomyoszwift/BikemodoUpdate", "complete",
                                              "(Landroid/content/Context;)V", QtAndroid::androidContext().object());
#endif
}

QString BikemodoBridge::updateState() {
#ifdef Q_OS_ANDROID
    return QAndroidJniObject::callStaticObjectMethod<jstring>("org/cagnulen/qdomyoszwift/BikemodoUpdate", "state").toString();
#else
    return QString();
#endif
}
