#!/bin/sh
set -eu

TARGET=/app/public/src/Service/ImageHandler.php

if grep -q ", 450, " "$TARGET" && grep -q ", 900, " "$TARGET"; then
  echo "Thumbnail patch already present"
else
  echo "Applying thumbnail patch"
  sed -i 's/, 300, /, 450, /' "$TARGET"
  sed -i 's/, 600, /, 900, /' "$TARGET"
fi

exec sh /app/public/docker/entrypoint.sh
