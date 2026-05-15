# OneDrive Local File MCP Server

A lightweight MCP server that exposes locally synced OneDrive files to Claude, without cloud API auth.

## Use Case

Use this when files are synced locally from OneDrive/SharePoint but a cloud connector cannot reach a second tenant directly.

## Setup (Windows Default)

### Step 1: Run interactive setup

Windows already includes PowerShell, so no runtime install is required.

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\mcp-onedrive-local.ps1 -Setup
```

The setup command:
1. Auto-discovers OneDrive folders under your user profile.
2. Asks which folders to expose.
3. Saves config to `%USERPROFILE%\.mcp-onedrive.json`.

### Step 2: Add to Claude Desktop

Edit `%APPDATA%\Claude\claude_desktop_config.json` and add:

```json
{
  "mcpServers": {
    "onedrive-local-files": {
      "command": "powershell",
      "args": [
        "-NoProfile",
        "-ExecutionPolicy",
        "Bypass",
        "-File",
        "C:\\path\\to\\mcp-onedrive-local.ps1"
      ],
      "disabled": false
    }
  }
}
```

Then restart Claude Desktop.

## Methods exposed

The server accepts JSON-RPC over stdio:
- `list_folders`
- `list_files` with optional `folder`
- `read_file` with required `path`

## Config file

Stored at `%USERPROFILE%\.mcp-onedrive.json`:

```json
{
  "enabled_folders": [
    "C:\\Users\\[user]\\OneDrive - [OrgA]"
  ],
  "max_depth": 3
}
```

## Optional Python variant

A Python script is included for teams that prefer Python:

```powershell
python .\mcp-onedrive-local.py --setup
```

## Notes

- Local files only.
- OneDrive sync must be active for target folders.
- This is a stop-gap until full multi-tenant cloud connector setup is complete.
