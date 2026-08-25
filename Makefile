.PHONY: setup local-start local-stop db-reset db-test edge-format-check edge-lint edge-typecheck edge-test edge-check format format-check lint typecheck test check flutter-build functions-build build

setup:
	npm ci
	flutter pub get
	npm --prefix functions ci

local-start:
	npx supabase start

local-stop:
	npx supabase stop

db-reset:
	npx supabase db reset

db-test:
	npx supabase test db

edge-format-check:
	deno fmt --check supabase/functions

edge-lint:
	deno lint --config supabase/functions/deno.json supabase/functions

edge-typecheck:
	deno check --config supabase/functions/deno.json supabase/functions/*/index.ts

edge-test:
	deno test --config supabase/functions/deno.json supabase/functions/tests

edge-check: edge-format-check edge-lint edge-typecheck edge-test

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

check: format-check lint typecheck test edge-check

flutter-build:
	flutter build apk --debug --dart-define=STRIPE_PK=pk_test_placeholder_replace_me

functions-build:
	npm --prefix functions run build

build: flutter-build functions-build
