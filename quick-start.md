# SPO Local MCP

Native Windows setup (no Python required):

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\mcp-onedrive-local.ps1 -Setup
```

Then add this to `%APPDATA%\Claude\claude_desktop_config.json`:

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

Restart Claude Desktop.
