#!/command/with-contenv bashio
# shellcheck shell=bash
# ==============================================================================
# Hetzner DNS DDNS Addon
# Main DDNS update script using Hetzner DNS API
# ==============================================================================

# API endpoint
API_BASE="https://dns.hetzner.com/api/v1"

# ------------------------------------------------------------------------------
# Get current public IP address
#
# Returns:
#   The current public IP address
# ------------------------------------------------------------------------------
get_current_ip() {
    local ip
    
    bashio::log.trace "${FUNCNAME[0]}"
    
    # Try multiple services to get IP
    ip=$(curl -s -4 https://api.ipify.org) || \
    ip=$(curl -s -4 https://icanhazip.com) || \
    ip=$(curl -s -4 https://ifconfig.me)
    
    if [ -z "${ip}" ]; then
        bashio::log.error "Failed to get current IP address"
        return 1
    fi
    
    bashio::log.debug "Current IP: ${ip}"
    echo "${ip}"
}

# ------------------------------------------------------------------------------
# Get IP from DNS record
#
# Arguments:
#   $1 - Domain name
# Returns:
#   The IP address from DNS
# ------------------------------------------------------------------------------
get_dns_ip() {
    local domain=$1
    local ip
    
    bashio::log.trace "${FUNCNAME[0]}"
    
    ip=$(nslookup "${domain}" 8.8.8.8 2>/dev/null | grep -A1 "Name:" | tail -1 | awk '{print $2}')
    
    if [ -z "${ip}" ]; then
        bashio::log.debug "Could not resolve DNS for ${domain}"
        return 1
    fi
    
    bashio::log.debug "DNS IP for ${domain}: ${ip}"
    echo "${ip}"
}

# ------------------------------------------------------------------------------
# Get API token from secure storage
#
# Returns:
#   The API token
# ------------------------------------------------------------------------------
get_api_token() {
    cat /root/.config/hetzner-dns-token
}

# ------------------------------------------------------------------------------
# Find DNS record ID for a domain in a zone
#
# Arguments:
#   $1 - API token
#   $2 - Zone ID
#   $3 - Domain name (fully qualified)
# Returns:
#   The record ID if found, empty string otherwise
# ------------------------------------------------------------------------------
find_record_id() {
    local token=$1
    local zone_id=$2
    local domain=$3
    local response
    local record_id
    
    bashio::log.trace "${FUNCNAME[0]}"
    
    response=$(curl -s -H "Auth-API-Token: ${token}" \
        "${API_BASE}/records?zone_id=${zone_id}")
    
    # Find the A record matching the domain
    record_id=$(echo "${response}" | jq -r \
        ".records[] | select(.type == \"A\" and .name == \"${domain}\") | .id")
    
    echo "${record_id}"
}

# ------------------------------------------------------------------------------
# Create or update DNS record
#
# Arguments:
#   $1 - Zone ID
#   $2 - Domain name
#   $3 - New IP address
# Returns:
#   0 on success, 1 on failure
# ------------------------------------------------------------------------------
update_dns() {
    local zone_id=$1
    local domain=$2
    local new_ip=$3
    local token
    local record_id
    local response
    local http_code
    
    bashio::log.trace "${FUNCNAME[0]}"
    
    token=$(get_api_token)
    
    # Find existing record
    bashio::log.info "Checking for existing DNS record..."
    record_id=$(find_record_id "${token}" "${zone_id}" "${domain}")
    
    if [ -n "${record_id}" ]; then
        # Update existing record
        bashio::log.info "Updating existing A record (ID: ${record_id})..."
        
        response=$(curl -s -w "\n%{http_code}" -X PUT \
            -H "Content-Type: application/json" \
            -H "Auth-API-Token: ${token}" \
            -d "{\"value\":\"${new_ip}\",\"ttl\":3600,\"type\":\"A\",\"name\":\"${domain}\",\"zone_id\":\"${zone_id}\"}" \
            "${API_BASE}/records/${record_id}")
        
        http_code=$(echo "${response}" | tail -1)
        
        if [ "${http_code}" = "200" ]; then
            bashio::log.info "DNS record updated successfully"
            return 0
        else
            bashio::log.error "Failed to update DNS record (HTTP ${http_code})"
            bashio::log.debug "Response: $(echo "${response}" | head -n -1)"
            return 1
        fi
    else
        # Create new record
        bashio::log.info "Creating new A record..."
        
        response=$(curl -s -w "\n%{http_code}" -X POST \
            -H "Content-Type: application/json" \
            -H "Auth-API-Token: ${token}" \
            -d "{\"value\":\"${new_ip}\",\"ttl\":3600,\"type\":\"A\",\"name\":\"${domain}\",\"zone_id\":\"${zone_id}\"}" \
            "${API_BASE}/records")
        
        http_code=$(echo "${response}" | tail -1)
        
        if [ "${http_code}" = "200" ]; then
            bashio::log.info "DNS record created successfully"
            return 0
        else
            bashio::log.error "Failed to create DNS record (HTTP ${http_code})"
            bashio::log.debug "Response: $(echo "${response}" | head -n -1)"
            return 1
        fi
    fi
}

# ------------------------------------------------------------------------------
# Calculate sleep time based on update interval
#
# Arguments:
#   $1 - Update interval (hourly|daily|weekly)
# Returns:
#   Sleep time in seconds
# ------------------------------------------------------------------------------
get_sleep_time() {
    local interval=$1
    
    bashio::log.trace "${FUNCNAME[0]}"
    
    case ${interval} in
        hourly)
            echo 3600
            ;;
        daily)
            echo 86400
            ;;
        weekly)
            echo 604800
            ;;
        *)
            bashio::log.warning "Unknown interval: ${interval}, defaulting to hourly"
            echo 3600
            ;;
    esac
}

