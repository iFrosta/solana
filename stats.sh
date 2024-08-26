#!/bin/bash
# Made by @ifrosta (https://github.com/iFrosta)

VALIDATOR_IDENTITY=$(solana address)
if [[ -z "$VALIDATOR_IDENTITY" ]]; then
  echo "Error: Unable to fetch validator identity. Please make sure the Solana CLI is configured properly."
  exit 1
fi

GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

validator_data=$(solana validators --output json)

if [[ -z "$validator_data" ]]; then
  echo "Error: Failed to fetch validator data."
  exit 1
fi

sorted_validator_data=$(echo "$validator_data" | jq '[.validators[]] | sort_by(.epochCredits) | reverse')

epoch_info=$(solana epoch-info --output json)
epoch=$(echo "$epoch_info" | jq -r '.epoch')
epoch_completed_percent=$(echo "$epoch_info" | jq -r '.epochCompletedPercent')
epoch_completed_percent=$(printf "%.1f" "$epoch_completed_percent")

average_credits=$(echo "$sorted_validator_data" | jq -r '[.[] | select(.epochCredits > 0 and .activatedStake > 0 and .skipRate != null) | .epochCredits] | add / length')
average_credits=$(printf "%.0f" $average_credits) 


validator_info=$(echo "$sorted_validator_data" | jq -r --arg VALIDATOR_IDENTITY "$VALIDATOR_IDENTITY" '.[] | select(.identityPubkey == $VALIDATOR_IDENTITY)')
if [[ -z "$validator_info" ]]; then
  echo "Error: Failed to fetch validator info."
  exit 1
fi

validator_credits=$(echo "$validator_info" | jq -r '.epochCredits')
validator_version=$(echo "$validator_info" | jq -r '.version')
validator_stake=$(echo "$validator_info" | jq -r '.activatedStake')
validator_stake=$(printf "%.0f" $(bc <<< "scale=0; $validator_stake / 1000000000"))
validator_place=$(echo "$sorted_validator_data" | jq -r --arg VALIDATOR_ID "$VALIDATOR_IDENTITY" 'to_entries[] | select(.value.identityPubkey == $VALIDATOR_ID) | (.key + 1)')

leader_info=$(echo "$sorted_validator_data" | jq -r '.[0]')
leader_credits=$(echo "$leader_info" | jq -r '.epochCredits')
leader_pubkey=$(echo "$leader_info" | jq -r '.identityPubkey')
diff_leader=$((validator_credits - leader_credits))

cluster_version=$(echo "$sorted_validator_data" | jq -r '[group_by(.version) | max_by(length)][0][0].version')

leader_slots=$(solana leader-schedule --epoch "$epoch" | grep "$VALIDATOR_IDENTITY" | wc -l)

diff_cluster=$((validator_credits - average_credits))
diff_cluster_minus_3percent=$(echo "scale=0; ($validator_credits - $average_credits * 0.97)/1" | bc)


colorize_diff() {
  if (( $(echo "$1 > 0" | bc -l) )); then
    echo -e "${GREEN}$1${NC}"
  else
    echo -e "${RED}$1${NC}"
  fi
}

printf "%-20s %-20s %-20s %-20s\n" "" "Credits AVG" "AVG 97%" "Diff"
printf "%-20s %-20s %-20s %-20s\n" "You" "$validator_credits" "-" "-"
# printf "%-20s %-20s %-20s %-20s\n" "Leader" "$leader_credits" "-" "$(colorize_diff $diff_leader)"
printf "%-20s %-20s %-20s %-20s\n" "Cluster" "$average_credits" "$(($average_credits * 97 / 100))" "$(colorize_diff $diff_cluster_minus_3percent)"
# printf "%-20s %-20s %-20s %-20s\n" "Active Stake" "$active_stake_credits" "$(($active_stake_credits * 97 / 100))" "$(colorize_diff $diff_active_stake_minus_3percent)"
echo ""
printf "%-20s %-20s\n" "Epoch" "$epoch"
printf "%-20s %-20s\n" "Epoch Completed" "$epoch_completed_percent%"
echo ""
printf "%-20s %-20s\n" "Place" "$validator_place"
printf "%-20s %-20s\n" "Leader Slots" "$leader_slots"
printf "%-20s %-20s\n" "Stake" "$validator_stake SOL"
printf "%-20s %-20s\n" "Version" "$validator_version (Cluster: $cluster_version)"