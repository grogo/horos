.PHONY: Horos clean

# CMake 4.x refuses projects declaring compatibility with CMake < 3.5 (e.g. CharLS); older CMake ignores this
export CMAKE_POLICY_VERSION_MINIMUM := 3.5

# Without a DEVELOPMENT_TEAM in Config.xcconfig, sign ad-hoc for local use
DEVELOPMENT_TEAM := $(strip $(shell sed -n 's/^DEVELOPMENT_TEAM *= *//p' Config.xcconfig))
ifeq ($(DEVELOPMENT_TEAM),)
SIGNING_FLAGS := CODE_SIGN_IDENTITY=- CODE_SIGN_STYLE=Manual
endif

Horos:
	xcodebuild -project "Horos.xcodeproj" -target Horos $(SIGNING_FLAGS)

clean:
	@rm -rf ./build
