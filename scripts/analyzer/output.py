"""Output helpers — section banners, cache status lines, data printing."""
import json

from rich.console import Console

console = Console()


def section(title: str) -> None:
    console.rule(f"[bold]{title}[/bold]", style="cyan")


def subsection(title: str) -> None:
    console.print(f"\n[bold cyan]#### {title}[/bold cyan]")


def cache_hit(label: str, age_days: int) -> None:
    console.print(f"  [green][CACHE HIT  {age_days:2d}d][/green] {label}")


def cache_miss(label: str) -> None:
    console.print(f"  [yellow][CACHE MISS    ][/yellow] {label}")


def warn(msg: str) -> None:
    console.print(f"  [yellow]⚠️  {msg}[/yellow]")


def error(msg: str) -> None:
    console.print(f"  [red]❌  {msg}[/red]")


def print_data(data: str | dict | list | None, *, fallback: str = "(unavailable)") -> None:
    """Print arbitrary data — dict/list as JSON, str as-is, None as fallback."""
    if data is None:
        console.print(fallback)
    elif isinstance(data, (dict, list)):
        console.print_json(json.dumps(data))
    else:
        console.print(str(data))
