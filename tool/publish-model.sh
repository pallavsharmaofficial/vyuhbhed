#!/usr/bin/env bash
# Publishes a model file as a GitHub Release asset, so the app has somewhere
# to download it from. Free. No Cloudflare, no card, no second account.
#
#   ./tool/publish-model.sh <file.litertlm> [tag]
#
# WHY GITHUB RELEASES AND NOT R2
# ------------------------------
# GitHub allows release assets up to 2 GB and does not meter bandwidth on
# public repos. Both models that matter fit:
#
#   gemma3-1b-it-int4.litertlm        584 MB
#   Qwen2.5-1.5B q8 .litertlm       1,598 MB
#
# Cloudflare R2's free tier is also fine, but enabling R2 requires a payment
# card on the Cloudflare account even though the free tier bills nothing. If
# you would rather not put a card down, this is the path.
#
# The 3.7 GB Gemma 3n E2B model does NOT fit in a release asset. That one
# needs R2 or a Hugging Face repo of your own.

set -euo pipefail

FILE="${1:-}"
TAG="${2:-models}"

[[ -n "$FILE" && -f "$FILE" ]] || {
  echo "usage: $0 <model-file> [tag]"
  echo
  echo "Get a model file first. Ungated, works immediately:"
  echo "  curl -L -o qwen.litertlm \\"
  echo "    https://huggingface.co/litert-community/Qwen2.5-1.5B-Instruct/resolve/main/Qwen2.5-1.5B-Instruct_multi-prefill-seq_q8_ekv4096.litertlm"
  echo
  echo "Gated, smaller and better for Hindi — needs a free Hugging Face account"
  echo "that has accepted the Gemma licence, then a read token:"
  echo "  curl -L -H \"Authorization: Bearer \$HF_TOKEN\" -o gemma3-1b-it-int4.litertlm \\"
  echo "    https://huggingface.co/litert-community/Gemma3-1B-IT/resolve/main/gemma3-1b-it-int4.litertlm"
  exit 1
}

command -v gh >/dev/null 2>&1 || { echo "gh CLI not found."; exit 1; }

SIZE_BYTES=$(stat -f%z "$FILE" 2>/dev/null || stat -c%s "$FILE")
LIMIT=$((2 * 1024 * 1024 * 1024))
if (( SIZE_BYTES > LIMIT )); then
  printf 'That file is %.1f GB. GitHub caps release assets at 2 GB.\n' \
    "$(echo "$SIZE_BYTES / 1073741824" | bc -l)"
  echo "Use Cloudflare R2 or your own Hugging Face repo for this one."
  exit 1
fi

REPO=$(gh repo view --json nameWithOwner --jq .nameWithOwner)
BASENAME=$(basename "$FILE")

printf 'Publishing %s (%.0f MB) to %s @ %s\n' \
  "$BASENAME" "$(echo "$SIZE_BYTES / 1048576" | bc -l)" "$REPO" "$TAG"

gh release view "$TAG" >/dev/null 2>&1 || gh release create "$TAG" \
  --title "Model files" \
  --notes "On-device model files for Saath. Downloaded once by the app, on the user's say-so, over Wi-Fi.

These are third-party models redistributed under their own licences — check the
upstream repository for terms before relying on this."

gh release upload "$TAG" "$FILE" --clobber

URL="https://github.com/${REPO}/releases/download/${TAG}"

cat <<DONE

Done. Model files now served from:
  ${URL}/

Build the app against it:
  flutter build apk --release --target-platform android-arm64 \\
    --dart-define=SAATH_MODEL_BASE_URL=${URL}

Or set it once for CI, so every tagged release picks it up:
  gh variable set SAATH_MODEL_BASE_URL --body "${URL}"

The app appends the filename from SaathModel.fileName, so the name on the
release must match the catalogue entry exactly:
  ${BASENAME}
DONE
