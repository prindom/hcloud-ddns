# Home Assistant Addon: Hetzner Cloud DDNS

[![GitHub Release][releases-shield]][releases]
![Project Stage][project-stage-shield]
[![License][license-shield]](LICENSE.md)

![Supports aarch64 Architecture][aarch64-shield]
![Supports amd64 Architecture][amd64-shield]

[![Github Actions][github-actions-shield]][github-actions]
![Project Maintenance][maintenance-shield]
[![GitHub Activity][commits-shield]][commits]

Automatically update DNS records via Hetzner Cloud DNS.

## About

Automatically update your DNS records via Hetzner Cloud DNS to keep your domain pointing to your current IP address. Perfect for home servers with dynamic IP addresses.

Features:

- Automatic IP detection from multiple sources
- Configurable update intervals (hourly, daily, weekly)
- Automatic download of the latest Hetzner Cloud CLI
- Support for both amd64 and arm64 architectures
- Uses Hetzner Cloud zone export/import for reliable DNS updates

[:books: Read the full addon documentation][docs]

## Installation

1. Add this repository to your Home Assistant instance.
2. Install the "Hetzner Cloud DDNS" addon.
3. Configure the addon with your Hetzner Cloud API key, zone ID, and domain.
4. Start the addon.

## Configuration

Example configuration:

```yaml
api_key: "your-hetzner-cloud-api-key"
zone_id: "your-zone-id"
domain: "subdomain.example.com"
update_interval: "hourly"
log_level: "info"
```

See the [documentation][docs] for detailed configuration instructions.

## Support

Got questions?

You could [open an issue here][issue] on GitHub.

## Contributing

This is an active open-source project. We are always open to people who want to
use the code or contribute to it.

We have set up a separate document containing our
[contribution guidelines](.github/CONTRIBUTING.md).

Thank you for being involved! :heart_eyes:

## License

MIT License

Copyright (c) 2026

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.

[aarch64-shield]: https://img.shields.io/badge/aarch64-yes-green.svg
[amd64-shield]: https://img.shields.io/badge/amd64-yes-green.svg
[commits-shield]: https://img.shields.io/github/commit-activity/y/prindom/hcloud-ddns.svg
[commits]: https://github.com/prindom/hcloud-ddns/commits/main
[docs]: https://github.com/prindom/hcloud-ddns/blob/main/hcloud-ddns/DOCS.md
[github-actions-shield]: https://github.com/prindom/hcloud-ddns/workflows/CI/badge.svg
[github-actions]: https://github.com/prindom/hcloud-ddns/actions
[issue]: https://github.com/prindom/hcloud-ddns/issues
[license-shield]: https://img.shields.io/github/license/prindom/hcloud-ddns.svg
[maintenance-shield]: https://img.shields.io/maintenance/yes/2026.svg
[project-stage-shield]: https://img.shields.io/badge/project%20stage-production%20ready-brightgreen.svg
[releases-shield]: https://img.shields.io/github/release/prindom/hcloud-ddns.svg
[releases]: https://github.com/prindom/hcloud-ddns/releases
