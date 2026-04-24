INSTALL_TARGET_PROCESSES = ShadowTrackerExtra
ARCHS = arm64 arm64e

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = MapReplacer

# 使用纯 ObjC 文件 (不需要 Logos 预处理器)
MapReplacer_FILES = Tweak.m MapManager.m UIOverlay.m
MapReplacer_CFLAGS = -fobjc-arc -Wno-deprecated-declarations
MapReplacer_FRAMEWORKS = UIKit Foundation
MapReplacer_PRIVATE_FRAMEWORKS =
MapReplacer_LIBRARIES = substrate

include $(THEOS_MAKE_PATH)/tweak.mk

after-install::
	install.exec "killall -9 ShadowTrackerExtra" || true
