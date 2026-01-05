#!/bin/bash
#
# hostmask.sh - Manage /etc/hosts routing with config file support
#
# Bypasses DNS resolution by adding entries to /etc/hosts.
# When entries removed, normal DNS resolution resumes.
#
# Usage:
#   hostmask.sh -c <config.json> on [profile]    Apply profile (default: first profile)
#   hostmask.sh -c <config.json> off             Remove all config hosts (use DNS)
#   hostmask.sh -c <config.json> status          Show current routing status
#   hostmask.sh -c <config.json> list            List available profiles
#   hostmask.sh -c <config.json> init            Create default hosts.json if not exists
#
# Config format (JSON):
# {
#   "profiles": {
#     "local": {
#       "ip": "192.168.1.100",
#       "description": "local dev server",
#       "hosts": ["api.example.com", "assets.example.com"]
#     }
#   }
# }
#

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

CONFIG_FILE=""
ACTION=""
PROFILE=""

# Parse arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    -c|--config)
      CONFIG_FILE="$2"
      shift 2
      ;;
    *)
      if [[ -z "$ACTION" ]]; then
        ACTION="$1"
      elif [[ -z "$PROFILE" ]]; then
        PROFILE="$1"
      fi
      shift
      ;;
  esac
done

# Default action
ACTION="${ACTION:-status}"

# Validate config file
if [[ -z "$CONFIG_FILE" ]]; then
  echo -e "${RED}Error: Config file required. Use -c <config.json>${NC}"
  echo "Usage: $0 -c <config.json> [on|off|status|list|init] [profile]"
  exit 1
fi

# Handle init action before checking if file exists
if [[ "$ACTION" == "init" ]]; then
  if [[ -f "$CONFIG_FILE" ]]; then
    echo -e "${YELLOW}Config file already exists: $CONFIG_FILE${NC}"
    exit 0
  fi

  # Create default hosts.json
  cat > "$CONFIG_FILE" << 'INITEOF'
{
  "profiles": {
    "local": {
      "ip": "192.168.1.100",
      "description": "local dev server",
      "hosts": [
        "api.example.com"
      ]
    }
  }
}
INITEOF

  echo -e "${GREEN}Created default config: $CONFIG_FILE${NC}"
  echo -e "${CYAN}Edit the file to add your project's hosts${NC}"
  exit 0
fi

if [[ ! -f "$CONFIG_FILE" ]]; then
  echo -e "${RED}Error: Config file not found: $CONFIG_FILE${NC}"
  echo -e "${YELLOW}Hint: Run '$0 -c $CONFIG_FILE init' to create a default config${NC}"
  exit 1
fi

# Check for jq
if ! command -v jq &> /dev/null; then
  echo -e "${RED}Error: jq is required. Install with: sudo apt install jq${NC}"
  exit 1
fi

# Get all hosts from all profiles (for removal)
get_all_hosts() {
  jq -r '.profiles | to_entries[] | .value.hosts[]' "$CONFIG_FILE" 2>/dev/null | sort -u
}

# Get profile names
get_profiles() {
  jq -r '.profiles | keys[]' "$CONFIG_FILE" 2>/dev/null
}

# Get first profile name
get_default_profile() {
  jq -r '.profiles | keys[0]' "$CONFIG_FILE" 2>/dev/null
}

# Get profile IP
get_profile_ip() {
  local profile="$1"
  jq -r ".profiles[\"$profile\"].ip // empty" "$CONFIG_FILE" 2>/dev/null
}

# Get profile description
get_profile_desc() {
  local profile="$1"
  jq -r ".profiles[\"$profile\"].description // \"$profile\"" "$CONFIG_FILE" 2>/dev/null
}

# Get profile hosts
get_profile_hosts() {
  local profile="$1"
  jq -r ".profiles[\"$profile\"].hosts[]" "$CONFIG_FILE" 2>/dev/null
}

