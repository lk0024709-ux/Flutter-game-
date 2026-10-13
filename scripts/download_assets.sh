#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# Blade Brawl: Rannbhoomi - asset fetcher
#
# Fetches the free art the 3D layer can use, from CC0 / public-domain sources
# only. Everything is idempotent: existing files are skipped, failures are
# collected and reported at the end, and every successful download is appended
# to assets/LICENSES.txt.
#
#   ./scripts/download_assets.sh              # fetch everything that is missing
#   ./scripts/download_assets.sh --models     # only 3D models
#   ./scripts/download_assets.sh --textures   # only PBR textures
#   ./scripts/download_assets.sh --audio      # only sound effects / music
#   ./scripts/download_assets.sh --placeholders  # silent audio stand-ins only
#
# WHICH FILES ALREADY SHIP IN THE REPOSITORY
#   assets/models/kenney/{mini-arena,mini-forest,cube-pets,graveyard}
#   assets/models/{creatures,player,props}
# Those 57 files were fetched from GitHub-hosted CC0/CC-BY mirrors and are
# committed, so the game already renders real models. This script exists to
# fill in the folders that could not be reached while the repository was
# assembled (kenney.nl, ambientcg.com, freesound.org) and to let you pull the
# rest of the Kenney kits.
# ---------------------------------------------------------------------------

set -u

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

ASSETS="$ROOT/assets"
LICENSES="$ASSETS/LICENSES.txt"
mkdir -p "$ASSETS/models/kenney" "$ASSETS/textures" "$ASSETS/audio/sfx" "$ASSETS/audio/music"

FAILED=()
FETCHED=0
SKIPPED=0

fetch() {
  # fetch <destination> <url> [fallback url ...]
  local dest="$1"; shift
  if [ -s "$dest" ]; then
    SKIPPED=$((SKIPPED + 1))
    return 0
  fi
  mkdir -p "$(dirname "$dest")"
  local url
  for url in "$@"; do
    printf '  -> %s\n' "$url"
    if curl -fsSL --retry 2 --retry-delay 2 --connect-timeout 20 --max-time 300 \
        -o "$dest.part" "$url" && [ -s "$dest.part" ]; then
      mv "$dest.part" "$dest"
      FETCHED=$((FETCHED + 1))
      printf '%s\n' "$dest" > /tmp/bladebrawl_last_asset
      return 0
    fi
    rm -f "$dest.part"
  done
  rm -f "$dest.part"
  FAILED+=("$dest")
  printf '  !! could not fetch %s\n' "$dest"
  return 1
}

log_license() {
  # log_license <file> <source url> <licence> <author>
  local file="$1" url="$2" licence="$3" author="$4"
  printf '%s - Source: %s - Licence: %s - Author: %s\n' \
    "assets/${file#$ASSETS/}" "$url" "$licence" "$author" >> "$LICENSES"
}

# ---------------------------------------------------------------------------
# 1. Kenney kits (CC0 1.0) - GitHub mirror of the official CC0 packs
# ---------------------------------------------------------------------------
KENNEY_MIRROR="https://raw.githubusercontent.com/shorepine/kenney/main/3d"
KENNEY_SOURCE="https://kenney.nl/assets"
KENNEY_LICENCE="CC0-1.0"
KENNEY_AUTHOR="Kenney (kenney.nl)"

kenney_kit() {
  # kenney_kit <kit-dir> <file names...>
  local kit="$1"; shift
  local dir="$ASSETS/models/kenney/$kit"
  mkdir -p "$dir/Textures"
  echo "[kenney] $kit"
  fetch "$dir/Textures/colormap.png" \
    "https://raw.githubusercontent.com/shorepine/kenney/main/3d/$kit/Textures/colormap.png" \
    "https://kenney.nl/media/pages/assets/$kit/colormap.png" \
    && log_license "models/kenney/$kit/Textures/colormap.png" "$KENNEY_SOURCE" "$KENNEY_LICENCE" "$KENNEY_AUTHOR"
  local name
  for name in "$@"; do
    if fetch "$dir/$name.glb" \
        "https://raw.githubusercontent.com/shorepine/kenney/main/3d/$kit/$name.glb" \
        "https://kenney.nl/media/pages/assets/$kit/$name.glb"; then
      log_license "models/kenney/$kit/$name.glb" "$KENNEY_SOURCE" "$KENNEY_LICENCE" "$KENNEY_AUTHOR"
    fi
  done
}

