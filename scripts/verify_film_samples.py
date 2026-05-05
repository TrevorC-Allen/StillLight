#!/usr/bin/env python3
import json
import re
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
PRESETS = ROOT / "StillLight" / "Film" / "FilmLibrary.swift"
MANIFEST = ROOT / "StillLight" / "Resources" / "FilmSamples" / "film_samples_manifest.json"
REQUIRED_ROLES = {"hero", "thumb", "micro", "blur"}


def main() -> int:
    preset_ids = re.findall(r'id:\s*"([^"]+)"', PRESETS.read_text())
    manifest = json.loads(MANIFEST.read_text())
    entries = {entry["filmId"]: entry for entry in manifest.get("samples", [])}

    errors = []
    for preset_id in preset_ids:
        entry = entries.get(preset_id)
        if not entry:
            errors.append(f"missing manifest entry: {preset_id}")
            continue

        roles = {asset.get("role") for asset in entry.get("assets", [])}
        missing_roles = REQUIRED_ROLES - roles
        if missing_roles:
            errors.append(f"{preset_id}: missing roles {sorted(missing_roles)}")

        for asset in entry.get("assets", []):
            path = asset.get("path", "")
            if not path.startswith("FilmSamples/Samples/"):
                errors.append(f"{preset_id}: path should stay under FilmSamples/Samples: {path}")
            if not path.endswith(".jpg"):
                errors.append(f"{preset_id}: sample should be jpg: {path}")
            if not (ROOT / "StillLight" / "Resources" / path).exists():
                print(f"pending asset: {path}")

    extra = sorted(set(entries) - set(preset_ids))
    for film_id in extra:
        errors.append(f"manifest entry has no preset: {film_id}")

    if errors:
        print("\n".join(errors), file=sys.stderr)
        return 1

    print(f"manifest valid for {len(preset_ids)} film presets")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
