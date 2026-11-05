.DEFAULT_GOAL := build
.PHONY: build run dev test clean

build:
	@bash Scripts/build-app.sh

run: build
	@bash Scripts/launch.sh

dev:
	@bash Scripts/build-app.sh --local
	@bash Scripts/launch.sh dist/local/KeyHop.app

test:
	swift test

clean:
	swift package clean
	rm -rf dist/KeyHop.app dist/local/KeyHop.app
