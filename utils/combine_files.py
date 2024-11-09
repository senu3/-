#  実行する前にpathspecをインストールしてください

import os
from pathspec import PathSpec
from pathspec.patterns import GitWildMatchPattern

# 出力ファイル名
output_file = "combined_output.txt"

# リポジトリのルートディレクトリを指定（スクリプトのディレクトリ）
repo_root = os.path.dirname(os.path.abspath(__file__))

# カレントディレクトリをリポジトリのルートに変更
os.chdir(repo_root)

# .gitignore ファイルが存在する場合は読み込む
if os.path.exists(".gitignore"):
    with open(".gitignore", "r", encoding="utf-8") as f:
        gitignore_patterns = f.read().splitlines()
else:
    gitignore_patterns = []

# .gitignore のパターンを解析
spec = PathSpec.from_lines(GitWildMatchPattern, gitignore_patterns)

# 除外するディレクトリやファイルを追加（必要に応じて）
exclude_dirs = {".git", "__pycache__"}
exclude_files = {output_file}

# 出力ファイルを開く
with open(output_file, "w", encoding="utf-8") as outfile:
    # リポジトリのルートディレクトリから全てのサブディレクトリを再帰的に探索
    for root, dirs, files in os.walk(repo_root):
        # 除外するディレクトリをフィルタリング
        dirs[:] = [
            d
            for d in dirs
            if d not in exclude_dirs
            and not spec.match_file(os.path.relpath(os.path.join(root, d), repo_root))
        ]
        for filename in files:
            # 出力ファイルや除外ファイルをスキップ
            if filename in exclude_files:
                continue
            # ファイルの相対パスを取得
            file_path = os.path.join(root, filename)
            relative_path = os.path.relpath(file_path, repo_root).replace("\\", "/")
            # .gitignore により除外されたファイルをスキップ
            if spec.match_file(relative_path):
                continue
            # 区切り線とファイル名を書き込む
            outfile.write("---\n")
            outfile.write(f"{relative_path}\n\n")

            # ファイル内容を読み込んで書き込む
            try:
                with open(file_path, "r", encoding="utf-8") as infile:
                    outfile.write(infile.read())
            except (PermissionError, FileNotFoundError, IsADirectoryError) as e:
                print(f'警告: ファイル "{relative_path}" を読み込めませんでした: {e}')
            outfile.write("\n")

print(f"全てのファイルが {output_file} に結合されました。")
