.PHONY: app run debug clean test lint lint-fix

app:            ## Build Halation.app (release)
	@Scripts/make_app.sh release

debug:          ## Build Halation.app (debug)
	@Scripts/make_app.sh debug

run: app        ## Build and launch
	@open dist/Halation.app

clean:
	@rm -rf .build dist

test:
	@swift build 2>&1 | tail -5

lint:           ## Run SwiftLint with the project config
	@swiftlint lint --config .swiftlint.yml --quiet || true
	@echo "violations: $$(swiftlint lint --config .swiftlint.yml --quiet --reporter csv 2>/dev/null | tail -n +2 | wc -l | tr -d ' ')"

lint-fix:       ## Apply SwiftLint's automatic corrections
	@swiftlint --fix --config .swiftlint.yml --quiet
