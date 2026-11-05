#ifndef BIKEMODOBRIDGE_H
#define BIKEMODOBRIDGE_H

#include <QObject>
#include <QString>

class bluetooth;
class QQmlApplicationEngine;
class RideLibrary;

// Bikemodo's one seam into QZ (bikemodo.pri, CONFIG+=bikemodo): homeform makes it, and it starts
// the ride library and the live numbers of src/ui2, puts them in QML (rideLibrary, rideMetrics, and
// itself as bikemodoBridge), and listens to homeform for the rides it saves. It also holds the
// Android calls of the interface that need nothing of the ride engine; what does (the bike, the
// ride, the speech) stays in homeform, which ui2 reaches as core.
class BikemodoBridge : public QObject {
    Q_OBJECT
  public:
    BikemodoBridge(bluetooth *bl, QQmlApplicationEngine *engine, const QString &appDir, QObject *parent);

    // a ride saved as a .fit file goes into the library
    void fitSaved(const QString &filename);
    // rides brought into the fit folder: the library reads it again
    void fitFolderChanged();

    // The ride in the Android notification: the clock counts from startedAtMs while it moves, the
    // text holds the numbers, and Pause (or Resume) and Lap; hidden when the ride is over
    Q_INVOKABLE void showRideNotification(const QString &title, const QString &text, double startedAtMs, bool paused);
    Q_INVOKABLE void hideRideNotification();
    // a tap on the notification's buttons: 0 none, 1 pause or resume, 2 lap; each one is taken once
    Q_INVOKABLE int takeRideNotificationAction();
    // the screen stays on while this is on (Bikemodo: on the ride screen only)
    Q_INVOKABLE void setKeepScreenOn(bool on);
    // a beep and a buzz of the ride (0 a tick, 1 a count, 2 a change), quiet on silent
    Q_INVOKABLE void cue(int kind);
    // Readiness from Health Connect (BikemodoHealth.kt): whether it is there, the dialog to allow
    // reading HRV, resting heart rate and sleep, a read of the last 35 days in the background, and
    // its answer once (JSON, "" while it is not there)
    Q_INVOKABLE bool healthAvailable();
    Q_INVOKABLE void healthRequestRead();
    Q_INVOKABLE void healthRefresh();
    Q_INVOKABLE QString healthTake();
    // the home screen widget's numbers (the week, the goal, the streak), and the week's recap for
    // Monday's notification, kept with the Monday of its week (yyyy-MM-dd)
    Q_INVOKABLE void updateWidget(const QString &value, const QString &detail, const QString &streak,
                                  const QString &weekKey, const QString &recapTitle, const QString &recapText);
    // the widget's line about the body today (Health Connect readiness), "" for none
    Q_INVOKABLE void updateWidgetBody(const QString &words);
    // the phone's font size (1 is the default) and whether its animations are off, for Theme
    Q_INVOKABLE double systemFontScale();
    Q_INVOKABLE bool systemAnimationsOff();
    // the phone's dark theme, for Bikemodo's Look: Phone (main2.qml)
    Q_INVOKABLE bool systemNightMode();

  private:
    RideLibrary *m_library = nullptr;
};

#endif // BIKEMODOBRIDGE_H
