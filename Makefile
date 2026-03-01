.PHONY: run lint format test clean export-web

GODOT := godot
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

export-web:
	@mkdir -p export/web
	$(GODOT) --headless --export-release "Web"
	@echo "Web build exported to export/web/"

clean:
	rm -rf .godot/ export/
