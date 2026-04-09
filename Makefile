.PHONY: run lint format test coverage clean export-web

GODOT := godot
GODOT_COV := $(firstword $(wildcard /Users/cristi/bin/godot) $(GODOT))
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
	$(GODOT_COV) --path . --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/ -gexit \
		--coverage-output /tmp/godot_coverage.json \
		--coverage-format json \
		--coverage-include "res://src/**" \
		--coverage-include "res://scenes/**" \
		--coverage-threshold 30

# Run coverage for a single source file using its matching test file.
# Usage: make coverage-file SRC=src/autoloads/game_manager.gd
# Derives TEST from SRC: src/autoloads/game_manager.gd → tests/test_game_manager.gd
coverage-file:
	$(eval _base := $(notdir $(basename $(SRC))))
	$(eval _test := res://tests/test_$(_base).gd)
	$(eval _out  := /tmp/godot_coverage_$(_base).json)
	$(GODOT_COV) --path . --headless -s addons/gut/gut_cmdln.gd \
		-gtest=$(_test) -gexit \
		--coverage-output $(_out) \
		--coverage-format json \
		--coverage-include "res://$(SRC)" \
		--coverage-threshold 0
	@python3 -c "import json,sys; d=json.load(open('$(_out)')); [print(f'{sum(1 for v in f[\"lines\"].values() if v>0)/len(f[\"lines\"])*100:.1f}%  {n}  ({sum(1 for v in f[\"lines\"].values() if v>0)}/{len(f[\"lines\"])} lines)') for n,f in d.get('files',{}).items() if f.get('lines')]" 2>/dev/null || true

export-web:
	@mkdir -p export/web
	$(GODOT) --headless --export-release "Web"
	@echo "Web build exported to export/web/"

clean:
	rm -rf .godot/ export/
