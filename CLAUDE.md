# Technical Notes (CLAUDE.md)

This file contains the technical setup details for the local MCP server.

## Server Files

- Primary Windows server: `mcp-onedrive-local.ps1`
- Optional Python variant: `mcp-onedrive-local.py`

## PowerShell Setup Command

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\mcp-onedrive-local.ps1 -Setup
```

Setup behavior:
1. Auto-discovers OneDrive folders under `%USERPROFILE%`.
2. Prompts the user to select folder scope.
3. Writes config to `%USERPROFILE%\.mcp-onedrive.json`.

## Claude Desktop MCP Config

File path:
`%APPDATA%\Claude\claude_desktop_config.json`

Example entry:

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
        "C:\\path\\to\\spo-local-mcp\\mcp-onedrive-local.ps1"
      ],
      "disabled": false
    }
  }
}
```

Restart Claude Desktop after editing config.

## JSON-RPC Methods

The PowerShell MCP server listens on stdio and supports:

- `list_folders`
- `list_files` (optional `folder` param)
- `read_file` (required `path` param)

## Config File Format

Path:
`%USERPROFILE%\.mcp-onedrive.json`

Example:

```json
{
  "enabled_folders": [
    "C:\\Users\\[user]\\OneDrive - [OrgA]"
  ],
  "max_depth": 3
}
```

## Operational Notes

- Local files only; no direct cloud API calls.
- OneDrive sync must be active for selected folders.
- Best used as a stop-gap until full multi-tenant cloud connector setup is in place.
