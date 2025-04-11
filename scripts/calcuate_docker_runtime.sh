#!/bin/bash

container_id=$1

if [ -z "$container_id" ]; then
  echo "Please provide a container ID"
  exit 1
fi

# Get start and end times
start_time=$(docker inspect --format='{{.State.StartedAt}}' "$container_id")
end_time=$(docker inspect --format='{{.State.FinishedAt}}' "$container_id")

# Check if container has finished
if [[ "$end_time" == *"0001-01-01"* ]]; then
  echo "Container is still running"
  exit 1
fi

# Convert to timestamps (seconds since epoch)
start_timestamp=$(date -d "$start_time" +%s)
end_timestamp=$(date -d "$end_time" +%s)

# Calculate duration
duration=$((end_timestamp - start_timestamp))

# Format duration
days=$((duration / 86400))
hours=$(( (duration % 86400) / 3600 ))
minutes=$(( (duration % 3600) / 60 ))
seconds=$((duration % 60))

# Print result
if [ $days -gt 0 ]; then
  echo "Container runtime: ${days}d ${hours}h ${minutes}m ${seconds}s"
elif [ $hours -gt 0 ]; then
  echo "Container runtime: ${hours}h ${minutes}m ${seconds}s"
elif [ $minutes -gt 0 ]; then
  echo "Container runtime: ${minutes}m ${seconds}s"
else
  echo "Container runtime: ${seconds}s"
fi
