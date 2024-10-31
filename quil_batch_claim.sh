#!/bin/bash

set -euo pipefail

# QUIL Claim Tool

# Requirements:
# - bc
# - awk
# - qclient

# Default configurations
QCLIENT_PATH="$HOME/ceremonyclient/client/qclient-2.0.2.3-linux-amd64"
MAX_PARALLEL=3  # Maximum number of parallel processes

CONFIG_DIR=""
while [[ $# -gt 0 ]]; do
    case $1 in
        --path)
            CONFIG_DIR="$2"
            shift 2
            ;;
        --qclient-path)
            QCLIENT_PATH="$2"
            shift 2
            ;;
        --max-parallel)
            MAX_PARALLEL="$2"
            shift 2
            ;;
        --help|-h)
            echo "Usage: $0 --path <config_directory> [--qclient-path <qclient_path>] [--max-parallel <number>]"
            exit 0
            ;;
        *)
            echo "Unknown parameter passed: $1"
            exit 1
            ;;
    esac
done

# CONFIG_DIR validation
if [[ -z "$CONFIG_DIR" ]]; then
    echo "Error: --path argument is required."
    exit 1
fi

if [[ ! -d "$CONFIG_DIR" ]]; then
    echo "Error: The path provided is not a valid directory."
    exit 1
fi

INDEX_FILE="$CONFIG_DIR/q_index.txt"

generate_index() {
    local dir="$1"
    local index_file="$2"
    echo "Generating index file at $index_file"

    > "$index_file"

    find "$dir" -type f -name "config.yml" | while read -r config_file; do
        local config_dir
        config_dir=$(dirname "$(readlink -f "$config_file")")
        local keys_file="$config_dir/keys.yml"
        if [[ -f "$keys_file" ]]; then
            disable_grpc_in_config "$config_dir"

            local balance_output
            balance_output=$("$QCLIENT_PATH" token balance --config "$config_dir" 2>/dev/null)

            local account
            account=$(echo "$balance_output" | grep -o 'Account 0x[0-9a-fA-F]*' | awk '{print $2}')
            if [[ -n "$account" ]]; then
                echo "$account:$config_dir" >> "$index_file"
                echo "Found account $account in config $config_dir"
            else
                echo "Warning: Could not extract account address from balance output for config $config_dir"
            fi
        fi
    done
}

load_configs() {
    declare -g -A CONFIGS
    CONFIGS=()

    for attempt in {1..2}; do
        if [[ -f "$INDEX_FILE" && -r "$INDEX_FILE" ]]; then
            while IFS=: read -r addr config_dir; do
                [[ -z "$addr" || -z "$config_dir" ]] && continue
                CONFIGS["$addr"]="$config_dir"
            done < "$INDEX_FILE"
            echo "Loaded ${#CONFIGS[@]} configurations from index file."
            return 0  # Success
        elif [[ $attempt -eq 1 ]]; then
            echo "Index file not found or not readable at $INDEX_FILE"
            echo "Generating index file..."
            generate_index "$CONFIG_DIR" "$INDEX_FILE"
        else
            echo "Error: Failed to generate index file at $INDEX_FILE"
            exit 1
        fi
    done
}

disable_grpc_in_config() {
    local config_dir="$1"
    local config_file="$config_dir/config.yml"
    local backup_file="${config_file}.bak"

    echo "Processing: $config_file"

    if [[ ! -f "$config_file" ]]; then
        echo "Warning: Config file not found: $config_file"
        return
    fi

    cp "$config_file" "$backup_file"

    if grep -q "listenGrpcMultiaddr:" "$config_file"; then
        sed -i 's/listenGrpcMultiaddr:.*$/listenGrpcMultiaddr: ""/' "$config_file"
    else
        echo 'listenGrpcMultiaddr: ""' >> "$config_file"
    fi

    echo "✓ gRPC Updated: $config_file"

    if grep -q 'listenGrpcMultiaddr: ""' "$config_file"; then
        echo "✓ Verified change in: $config_file"
    else
        echo "! Failed to verify change in: $config_file"
        echo "Restoring backup..."
        mv "$backup_file" "$config_file"
    fi
}

disable_grpc_in_configs() {
    for addr in "${!CONFIGS[@]}"; do
        local config_dir="${CONFIGS[$addr]}"
        disable_grpc_in_config "$config_dir"
    done

    echo "Processing completed!"
}

