.PHONY: setup format format-check lint typecheck test check flutter-build functions-build build

setup:
	flutter pub get
	npm --prefix functions ci

format:
	dart format lib test

format-check:
	dart format --output=none --set-exit-if-changed lib test

lint:
	flutter analyze --no-fatal-infos
	npm --prefix functions run lint

typecheck:
	npm --prefix functions run typecheck

test:
	flutter test

check: format-check lint typecheck test

flutter-build:
	flutter build apk --debug --dart-define=STRIPE_PK=pk_test_placeholder_replace_me

functions-build:
	npm --prefix functions run build

build: flutter-build functions-build
