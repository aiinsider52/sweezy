#!/bin/zsh
set -euo pipefail

asset_root="/Users/vladyslav.katash/Desktop/SWEEEZY/sweezy/sweezy/Assets.xcassets"

install_triptych() {
  local slug="$1"
  local source="$2"
  local width height panel_width index offset image_name image_set output

  width=$(sips -g pixelWidth "$source" | awk '/pixelWidth/ {print $2}')
  height=$(sips -g pixelHeight "$source" | awk '/pixelHeight/ {print $2}')
  panel_width=$((width / 3))

  for index in 1 2 3; do
    offset=$(((index - 1) * panel_width))
    if [[ "$index" == "1" ]]; then
      image_name="swiss-discovery-${slug}"
    else
      image_name="swiss-discovery-${slug}-${index}"
    fi
    image_set="${asset_root}/${image_name}.imageset"
    output="${image_set}/${image_name}.jpg"
    mkdir -p "$image_set"
    sips --cropToHeightWidth "$height" "$panel_width" --cropOffset 0 "$offset" "$source" --out "$output" >/dev/null
    sips -s format jpeg -s formatOptions 90 "$output" --out "$output" >/dev/null
    cat > "${image_set}/Contents.json" <<JSON
{
  "images" : [
    {
      "filename" : "${image_name}.jpg",
      "idiom" : "universal",
      "scale" : "1x"
    },
    {
      "idiom" : "universal",
      "scale" : "2x"
    },
    {
      "idiom" : "universal",
      "scale" : "3x"
    }
  ],
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}
JSON
  done
}

install_triptych "zurich" "/Users/vladyslav.katash/.codex/generated_images/019b8d62-a073-70c0-b240-620c8c47815f/exec-9bcf8573-5004-4a52-8a25-5ded2eaaf297.png"
install_triptych "geneva" "/Users/vladyslav.katash/.codex/generated_images/019b8d62-a073-70c0-b240-620c8c47815f/exec-36511dcc-9969-43bd-982e-b398fc694ae3.png"
install_triptych "lucerne" "/Users/vladyslav.katash/.codex/generated_images/019b8d62-a073-70c0-b240-620c8c47815f/exec-c90b47dd-7833-4f6c-9f02-89aebbe31c20.png"
install_triptych "basel" "/Users/vladyslav.katash/.codex/generated_images/019b8d62-a073-70c0-b240-620c8c47815f/exec-b29bf487-3e40-4260-bf14-3aef7827bbec.png"
install_triptych "lausanne" "/Users/vladyslav.katash/.codex/generated_images/019b8d62-a073-70c0-b240-620c8c47815f/exec-e06b7cb0-dc14-4107-aba7-a553fc46e9a7.png"
install_triptych "montreux" "/Users/vladyslav.katash/.codex/generated_images/019b8d62-a073-70c0-b240-620c8c47815f/exec-270f010a-60c2-44a9-9675-d5cc0e67209c.png"
install_triptych "lugano" "/Users/vladyslav.katash/.codex/generated_images/019b8d62-a073-70c0-b240-620c8c47815f/exec-402080f4-2fb5-4c02-b0ca-a95350a528e3.png"
install_triptych "davos" "/Users/vladyslav.katash/.codex/generated_images/019b8d62-a073-70c0-b240-620c8c47815f/exec-7185e16c-4200-4fa4-b234-ddb79c4fa9e6.png"
install_triptych "ascona" "/Users/vladyslav.katash/.codex/generated_images/019b8d62-a073-70c0-b240-620c8c47815f/exec-2c78fde4-1691-4360-9195-49e45c25c100.png"
install_triptych "engadin" "/Users/vladyslav.katash/.codex/generated_images/019b8d62-a073-70c0-b240-620c8c47815f/exec-6881dab7-b752-4a5d-a57d-275cfcc87186.png"