get_balances() {
    local result_file="$CONFIG_DIR/result.txt"
    > "$result_file"
    echo "Account | Balance | Config" > "$result_file"

    local -a pids=()
    local tmp_dir
    tmp_dir=$(mktemp -d)

    for addr in "${!CONFIGS[@]}"; do
        local config_dir="${CONFIGS[$addr]}"

        (
            echo "Checking balance for config: $config_dir"
            local output balance rounded_balance
            output=$("$QCLIENT_PATH" token balance --config "$config_dir" 2>&1)
            balance=$(echo "$output" | grep 'Total balance:' | awk '{print $3}')
            rounded_balance=$(printf "%.12f" "$balance")

            echo "$rounded_balance" > "$tmp_dir/$addr.balance"
            echo "$addr : $rounded_balance QUIL : $config_dir" > "$tmp_dir/$addr.result"
        ) &

        pids+=($!)

        if (( ${#pids[@]} >= MAX_PARALLEL )); then
            wait -n
            for i in "${!pids[@]}"; do
                if ! kill -0 "${pids[i]}" 2>/dev/null; then
                    unset 'pids[i]'
                fi
            done
        fi
    done

    wait

    for result_file_part in "$tmp_dir"/*.result; do
        if [[ -f "$result_file_part" ]]; then
            cat "$result_file_part" >> "$result_file"
        fi
    done

    local total_balance=0
    for balance_file in "$tmp_dir"/*.balance; do
        if [[ -f "$balance_file" ]]; then
            local balance
            balance=$(cat "$balance_file")
            total_balance=$(echo "$total_balance + $balance" | bc)
        fi
    done

    rm -rf "$tmp_dir"

    echo "Results saved to $result_file"
    cat "$result_file"
    echo "Total Balance: $total_balance QUIL"
}

merge_coins() {
    local -a pids=()

    for addr in "${!CONFIGS[@]}"; do
        local config_dir="${CONFIGS[$addr]}"

        (
            mapfile -t COIN_ADDRS < <("$QCLIENT_PATH" token coins --config "$config_dir" | grep -o '0x[0-9a-fA-F]\{64\}')

            if [ ${#COIN_ADDRS[@]} -lt 2 ]; then
                echo "$addr: Not enough coins to merge. Found ${#COIN_ADDRS[@]} coin(s)."
                exit 0
            fi

            echo "$addr: Merging ${#COIN_ADDRS[@]} coins..."
            "$QCLIENT_PATH" token merge "${COIN_ADDRS[@]}" --config "$config_dir"
        ) &

        pids+=($!)

        if (( ${#pids[@]} >= MAX_PARALLEL )); then
            wait -n
            for i in "${!pids[@]}"; do
                if ! kill -0 "${pids[i]}" 2>/dev/null; then
                    unset 'pids[i]'
                fi
            done
        fi
    done

    wait

    echo "Coin merging completed!"
}

transfer_coins() {
    local recipient="$1"
    local -a pids=()

    for addr in "${!CONFIGS[@]}"; do
        local config_dir="${CONFIGS[$addr]}"

        (
            mapfile -t coin_addrs < <("$QCLIENT_PATH" token coins --config "$config_dir" | grep -o '0x[0-9a-fA-F]\{64\}')

            if [ ${#coin_addrs[@]} -eq 0 ]; then
                echo "$addr: No coin tokens found, skipping"
                return
            fi

            for coin_addr in "${coin_addrs[@]}"; do
                echo "$addr: Transferring coin $coin_addr to $recipient"
                "$QCLIENT_PATH" token transfer "$recipient" "$coin_addr" --config "$config_dir" 2>&1 | while IFS= read -r line; do
                    if [[ $line == *"Pending Transaction"* ]]; then
                        echo "$addr: $line"
                    fi
                    echo "$addr: $line"
                done
            done
        ) &

        pids+=($!)

        if (( ${#pids[@]} >= MAX_PARALLEL )); then
            wait -n
            pids=("${pids[@]/$!}")  # Remove completed PID
        fi
    done

    wait
    echo "All transfers completed"
}

mint_tokens() {
    for addr in "${!CONFIGS[@]}"; do
        local config_dir="${CONFIGS[$addr]}"
        local store_dir="$config_dir/store"

        if [[ -d "$store_dir" ]]; then
            echo "$addr: Minting tokens in $config_dir"
            "$QCLIENT_PATH" token mint all --config "$config_dir"
        else
            echo "$addr: No 'store' directory found in $config_dir, skipping"
        fi
    done

    echo "Minting process completed!"
}

# Load configurations at startup
load_configs

# Main menu loop
while true; do
    echo
    echo "=== QUIL Claim Tool ==="
    echo "Configuration:"
    echo "  1) Disable gRPC in configs"
    echo "  2) Refresh account index"
    echo
    echo "Account Data:"
    echo "  3) View account balances"
    echo
    echo "Token Management:"
    echo "  4) Mint tokens"
    echo "  5) Merge coins"
    echo "  6) Collect all coins to one account"
    echo
    echo "System:"
    echo "  0) Exit"
    echo "===================="
    read -rp "Enter your choice [0-6]: " choice

    case $choice in
        1)
            echo "Disabling gRPC in configs..."
            disable_grpc_in_configs
            ;;
        2)
            echo "Refreshing account index..."
            generate_index "$CONFIG_DIR" "$INDEX_FILE"
            load_configs
            ;;
        3)
            echo "Getting balances..."
            get_balances
            ;;
        4)
            echo "Minting tokens..."
            mint_tokens
            ;;
        5)
            echo "Merging coins..."
            merge_coins
            ;;
        6)
            read -rp "Enter recipient address (0x...): " recipient
            if [[ ! "$recipient" =~ ^0x[0-9a-fA-F]+$ ]]; then
                echo "Invalid recipient address"
            else
                transfer_coins "$recipient"
            fi
            ;;
        0)
            echo "Exiting."
            exit 0
            ;;
        *)
            echo "Invalid choice."
            ;;
    esac
done
