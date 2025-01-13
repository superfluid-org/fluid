#!/bin/bash

chains=(84532 11155111)

# Loop over each chainID
for chain in ${chains[@]}; do
  input_files=("broadcast/Deploy.s.sol/$chain/run-latest.json" "broadcast/DeploySupToken.s.sol/$chain/run-latest.json")

  output_folder="abi/"

  # Create the output folder if it does not exist
  mkdir -p "$output_folder"

  # Loop through each input file
  for input_file in "${input_files[@]}"; do
    # Extract contract names and addresses using jq
    contracts=$(jq -c '.transactions[] | {name: .contractName}' "$input_file")

    # Loop over each contract and create a JSON file with the contract address
    for contract in $contracts; do
      name=$(echo "$contract" | jq -r '.name')
      contract_json_file="out/$name.sol/$name.json"

      abi=$(jq -r '.abi' "$contract_json_file")

      echo "$abi" > "$output_folder/${name}.json"
    done
  done

  echo "[DONE]: ABI extracted to 'packages/contracts/abi' directory."
done
