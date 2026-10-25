TARGET := iphone:clang:latest:16.1
ARCHS := arm64
FINALPACKAGE := 1
KEEP_LOGOS_INTERMEDIATES := 1
include $(THEOS)/makefiles/common.mk
TWEAK_NAME := ASMSpotiUI
ASMSpotiUI_FILES := $(shell find Sources -name '*.m' -o -name '*.x' -o -name '*.swift' | sort)
ASMSpotiUI_CFLAGS := -fobjc-arc -ISources -DSG_DRIVER=0 -DASMSpoti_DRIVER=0 -DASMSpoti_VERSION=\"0.0.0-asm\"
ASMSpotiUI_FRAMEWORKS := UIKit QuartzCore UniformTypeIdentifiers MediaPlayer CoreImage AudioToolbox AVFoundation CoreHaptics Accelerate CoreMotion CoreML CoreText OSLog NaturalLanguage Security
ASMSpotiUI_LIBRARIES := z
ASMSpotiUI_LOGOS_DEFAULT_GENERATOR := internal
ASMSpotiUI_OBJ_FILES := ../../../vendor/libjamesdsp/build/ios/libjamesdsp.a
Sources/Shared/JamesDSP/ASMSpotiDSPEngine.m_CFLAGS := -isystem ../../../vendor/libjamesdsp/subtree/Main/libjamesdsp/jni/jamesdsp/jdsp -isystem ../../../vendor/libjamesdsp

include $(THEOS_MAKE_PATH)/tweak.mk
before-all::
	@sh scripts/check-layers.sh Sources
