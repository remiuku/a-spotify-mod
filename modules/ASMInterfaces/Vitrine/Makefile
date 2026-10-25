TARGET := iphone:clang:latest:16.1
ARCHS := arm64
FINALPACKAGE := 1
KEEP_LOGOS_INTERMEDIATES := 1
include $(THEOS)/makefiles/common.mk
TWEAK_NAME := ASMVitrineUI
ASMVitrineUI_FILES := $(shell find Sources -name '*.m' -o -name '*.x' -o -name '*.swift' | sort)
ASMVitrineUI_CFLAGS := -fobjc-arc -ISources -DSG_DRIVER=0 -DASMVitrine_DRIVER=0 -DASMVitrine_VERSION=\"0.0.0-asm\"
ASMVitrineUI_FRAMEWORKS := UIKit QuartzCore UniformTypeIdentifiers MediaPlayer CoreImage AudioToolbox AVFoundation CoreHaptics Accelerate CoreMotion CoreML CoreText OSLog NaturalLanguage Security
ASMVitrineUI_LIBRARIES := z
ASMVitrineUI_LOGOS_DEFAULT_GENERATOR := internal
ASMVitrineUI_OBJ_FILES := vendor/audio/build/ios/libsgaudio.a
Sources/Shared/AudioEffects/ASMVitrineDSPCrossfeed.m_CFLAGS := -isystem vendor/audio/libbs2b
Sources/Shared/AudioEffects/ASMVitrineDSPLiveprog.m_CFLAGS := -isystem vendor/audio/wdl/eel2

include $(THEOS_MAKE_PATH)/tweak.mk
before-all::
	@$(MAKE) --no-print-directory -C vendor/audio PLATFORM=ios $(ASM_INTERFACE_AUDIO_BUILD_ARGS)
	@sh scripts/check-layers.sh Sources
