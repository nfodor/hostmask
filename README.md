<p align="center">
  <img src="logo.svg" alt="hostmask logo" width="150">
</p>

# hostmask

A simple bash tool to manage `/etc/hosts` routing for local development environments.

## Why?

When developing locally, you often need requests to production domains (e.g., `api.example.com`) to route to your local development server instead of the production server. This tool manages `/etc/hosts` entries to bypass DNS resolution.

**Without hostmask**: `api.example.com` → DNS → production server  
**With hostmask on**: `api.example.com` → /etc/hosts → local dev server

## Installation

```bash
git clone https://github.com/nfodor/hostmask.git ~/dev/hostmask
chmod +x ~/dev/hostmask/hostmask.sh

# Optional: add alias to ~/.bashrc
echo 'alias hostmask="~/dev/hostmask/hostmask.sh"' >> ~/.bashrc
```

## Usage

```bash
# Initialize a default hosts.json in current directory
hostmask.sh -c hosts.json init

# Enable local routing
hostmask.sh -c hosts.json on

# Disable local routing (use DNS)
hostmask.sh -c hosts.json off

# Check current status
hostmask.sh -c hosts.json status

# List available profiles
hostmask.sh -c hosts.json list

# Apply a specific profile
hostmask.sh -c hosts.json on production
```

## Configuration

Create a `hosts.json` file in your project directory:

```json
{
  "profiles": {
    "local": {
      "ip": "10.10.10.223",
      "description": "local-dev server",
      "hosts": [
        "api.example.com",
        "assets.example.com"
      ]
    },
    "staging": {
      "ip": "192.168.1.100",
      "description": "staging server",
      "hosts": [
        "api.example.com"
      ]
    }
  }
}
```

Each profile defines:
- `ip` - The IP address to route hosts to
- `description` - Human-readable description
- `hosts` - Array of hostnames to intercept

## Per-Project Configs

Place a `hosts.json` in each project directory with project-specific hosts:

```
~/dev/
├── frontend/
│   └── hosts.json    # api.example.com, cdn.example.com
├── backend/
│   └── hosts.json    # api.example.com, db.example.com
└── proxy/
    └── hosts.json    # *.example.com
```

## Requirements

- `bash`
- `jq` (JSON parser)
- `sudo` access (to modify /etc/hosts)

## License

MIT
