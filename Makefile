APP := build/Pulsebar.app
INSTALL_DIR := $(HOME)/Applications
TESTING_FRAMEWORKS := /Library/Developer/CommandLineTools/Library/Developer/Frameworks
TEST_FLAGS := $(if $(wildcard $(TESTING_FRAMEWORKS)/Testing.framework),\
	-Xswiftc -F$(TESTING_FRAMEWORKS) -Xlinker -rpath -Xlinker $(TESTING_FRAMEWORKS))

.PHONY: build run install test lint

build:
	swift build -c release
	mkdir -p $(APP)/Contents/MacOS
	cp "$$(swift build -c release --show-bin-path)/Pulsebar" $(APP)/Contents/MacOS/Pulsebar
	cp Support/Info.plist $(APP)/Contents/Info.plist
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

