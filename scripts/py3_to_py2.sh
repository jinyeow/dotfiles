#!/usr/bin/bash

for f in $(ag '#!/usr/bin/env python *$' -l .)
do
  echo -n "Editing $f..."
  sed 's/#\!\/usr\/bin\/env python/#\!\/usr\/bin\/env python2/g' "$f" > tmp
  cat tmp > "$f"
  rm tmp
  echo "done"
done
