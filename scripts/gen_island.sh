#!/bin/bash

# Define your command here
COMMAND="sozo execute 0x2d7e04c80d1407b843368a5708072d30c7966918286e77fb4ae7ef06c758b86 gen_island_per_block -c 0x4fc36d4c2cfac55877f99f973079673d593baf79807765d802270bd4a058f2d,4134154341"
# Number of iterations
ITERATIONS=528

for (( i=1; i<=ITERATIONS; i++ )); do
  # Execute the command and capture the output
  OUTPUT=$($COMMAND)
  
  # Check if the command was successful
  if [ $? -ne 0 ]; then
    echo "Command failed on iteration $i. Exiting."
    exit 1
  fi

  # Print the output of the command
  echo "Iteration $i output:"
  echo "$OUTPUT"
  echo
  # Sleep for 5 seconds before the next iteration
  # sleep 5
done

echo "Command executed successfully $ITERATIONS times."
