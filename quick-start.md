# SPO Local MCP

A lightweight MCP (Model Context Protocol) server that exposes locally synced SharePoint Online files to Claude, without needing cloud API authentication.

**Use case:** Access files from different M365 tenants where you have B2B guest access but the cloud connector is limited to your home tenant.

## Quick Start

```powershell
# Setup: discover and select OneDrive folders
python mcp-onedrive-local.py --setup

# Add to Claude Desktop config, then restart Claude
# (See README.md for full instructions)
```

## Features

- ✅ Auto-discovers local OneDrive sync folders
- ✅ Interactive setup to select which folders to expose
- ✅ File listing and reading via MCP JSON-RPC
- ✅ Works with Claude Desktop or Claude Code/Cowork
- ✅ No cloud authentication required

## Documentation

See [README.md](README.md) for full setup, usage, and troubleshooting.
