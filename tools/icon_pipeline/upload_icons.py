"""
Icon pipeline: bulk-upload a folder of PNG icons to Roblox via the Open Cloud
Assets API, and emit a Luau table of the resulting asset ids ready to paste
into src/shared/Config/Items.luau's IconPool.

WHY THIS EXISTS: the game's item-generation system (PoolService.generateDefs)
can mint an unlimited number of items structurally (name + supply + weight are
all free), but every item needs a genuinely UNIQUE icon -- no two items may
ever share one. The built-in "Simulator Icon Pack" only has ~35-40 usable
icons before recycling starts, which is a hard wall. This script feeds that
pipeline from game-icons.net (github.com/game-icons/icons), a 4,180-icon,
CC-BY-3.0 single-color icon set that most Roblox players have never seen
(it's a tabletop/VTT asset library, not a Roblox one) -- solving the ceiling
for years, not months.

SOURCE SETUP (one-time, not part of this script):
  1. git clone https://github.com/game-icons/icons
  2. Rasterize the SVGs you want to PNG (any size >= 256x256; Roblox decals
     must be under 8000x8000). If you don't have a converter handy:
       pip install cairosvg
       python -c "
import cairosvg, pathlib
src = pathlib.Path('icons/delapouite')  # or whichever author folder(s)
out = pathlib.Path('rasterized'); out.mkdir(exist_ok=True)
for f in src.glob('*.svg'):
    cairosvg.svg2png(url=str(f), write_to=str(out / (f.stem + '.png')), output_width=512, output_height=512)
"
     Pick a handful of author subfolders rather than all 4,180 at once --
     see NOTES.md in this folder for curated category suggestions.

CREDENTIALS (required, not stored in this repo):
  - ROBLOX_OPEN_CLOUD_API_KEY: create at create.roblox.com/dashboard/credentials,
    scoped to "Assets" -> "Write" for this specific experience/creator.
  - ROBLOX_CREATOR_TYPE: "User" or "Group"
  - ROBLOX_CREATOR_ID: your userId or groupId (whichever owns the game)

USAGE:
  python upload_icons.py --input rasterized/ --manifest manifest.json --luau-out new_icons.luau [--limit 40]

  Re-running is safe: already-uploaded files (tracked in manifest.json) are
  skipped, so you can upload in small batches over time instead of all at
  once (recommended -- see rate-limit note below).

WHAT THIS DOES NOT DO:
  - Does not edit Items.luau directly. Paste new_icons.luau's contents into
    IconPool by hand, so a bad batch never silently corrupts the live config.
  - Does not attribute automatically. game-icons.net is CC-BY-3.0: credit the
    authors somewhere player-reachable (a credits screen, group wall page, or
    game description works) -- see NOTES.md.
"""

import argparse
import json
import os
import sys
import time
from pathlib import Path

import requests

ASSETS_ENDPOINT = "https://apis.roblox.com/assets/v1/assets"
OPERATIONS_ENDPOINT = "https://apis.roblox.com/assets/v1/operations/{}"

# Roblox throttles asset creation per creator. This is deliberately
# conservative -- moderation queues also back up if you slam them. Uploading
# 4,180 icons in one run is neither necessary nor advisable; do it in batches
# of a few dozen as the item roadmap actually needs them.
SECONDS_BETWEEN_UPLOADS = 3.0
POLL_INTERVAL_SECONDS = 2.0
POLL_TIMEOUT_SECONDS = 60.0


def load_manifest(path: Path) -> dict:
    if path.exists():
        return json.loads(path.read_text(encoding="utf-8"))
    return {}


def save_manifest(path: Path, manifest: dict) -> None:
    path.write_text(json.dumps(manifest, indent=2, sort_keys=True), encoding="utf-8")


