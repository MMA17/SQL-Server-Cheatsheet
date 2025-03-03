#!/bin/bash

# Source and destination database's configuration
SOURCE_SERVER="X.X.X.X"                        # REPLACE WITH NEW CREDENTIAL
SOURCE_USER="source_user"
SOURCE_PASS="pass"
SOURCE_DB="databaseA"

DEST_SERVER="Y.Y.Y.Y"
DEST_USER="destination_user"
DEST_PASS="pass"
DEST_DB="databaseA"

if [ "$#" -ne 1 ]; then
    echo "Usage: $0 <tables_file.txt>" | tee -a "$MAIN_LOG"
    exit 1
fi

TABLES_FILE=$1
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

# Main log file
MAIN_LOG="log/migration_${TIMESTAMP}.log"

echo "Starting database migration at $(date)" | tee -a "$MAIN_LOG"

# Check if the tables file exists
if [ ! -f "$TABLES_FILE" ]; then
    echo "Error: File '$TABLES_FILE' not found." | tee -a "$MAIN_LOG"
    exit 1
fi

# Process each table from the file
echo "Reading tables from file: $TABLES_FILE" | tee -a "$MAIN_LOG"

while IFS= read -r TABLE || [ -n "$TABLE" ]; do
    # Skip empty lines
    [[ -z "$TABLE" ]] && continue
    
    # Remove any carriage returns
    TABLE=$(echo "$TABLE" | tr -d '\r')
    TABLE_LOG="log/migration_${TIMESTAMP}_tables.log"
    
    echo "Processing table: $TABLE" | tee -a "$MAIN_LOG" 
    
    # Export data from source
    echo "$(date): Starting export for $TABLE" | tee -a "$TABLE_LOG"
    bcp "[$SOURCE_DB].[dbo].[$TABLE]" out "data-csv/${TABLE}.csv" \
        -S "$SOURCE_SERVER" -U "$SOURCE_USER" -P "$SOURCE_PASS" \
        -c -t "@,@ " -r "\n" &>> "$TABLE_LOG"
    
    if [ $? -eq 0 ]; then
        echo "$(date): Export completed successfully for $TABLE" | tee -a "$TABLE_LOG"
    else
        echo "$(date): ERROR - Export failed for $TABLE" | tee -a "$TABLE_LOG"
        continue
    fi
    
    # Import data to destination
    echo "$(date): Starting import for $TABLE" | tee -a "$TABLE_LOG"
    bcp "[$DEST_DB].[dbo].[$TABLE]" in "data-csv/${TABLE}.csv" \
        -S "$DEST_SERVER" -U "$DEST_USER" -P "$DEST_PASS" \
        -c -t "@,@ " -r "\n" -u -E &>> "$TABLE_LOG"

    if [ $? -eq 0 ]; then
        echo "$(date): Import completed successfully for $TABLE" | tee -a "$TABLE_LOG"
    else
        echo "$(date): ERROR - Import failed for $TABLE" | tee -a "$TABLE_LOG"
    fi
    
    # Add separator in main log
    echo "----------------------------------------" | tee -a "$MAIN_LOG"
done < "$TABLES_FILE"

echo "Migration process completed at $(date)" | tee -a "$MAIN_LOG"
