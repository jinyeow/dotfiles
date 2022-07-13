#!/bin/bash

#
# Sorts all sub-directories in the current directory into alphabetic sub-folders.
# e.g.
#   .
#   |--Ant
#   |--amy
#   |--Baby
#   |--ben
# becomes:
#   .
#   |--A
#   |  |--Ant
#   |  |--amy
#   |--B
#   |  |--Baby
#   |  |--ben

for dir in */ ; do
  # Grab sub-string from directory name; in this case the first letter
  start=${dir:0:1}

  # Create directory; uses -p flag to avoid error on duplication.
  # The ^^ command makes things upper case.
  mkdir -p ${start^^}

  # Move dir into the new created directory
  mv "$dir" ${start^^}
done
