#!/usr/bin/env python3
"""Prints one version's CHANGELOG.md entry as HTML, for Sparkle's update window.

Usage: release-notes.py CHANGELOG.md 1.1.0
Handles what the changelog uses: ### headings, - bullets (with indented sub-bullets and
wrapped lines), **bold**, and `code`.
"""
import html
import re
import sys


def inline(text):
    text = html.escape(text)
    text = re.sub(r"\*\*(.+?)\*\*", r"<strong>\1</strong>", text)
    return re.sub(r"`(.+?)`", r"<code>\1</code>", text)


def entry(changelog, version):
    lines, inside = [], False
    for line in changelog.splitlines():
        if line.startswith("## "):
            if inside:
                break
            inside = line.startswith(f"## [{version}]")
            continue
        if inside:
            lines.append(line)
    if not inside and not lines:
        sys.exit(f"No entry for {version} in the changelog.")
    return lines


def to_html(lines):
    out, items, depth = [], [], 0
    # Join wrapped lines onto their bullet first.
    for line in lines:
        stripped = line.strip()
        if not stripped:
            continue
        if stripped.startswith("### ") or stripped.startswith("- "):
            items.append([len(line) - len(line.lstrip()), stripped])
        elif items:
            items[-1][1] += " " + stripped
    for indent, text in items:
        level = 1 if indent >= 2 else 0
        if text.startswith("### "):
            while depth:
                out.append("</ul>")
                depth -= 1
            out.append(f"<h3>{inline(text[4:])}</h3>")
            continue
        while depth < level + 1:
            out.append("<ul>")
            depth += 1
        while depth > level + 1:
            out.append("</ul>")
            depth -= 1
        out.append(f"<li>{inline(text[2:])}</li>")
    out += ["</ul>"] * depth
    return "\n".join(out)


if __name__ == "__main__":
    path, version = sys.argv[1], sys.argv[2]
    with open(path, encoding="utf-8") as f:
        print(to_html(entry(f.read(), version)))