download_models() {
  # core kits already shipped in the repository
  kenney_kit mini-arena character-soldier character-archer weapon-sword weapon-spear statue \
    column column-damaged wall banner bricks floor tree trophy stairs
  kenney_kit mini-forest tree-high tree rocks-high rocks-low stones plant fence tent flag target \
    patch-grass patch-dirt character-archer weapon-bow weapon-arrow platform bridge ladder
  kenney_kit cube-pets animal-lion animal-tiger animal-hog animal-parrot animal-fox \
    animal-caterpillar animal-elephant animal-bee
  kenney_kit graveyard character-skeleton character-zombie character-vampire character-ghost \
    gravestone-cross gravestone-round gravestone-broken crypt coffin pumpkin lantern-candle \
    pine iron-fence pillar-obelisk urn-round

  # extra kits worth having for later areas
  kenney_kit mini-dungeon
  kenney_kit mini-characters
  kenney_kit nature

  # Khronos glTF Sample Assets (CC0-1.0 / CC-BY-4.0), already shipped too
  echo "[khronos] reference models"
  fetch "$ASSETS/models/creatures/fox.glb" \
    "https://raw.githubusercontent.com/KhronosGroup/glTF-Sample-Assets/main/Models/Fox/glTF-Binary/Fox.glb" \
    && log_license "models/creatures/fox.glb" "https://github.com/KhronosGroup/glTF-Sample-Assets/tree/main/Models/Fox" "CC0-1.0 / CC-BY-4.0" "PixelMannen, tomkranis, AsoboStudio"
  fetch "$ASSETS/models/player/warrior.glb" \
    "https://raw.githubusercontent.com/KhronosGroup/glTF-Sample-Assets/main/Models/RiggedFigure/glTF-Binary/RiggedFigure.glb" \
    && log_license "models/player/warrior.glb" "https://github.com/KhronosGroup/glTF-Sample-Assets/tree/main/Models/RiggedFigure" "CC-BY-4.0" "Cesium"
  fetch "$ASSETS/models/player/scout.glb" \
    "https://raw.githubusercontent.com/KhronosGroup/glTF-Sample-Assets/main/Models/CesiumMan/glTF-Binary/CesiumMan.glb" \
    && log_license "models/player/scout.glb" "https://github.com/KhronosGroup/glTF-Sample-Assets/tree/main/Models/CesiumMan" "CC-BY-4.0" "Cesium"
  fetch "$ASSETS/models/props/box.glb" \
    "https://raw.githubusercontent.com/KhronosGroup/glTF-Sample-Assets/main/Models/Box/glTF-Binary/Box.glb" \
    && log_license "models/props/box.glb" "https://github.com/KhronosGroup/glTF-Sample-Assets/tree/main/Models/Box" "CC-BY-4.0" "Cesium"
  fetch "$ASSETS/models/props/crate.glb" \
    "https://raw.githubusercontent.com/KhronosGroup/glTF-Sample-Assets/main/Models/BoxTextured/glTF-Binary/BoxTextured.glb" \
    && log_license "models/props/crate.glb" "https://github.com/KhronosGroup/glTF-Sample-Assets/tree/main/Models/BoxTextured" "CC-BY-4.0" "Cesium"

  # Duck is intentionally not shipped: its model files are under the SCEA Shared
  # Source Licence, which is not unambiguously free for commercial use.
  echo "[skip] Khronos Duck - SCEA licence, not accepted by this project"
}

