.PHONY: app dmg run debug clean test lint lint-fix strings check hooks

app:            ## Build Halation.app (release)
	@Scripts/make_app.sh release

dmg: app        ## Build a distributable disk image
	@Scripts/make_dmg.sh

debug:          ## Build Halation.app (debug)
	@Scripts/make_app.sh debug

run: app        ## Build and launch
	@open dist/Halation.app

clean:
	@rm -rf .build dist

test:
	@swift build 2>&1 | tail -5

strings:        ## Regenerate the .strings files and the catalogue
	@python3 Scripts/build_strings.py

check:          ## Verify translations.py, the .strings files and the code agree
	@python3 Scripts/check_translations.py

hooks:          ## Install the pre-commit hook that runs `make check`
	@git config core.hooksPath Scripts/hooks
	@echo "core.hooksPath -> Scripts/hooks"

lint:           ## Run SwiftLint with the project config
	@swiftlint lint --config .swiftlint.yml --quiet || true
	@echo "violations: $$(swiftlint lint --config .swiftlint.yml --quiet --reporter csv 2>/dev/null | tail -n +2 | wc -l | tr -d ' ')"

lint-fix:       ## Apply SwiftLint's automatic corrections
	@swiftlint --fix --config .swiftlint.yml --quiet
