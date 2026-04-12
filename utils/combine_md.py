#!/usr/bin/env python3
import argparse
import os
from pathlib import Path

MD_EXTS = {".md", ".markdown"}

DEFAULT_EXCLUDES = {
    ".git", ".svn", ".hg",
    "node_modules", "dist", "build", ".next",
    ".idea", ".vscode", "__pycache__",
    ".notes",
    "archive",  # ← docs配下でも階層問わず除外（降りない）
}

def detect_root(script_path: Path) -> Path:
    # <root>/.notes/ に置く運用を想定
    if script_path.parent.name == ".notes":
        return script_path.parent.parent.resolve()
    return Path.cwd().resolve()

def make_header(rel: Path, level: int) -> str:
    h = "#" * max(1, min(level, 6))
    return f"{h} {rel.as_posix()}\n\n"

def sort_key_by_depth_then_path(p: Path, root: Path) -> tuple[int, str]:
    rel = p.relative_to(root)
    return (len(rel.parts), rel.as_posix().lower())

def normalize(text: str) -> str:
    return text.replace("\r\n", "\n").replace("\r", "\n").rstrip() + "\n\n"

def collect_markdown_under(root: Path, base: Path, excludes: set[str]) -> list[Path]:
    files: list[Path] = []
    # os.walk でディレクトリを“降りない”除外ができる
    for dirpath, dirnames, filenames in os.walk(base):
        # 除外ディレクトリはここで刈り取る（これ以降探索されない）
        dirnames[:] = [d for d in dirnames if d not in excludes]

        for fn in filenames:
            p = Path(dirpath) / fn
            if p.suffix.lower() not in MD_EXTS:
                continue
            # 念のため、相対パス部品にも除外名が混じっていれば落とす
            rel = p.relative_to(root)
            if any(part in excludes for part in rel.parts):
                continue
            files.append(p)

    files.sort(key=lambda x: sort_key_by_depth_then_path(x, root))
    return files

def main():
    ap = argparse.ArgumentParser(description="Combine markdown from specific subfolders, skipping docs/**/archive/**.")
    ap.add_argument("-s", "--subfolder", action="append", required=True,
                    help="Target subfolder under project root (repeatable), e.g. -s docs -s specs")
    ap.add_argument("-o", "--output", default="combined.md")
    ap.add_argument("--header-level", type=int, default=1)
    ap.add_argument("--exclude", action="append", default=[],
                    help="Additional folder/file names to exclude (repeatable)")
    ap.add_argument("--no-default-excludes", action="store_true",
                    help="Disable default excludes (includes archive)")
    args = ap.parse_args()

    script_path = Path(__file__).resolve()
    root = detect_root(script_path)

    excludes = set(args.exclude)
    if not args.no_default_excludes:
        excludes |= DEFAULT_EXCLUDES

    all_files: list[Path] = []
    for sub in args.subfolder:
        base = (root / sub).resolve()
        if not base.exists() or not base.is_dir():
            raise SystemExit(f"Subfolder not found: {base}")
        all_files.extend(collect_markdown_under(root, base, excludes))

    # 重複排除
    uniq = {p.resolve(): p for p in all_files}
    files = list(uniq.values())
    files.sort(key=lambda x: sort_key_by_depth_then_path(x, root))

    if not files:
        raise SystemExit("No markdown files found.")

    out = Path(args.output).resolve()
    buf = []
    buf.append(f"<!-- root: {root.as_posix()} -->\n")
    buf.append(f"<!-- subfolders: {', '.join(args.subfolder)} -->\n")
    buf.append(f"<!-- excludes: {', '.join(sorted(excludes))} -->\n")
    buf.append(f"<!-- files: {len(files)} -->\n\n")

    for f in files:
        rel = f.relative_to(root)
        buf.append(make_header(rel, args.header_level))
        buf.append(normalize(f.read_text(encoding="utf-8", errors="replace")))

    out.write_text("".join(buf), encoding="utf-8")
    print(f"Wrote: {out}  (files: {len(files)})")

if __name__ == "__main__":
    main()
