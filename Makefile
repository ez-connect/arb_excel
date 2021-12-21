#
# arb_sheet
#

.DEFAULT_GOAL := run
.PHONY: doc test build

# Service
name := arb_sheet
version := 0.0.1

# Git
gitBranch := $(shell git rev-parse --abbrev-ref HEAD)
gitCommit := $(shell git rev-parse --short HEAD)

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

run:
	@dart run bin/arb_excel.dart -n example/test.xlsx
	@dart run bin/arb_excel.dart -a example/test.xlsx

build:
	@dart compile aot-snapshot bin/arb_excel.dart

active:
	@dart pub global activate --source path .

publish-test:
	@dart pub publish --dry-run

publish:
	@dart pub publish
