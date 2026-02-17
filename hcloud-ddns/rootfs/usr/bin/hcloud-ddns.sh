#!/command/with-contenv bashio
# shellcheck shell=bash
# ==============================================================================
# Hetzner Cloud DDNS Addon
# Main DDNS update script
# ==============================================================================

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
# Update DNS record via hcloud
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
    local zonefile
    local record_name
    local zone_name
    
    bashio::log.trace "${FUNCNAME[0]}"
    
    # Export current zone file
    bashio::log.info "Exporting zone file for zone ${zone_id}..."
    if ! zonefile=$(/usr/local/bin/hcloud dns zone export "${zone_id}" 2>&1); then
        bashio::log.error "Failed to export zone file: ${zonefile}"
        return 1
    fi
    
    # Extract zone name and record name
    # If domain is "test.example.com" and zone is "example.com", record_name is "test"
    zone_name=$(echo "${zonefile}" | grep -m1 "^\$ORIGIN" | awk '{print $2}' | sed 's/\.$//')
    
    if [ -z "${zone_name}" ]; then
        bashio::log.error "Could not determine zone name from zone file"
        return 1
    fi
    
    bashio::log.debug "Zone name: ${zone_name}"
    
    # Calculate record name
    if [ "${domain}" = "${zone_name}" ]; then
        record_name="@"
    else
        record_name="${domain%."${zone_name}"}"
    fi
    
    bashio::log.debug "Record name: ${record_name}"
    
    # Create temporary file for zone file
    local temp_zonefile="/tmp/zonefile.txt"
    echo "${zonefile}" > "${temp_zonefile}"
    
    # Check if record exists and update it, or add new record
    if grep -q "^${record_name}[[:space:]]" "${temp_zonefile}" || \
       ([ "${record_name}" = "@" ] && grep -q "^@[[:space:]]" "${temp_zonefile}"); then
        # Update existing A record
        bashio::log.info "Updating existing A record for ${record_name}..."
        sed -i "s/^\(${record_name}[[:space:]]\+[0-9]\+[[:space:]]\+IN[[:space:]]\+A[[:space:]]\+\)[0-9.]\+/\1${new_ip}/" "${temp_zonefile}"
        
        # Also handle @ records without explicit @
        if [ "${record_name}" = "@" ]; then
            sed -i "s/^\(@[[:space:]]\+[0-9]\+[[:space:]]\+IN[[:space:]]\+A[[:space:]]\+\)[0-9.]\+/\1${new_ip}/" "${temp_zonefile}"
        fi
    else
        # Add new A record
        bashio::log.info "Adding new A record for ${record_name}..."
        echo "${record_name} 3600 IN A ${new_ip}" >> "${temp_zonefile}"
    fi
    
    # Import updated zone file
    bashio::log.info "Importing updated zone file..."
    if ! /usr/local/bin/hcloud dns zone import "${zone_id}" --file "${temp_zonefile}" 2>&1; then
        bashio::log.error "Failed to import zone file"
        rm -f "${temp_zonefile}"
        return 1
    fi
    
    rm -f "${temp_zonefile}"
    bashio::log.info "DNS record updated successfully"
    return 0
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
    
    bashio::log.info "Hetzner Cloud DDNS starting..."
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
