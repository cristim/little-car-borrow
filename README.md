# Little Car Borrow

A tongue-in-cheek open-world driving game built with Godot 4.5. Walk around, hop into cars, and cruise through a procedurally generated greybox city.

**[Play in browser](https://cristim.github.io/little-car-borrow/)**

## Controls

### On Foot

| Action | Keyboard | Gamepad |
|--------|----------|---------|
| Move | WASD | Left stick |
| Sprint | Shift | Left trigger |
| Enter vehicle | F (near vehicle) | Y |

### Driving

| Action | Keyboard | Gamepad |
|--------|----------|---------|
| Accelerate | W | Left stick up |
| Brake / Reverse | S | Left stick down |
| Steer | A / D | Left stick left/right |
| Handbrake | Space | A |
| Exit vehicle | F | Y |
| Horn | H | L3 |
| Pause | Esc | Start |

## Development

### Prerequisites

- [Godot 4.5.1](https://godotengine.org/download/) (standard build)
- Python 3 with venv (for gdtoolkit)

### Setup

```bash
git clone <repo-url>
cd little-car-borrow
python3 -m venv .venv
.venv/bin/pip install gdtoolkit
```

### Common tasks

```bash
make run            # Launch the game
make run-editor     # Open in Godot editor
make lint           # Run gdlint
make format         # Auto-format GDScript
make test           # Run GUT tests
make export-web     # Export web build to export/web/
```

### Local web testing

After `make export-web`, serve the build with any HTTP server:

```bash
cd export/web
python3 -m http.server 8080
```

Then open http://localhost:8080 in your browser.

## Tech Stack

- **Engine**: Godot 4.5 (Forward Plus desktop / GL Compatibility web)
- **Vehicle physics**: GEVP (Godot Easy Vehicle Physics)
- **World generation**: Procedural greybox city
- **Testing**: GUT (Godot Unit Testing)

## Deployment

The game auto-deploys to GitHub Pages on every push to `main` via GitHub Actions. To enable:

1. Create a GitHub repo
2. Go to Settings > Pages > Source: **GitHub Actions**
3. Push to `main`
