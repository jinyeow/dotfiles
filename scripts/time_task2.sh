#!/bin/bash

echo "Starting time. Using $1 with file $2."

if [ "$1" == "usel" ]; then
  echo "a"
  time ~/Dropbox/UNSW/2015\ -\ First\ Year/Semester\ 2\ -\ Spring/COMP1927/labs/week02/usel < "$2" > /dev/null
elif [ "$1" == "sort" ]; then
  echo "b"
  time sort -n < "$2" > /dev/null
fi
