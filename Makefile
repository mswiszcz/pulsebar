APP := build/Pulsebar.app
INSTALL_DIR := $(HOME)/Applications
BUILD_NUMBER ?= 1
SWIFT_BUILD := swift build -c release $(ARCHS:%=--arch %)
TESTING_FRAMEWORKS := /Library/Developer/CommandLineTools/Library/Developer/Frameworks
TEST_FLAGS := $(if $(wildcard $(TESTING_FRAMEWORKS)/Testing.framework),\
	-Xswiftc -F$(TESTING_FRAMEWORKS) -Xlinker -rpath -Xlinker $(TESTING_FRAMEWORKS))

.PHONY: build run install test lint

build:
	$(SWIFT_BUILD)
	mkdir -p $(APP)/Contents/MacOS
	cp "$$($(SWIFT_BUILD) --show-bin-path)/Pulsebar" $(APP)/Contents/MacOS/Pulsebar
	cp Support/Info.plist $(APP)/Contents/Info.plist
	$(if $(VERSION),/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $(VERSION)" -c "Set :CFBundleVersion $(BUILD_NUMBER)" $(APP)/Contents/Info.plist)
	codesign --sign - --force $(APP)

run: build
	open $(APP)

install: build
	mkdir -p $(INSTALL_DIR)
	ditto $(APP) $(INSTALL_DIR)/Pulsebar.app

test:
	swift test $(TEST_FLAGS)

lint:
	swift format lint --strict -r Package.swift Sources Tests

