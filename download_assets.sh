#!/usr/bin/env bash
set -euo pipefail

# Downloads free game assets and organizes them into the project structure.
# All assets are CC0 or royalty-free.
# Run from project root: ./download_assets.sh

PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
ASSETS_DIR="$PROJECT_DIR/assets"
ADDONS_DIR="$PROJECT_DIR/addons"
TMP_DIR="$PROJECT_DIR/.tmp_downloads"

mkdir -p "$TMP_DIR"

echo "=== City Car Stealing Game Asset Downloader ==="
echo ""

# Helper: download and extract a zip from a URL
download_and_extract() {
    local url="$1"
    local dest_dir="$2"
    local name="$3"

    echo "  Downloading: $name"
    mkdir -p "$dest_dir"
    local zip_file="$TMP_DIR/${name// /_}.zip"

    if [ -f "$zip_file" ]; then
        echo "    (cached, skipping download)"
    else
        curl -L -o "$zip_file" "$url" 2>/dev/null || {
            echo "    FAILED to download $name from $url"
            return 1
        }
    fi

    echo "    Extracting to $dest_dir"
    unzip -q -o "$zip_file" -d "$dest_dir" 2>/dev/null || {
        echo "    FAILED to extract $name"
        return 1
    }
    echo "    Done: $name"
}

# -------------------------------------------------------
# KENNEY ASSETS (CC0)
# -------------------------------------------------------
echo "[1/8] Kenney Vehicles..."
download_and_extract \
    "https://kenney.nl/media/pages/assets/car-kit/cdd1fb553a-1738810389/kenney_car-kit.zip" \
    "$ASSETS_DIR/models/vehicles/kenney_car_kit" \
    "Kenney Car Kit"

download_and_extract \
    "https://kenney.nl/media/pages/assets/racing-kit/ceede6f2fa-1738810395/kenney_racing-kit.zip" \
    "$ASSETS_DIR/models/vehicles/kenney_racing" \
    "Kenney Racing Kit"

echo ""
echo "[2/8] Kenney City Roads..."
download_and_extract \
    "https://kenney.nl/media/pages/assets/city-kit-roads/13ed5b3f0f-1738810390/kenney_city-kit-roads.zip" \
    "$ASSETS_DIR/models/roads/kenney_roads" \
    "Kenney City Kit Roads"

download_and_extract \
    "https://kenney.nl/media/pages/assets/3d-road-tiles/3ad9879e3e-1738810388/kenney_3d-road-tiles.zip" \
    "$ASSETS_DIR/models/roads/kenney_road_tiles" \
    "Kenney 3D Road Tiles"

echo ""
echo "[3/8] Kenney City Buildings..."
download_and_extract \
    "https://kenney.nl/media/pages/assets/city-kit-commercial/b1e70ff8f4-1738810389/kenney_city-kit-commercial.zip" \
    "$ASSETS_DIR/models/buildings/kenney_commercial" \
    "Kenney City Kit Commercial"

download_and_extract \
    "https://kenney.nl/media/pages/assets/city-kit-suburban/9ff4bd61f0-1738810390/kenney_city-kit-suburban.zip" \
    "$ASSETS_DIR/models/buildings/kenney_suburban" \
    "Kenney City Kit Suburban"

download_and_extract \
    "https://kenney.nl/media/pages/assets/city-kit-industrial/7be6326e1e-1738810390/kenney_city-kit-industrial.zip" \
    "$ASSETS_DIR/models/buildings/kenney_industrial" \
    "Kenney City Kit Industrial"

download_and_extract \
    "https://kenney.nl/media/pages/assets/modular-buildings/83b04decbb-1738810394/kenney_modular-buildings.zip" \
    "$ASSETS_DIR/models/buildings/kenney_modular" \
    "Kenney Modular Buildings"

echo ""
echo "[4/8] Kenney UI & Audio..."
download_and_extract \
    "https://kenney.nl/media/pages/assets/ui-pack/d9d372d10f-1738810398/kenney_ui-pack.zip" \
    "$ASSETS_DIR/textures/ui/kenney_ui_pack" \
    "Kenney UI Pack"

download_and_extract \
    "https://kenney.nl/media/pages/assets/impact-sounds/57e7bec610-1738810392/kenney_impact-sounds.zip" \
    "$ASSETS_DIR/audio/sfx/impacts" \
    "Kenney Impact Sounds"

download_and_extract \
    "https://kenney.nl/media/pages/assets/interface-sounds/bbec5d4a75-1738810393/kenney_interface-sounds.zip" \
    "$ASSETS_DIR/audio/sfx/ui" \
    "Kenney Interface Sounds"