# ==============================================================================
# MAIN LOGIC
# ==============================================================================
main() {
    local zone_id
    local domain
    local update_interval
    local sleep_time
    local current_ip
    local dns_ip
    
    bashio::log.trace "${FUNCNAME[0]}"
    
    # Get configuration
    zone_id=$(bashio::config 'zone_id')
    domain=$(bashio::config 'domain')
    update_interval=$(bashio::config 'update_interval')
    
    if [ -z "${zone_id}" ] || [ -z "${domain}" ]; then
        bashio::log.fatal "Zone ID and domain must be configured"
        exit 1
    fi
    
    bashio::log.info "Hetzner DNS DDNS starting..."
    bashio::log.info "Zone ID: ${zone_id}"
    bashio::log.info "Domain: ${domain}"
    bashio::log.info "Update interval: ${update_interval}"
    
    sleep_time=$(get_sleep_time "${update_interval}")
    bashio::log.info "Checking every ${sleep_time} seconds"
    
    # Main loop
    while true; do
        bashio::log.info "Checking IP address..."
        
        # Get current public IP
        if ! current_ip=$(get_current_ip); then
            bashio::log.error "Failed to get current IP, will retry later"
            sleep "${sleep_time}"
            continue
        fi
        
        # Get DNS IP
        dns_ip=$(get_dns_ip "${domain}")
        
        # Compare IPs
        if [ "${current_ip}" = "${dns_ip}" ]; then
            bashio::log.info "IP unchanged (${current_ip}), no update needed"
        else
            bashio::log.info "IP changed from ${dns_ip} to ${current_ip}, updating DNS..."
            
            if update_dns "${zone_id}" "${domain}" "${current_ip}"; then
                bashio::log.info "DNS update completed successfully"
            else
                bashio::log.error "DNS update failed"
            fi
        fi
        
        bashio::log.info "Next check in ${sleep_time} seconds"
        sleep "${sleep_time}"
    done
}

main "$@"
