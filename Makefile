TARGET = appletv:clang:latest:14.0
INSTALL_TARGET_PROCESSES = Stasis

# Fun fact: I really did not enjoy needing to compile the app using Xcode to get an Assets.car with an app icon and accent color. Miserable.
# How 2 compile for TrollStore
#PACKAGE_FORMAT = ipa

include $(THEOS)/makefiles/common.mk

APPLICATION_NAME = Stasis

Stasis_FILES = ContentView.swift StasisApp.swift
CODESIGN_ENTITLEMENT = entitlements.xml
Stasis_CODESIGN_FLAGS = -S$(CODESIGN_ENTITLEMENT)

include $(THEOS_MAKE_PATH)/application.mk
