.PHONY: app run debug clean test

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