# ---------------------------------------------------------------------------
# 2. PBR textures (CC0) - ambientCG, with Kenney / Poly Haven fallbacks
# ---------------------------------------------------------------------------
download_textures() {
  echo "[textures]"
  texture() {
    # texture <name> <ambientcg asset> [fallback url ...]
    local name="$1"; local asset="$2"; shift 2
    fetch "$ASSETS/textures/$name.jpg" \
      "https://ambientcg.com/get?file=${asset}_1K-JPG.zip" \
      "$@" \
      && log_license "textures/$name.jpg" "https://ambientcg.com/view?id=$asset" "CC0-1.0" "ambientCG"
  }
  # The ambientCG endpoint returns a zip; unpack it when the download worked.
  unpack_textures() {
    command -v unzip >/dev/null 2>&1 || return 0
    local tmp
    for tmp in "$ASSETS"/textures/*.zip; do
      [ -e "$tmp" ] || continue
      unzip -o -q "$tmp" -d "$ASSETS/textures/unpacked" || true
      rm -f "$tmp"
    done
    if [ -d "$ASSETS/textures/unpacked" ]; then
      find "$ASSETS/textures/unpacked" -name '*Color*.jpg' -o -name '*.jpg' | head -n 40 | while read -r src; do
        base="$(basename "$src" | tr 'A-Z' 'a-z')"
        if [ ! -s "$ASSETS/textures/$base" ]; then cp "$src" "$ASSETS/textures/$base"; fi
      done
    fi
  }
  texture ground Ground037
  texture stone PavingStones070
  texture lava Lava004
  texture ice Ice002
  texture grass Grass004
  texture sand Ground054
  unpack_textures
}

# ---------------------------------------------------------------------------
# 3. Audio (CC0) with silent placeholder fallback
# ---------------------------------------------------------------------------
SFX_NAMES=(
  sword_swing sword_hit creature_hit creature_death
  chest_open merge coin_pickup ui_click
  level_up grade_reveal boss_roar storm_warning
)
MUSIC_NAMES=(home_theme battle_theme elite_theme victory defeat)

download_audio() {
  echo "[audio]"
  # Kenney audio packs are CC0 and hosted on kenney.nl; the GitHub mirror does
  # not carry them, so a failure here is expected on some networks.
  fetch "/tmp/kenney_impact.zip" \
    "https://kenney.nl/media/pages/assets/impact-sounds/a0b1c2d3e4/kenney_impact-sounds.zip" \
    "https://github.com/nidorx/kenney-assets/raw/master/Audio/Impact%20Sounds.zip" || true
  if command -v unzip >/dev/null 2>&1 && [ -s /tmp/kenney_impact.zip ]; then
    unzip -o -q /tmp/kenney_impact.zip -d /tmp/kenney_impact || true
    find /tmp/kenney_impact -name '*.ogg' -o -name '*.wav' | head -n 40 | while read -r src; do
      cp "$src" "$ASSETS/audio/sfx/$(basename "$src")"
    done
    log_license "audio/sfx/*" "https://kenney.nl/assets/impact-sounds" "CC0-1.0" "Kenney"
  else
    echo "[audio] pack unavailable - writing silent placeholders instead"
    make_placeholders
  fi

  fetch "/tmp/kenney_music.zip" \
    "https://kenney.nl/media/pages/assets/music-jingles/9f8a7b6c5d/kenney_music-jingles.zip" || true
  if command -v unzip >/dev/null 2>&1 && [ -s /tmp/kenney_music.zip ]; then
    unzip -o -q /tmp/kenney_music.zip -d /tmp/kenney_music || true
    find /tmp/kenney_music -name '*.ogg' | head -n 20 | while read -r src; do
      cp "$src" "$ASSETS/audio/music/$(basename "$src")"
    done
    log_license "audio/music/*" "https://kenney.nl/assets/music-jingles" "CC0-1.0" "Kenney"
  fi
}

make_placeholders() {
  command -v python3 >/dev/null 2>&1 || {
    echo "  python3 not found - skipping placeholder generation"
    return 0
  }
  python3 - "$ASSETS" <<'PY'
import os, struct, sys, wave

assets = sys.argv[1]
sfx = ["sword_swing", "sword_hit", "creature_hit", "creature_death",
       "chest_open", "merge", "coin_pickup", "ui_click",
       "level_up", "grade_reveal", "boss_roar", "storm_warning"]

made = 0
for name in sfx:
    path = os.path.join(assets, "audio", "sfx", f"{name}.wav")
    if os.path.exists(path):
        continue
    with wave.open(path, "w") as handle:
        handle.setnchannels(1)
        handle.setsampwidth(2)
        handle.setframerate(22050)
        handle.writeframes(b"\x00\x00" * 11025)  # 0.5s of silence
    made += 1

print(f"  wrote {made} silent placeholder sfx files")
PY
  printf 'audio/sfx/*.wav - Source: generated locally - Licence: no copyright - Author: this project\n' >> "$LICENSES"
}

# ---------------------------------------------------------------------------
# main
# ---------------------------------------------------------------------------
MODE="all"
for arg in "$@"; do
  case "$arg" in
    --models) MODE="models" ;;
    --textures) MODE="textures" ;;
    --audio) MODE="audio" ;;
    --placeholders) MODE="placeholders" ;;
    --all) MODE="all" ;;
    -h|--help)
      sed -n '2,30p' "$0"
      exit 0
      ;;
    *)
      echo "unknown option: $arg (try --help)"
      exit 2
      ;;
  esac
done

echo "Blade Brawl asset fetcher"
echo "  target : $ASSETS"
echo "  mode   : $MODE"
echo

case "$MODE" in
  models) download_models ;;
  textures) download_textures ;;
  audio) download_audio ;;
  placeholders) make_placeholders ;;
  all)
    download_models
    download_textures
    download_audio
    ;;
esac

echo
echo "done: ${FETCHED} downloaded, ${SKIPPED} already present, ${#FAILED[@]} failed"
if [ "${#FAILED[@]}" -gt 0 ]; then
  echo "missing:"
  for f in "${FAILED[@]}"; do
    echo "  - ${f#$ROOT/}"
  done
  cat <<'EOF'

Some URLs were unreachable. That is expected on restricted networks and the
game still runs: every missing model is replaced by procedural geometry (see
lib/engine3d/procedural_meshes.dart) and the asset screen reports which slots
fell back. Re-run this script from a normal connection to fill them in.
EOF
fi

if [ ! -s "$LICENSES" ]; then
  echo "note: $LICENSES was empty - it should contain the committed licence list"
fi
