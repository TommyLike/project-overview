"""Configuration loading and GitHub API authentication."""
from __future__ import annotations

import json
import os
import subprocess
from pathlib import Path

import requests

from . import output

_CONFIG_PRIMARY = Path.home() / ".config" / "github-analyzer" / "config"
_CONFIG_LOCAL = Path(__file__).parent.parent.parent / "config"


class Config:
    def __init__(self):
        self.github_token: str = os.environ.get("GITHUB_TOKEN", "")
        self.libraries_io_key: str = os.environ.get("LIBRARIES_IO_KEY", "")
        self.youtube_api_key: str = os.environ.get("YOUTUBE_API_KEY", "")
        self.auth_method: str = ""
        self.token_valid: bool = False
        self._load_config(_CONFIG_PRIMARY)
        self._load_config(_CONFIG_LOCAL)

    def _load_config(self, path: Path) -> None:
        if not path.exists():
            return
        for line in path.read_text().splitlines():
            line = line.strip()
            if not line or line.startswith("#") or "=" not in line:
                continue
            key, _, val = line.partition("=")
            val = val.strip().strip('"').strip("'")
            if key == "GITHUB_TOKEN" and not self.github_token:
                self.github_token = val
            elif key == "LIBRARIES_IO_KEY" and not self.libraries_io_key:
                self.libraries_io_key = val
            elif key == "YOUTUBE_API_KEY" and not self.youtube_api_key:
                self.youtube_api_key = val

    def _validate_token(self, token: str) -> int:
        try:
            resp = requests.get(
                "https://api.github.com/user",
                headers={"Authorization": f"Bearer {token}", "Accept": "application/vnd.github+json"},
                timeout=10,
            )
            return resp.status_code
        except Exception:
            return 0

    def _gh_cli_available(self) -> bool:
        try:
            return subprocess.run(["gh", "auth", "status"], capture_output=True, timeout=5).returncode == 0
        except Exception:
            return False

    def authenticate(self) -> None:
        if self.github_token:
            output.console.print("  Token found — validating ...", end=" ")
            code = self._validate_token(self.github_token)
            if code == 200:
                output.console.print("[green]✓ valid[/green]")
                self.token_valid = True
                self.auth_method = "token"
            else:
                output.console.print(f"[red]✗ HTTP {code} — falling back to unauthenticated[/red]")
                self.github_token = ""
                self.auth_method = "unauthenticated"
        elif self._gh_cli_available():
            output.console.print("  [green]Using gh CLI (authenticated)[/green]")
            self.auth_method = "gh"
        else:
            output.console.print("  No token — unauthenticated (60 req/hr limit)")
            self.auth_method = "unauthenticated"
        output.console.print()

    def github_api(self, endpoint: str) -> dict | list | None:
        """Call GitHub API, return parsed JSON or None on error."""
        url = f"https://api.github.com/{endpoint}"
        if self.auth_method == "token":
            try:
                resp = requests.get(
                    url,
                    headers={"Authorization": f"Bearer {self.github_token}", "Accept": "application/vnd.github+json"},
                    timeout=30,
                )
                if resp.status_code in (200, 201, 204):
                    return resp.json()
                if resp.status_code == 404:
                    return None
                output.warn(f"GitHub API HTTP {resp.status_code}: {endpoint}")
                return None
            except Exception as e:
                output.warn(f"GitHub API error: {e}")
                return None
        elif self.auth_method == "gh":
            try:
                result = subprocess.run(["gh", "api", endpoint], capture_output=True, text=True, timeout=30)
                return json.loads(result.stdout) if result.returncode == 0 else None
            except Exception:
                return None
        else:
            try:
                resp = requests.get(url, headers={"Accept": "application/vnd.github+json"}, timeout=30)
                if resp.status_code == 403:
                    output.warn(f"Rate limit hit — add GITHUB_TOKEN to {_CONFIG_PRIMARY}")
                    return None
                return resp.json() if resp.status_code in (200, 201, 204) else None
            except Exception:
                return None
