#!/usr/bin/env python3
"""
Simple MCP server that exposes locally synced OneDrive files to Claude.
Auto-discovers OneDrive sync folders and lets user select which ones to expose.
"""

import json
import os
import sys
import subprocess
from pathlib import Path
from typing import Optional

# Try to import mcp library, fall back to direct JSON-RPC if not available
try:
    from mcp.server.lowlevel import Server
    from mcp.types import Tool, TextContent, JSONSchema
    HAS_MCP_LIB = True
except ImportError:
    HAS_MCP_LIB = False


def find_onedrive_folders() -> list[str]:
    """Find all OneDrive synced folders on Windows."""
    folders = []
    user_home = Path.home()
    
    # Check for OneDrive folders in multiple patterns
    # Pattern 1: C:\Users\[user]\OneDrive - [OrgName]
    # Pattern 2: C:\Users\[user]\OneDrive
    # Pattern 3: Direct subdirectories in user home
    
    if user_home.exists():
        for item in user_home.iterdir():
            try:
                if item.is_dir() and "OneDrive" in item.name:
                    folders.append(str(item))
            except PermissionError:
                pass
    
    return sorted(folders)


def list_files_in_folder(folder_path: str, max_depth: int = 3, current_depth: int = 0) -> list[dict]:
    """Recursively list files in folder, respecting max_depth."""
    files = []
    
    if current_depth >= max_depth:
        return files
    
    try:
        for item in sorted(Path(folder_path).iterdir()):
            if item.is_file():
                files.append({
                    "name": item.name,
                    "path": str(item),
                    "size": item.stat().st_size,
                    "type": "file"
                })
            elif item.is_dir() and not item.name.startswith("."):
                files.append({
                    "name": item.name,
                    "path": str(item),
                    "type": "folder"
                })
                # Recursively list subdirectories
                files.extend(list_files_in_folder(str(item), max_depth, current_depth + 1))
    except PermissionError:
        pass
    
    return files


def read_file(file_path: str) -> str:
    """Read a file and return its contents."""
    try:
        with open(file_path, "r", encoding="utf-8") as f:
            return f.read()
    except UnicodeDecodeError:
        # Binary file, return placeholder
        return f"[Binary file: {file_path}]"
    except Exception as e:
        return f"Error reading file: {e}"


def interactive_setup() -> list[str]:
    """Interactively ask user which OneDrive folders to expose."""
    onedrive_folders = find_onedrive_folders()
    
    print("\n=== OneDrive Local File MCP Server Setup ===\n")
    
    if not onedrive_folders:
        print("No OneDrive folders auto-detected.")
        print("Would you like to enter a custom folder path? (y/n)")
        if input("> ").strip().lower() == "y":
            path = input("Enter folder path: ").strip()
            if Path(path).exists():
                onedrive_folders = [path]
            else:
                print(f"Path not found: {path}")
                return []
        else:
            return []
    else:
        print(f"Found {len(onedrive_folders)} OneDrive folder(s):\n")
        for i, folder in enumerate(onedrive_folders, 1):
            print(f"  {i}. {folder}")
        
        print("\nWhich folders would you like to include? (comma-separated numbers, or 'all')")
        print("Example: 1,2  or  all")
        
        response = input("> ").strip().lower()
        
        selected = []
        if response == "all":
            selected = onedrive_folders
        else:
            try:
                indices = [int(x.strip()) - 1 for x in response.split(",")]
                selected = [onedrive_folders[i] for i in indices if 0 <= i < len(onedrive_folders)]
            except (ValueError, IndexError):
                print("Invalid input. Defaulting to all folders.")
                selected = onedrive_folders
        
        onedrive_folders = selected
    
    if onedrive_folders:
        print(f"\n✓ Selected {len(onedrive_folders)} folder(s):")
        for folder in onedrive_folders:
            print(f"  - {folder}")
        
        # Save config
        config_file = Path.home() / ".mcp-onedrive.json"
        config = {
            "enabled_folders": onedrive_folders,
            "max_depth": 3
        }
        try:
            with open(config_file, "w") as f:
                json.dump(config, f, indent=2)
            print(f"\n✓ Config saved to {config_file}")
        except Exception as e:
            print(f"Warning: Could not save config: {e}")
    
    return onedrive_folders


def main():
    """Main entry point - run as stdio MCP server."""
    
    if len(sys.argv) > 1 and sys.argv[1] == "--setup":
        # Interactive setup mode
        selected_folders = interactive_setup()
        config = {
            "enabled_folders": selected_folders,
            "max_depth": 3
        }
        print("\nServer config:")
        print(json.dumps(config, indent=2))
        sys.exit(0)
    
    # Load config if provided
    config_file = Path.home() / ".mcp-onedrive.json"
    if config_file.exists():
        with open(config_file) as f:
            config = json.load(f)
        enabled_folders = config.get("enabled_folders", [])
    else:
        print("No config found. Run with --setup to configure.", file=sys.stderr)
        enabled_folders = find_onedrive_folders()
    
    if not enabled_folders:
        print("No OneDrive folders configured.", file=sys.stderr)
        sys.exit(1)
    
    # Build file index for fast access
    print(f"Indexing {len(enabled_folders)} folder(s)...", file=sys.stderr)
    file_index = {}
    for folder in enabled_folders:
        files = list_files_in_folder(folder, max_depth=3)
        for file_info in files:
            file_index[file_info["path"]] = file_info
    
    print(f"Indexed {len(file_index)} items", file=sys.stderr)
    
    # Simple JSON-RPC stdio server
    while True:
        try:
            line = sys.stdin.readline()
            if not line:
                break
            
            msg = json.loads(line)
            method = msg.get("method")
            params = msg.get("params", {})
            msg_id = msg.get("id")
            
            response = {"jsonrpc": "2.0", "id": msg_id}
            
            if method == "list_files":
                folder = params.get("folder", enabled_folders[0])
                files = list_files_in_folder(folder, max_depth=3)
                response["result"] = {"files": files}
            
            elif method == "read_file":
                file_path = params.get("path")
                content = read_file(file_path)
                response["result"] = {"content": content}
            
            elif method == "list_folders":
                response["result"] = {"folders": enabled_folders}
            
            else:
                response["error"] = {"code": -32601, "message": "Method not found"}
            
            print(json.dumps(response))
            sys.stdout.flush()
        
        except json.JSONDecodeError:
            pass
        except Exception as e:
            print(json.dumps({"jsonrpc": "2.0", "error": {"code": -32603, "message": str(e)}}))
            sys.stdout.flush()


if __name__ == "__main__":
    main()
