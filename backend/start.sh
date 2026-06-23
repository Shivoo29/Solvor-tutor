#!/bin/bash
set -e

# If FIREBASE_SA_B64 env var is set, decode it to the expected path
if [ -n "$FIREBASE_SA_B64" ]; then
  mkdir -p src
  echo "$FIREBASE_SA_B64" | base64 -d > src/serviceAccountKey.json
fi

# Run migrations
node src/db/migrate.js

exec node index.js