# -------------------------------------------------------
# THIRD-PARTY ASSETS
# -------------------------------------------------------
echo ""
echo "[5/8] KayKit Assets (CC0)..."
echo "  NOTE: KayKit and RGS_Dev assets are on itch.io and may require manual download."
echo "  Visit these URLs to download:"
echo "    - https://kaylousberg.itch.io/city-builder-bits"
echo "    - https://kaylousberg.itch.io/kaykit-adventurers"
echo "    - https://rgsdev.itch.io/free-low-poly-vehicles-pack"
echo ""
echo "  After downloading, extract to:"
echo "    City Builder Bits -> $ASSETS_DIR/models/buildings/kaykit_city/"
echo "    KayKit Adventurers -> $ASSETS_DIR/models/characters/kaykit_adventurers/"
echo "    RGS_Dev Vehicles  -> $ASSETS_DIR/models/vehicles/rgs_dev/"

# Try GitHub mirror for KayKit City Builder Bits
echo ""
echo "  Attempting KayKit City Builder Bits from GitHub..."
if [ ! -d "$ASSETS_DIR/models/buildings/kaykit_city/KayKit-City-Builder-Bits" ]; then
    git clone --depth 1 https://github.com/KayKit-Game-Assets/KayKit-City-Builder-Bits-1.0.git \
        "$ASSETS_DIR/models/buildings/kaykit_city/KayKit-City-Builder-Bits" 2>/dev/null && \
        echo "    Done: KayKit City Builder Bits" || \
        echo "    FAILED: Download manually from itch.io"
else
    echo "    (already exists, skipping)"
fi

# -------------------------------------------------------
# ENGINE SOUNDS (CC0 from OpenGameArt)
# -------------------------------------------------------
echo ""
echo "[6/8] Engine Sound Loops (OpenGameArt CC0)..."
echo "  NOTE: OpenGameArt requires manual download."
echo "  Visit: https://opengameart.org/content/racing-car-engine-sound-loops"
echo "  Extract to: $ASSETS_DIR/audio/sfx/engine/"

# -------------------------------------------------------
# GEVP (Godot Easy Vehicle Physics)
# -------------------------------------------------------
echo ""
echo "[7/8] GEVP (Godot Easy Vehicle Physics)..."
if [ ! -d "$ADDONS_DIR/gevp/.git" ]; then
    git clone --depth 1 https://github.com/DAShoe1/Godot-Easy-Vehicle-Physics.git \
        "$TMP_DIR/gevp_repo" 2>/dev/null && {
        # Copy just the addon files
        if [ -d "$TMP_DIR/gevp_repo/addons/gevp" ]; then
            cp -r "$TMP_DIR/gevp_repo/addons/gevp/"* "$ADDONS_DIR/gevp/"
            echo "    Done: GEVP installed"
        elif [ -d "$TMP_DIR/gevp_repo/addons" ]; then
            # Find the actual addon directory
            ls "$TMP_DIR/gevp_repo/addons/"
            echo "    Check addon structure above and copy manually"
        else
            echo "    Unexpected repo structure. Copying all to addons/gevp/"
            cp -r "$TMP_DIR/gevp_repo/"* "$ADDONS_DIR/gevp/"
        fi
        rm -rf "$TMP_DIR/gevp_repo"
    } || echo "    FAILED: Install GEVP from Godot Asset Library instead"
else
    echo "    (already exists, skipping)"
fi

# -------------------------------------------------------
# CLEANUP
# -------------------------------------------------------
echo ""
echo "[8/8] Cleanup..."
echo "  Temporary downloads kept in $TMP_DIR for caching."
echo "  Run 'rm -rf $TMP_DIR' to free space after verifying assets."

echo ""
echo "=== Download Summary ==="
echo "Automatic downloads attempted for all Kenney assets."
echo ""
echo "MANUAL DOWNLOADS NEEDED:"
echo "  1. RGS_Dev Vehicles: https://rgsdev.itch.io/free-low-poly-vehicles-pack"
echo "     -> Extract to: assets/models/vehicles/rgs_dev/"
echo "  2. KayKit Adventurers: https://kaylousberg.itch.io/kaykit-adventurers"
echo "     -> Extract to: assets/models/characters/kaykit_adventurers/"
echo "  3. Engine Loops: https://opengameart.org/content/racing-car-engine-sound-loops"
echo "     -> Extract to: assets/audio/sfx/engine/"
echo "  4. Music (for radio): Browse https://incompetech.com/music/ and https://pixabay.com/music/"
echo "     -> Save to: assets/audio/music/{rock,electronic,chill}/"
echo ""
echo "Done!"