# Remove hosts from /etc/hosts
remove_hosts() {
  local hosts="$1"
  for host in $hosts; do
    # Escape dots for sed
    local escaped=$(echo "$host" | sed 's/\./\\./g')
    sudo sed -i "/[[:space:]]${escaped}$/d" /etc/hosts 2>/dev/null || true
    sudo sed -i "/[[:space:]]${escaped}[[:space:]]/d" /etc/hosts 2>/dev/null || true
  done
}

# Add host entry
add_host() {
  local ip="$1"
  local host="$2"
  echo "$ip $host" | sudo tee -a /etc/hosts > /dev/null
}

case $ACTION in
  on)
    # Use specified profile or default
    PROFILE="${PROFILE:-$(get_default_profile)}"

    if [[ -z "$PROFILE" ]]; then
      echo -e "${RED}Error: No profiles found in config${NC}"
      exit 1
    fi

    IP=$(get_profile_ip "$PROFILE")
    DESC=$(get_profile_desc "$PROFILE")

    if [[ -z "$IP" ]]; then
      echo -e "${RED}Error: Profile '$PROFILE' not found or has no IP${NC}"
      exit 1
    fi

    echo -e "${GREEN}Applying profile: $PROFILE ($DESC)${NC}"

    # Remove all managed hosts first
    ALL_HOSTS=$(get_all_hosts)
    remove_hosts "$ALL_HOSTS"

    # Add profile hosts
    while IFS= read -r host; do
      add_host "$IP" "$host"
      echo -e "  ${GREEN}+${NC} $host → $IP"
    done < <(get_profile_hosts "$PROFILE")

    echo -e "${GREEN}Done. Routing via $DESC${NC}"
    ;;

  off)
    echo -e "${YELLOW}Removing hosts intercepts (using DNS)...${NC}"

    ALL_HOSTS=$(get_all_hosts)
    remove_hosts "$ALL_HOSTS"

    for host in $ALL_HOSTS; do
      echo -e "  ${YELLOW}-${NC} $host → DNS"
    done

    echo -e "${BLUE}Done. Normal DNS resolution active${NC}"
    ;;

  status)
    echo -e "${BLUE}Hosts routing status:${NC}"
    echo -e "${CYAN}Config: $CONFIG_FILE${NC}"
    echo ""

    # Check each host from config
    ALL_HOSTS=$(get_all_hosts)
    for host in $ALL_HOSTS; do
      escaped=$(echo "$host" | sed 's/\./\\./g')
      entry=$(grep -v "^#" /etc/hosts 2>/dev/null | grep -E "[[:space:]]${escaped}($|[[:space:]])" || true)

      if [[ -n "$entry" ]]; then
        ip=$(echo "$entry" | awk '{print $1}')
        # Find which profile this IP belongs to
        profile_match=""
        for p in $(get_profiles); do
          if [[ "$(get_profile_ip "$p")" == "$ip" ]]; then
            profile_match="$p"
            break
          fi
        done
        if [[ -n "$profile_match" ]]; then
          echo -e "  ${GREEN}LOCAL${NC} [$profile_match]: $host → $ip"
        else
          echo -e "  ${YELLOW}CUSTOM${NC}: $host → $ip"
        fi
      else
        echo -e "  ${BLUE}DNS${NC}: $host → (resolved via DNS)"
      fi
    done
    ;;

  list)
    echo -e "${BLUE}Available profiles in $CONFIG_FILE:${NC}"
    echo ""
    for profile in $(get_profiles); do
      ip=$(get_profile_ip "$profile")
      desc=$(get_profile_desc "$profile")
      echo -e "  ${GREEN}$profile${NC}: $ip"
      echo -e "    ${CYAN}$desc${NC}"
      echo -e "    Hosts:"
      for host in $(get_profile_hosts "$profile"); do
        echo -e "      - $host"
      done
      echo ""
    done
    ;;

  *)
    echo -e "${RED}Unknown action: $ACTION${NC}"
    echo "Usage: $0 -c <config.json> [on|off|status|list] [profile]"
    exit 1
    ;;
esac
