<p align="center">
  <img src="logo.svg" alt="hostmask logo" width="150">
</p>

# hostmask

A simple bash tool to manage `/etc/hosts` routing for local development environments.

## How DNS Resolution Works

When your computer needs to connect to a domain like `api.example.com`, it follows this order:

1. **Check `/etc/hosts`** - Local file mapping hostnames to IPs
2. **Query DNS servers** - If not found in hosts file, ask DNS

The `/etc/hosts` file takes priority over DNS. This is what hostmask exploits.

## What hostmask Does

hostmask adds/removes entries in `/etc/hosts` to intercept DNS resolution:

**Before (hostmask off):**
```
# /etc/hosts
127.0.0.1   localhost
```
→ `api.example.com` resolves via DNS → `93.184.216.34` (production)

**After (hostmask on):**
```
# /etc/hosts
127.0.0.1   localhost
192.168.1.100 api.example.com
192.168.1.100 assets.example.com
```
→ `api.example.com` resolves via hosts file → `192.168.1.100` (your local dev)

**When you run `hostmask off`**, the entries are removed and DNS resolution resumes.

## Installation

```bash
git clone https://github.com/nfodor/hostmask.git ~/dev/hostmask
chmod +x ~/dev/hostmask/hostmask.sh

# Optional: add alias to ~/.bashrc
echo 'alias hostmask="~/dev/hostmask/hostmask.sh"' >> ~/.bashrc
```

## Usage

From any directory with a `hosts.json` file:

```bash
hostmask.sh on       # Enable local routing
hostmask.sh off      # Disable (use DNS)
hostmask.sh status   # Show current status
hostmask.sh init     # Create default hosts.json
```

### Advanced: Specify Config File

```bash
hostmask.sh -c /path/to/config.json on
hostmask.sh -c /path/to/config.json off
hostmask.sh -c /path/to/config.json status
```

### Example Session

```bash
$ cd ~/myproject
$ hostmask.sh on
Config: /home/user/myproject/hosts.json
Applying profile: local (local-dev server)
  + api.example.com → 192.168.1.100
  + assets.example.com → 192.168.1.100
Done. Routing via local-dev server

$ hostmask.sh status
Hosts routing status:
Config: /home/user/myproject/hosts.json

  LOCAL [local]: api.example.com → 192.168.1.100
  LOCAL [local]: assets.example.com → 192.168.1.100

$ hostmask.sh off
Config: /home/user/myproject/hosts.json
Removing hosts intercepts (using DNS)...
  - api.example.com → DNS
  - assets.example.com → DNS
Done. Normal DNS resolution active
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
    }
  }
}
```

- `ip` - The IP address to route hosts to (your local dev server)
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
    └── hosts.json    # api.example.com, assets.example.com
```

Each project only intercepts the domains it needs.

## Requirements

- `bash`
- `jq` (JSON parser) - `sudo apt install jq`
- `sudo` access (to modify /etc/hosts)

## License

MIT
