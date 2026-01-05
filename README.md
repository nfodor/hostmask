<p align="center">
  <img src="logo.svg" alt="hostmask logo" width="150">
</p>

# hostmask

Redirect any domain to a different IP for local development and testing.

## The Problem

When developing locally, you want `api.example.com` to hit your local dev server instead of production. This affects everything: `ping`, `curl`, browsers, any application.

**Without hostmask:**
```bash
$ ping api.example.com
PING api.example.com (93.184.216.34)  # → production server
```

**With hostmask:**
```bash
$ hostmask.sh on
$ ping api.example.com
PING api.example.com (127.0.0.1)  # → your local dev server
```

Now `curl`, browsers, and any app connecting to `api.example.com` will reach your local machine instead.

## How It Works

Your computer checks `/etc/hosts` before querying DNS. hostmask adds/removes entries in this file:

**Before (hostmask off):**
```
# /etc/hosts
127.0.0.1   localhost
```

**After (hostmask on):**
```
# /etc/hosts
127.0.0.1   localhost
127.0.0.1 api.example.com
127.0.0.1 assets.example.com
```

**When you run `hostmask off`**, entries are removed and normal DNS resolution resumes.

## Verify It Works

```bash
# Before
$ hostmask.sh off
$ ping -c1 api.example.com | head -1
PING api.example.com (93.184.216.34) 56(84) bytes of data.

# After
$ hostmask.sh on
$ ping -c1 api.example.com | head -1
PING api.example.com (127.0.0.1) 56(84) bytes of data.

# Also works with curl
$ curl -I https://api.example.com  # hits 127.0.0.1
```

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
  + api.example.com → 127.0.0.1
  + assets.example.com → 127.0.0.1
Done. Routing via local-dev server

$ hostmask.sh status
Hosts routing status:
Config: /home/user/myproject/hosts.json

  LOCAL [local]: api.example.com → 127.0.0.1
  LOCAL [local]: assets.example.com → 127.0.0.1

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
      "ip": "127.0.0.1",
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

### Choosing the Right IP Address

**For most cases, use `127.0.0.1` (localhost):**
- `127.0.0.1` is the standard localhost address that points to your own machine
- This is the recommended default for local development
- Use this when your dev server is running on the same machine

**When to use `192.168.x.x` (local network addresses):**
- Use a `192.168.x.x` address when routing to a different machine on your local network
- For example, if your dev server runs on a separate machine or VM
- Common scenarios: Docker containers with custom networks, separate dev servers, testing across devices

**Example with localhost (recommended default):**
```json
{
  "profiles": {
    "local": {
      "ip": "127.0.0.1",
      "description": "localhost dev server",
      "hosts": ["api.example.com"]
    }
  }
}
```

**Example with local network address:**
```json
{
  "profiles": {
    "network-dev": {
      "ip": "192.168.1.100",
      "description": "dev server on local network",
      "hosts": ["api.example.com"]
    }
  }
}
```

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
