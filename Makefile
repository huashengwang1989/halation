.PHONY: app run debug clean test lint lint-fix

app:            ## Build VideoGen.app (release)
	@Scripts/make_app.sh release

debug:          ## Build VideoGen.app (debug)
	@Scripts/make_app.sh debug

run: app        ## Build and launch
	@open dist/VideoGen.app

clean:
	@rm -rf .build dist

test:
	@swift build 2>&1 | tail -5

lint:           ## Run SwiftLint with the project config
	@swiftlint lint --config .swiftlint.yml --quiet || true
	@echo "violations: $$(swiftlint lint --config .swiftlint.yml --quiet --reporter csv 2>/dev/null | tail -n +2 | wc -l | tr -d ' ')"

lint-fix:       ## Apply SwiftLint's automatic corrections
	@swiftlint --fix --config .swiftlint.yml --quiet
