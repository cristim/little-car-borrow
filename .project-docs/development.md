# Development

## Prerequisites
- Godot 4.5.1 (binary at `/opt/homebrew/bin/godot`)
- Python 3 with venv (for gdtoolkit)

## Setup
```bash
python3 -m venv .venv
source .venv/bin/activate
pip install gdtoolkit
```

gdtoolkit tools are installed in `.venv/` — always use `.venv/bin/gdlint` and
`.venv/bin/gdformat` (not any globally installed versions).

## Commands (via Makefile)
| Command | What it does |
|---------|-------------|
| `make run` | Launch the game (background) |
| `make run-editor` | Open in Godot editor (background) |
| `make lint` | Run gdlint on all GDScript files in `src/`, `scenes/`, `tests/` |
| `make format` | Auto-format all GDScript files |
| `make format-check` | Check formatting without changing files |
| `make test` | Run GUT unit tests headless |
| `make coverage` | Run GUT tests with coverage (≥80% threshold) |
| `make export-web` | Export a Web build to `export/web/` |
| `make clean` | Remove `.godot/` and `export/` directories |

The Makefile uses `godot` from `$PATH`. On macOS with Homebrew, the binary is at
`/opt/homebrew/bin/godot`.

## Testing

Run the full test suite headlessly:
```bash
godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/ -gexit
```

Run a single test file:
```bash
godot --headless --path . -s addons/gut/gut_cmdln.gd -gtest=res://tests/test_X.gd -gexit
```

Replace `test_X.gd` with the actual file name (e.g. `test_player.gd`).

## Git Hooks

Pre-commit hooks are defined in `.pre-commit-config.yaml` and run automatically
on every `git commit`. Three hooks are configured:

| Hook | What it does |
|------|-------------|
| `gdlint` | Runs `gdlint` on all `.gd` files in `src/`, `scenes/`, `tests/` — commit is blocked on any lint error |
| `gdformat-check` | Runs `gdformat --check` on all `.gd` files — commit is blocked if any file is not formatted |
| `coverage` | Runs `make coverage`, which executes the full GUT test suite and enforces ≥80% code coverage |

All hooks use `always_run: true`, so they fire even when no `.gd` files are
staged. Install the hooks once after cloning:
```bash
source .venv/bin/activate
pre-commit install
```

## Project Structure
- `src/` - Core scripts (autoloads, state machine, utils)
- `scenes/` - Godot scenes (.tscn) and their scripts
- `tests/` - GUT unit tests
- `assets/` - Art, audio, textures (Git LFS tracked)
- `addons/` - GEVP vehicle physics, GUT testing
