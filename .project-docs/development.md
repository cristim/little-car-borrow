# Development

## Prerequisites
- Godot 4.5+
- Python 3 with venv (for gdtoolkit)

## Setup
```bash
python3 -m venv .venv
source .venv/bin/activate
pip install gdtoolkit
```

## Commands (via Makefile)
| Command | What it does |
|---------|-------------|
| `make run` | Launch the game |
| `make run-editor` | Open in Godot editor |
| `make lint` | Run gdlint on all GDScript files |
| `make format` | Auto-format all GDScript files |
| `make format-check` | Check formatting without changing files |
| `make test` | Run GUT unit tests headless |

## Project Structure
- `src/` - Core scripts (autoloads, state machine, utils)
- `scenes/` - Godot scenes (.tscn) and their scripts
- `tests/` - GUT unit tests
- `assets/` - Art, audio, textures (Git LFS tracked)
- `addons/` - GEVP vehicle physics, GUT testing