def upload_one(api_key: str, creator_type: str, creator_id: str, image_path: Path) -> str:
    """Upload one PNG as a Decal, poll until done, return the resulting asset id."""
    display_name = image_path.stem[:50]  # Roblox caps displayName length
    request_payload = {
        "assetType": "Decal",
        "displayName": display_name,
        "description": "Procedural item icon (game-icons.net, CC-BY-3.0)",
        "creationContext": {
            "creator": ({"userId": creator_id} if creator_type == "User" else {"groupId": creator_id})
        },
    }

    with open(image_path, "rb") as f:
        response = requests.post(
            ASSETS_ENDPOINT,
            headers={"x-api-key": api_key},
            data={"request": json.dumps(request_payload)},
            files={"fileContent": (image_path.name, f, "image/png")},
            timeout=30,
        )
    response.raise_for_status()
    operation_path = response.json()["path"]  # "operations/{id}"
    operation_id = operation_path.split("/")[-1]

    deadline = time.time() + POLL_TIMEOUT_SECONDS
    while time.time() < deadline:
        poll = requests.get(
            OPERATIONS_ENDPOINT.format(operation_id),
            headers={"x-api-key": api_key},
            timeout=15,
        )
        poll.raise_for_status()
        body = poll.json()
        if body.get("done"):
            asset_id = body["response"]["assetId"]
            return str(asset_id)
        time.sleep(POLL_INTERVAL_SECONDS)

    raise TimeoutError(f"Upload of {image_path.name} did not finish within {POLL_TIMEOUT_SECONDS}s")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--input", required=True, type=Path, help="Folder of PNG icons to upload")
    parser.add_argument("--manifest", required=True, type=Path, help="JSON file tracking filename -> assetId (created if missing)")
    parser.add_argument("--luau-out", required=True, type=Path, help="Where to write the new Luau IconPool entries")
    parser.add_argument("--limit", type=int, default=40, help="Max NEW uploads this run (default 40 -- stay deliberate)")
    args = parser.parse_args()

    api_key = os.environ.get("ROBLOX_OPEN_CLOUD_API_KEY")
    creator_type = os.environ.get("ROBLOX_CREATOR_TYPE")
    creator_id = os.environ.get("ROBLOX_CREATOR_ID")
    if not (api_key and creator_type and creator_id):
        print("Missing env vars: ROBLOX_OPEN_CLOUD_API_KEY, ROBLOX_CREATOR_TYPE, ROBLOX_CREATOR_ID", file=sys.stderr)
        return 1
    if creator_type not in ("User", "Group"):
        print("ROBLOX_CREATOR_TYPE must be 'User' or 'Group'", file=sys.stderr)
        return 1

    manifest = load_manifest(args.manifest)
    pngs = sorted(p for p in args.input.glob("*.png"))
    todo = [p for p in pngs if p.name not in manifest][: args.limit]

    if not todo:
        print("Nothing new to upload (check --input path or raise --limit).")
        return 0

    print(f"Uploading {len(todo)} of {len(pngs)} total icons ({len(pngs) - len(todo)} already done)...")
    newly_uploaded = []
    for i, image_path in enumerate(todo, 1):
        try:
            asset_id = upload_one(api_key, creator_type, creator_id, image_path)
            manifest[image_path.name] = asset_id
            newly_uploaded.append((image_path.stem, asset_id))
            print(f"  [{i}/{len(todo)}] {image_path.name} -> {asset_id}")
        except Exception as exc:  # noqa: BLE001 -- one bad file shouldn't kill the batch
            print(f"  [{i}/{len(todo)}] FAILED {image_path.name}: {exc}", file=sys.stderr)
        save_manifest(args.manifest, manifest)  # persist after every file, not just at the end
        if i < len(todo):
            time.sleep(SECONDS_BETWEEN_UPLOADS)

    lines = ["\t\t-- Generated by tools/icon_pipeline/upload_icons.py -- game-icons.net (CC-BY-3.0)"]
    for name, asset_id in newly_uploaded:
        lines.append(f'\t\t"rbxassetid://{asset_id}", -- {name}')
    args.luau_out.write_text("\n".join(lines) + "\n", encoding="utf-8")

    print(f"\n{len(newly_uploaded)} new icon(s) uploaded.")
    print(f"Paste {args.luau_out} into IconPool in src/shared/Config/Items.luau.")
    print("Newly uploaded decals may sit in Roblox's moderation queue briefly before they render in-game.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
