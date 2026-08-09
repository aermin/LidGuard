.PHONY: build test package install clean

build:
	swift build --product LidGuardHelper
	swift build --product lidguard
	swift build --product LidGuardApp

test:
	swift run lidguard-tests

package:
	./scripts/build-app.sh

install:
	./scripts/install-local.sh

clean:
	swift package clean
