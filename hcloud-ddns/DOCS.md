# Home Assistant Addon: Hetzner DNS DDNS

Automatically update your DNS records via Hetzner DNS to keep your domain pointing to your current IP address.

## About

This addon automatically updates DNS records in your Hetzner DNS zone to match your current public IP address. It's perfect for home servers with dynamic IP addresses.

Features:

- Automatic IP detection from multiple sources
- Configurable update intervals (hourly, daily, weekly)
- Direct integration with Hetzner DNS API
- Support for both amd64 and arm64 architectures
- Secure API token storage
- Automatic creation of new DNS records if they don't exist

## Installation

1. Click the Home Assistant My button below to open the addon on your Home Assistant instance.
2. Click the "Install" button to install the addon.
3. Configure the addon (see configuration section below).
4. Start the "Hetzner DNS DDNS" addon.
5. Check the logs to see it in action.

## Configuration

**Note**: _Remember to restart the addon when the configuration is changed._

Example addon configuration:

```yaml
api_key: "your-hetzner-dns-api-token"
zone_id: "your-zone-id"
domain: "subdomain.example.com"
update_interval: "hourly"
log_level: "info"
```

### Option: `api_key` (required)

Your Hetzner DNS API token. You can create one in the Hetzner DNS Console:

1. Log in to [Hetzner DNS Console](https://dns.hetzner.com/)
2. Click on "API Tokens" in the left menu
3. Click "Create access token"
4. Give it a name and click "Create access token"
5. Copy the token (you won't be able to see it again!)

**Note**: This is different from the Hetzner Cloud API token. Make sure to use the DNS API token.

### Option: `zone_id` (required)

The ID of your DNS zone in Hetzner DNS. You can find this:

1. Log in to [Hetzner DNS Console](https://dns.hetzner.com/)
2. Click on your zone (domain)
3. The zone ID is shown in the URL (e.g., `https://dns.hetzner.com/zone/ZONE_ID`)
   or you can find it in the zone details

### Option: `domain` (required)

The fully qualified domain name to update (e.g., `home.example.com` or `example.com`).

- For root domain: use `example.com`
- For subdomain: use `subdomain.example.com`

### Option: `update_interval`

How often to check and update the DNS record. Options are:

- `hourly`: Check every hour (default)
- `daily`: Check once per day
- `weekly`: Check once per week

### Option: `log_level`

The log level for the addon. Options are:

- `trace`: Show every detail
- `debug`: Show detailed debug information
- `info`: Normal interesting events (default)
- `notice`: Normal but significant events
- `warning`: Exceptional occurrences that are not errors
- `error`: Runtime errors
- `fatal`: Something went terribly wrong

## How It Works

1. On startup, the addon validates your API token and zone configuration
2. Every interval (hourly/daily/weekly):
   - Detects your current public IP address
   - Queries your domain's current DNS record
   - If they differ:
     - Checks if the DNS record exists
     - Creates a new A record or updates the existing one
     - Uses the Hetzner DNS API to apply the changes

## Support

Got questions?

You could [open an issue on GitHub][issue].

## License

MIT License

Copyright (c) 2026

[issue]: https://github.com/prindom/hcloud-ddns/issues
