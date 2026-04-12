#!/usr/bin/env python3
import argparse
import re
from pathlib import Path
from urllib.parse import unquote

MD_EXTS = {".md", ".markdown"}

SECTION_START_RE = re.compile(r"^\s*##\s+収録ファイル\s*$")
SECTION_END_RE = re.compile(r"^\s*##\s+")
CODE_PATH_RE = re.compile(r"`([^`]+?\.(?:md|markdown))`", re.IGNORECASE)

def detect_root(script_path: Path) -> Path:
    # 想定配置: <root>/.notes/archive_combine.py
    if script_path.parent.name == ".notes":
        return script_path.parent.parent.resolve()
    return Path.cwd().resolve()

def normalize(text: str) -> str:
    return text.replace("\r\n", "\n").replace("\r", "\n").rstrip() + "\n\n"

def make_header(rel: Path, level: int) -> str:
    h = "#" * max(1, min(level, 6))
    return f"{h} {rel.as_posix()}\n\n"

def extract_archive_entries(index_text: str) -> list[str]:
    """
    Extract markdown paths from the '## 収録ファイル' section.
    Expected format example:
      - `docs/notes/archive/example.md`

    Keeps original order and removes duplicates.
    """
    lines = index_text.splitlines()
    in_section = False
    found: list[str] = []
    seen: set[str] = set()

    for line in lines:
        if not in_section:
            if SECTION_START_RE.match(line):
                in_section = True
            continue

        # 次の H2 に来たら終わり
        if SECTION_END_RE.match(line):
            break

        for raw in CODE_PATH_RE.findall(line):
            path_str = unquote(raw.strip())
            if path_str not in seen:
                seen.add(path_str)
                found.append(path_str)

    return found

def resolve_index_entries(index_path: Path, root: Path) -> list[Path]:
    text = index_path.read_text(encoding="utf-8", errors="replace")
    entries = extract_archive_entries(text)

    resolved: list[Path] = []
    seen: set[Path] = set()

    for entry in entries:
        # 絶対パスではなく、project root 基準の相対パスとして解釈
        p = (root / entry).resolve()

        # root外は無視
        try:
            p.relative_to(root)
        except ValueError:
            continue

        if not p.exists() or not p.is_file():
            continue
        if p.suffix.lower() not in MD_EXTS:
            continue

        rp = p.resolve()
        if rp not in seen:
            seen.add(rp)
            resolved.append(p)

    return resolved

def main():
    ap = argparse.ArgumentParser(
        description="Combine only markdown files listed in Archive INDEX.md"
    )
    ap.add_argument(
        "-a", "--archive-subfolder",
        required=True,
        help="Archive folder under project root, e.g. docs/notes/archive"
    )
    ap.add_argument(
        "-i", "--index-name",
        default="INDEX.md",
        help="Index markdown filename inside archive folder (default: INDEX.md)"
    )
    ap.add_argument(
        "-o", "--output",
        default="combined_archive.md",
        help="Output markdown file path"
    )
    ap.add_argument(
        "--header-level",
        type=int,
        default=1,
        help="Header level for each file title (1-6)"
    )
    ap.add_argument(
        "--include-index",
        action="store_true",
        help="Include INDEX.md itself at the beginning of the output"
    )
    args = ap.parse_args()

    script_path = Path(__file__).resolve()
    root = detect_root(script_path)

    archive_dir = (root / args.archive_subfolder).resolve()
    if not archive_dir.exists() or not archive_dir.is_dir():
        raise SystemExit(f"Archive folder not found: {archive_dir}")

    index_path = archive_dir / args.index_name
    if not index_path.exists() or not index_path.is_file():
        raise SystemExit(f"Index file not found: {index_path}")

    files = resolve_index_entries(index_path, root)
    if not files:
        raise SystemExit("No valid markdown files listed in INDEX.md.")

    out = Path(args.output).resolve()

    buf = []
    buf.append(f"<!-- root: {root.as_posix()} -->\n")
    buf.append(f"<!-- archive: {archive_dir.relative_to(root).as_posix()} -->\n")
    buf.append(f"<!-- index: {index_path.relative_to(root).as_posix()} -->\n")
    buf.append(f"<!-- files: {len(files)} -->\n\n")

    if args.include_index:
        rel = index_path.relative_to(root)
        buf.append(make_header(rel, args.header_level))
        buf.append(normalize(index_path.read_text(encoding="utf-8", errors="replace")))

    for f in files:
        rel = f.relative_to(root)
        buf.append(make_header(rel, args.header_level))
        buf.append(normalize(f.read_text(encoding="utf-8", errors="replace")))

    out.write_text("".join(buf), encoding="utf-8")
    print(f"Wrote: {out}  (files: {len(files)})")

if __name__ == "__main__":
    main()