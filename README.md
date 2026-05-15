# OneDrive Local File MCP Server

A lightweight MCP (Model Context Protocol) server that exposes locally synced OneDrive files to Claude, without needing cloud API authentication.

## Use Case

When you have files synced locally via OneDrive desktop sync but need Claude to read them from a different M365 tenant (e.g., a different organizational unit or partner tenant synced locally), this MCP server bridges the gap by:
1. Auto-discovering local OneDrive sync folders
2. Allowing user selection of which folders to expose
3. Providing file listing and reading capabilities via MCP
4. Connecting directly to Claude as a local MCP server

## Setup

### Step 1: Install (One-time)

The script requires only Python 3.9+. No additional dependencies needed.

```powershell
python -m pip install --upgrade pip
```

### Step 2: Configure Folders

Run interactive setup to discover and select which OneDrive folders to expose:

```powershell
python mcp-onedrive-local.py --setup
```

This will:
- Auto-detect any `OneDrive - [OrgName]` folders in your user directory
- Prompt you to select which ones to include
- Save config to `~/.mcp-onedrive.json`

Example:
```
=== OneDrive Local File MCP Server Setup ===

Found 2 OneDrive folder(s):

  1. C:\Users\[user]\OneDrive - [Department A]
  2. C:\Users\[user]\OneDrive - [Department B]

Which folders would you like to include? (comma-separated numbers, or 'all')
Example: 1,2  or  all
> 2

✓ Selected 1 folder(s):
  - C:\Users\[user]\OneDrive - [Department B]

✓ Config saved to C:\Users\[user]\.mcp-onedrive.json
```

### Step 3: Add to Claude

#### Option A: Add to Claude Desktop (Recommended)

Edit your Claude desktop MCP configuration file:
- **Windows:** `%APPDATA%\Claude\claude_desktop_config.json`
- **macOS:** `~/Library/Application Support/Claude/claude_desktop_config.json`

Add this server:

```json
{
  "mcpServers": {
    "onedrive-local-files": {
      "command": "python",
      "args": ["C:\\path\\to\\mcp-onedrive-local.py"],
      "disabled": false
    }
  }
}
```

Then restart Claude Desktop.

#### Option B: Add to Claude Web (Cowork/Claude Code)

If using Claude Code or Cowork:
1. Open connector settings
2. Add a custom MCP server
3. Point to: `http://localhost:8000` (after starting the server)

Start the server in a terminal:
```powershell
python mcp-onedrive-local.py --serve 8000
```

## Usage

Once configured, Claude will have access to:

- **List available folders** — Claude can discover which OneDrive folders are configured
- **List files** — Claude can browse files in any configured folder recursively (up to 3 levels deep by default)
- **Read file contents** — Claude can read .txt, .md, .json, .csv, .py, and other text-based files

### Example Prompts in Claude

```
"What files are in my OneDrive Sales folder?"

"Read the file at C:\Users\[user]\OneDrive - Sales\Management Files\Q1 Report.xlsx"
   (Note: Excel files return [Binary file] but the filename/metadata is preserved)

"Search through my synced SharePoint files for any documents mentioning 'budget'"
```

## Configuration File

The configuration file reads from `~/.mcp-onedrive.json`:

```json
{
  "enabled_folders": [
    "C:\\Users\\[user]\\OneDrive - [Department A]",
    "C:\\Users\\[user]\\OneDrive - [Department B]"
  ],
  "max_depth": 3
}
```

**Settings:**
- `enabled_folders`: List of folder paths to expose
- `max_depth`: How many folder levels deep to index (default: 3)

To reconfigure, either:
1. Run `python mcp-onedrive-local.py --setup` again
2. Manually edit `~/.mcp-onedrive.json`

## Troubleshooting

### No folders found during setup
- Ensure OneDrive is installed and running
- Check that at least one folder is synced locally
- Manually enter a folder path when prompted

### Claude can't read files
- Verify the folder path exists and contains files
- Check that OneDrive sync is active for that folder
- Review the config file: `type cat ~/.mcp-onedrive.json`

### Permission errors
- Ensure you have read permissions for the OneDrive folder
- Run the terminal/Claude as the same user account that owns the OneDrive folder

## Performance Notes

- First run indexes all files in configured folders (up to max_depth)
- Indexing is cached in memory for the duration of the server session
- File reads are streamed on-demand

## Security & Privacy

- **Local only:** All file access happens locally on your machine
- **No cloud sync:** Files are read from local disk, not re-uploaded
- **No filtering:** Make sure you trust only configured folders with sensitive data
- **Config stored locally:** `~/.mcp-onedrive.json` is never sent to cloud

## Limitations

- **Text files only:** Binary files (Excel, Word docs, PDFs) return a placeholder — use Claude's file upload for those
- **Max 3 levels:** Folder nesting is limited to 3 levels by default (configurable in config file)
- **Local sync required:** OneDrive desktop sync must be active and folders must be synced locally

## Stop-Gap vs. Long-Term Solution

This MCP server is a **temporary workaround** until proper multi-tenant app registration and OAuth setup is completed for additional tenants.

**Long-term plan:** Register a second M365 app in the target tenant and configure a dedicated Claude M365 connector for that tenant. This will provide:
- Full cloud-based access (no local sync required)
- Automatic updates to files in SharePoint
- Better performance for large document sets

Use this local file MCP while that setup is in progress.
