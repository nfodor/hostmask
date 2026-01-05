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
PING api.example.com (127.0.0.1)  # → localhost
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
127.0.0.1   api.example.com
127.0.0.1   assets.example.com
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
$ curl -I https://api.example.com  # hits 127.0.0.1 (localhost)
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
Applying profile: local (localhost)
  + api.example.com → 127.0.0.1
  + assets.example.com → 127.0.0.1
Done. Routing via localhost

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

Create a `hosts.json` file in your project directory (or run `hostmask.sh init`):

```json
{
  "profiles": {
    "local": {
      "ip": "127.0.0.1",
      "description": "localhost",
      "hosts": [
        "api.example.com",
        "assets.example.com"
      ]
    }
  }
}
```

- `ip` - The IP address to route hosts to (`127.0.0.1` for localhost, or another machine's IP)
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

## Limitations: HTTPS and Certificates

hostmask only redirects network traffic to a different IP. It does **not** handle TLS certificate validation.

### The Problem

When you visit `https://api.example.com`, your browser:
1. Resolves `api.example.com` → IP address (hostmask intercepts this)
2. Connects to that IP
3. **Validates the TLS certificate** matches `api.example.com`

If your local server doesn't have a valid certificate for `api.example.com`, you'll get certificate errors:

```
curl: (60) SSL certificate problem: unable to get local issuer certificate
```

### Solutions

**Option 1: Ignore certificate errors (development only)**
```bash
curl -k https://api.example.com        # -k ignores cert errors
```
Browsers: Click through "Your connection is not private" warning.

**Option 2: Use HTTP instead of HTTPS**
If your local server supports HTTP, use that for development.

**Option 3: Generate local certificates**
Tools like [mkcert](https://github.com/FiloSottile/mkcert) create locally-trusted certificates:
```bash
mkcert api.example.com
# Creates api.example.com.pem and api.example.com-key.pem
# Configure your local server to use these
```

**Option 4: Use real certificates**
If you have access to real certificates for the domain (e.g., from Let's Encrypt), install them on your local server.

### What hostmask CAN'T do

- Bypass certificate pinning in apps
- Make browsers trust invalid certificates automatically
- Handle mutual TLS (client certificates)

hostmask is a DNS-level redirect. Authentication, encryption, and certificate validation happen at a different layer.

## Requirements

- `bash`
- `jq` (JSON parser) - `sudo apt install jq`
- `sudo` access (to modify /etc/hosts)

## License

MIT
