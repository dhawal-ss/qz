# The ride library (src/ridelibrary.cpp) against its real code, with QZ's FIT reader replaced by a
# stub that reads small JSON rides (stub_qfit.cpp). Desktop Qt 5 is enough:
#   qmake ridelibrary_test.pro && make && ./ridelibrary_test
QT += core sql positioning bluetooth testlib
QT -= gui
CONFIG += console c++17 testcase
CONFIG -= app_bundle
TARGET = ridelibrary_test

SRC = $$PWD/../../src
INCLUDEPATH += $$SRC $$SRC/fit-sdk $$SRC/devices
DEFINES += BIKEMODO_TESTS

SOURCES += tst_ridelibrary.cpp stub_qfit.cpp stub_ridemetrics.cpp \
    $$SRC/ridelibrary.cpp $$SRC/ridestats.cpp $$SRC/sessionline.cpp $$SRC/qzsettings.cpp
HEADERS += $$SRC/ridelibrary.h $$SRC/ridemetrics.h
