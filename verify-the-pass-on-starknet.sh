#!/usr/bin/env bash

# Check if the arguments are provided
if [ $# -ne 3 ]; then
    echo "Usage: $0 <the_pass_verifier_address> <calldata_file> <x>"
    exit 1
fi

string_to_hex() {
    input_string="$1"
    hex_string="0x"
    for ((i = 0; i < ${#input_string}; i++)); do
        hex_char=$(printf "%x" "'${input_string:$i:1}")
        hex_string+=$hex_char
    done
    echo "$hex_string"
}

# Assign arguments to variables
contract_address=$1
calldata_file=$2
x=$(string_to_hex $3)

# Check if the file exists
if [ ! -f "$calldata_file" ]; then
    echo "Error: File '$calldata_file' not found."
    exit 1
fi

# Read calldata from the specified file
calldata=$(<$calldata_file)

# Pass the calldata to the sncast command
sncast \
    --wait  \
    invoke \
    --contract-address "$contract_address" \
    --function "claim_pass" \
    --calldata $calldata $x \
    --fee-token eth
