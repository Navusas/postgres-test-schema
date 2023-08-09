#!/bin/bash
###################################################################
# Creates a file with 1 table and 1600 columns in it
#
# Note: Postgresql only supports 1600 columns as a hard limit
###################################################################


# Initialize the output file
OUTPUT_FILE='3-big-table.sql'

# Initialize your SQL schema and table
echo "CREATE SCHEMA big;
CREATE TABLE BigTable(" > $OUTPUT_FILE

# Loop X times to add new columns
for i in $(seq 1 1600)
do 
  echo "column_$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | head -c 6) varchar(255)," >> $OUTPUT_FILE
done

# Remove the last comma and close the table creation statement
sed -i '$ s/,$/)/' $OUTPUT_FILE
