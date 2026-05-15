# Setup Instructions

## Is Python required on Windows 11?

No for the default path. This project now supports a native PowerShell server.

- Windows 11 includes PowerShell by default.
- You can run setup and the MCP server without installing Python.
- Python remains optional if you prefer the Python script.

## Quick Setup (PowerShell)

1. Clone repository:

```powershell
git clone https://github.com/jessef1983/spo-local-mcp.git
cd spo-local-mcp
```

2. Run setup:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\mcp-onedrive-local.ps1 -Setup
```

3. Add to Claude Desktop config at `%APPDATA%\Claude\claude_desktop_config.json`:

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
      ]
    }
  }
}
```

4. Restart Claude Desktop.

## Troubleshooting

- If no OneDrive folders are found, enter a folder path manually during setup.
- If Claude cannot connect, verify the script path and JSON syntax.
- Config file is `%USERPROFILE%\.mcp-onedrive.json`.

## Optional Python Path

If your environment already has Python:

```powershell
python .\mcp-onedrive-local.py --setup
```
