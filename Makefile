.PHONY: run lint format test coverage clean export-web

GODOT := $(or $(wildcard $(HOME)/bin/godot),godot)
VENV := .venv/bin

run:
	$(GODOT) --path . 2>/dev/null &

run-editor:
	$(GODOT) --path . --editor 2>/dev/null &

lint:
	@find src/ scenes/ tests/ -name "*.gd" 2>/dev/null | xargs -r $(VENV)/gdlint

format:
	@find src/ scenes/ tests/ -name "*.gd" 2>/dev/null | xargs -r $(VENV)/gdformat

format-check:
	@find src/ scenes/ tests/ -name "*.gd" 2>/dev/null | xargs -r $(VENV)/gdformat --check

test:
	$(GODOT) --path . --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/ -gexit

coverage:
	$(GODOT) --path . --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/ -gexit \
		--coverage-output /tmp/godot_coverage.json \
		--coverage-format json \
		--coverage-include "res://src/*" \
		--coverage-threshold 80

export-web:
	@mkdir -p export/web
	$(GODOT) --headless --export-release "Web"
	@echo "Web build exported to export/web/"

clean:
	rm -rf .godot/ export/
