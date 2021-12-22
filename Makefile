#
# arb_sheet
#

.DEFAULT_GOAL := run
.PHONY: doc test build

# # Git
# gitBranch := $(shell git rev-parse --abbrev-ref HEAD)
# gitCommit := $(shell git rev-parse --short HEAD)

clean:
	@git clean -fdx

log:
	@git log --abbrev-commit

fmt:
	@dart format --fix .

lint:
	@dart analyze

doc:
	@dart pub global run dartdoc

assets:
	@dart run lib/src/packer.dart
	@make -s fmt

run: assets
	@dart run bin/arb_excel.dart -n example/test.xlsx
	@dart run bin/arb_excel.dart -a example/test.xlsx

build: assets
	@mkdir -p build
	@dart compile exe bin/arb_excel.dart -o build/arb_excel
	@dart compile aot-snapshot bin/arb_excel.dart -o build/arb_excel.aot

active: assets
	@dart pub global activate --source path .

publish-test: build
	@dart pub publish --dry-run

publish: publish-test
	@dart pub publish
