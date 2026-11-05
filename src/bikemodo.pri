# Bikemodo on top of QZ: built only with qmake CONFIG+=bikemodo (tools/bikemodo_android_build.sh,
# tools/bikemodo_android_release.sh and .github/workflows/android.yml pass it). Without it the
# project is QZ as upstream builds it: its own main.qml, no ride library, no Bikemodo resources.
# BIKEMODO tells the code (main.cpp opens ui2/main2.qml, homeform makes the BikemodoBridge).

DEFINES += BIKEMODO

SOURCES += \
bikemodobridge.cpp \
ridemetrics.cpp \
ridelibrary.cpp \
ridestats.cpp

HEADERS += \
bikemodobridge.h \
ridemetrics.h \
ridelibrary.h \
ridestats.h

# the interface (src/ui2), at the same qrc:/ui2/ paths as before
RESOURCES += ui2.qrc

# Bikemodo's Android helpers; gradle builds every file of android/src, these are listed for the IDE
DISTFILES += \
    $$PWD/android/src/BikemodoCues.java \
    $$PWD/android/src/BikemodoSystem.java \
    $$PWD/android/src/BikemodoWidget.java \
    $$PWD/android/src/BikemodoRecap.java \
    $$PWD/android/src/BikemodoHealth.kt
