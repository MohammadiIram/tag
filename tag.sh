#!/bin/bash

# File containing the repository URL and the path
config_file="./repo_url.txt"

# Check if the configuration file exists
if [ ! -f "$config_file" ]; then
  echo "Error: Configuration file not found: $config_file"
  exit 1
fi

# Read the repository URL and path from the file
read -r repo_url file_path < "$config_file"

# Validate that both the URL and the path have been read
if [[ -z "$repo_url" || -z "$file_path" ]]; then
  echo "Error: Repository URL or file path is missing in $config_file"
  exit 1
fi

# Define the full path to the file you want to check in the cloned directory
full_path="./kserve/$file_path"

# Initialize a variable to keep track of SHA mismatches
sha_mismatch_found=0

# Function to check SHAs and print results
check_sha() {
  local name="$1"
  local hash="$2"
  local tag="$3"

  if [ -z "$hash" ]; then
    echo "Error: The $name image is referenced using floating tags. Exiting..."
    exit 1
  fi

  # Fetch the SHA digest for the specific tag from Quay
  local quay_hash
  quay_hash=$(skopeo inspect docker://quay.io/modh/"$name":"$tag" | jq -r '.Digest')

  if [ -z "$quay_hash" ]; then
    echo -e "\e[31mError: Quay SHA could not be fetched for tag: $tag\e[0m"
    sha_mismatch_found=1
    return
  fi

  if [ "$hash" = "$quay_hash" ]; then
    echo -e "\e[32mRepository SHA ($hash) matches Quay SHA ($quay_hash) for tag: $tag\e[0m"
  else
    echo -e "\e[31mRepository SHA ($hash) does NOT match Quay SHA ($quay_hash) for tag: $tag\e[0m"
    sha_mismatch_found=1
  fi
}

# Main logic for processing the file and SHAs
main() {
  if [ -f "$full_path" ]; then
    echo "File found: $full_path"
    while IFS='=' read -r name hash; do
      check_sha "$name" "${hash#sha256:}" "${name#*-}"
    done < "$full_path"
  else
    echo "File not found: $full_path"
  fi

  # Check if any SHA mismatches were found
  if [ "$sha_mismatch_found" -ne 0 ]; then
    echo "One or more SHA mismatches were found."
    exit 1
  else
    echo "All SHA hashes match."
  fi
}

# Execute the main logic
main
