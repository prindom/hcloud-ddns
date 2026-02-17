# Home Assistant Addon: Hetzner Cloud DDNS

Automatically update your DNS records via Hetzner Cloud DNS to keep your domain pointing to your current IP address.

## About

This addon automatically updates DNS records in your Hetzner Cloud DNS zone to match your current public IP address. It's perfect for home servers with dynamic IP addresses.

Features:

- Automatic IP detection from multiple sources
- Configurable update intervals (hourly, daily, weekly)
- Automatic download of the latest Hetzner Cloud CLI
- Support for both amd64 and arm64 architectures
- Uses Hetzner Cloud zone export/import for reliable DNS updates

## Installation

1. Click the Home Assistant My button below to open the addon on your Home Assistant instance.
2. Click the "Install" button to install the addon.
3. Configure the addon (see configuration section below).
4. Start the "Hetzner Cloud DDNS" addon.
5. Check the logs to see it in action.

## Configuration

**Note**: _Remember to restart the addon when the configuration is changed._

Example addon configuration:

```yaml
api_key: "your-hetzner-cloud-api-key"
zone_id: "your-zone-id"
domain: "subdomain.example.com"
update_interval: "hourly"
log_level: "info"
```

### Option: `api_key` (required)

Your Hetzner Cloud API key. You can create one in the Hetzner Cloud Console:

1. Log in to [Hetzner Cloud Console](https://console.hetzner.cloud/)
2. Select your project
3. Go to Security → API Tokens
4. Generate a new token with Read & Write permissions

### Option: `zone_id` (required)

The ID of your DNS zone in Hetzner Cloud. You can find this:

1. Log in to Hetzner Cloud Console
2. Go to DNS
3. Click on your zone
4. The zone ID is shown in the URL or zone details

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

1. On startup, the addon downloads the latest Hetzner Cloud CLI for your architecture
2. It configures the CLI with your API key
3. Every interval (hourly/daily/weekly):
   - Detects your current public IP address
   - Queries your domain's current DNS record
   - If they differ, exports your DNS zone file
   - Updates the A record with your current IP
   - Imports the updated zone file back to Hetzner Cloud

## Support

Got questions?

You could [open an issue on GitHub][issue].

## License

MIT License

Copyright (c) 2026

[issue]: https://github.com/prindom/hcloud-ddns/issues
