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
  JS_TARGET="$(grep -Ril 'viewport:{width:150,height:150,type:"circle"}' /app/public/public/build 2>/dev/null | head -n 1 || true)"
  [ -n "$JS_TARGET" ] || fail "Could not find compiled JS bundle for collection thumbnail editor"

  if grep -Fq 'viewport:{width:220,height:220,type:"square"}' "$JS_TARGET" && \
     grep -Fq 'boundary:{width:280,height:280}' "$JS_TARGET" && \
     grep -Fq 'size:{width:800,height:800}' "$JS_TARGET"; then
    log "Collection editor JS patch already present in $JS_TARGET"
    return
  fi

  if grep -Fq 'viewport:{width:150,height:150,type:"circle"}' "$JS_TARGET" && \
     grep -Fq 'boundary:{width:200,height:200}' "$JS_TARGET" && \
     grep -Fq 'size:{width:200,height:200}' "$JS_TARGET"; then
    log "Expected upstream collection editor JS found in $JS_TARGET, applying patch"

    sed -i 's/viewport:{width:150,height:150,type:"circle"}/viewport:{width:220,height:220,type:"square"}/' "$JS_TARGET"
    sed -i 's/boundary:{width:200,height:200}/boundary:{width:280,height:280}/' "$JS_TARGET"
    sed -i 's/size:{width:200,height:200}/size:{width:600,height:600}/' "$JS_TARGET"
    sed -i 's/\.querySelector(".cr-vp-circle")/.querySelector(".cr-viewport")/' "$JS_TARGET"

    if grep -Fq 'viewport:{width:220,height:220,type:"square"}' "$JS_TARGET" && \
       grep -Fq 'boundary:{width:280,height:280}' "$JS_TARGET" && \
       grep -Fq 'size:{width:600,height:600}' "$JS_TARGET"; then
      log "Collection editor JS patch applied successfully"
    else
      fail "Collection editor JS patch attempt ran, but verification failed"
    fi
  else
    fail "Compiled collection editor JS does not match expected upstream or patched code. Upstream may have changed."
  fi
}

patch_collection_editor_css() {
  CROPPY_CSS="$(grep -Ril '\.croppie-container \.cr-vp-circle{border-radius:50%}' /app/public/public/build 2>/dev/null | head -n 1 || true)"
  APP_CSS="$(grep -Ril '\.content-wrapper \.title-block \.thumbnail{border-radius:100%' /app/public/public/build 2>/dev/null | head -n 1 || true)"

  [ -n "$CROPPY_CSS" ] || fail "Could not find compiled Croppie CSS bundle"
  [ -n "$APP_CSS" ] || fail "Could not find compiled app CSS bundle"

  if grep -Fq '.croppie-container .cr-vp-circle{border-radius:0}' "$CROPPY_CSS" && \
     grep -Fq '.croppie-preview img{border-radius:8px' "$APP_CSS" && \
     grep -Fq '.content-wrapper .title-block .thumbnail{border-radius:8px' "$APP_CSS" && \
     grep -Fq '.collections img{border-radius:8px' "$APP_CSS"; then
    log "Collection editor CSS patch already present"
    return
  fi

  if grep -Fq '.croppie-container .cr-vp-circle{border-radius:50%}' "$CROPPY_CSS"; then
    log "Expected upstream Croppie CSS found in $CROPPY_CSS, applying patch"
    sed -i 's/\.croppie-container \.cr-vp-circle{border-radius:50%}/.croppie-container .cr-vp-circle{border-radius:0}/' "$CROPPY_CSS"
  else
    fail "Croppie CSS does not match expected upstream or patched code. Upstream may have changed."
  fi

  if grep -Fq '.cr-vp-circle.fa:before{' "$APP_CSS" && \
     grep -Fq '.content-wrapper .title-block .thumbnail{border-radius:100%' "$APP_CSS" && \
     grep -Fq '.collections img{border-radius:100%' "$APP_CSS" && \
     grep -Fq '.croppie-preview img{border-radius:100%' "$APP_CSS"; then
    log "Expected upstream app CSS found in $APP_CSS, applying patch"

    sed -i 's/\.cr-vp-circle\.fa:before{/\.cr-viewport.fa:before{/' "$APP_CSS"
    sed -i 's/\.content-wrapper \.title-block \.thumbnail{border-radius:100%/.content-wrapper .title-block .thumbnail{border-radius:8px/' "$APP_CSS"
    sed -i 's/\.collections img{border-radius:100%/.collections img{border-radius:8px/' "$APP_CSS"
    sed -i 's/\.croppie-preview img{border-radius:100%/.croppie-preview img{border-radius:8px/' "$APP_CSS"

    if grep -Fq '.croppie-preview img{border-radius:8px' "$APP_CSS" && \
       grep -Fq '.content-wrapper .title-block .thumbnail{border-radius:8px' "$APP_CSS" && \
       grep -Fq '.collections img{border-radius:8px' "$APP_CSS"; then
      log "App CSS patch applied successfully"
    else
      fail "App CSS patch attempt ran, but verification failed"
    fi
  else
    fail "App CSS does not match expected upstream or patched code. Upstream may have changed."
  fi
}

patch_php_thumbnails
patch_collection_editor_js
patch_collection_editor_css

exec sh /app/public/docker/entrypoint.sh
