#!/bin/sh
set -eu

PHP_TARGET="/app/public/src/Service/ImageHandler.php"
ORIGINAL_SMALL='generate($absolutePath . '\''/'\'' . $fileName, $absolutePath . '\''/'\'' . $smallThumbnailFileName, 300, $thumbnailFormat)'
ORIGINAL_LARGE='generate($absolutePath . '\''/'\'' . $fileName, $absolutePath . '\''/'\'' . $largeThumbnailFileName, 600, $thumbnailFormat)'
PATCHED_SMALL='generate($absolutePath . '\''/'\'' . $fileName, $absolutePath . '\''/'\'' . $smallThumbnailFileName, 450, $thumbnailFormat)'
PATCHED_LARGE='generate($absolutePath . '\''/'\'' . $fileName, $absolutePath . '\''/'\'' . $largeThumbnailFileName, 900, $thumbnailFormat)'

log() {
  printf '[start-n-patch] %s\n' "$1"
}

fail() {
  printf '[start-n-patch] PATCH ERROR: %s\n' "$1" >&2
  exit 1
}

patch_php_thumbnails() {
  [ -f "$PHP_TARGET" ] || fail "Target file not found: $PHP_TARGET"

  if grep -Fq "$PATCHED_SMALL" "$PHP_TARGET" && grep -Fq "$PATCHED_LARGE" "$PHP_TARGET"; then
    log "PHP thumbnail patch already present"
  elif grep -Fq "$ORIGINAL_SMALL" "$PHP_TARGET" && grep -Fq "$ORIGINAL_LARGE" "$PHP_TARGET"; then
    log "Expected upstream PHP thumbnail code found, applying patch"

    sed -i "s/300, \$thumbnailFormat/450, \$thumbnailFormat/" "$PHP_TARGET"
    sed -i "s/600, \$thumbnailFormat/900, \$thumbnailFormat/" "$PHP_TARGET"

    if grep -Fq "$PATCHED_SMALL" "$PHP_TARGET" && grep -Fq "$PATCHED_LARGE" "$PHP_TARGET"; then
      log "PHP thumbnail patch applied successfully"
    else
      fail "PHP patch attempt ran, but verification failed"
    fi
  else
    fail "ImageHandler.php does not match expected upstream or patched code. Upstream may have changed."
  fi
}

patch_collection_editor_js() {
  JS_FILES="$(grep -Ril 'size:{width:200,height:200}' /app/public/public/build 2>/dev/null || true)"
  log "JS files found: $JS_FILES"
  [ -n "$JS_FILES" ] || fail "Could not find compiled JS with Croppie export size"

  for f in $JS_FILES; do
    if grep -Fq 'size:{width:600,height:600}' "$f"; then
      log "Collection editor JS already patched in $f"
      continue
    fi

    log "Patching collection editor JS in $f"
    sed -i 's/viewport:{width:150,height:150,type:"circle"}/viewport:{width:220,height:220,type:"square"}/g' "$f"
    sed -i 's/boundary:{width:200,height:200}/boundary:{width:280,height:280}/g' "$f"
    sed -i 's/size:{width:200,height:200}/size:{width:600,height:600}/g' "$f"
    sed -i 's/\.querySelector(".cr-vp-circle")/.querySelector(".cr-viewport")/g' "$f"
  done
}

patch_collection_editor_css() {
  CSS_FILES="$(grep -Ril 'croppie-preview img{border-radius:100%' /app/public/public/build 2>/dev/null || true)"
  log "CSS files found: $CSS_FILES"
  [ -n "$CSS_FILES" ] || fail "Could not find compiled CSS with Croppie preview rule"

  for f in $CSS_FILES; do
    log "Patching collection editor CSS in $f"
    sed -i 's/\.croppie-preview img{border-radius:100%/.croppie-preview img{border-radius:8px/g' "$f"
    sed -i 's/\.content-wrapper \.title-block \.thumbnail{border-radius:100%/.content-wrapper .title-block .thumbnail{border-radius:8px/g' "$f"
    sed -i 's/\.collections img{border-radius:100%/.collections img{border-radius:8px/g' "$f"
    sed -i 's/\.cr-vp-circle\.fa:before{/\.cr-viewport.fa:before{/g' "$f"
  done
}

patch_collection_entity_size() {
  TARGET="/app/public/src/Entity/Collection.php"

  [ -f "$TARGET" ] || fail "Target file not found: $TARGET"

  if grep -Fq "maxWidth: 600, maxHeight: 600" "$TARGET"; then
    log "Collection entity size patch already present"
    return
  fi

  if grep -Fq "maxWidth: 200, maxHeight: 200" "$TARGET"; then
    log "Expected upstream Collection entity upload size found, applying patch"
    sed -i 's/maxWidth: 200, maxHeight: 200/maxWidth: 600, maxHeight: 600/' "$TARGET"

    if grep -Fq "maxWidth: 600, maxHeight: 600" "$TARGET"; then
      log "Collection entity size patch applied successfully"
    else
      fail "Collection entity size patch verification failed"
    fi
  else
    fail "Collection.php does not match expected upstream or patched code. Upstream may have changed."
  fi
}

patch_php_thumbnails
patch_collection_entity_size
patch_collection_editor_js
patch_collection_editor_css

exec sh /app/public/docker/entrypoint.sh
