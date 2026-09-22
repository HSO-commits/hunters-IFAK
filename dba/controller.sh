#!/bin/bash

# 1. Check if a script name was provided as an argument
if [ -z "$1" ]; then
  echo "Usage: $0 <scriptname.sql>"
  exit 1
fi

SCRIPT_NAME=$1

# 2. Check if the provided file actually exists
if [ ! -f "$SCRIPT_NAME" ]; then
  echo "Error: File '$SCRIPT_NAME' not found!"
  exit 1
fi

# 3. Array of target databases (excluding postgres, template0, template1)
DATABASES=()

# 4. Loop through each database and run the script
for DB in "${DATABASES[@]}"; do
  echo "### $DB ####"

  sudo -u postgres psql -d "$DB" < "$SCRIPT_NAME"

  echo "### End of $DB ###"
  echo "" # Adds an empty line between outputs for easier reading
done

