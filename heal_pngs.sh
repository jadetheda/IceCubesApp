#!/bin/bash
echo "Healing PNGs by fetching originals from Dimillian/IceCubesApp..."
rm -rf /tmp/ice-cubes-orig
git clone --depth 1 https://github.com/Dimillian/IceCubesApp.git /tmp/ice-cubes-orig

# Find all pngs in ios-workspace, get their relative path, and copy them from orig if they exist
find . -name "*.png" | while read -r file; do
  if [ -f "/tmp/ice-cubes-orig/$file" ]; then
    cp -f "/tmp/ice-cubes-orig/$file" "$file"
  fi
done
rm -rf /tmp/ice-cubes-orig
echo "PNGs healed!"
