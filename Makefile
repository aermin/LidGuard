.PHONY: build test package dmg release install clean

build:
	swift build --product LidGuardHelper
	swift build --product lidguard
	swift build --product LidGuardApp

test:
	swift run lidguard-tests

package:
	./scripts/build-app.sh

dmg:
	CONFIGURATION=release ./scripts/build-dmg.sh

release:
	@test -n "$(SIGNING_IDENTITY)" || (echo "SIGNING_IDENTITY is required" >&2; exit 1)
	@test -n "$(NOTARY_PROFILE)" || (echo "NOTARY_PROFILE is required" >&2; exit 1)
	CONFIGURATION=release SIGNING_IDENTITY="$(SIGNING_IDENTITY)" NOTARY_PROFILE="$(NOTARY_PROFILE)" ./scripts/build-dmg.sh

install:
	./scripts/install-local.sh

clean:
	swift package clean
