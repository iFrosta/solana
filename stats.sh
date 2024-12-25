#!/bin/bash
# Made by @ifrosta (https://github.com/iFrosta)
# bash <(curl -s https://raw.githubusercontent.com/iFrosta/solana/main/stats.sh)

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

# Sorting and removing the last 1000 validators from consideration
sorted_validator_data=$(echo "$validator_data" | jq '[.validators[]] | sort_by(.epochCredits) | reverse')
sorted_validator_data_trimmed=$(echo "$validator_data" | jq '[.validators[]] | sort_by(.epochCredits) | reverse | .[0:-1000]')

epoch_info=$(solana epoch-info --output json)
epoch=$(echo "$epoch_info" | jq -r '.epoch')
epoch_completed_percent=$(echo "$epoch_info" | jq -r '.epochCompletedPercent')
epoch_completed_percent=$(printf "%.1f" "$epoch_completed_percent")

previous_epoch=$((epoch - 1))
next_epoch=$((epoch + 1))

average_credits=$(echo "$sorted_validator_data_trimmed" | jq -r '[.[] | select(.epochCredits > 0 and .activatedStake > 0 and .skipRate != null) | .epochCredits] | add / length')
average_credits=$(printf "%.0f" $average_credits)

validator_info=$(echo "$sorted_validator_data" | jq -r --arg VALIDATOR_IDENTITY "$VALIDATOR_IDENTITY" '.[] | select(.identityPubkey == $VALIDATOR_IDENTITY)')
if [[ -z "$validator_info" ]]; then
  echo "Error: Failed to fetch validator info. Identity - $VALIDATOR_IDENTITY"
  exit 1
fi

validator_credits=$(echo "$validator_info" | jq -r '.epochCredits')
validator_version=$(echo "$validator_info" | jq -r '.version')
validator_stake=$(echo "$validator_info" | jq -r '.activatedStake')
validator_commission=$(echo "$validator_info" | jq -r '.commission')
validator_stake=$(printf "%.0f" $(bc <<< "scale=0; $validator_stake / 1000000000"))
validator_place=$(echo "$sorted_validator_data" | jq -r --arg VALIDATOR_ID "$VALIDATOR_IDENTITY" 'to_entries[] | select(.value.identityPubkey == $VALIDATOR_ID) | (.key + 1)')

total_validators=$(echo "$sorted_validator_data" | jq -r 'length')

leader_info=$(echo "$sorted_validator_data" | jq -r '.[0]')
leader_credits=$(echo "$leader_info" | jq -r '.epochCredits')
leader_pubkey=$(echo "$leader_info" | jq -r '.identityPubkey')
diff_leader=$((validator_credits - leader_credits))

cluster_version=$(echo "$sorted_validator_data_trimmed" | jq -r '[group_by(.version) | max_by(length)][0][0].version')

leader_slots=$(solana leader-schedule --epoch "$epoch" | grep "$VALIDATOR_IDENTITY" | wc -l)
previous_leader_slots=$(solana leader-schedule --epoch "$previous_epoch" | grep "$VALIDATOR_IDENTITY" | wc -l)
next_leader_slots=$(solana leader-schedule --epoch "$next_epoch" | grep "$VALIDATOR_IDENTITY" | wc -l)

diff_cluster=$((validator_credits - average_credits))
diff_cluster_minus_3percent=$(echo "scale=0; ($validator_credits - $average_credits * 0.97)/1" | bc)

colorize_diff() {
  if (( $(echo "$1 > 0" | bc -l) )); then
    echo -e "${GREEN}$1${NC}"
  else
    echo -e "${RED}$1${NC}"
  fi
}

# Conditional colorization for leader slots
colorize_leader_slots() {
  if [[ $leader_slots -eq 0 ]]; then
    echo -e "${RED}$leader_slots${NC}"
  elif [[ $leader_slots -gt $previous_leader_slots ]]; then
    echo -e "${GREEN}$leader_slots${NC}"
  else
    echo -e "$leader_slots"
  fi
}

# Conditional colorization for next epoch slots
colorize_next_epoch_slots() {
  if [[ $next_leader_slots -gt $leader_slots ]]; then
    echo -e "${GREEN}$next_leader_slots${NC}"
  else
    echo -e "${RED}$next_leader_slots${NC}"
  fi
}

# Conditional colorization for stake
colorize_stake() {
  if (( validator_stake <= 1000 )); then
    echo -e "${RED}$validator_stake SOL${NC}"
  else
    echo -e "$validator_stake SOL"
  fi
}

printf "%-20s %-20s %-20s %-20s\n" "" "Credits AVG" "AVG 97%" "Diff"
printf "%-20s %-20s %-20s %-20s\n" "You" "$validator_credits" "-" "-"
printf "%-20s %-20s %-20s %-20s\n" "Cluster" "$average_credits" "$(($average_credits * 97 / 100))" "$(colorize_diff $diff_cluster_minus_3percent)"
echo ""
printf "%-20s %-20s\n" "Epoch" "$epoch"
printf "%-20s %-20s\n" "Epoch Completed" "$epoch_completed_percent%"
echo ""
printf "%-20s %-20s\n" "Leader Slots  " "$(colorize_leader_slots)"
printf "%-20s %-20s\n" "Previous epoch" "$previous_leader_slots"
printf "%-20s %-20s\n" "Next epoch    " "$(colorize_next_epoch_slots)"
echo ""
printf "%-20s %-20s\n" "Place" "$validator_place/$total_validators"
printf "%-20s %-20s\n" "Stake" "$(colorize_stake)"
printf "%-20s %-20s\n" "Commission" "$validator_commission%"
printf "%-20s %-20s\n" "Version" "$validator_version (Cluster: $cluster_version)"