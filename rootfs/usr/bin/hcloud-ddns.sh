#!/command/with-contenv bashio
# shellcheck shell=bash
# ==============================================================================
# Hetzner DNS DDNS Addon
# Main DDNS update script using Hetzner Cloud API
# ==============================================================================

# API endpoint
API_BASE="https://api.hetzner.cloud/v1"

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
#   $1 - Domain name (fully qualified)
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
# Get zone name stored by init script
#
# Returns:
#   The DNS zone name (e.g. "example.com")
# ------------------------------------------------------------------------------
get_zone_name() {
    cat /root/.config/hetzner-zone-name
}

# ------------------------------------------------------------------------------
# Create or update DNS A record
#
# Arguments:
#   $1 - Zone ID
#   $2 - Record name (relative, e.g. "home" or "@")
#   $3 - New IP address
# Returns:
#   0 on success, 1 on failure
# ------------------------------------------------------------------------------
update_dns() {
    local zone_id=$1
    local record_name=$2
    local new_ip=$3
    local token
    local response
    local http_code

    bashio::log.trace "${FUNCNAME[0]}"

    token=$(get_api_token)

    # Check whether the RRSet already exists
    bashio::log.info "Checking for existing DNS record..."
    http_code=$(curl -s -o /dev/null -w "%{http_code}" \
        -H "Authorization: Bearer ${token}" \
        "${API_BASE}/zones/${zone_id}/rrsets/${record_name}/A")

    if [ "${http_code}" = "200" ]; then
        # Update existing RRSet via set_records action
        bashio::log.info "Updating existing A record..."

        response=$(curl -s -w "\n%{http_code}" -X POST \
            -H "Content-Type: application/json" \
            -H "Authorization: Bearer ${token}" \
            -d "{\"records\":[{\"value\":\"${new_ip}\"}]}" \
            "${API_BASE}/zones/${zone_id}/rrsets/${record_name}/A/actions/set_records")

        http_code=$(echo "${response}" | tail -1)

        if [[ "${http_code}" == 2* ]]; then
            bashio::log.info "DNS record updated successfully"
            return 0
        else
            bashio::log.error "Failed to update DNS record (HTTP ${http_code})"
            bashio::log.debug "Response: $(echo "${response}" | head -n -1)"
            return 1
        fi
    else
        # Create new RRSet
        bashio::log.info "Creating new A record..."

        response=$(curl -s -w "\n%{http_code}" -X POST \
            -H "Content-Type: application/json" \
            -H "Authorization: Bearer ${token}" \
            -d "{\"name\":\"${record_name}\",\"type\":\"A\",\"ttl\":3600,\"records\":[{\"value\":\"${new_ip}\"}]}" \
            "${API_BASE}/zones/${zone_id}/rrsets")

        http_code=$(echo "${response}" | tail -1)

        if [[ "${http_code}" == 2* ]]; then
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
    local zone_name
    local domain
    local record_name
    local update_interval
    local dry_run
    local sleep_time
    local current_ip
    local dns_ip

    bashio::log.trace "${FUNCNAME[0]}"

    # Get configuration
    zone_id=$(bashio::config 'zone_id')
    domain=$(bashio::config 'domain')
    update_interval=$(bashio::config 'update_interval')
    dry_run=$(bashio::config 'dry_run')

    if [ -z "${zone_id}" ] || [ -z "${domain}" ]; then
        bashio::log.fatal "Zone ID and domain must be configured"
        exit 1
    fi

    # Derive the relative record name from the FQDN and the zone name stored by init
    zone_name=$(get_zone_name)
    if [ "${domain}" = "${zone_name}" ]; then
        record_name="@"
    else
        record_name="${domain%.${zone_name}}"
    fi

    bashio::log.info "Hetzner DNS DDNS starting..."
    bashio::log.info "Zone: ${zone_name} (ID: ${zone_id})"
    bashio::log.info "Domain: ${domain} (record: ${record_name})"
    bashio::log.info "Update interval: ${update_interval}"

    if bashio::var.true "${dry_run}"; then
        bashio::log.notice "Dry run mode enabled — DNS records will NOT be modified"
    fi

    sleep_time=$(get_sleep_time "${update_interval}")
    bashio::log.info "Checking every ${sleep_time} seconds"

    # Write PID so the API server can signal us
    echo $$ > /var/run/hcloud-ddns.pid

    # Allow the API server to interrupt the sleep for a forced check
    _sleep_pid=""
    _forced=false
    trap '_forced=true; [ -n "${_sleep_pid}" ] && kill "${_sleep_pid}" 2>/dev/null || true' SIGUSR1

    # Main loop
    while true; do
        if bashio::var.true "${_forced}"; then
            bashio::log.notice "Forced update triggered via UI"
        fi
        _forced=false

        bashio::log.info "Checking IP address..."

        # Get current public IP
        if ! current_ip=$(get_current_ip); then
            bashio::log.error "Failed to get current IP, will retry later"
            sleep "${sleep_time}" & _sleep_pid=$!; wait "${_sleep_pid}" 2>/dev/null || true; _sleep_pid=""
            continue
        fi

        # Get DNS IP
        dns_ip=$(get_dns_ip "${domain}")

        # Compare IPs
        if [ "${current_ip}" = "${dns_ip}" ]; then
            bashio::log.info "IP unchanged (${current_ip}), no update needed"
        else
            if bashio::var.true "${dry_run}"; then
                bashio::log.notice "Dry run: would update ${domain} from ${dns_ip:-<no record>} to ${current_ip}"
            else
                bashio::log.info "IP changed from ${dns_ip} to ${current_ip}, updating DNS..."

                if update_dns "${zone_id}" "${record_name}" "${current_ip}"; then
                    bashio::log.info "DNS update completed successfully"
                else
                    bashio::log.error "DNS update failed"
                fi
            fi
        fi

        bashio::log.info "Next check in ${sleep_time} seconds"
        sleep "${sleep_time}" & _sleep_pid=$!; wait "${_sleep_pid}" 2>/dev/null || true; _sleep_pid=""
    done
}

main "$@"
