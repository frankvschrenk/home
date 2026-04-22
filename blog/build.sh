#!/usr/bin/env bash
#
# build.sh — render the onisin OS blog.
#
# Reads every Markdown file in posts/ and produces a matching HTML
# file under articles/. Each post must start with a YAML front matter
# block like this:
#
#     ---
#     title: "Warum wir kein Framework nutzen"
#     date: 2026-04-22
#     description: "Ein kurzer Rant über Toolchain-Müdigkeit."
#     ---
#
# After rendering all posts, the script regenerates blog/index.html
# from the titles, dates and descriptions of the posts, sorted by
# date (newest first).
#
# Requirements: pandoc (brew install pandoc).
#
# Usage: run from anywhere; the script locates itself.

set -euo pipefail

# Resolve the directory this script lives in, independent of the
# caller's current working directory.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
POSTS_DIR="$SCRIPT_DIR/posts"
OUT_DIR="$SCRIPT_DIR/articles"
TEMPLATE="$SCRIPT_DIR/template.html"
INDEX="$SCRIPT_DIR/index.html"

if ! command -v pandoc >/dev/null 2>&1; then
  echo "Error: pandoc is not installed. Run: brew install pandoc" >&2
  exit 1
fi

mkdir -p "$OUT_DIR"

# ---------------------------------------------------------------
# Step 1: render every post.
#
# A temporary manifest file collects one line per post in the form:
#     <date>|<slug>|<title>|<description>
# This is later sorted and used to build the index.
# ---------------------------------------------------------------

MANIFEST="$(mktemp)"
trap 'rm -f "$MANIFEST"' EXIT

shopt -s nullglob
post_count=0

for md in "$POSTS_DIR"/*.md; do
  slug="$(basename "$md" .md)"
  out="$OUT_DIR/$slug.html"

  # Extract a single YAML front matter field from a Markdown file.
  # Reads only the first `---`-delimited block at the top of the
  # file, strips optional surrounding quotes, and prints the value.
  # Robust enough for our schema (title, date, description) without
  # pulling in a YAML parser.
  read_fm() {
    local file="$1" key="$2"
    awk -v key="$key" '
      BEGIN          { in_fm = 0 }
      NR == 1 && /^---[[:space:]]*$/ { in_fm = 1; next }
      in_fm && /^---[[:space:]]*$/   { exit }
      in_fm {
        # Match "key: value" at the start of the line.
        if (match($0, "^" key "[[:space:]]*:[[:space:]]*")) {
          val = substr($0, RLENGTH + 1)
          # Strip surrounding single or double quotes.
          sub(/^"/, "", val); sub(/"$/, "", val)
          sub(/^\x27/, "", val); sub(/\x27$/, "", val)
          print val
          exit
        }
      }
    ' "$file"
  }

  title="$(read_fm "$md" title)"
  date="$(read_fm "$md" date)"
  description="$(read_fm "$md" description)"

  if [[ -z "$title" || -z "$date" ]]; then
    echo "Skipping $md: missing title or date in front matter" >&2
    continue
  fi

  # Human-readable date (German). Fall back to the raw date if the
  # machine's locale cannot format it.
  date_human="$(
    LC_TIME=de_DE.UTF-8 date -j -f "%Y-%m-%d" "$date" "+%-d. %B %Y" 2>/dev/null \
      || echo "$date"
  )"

  pandoc "$md" \
    --from=markdown+smart \
    --to=html5 \
    --template="$TEMPLATE" \
    --metadata=date-human:"$date_human" \
    --output="$out"

  echo "  rendered  $slug"
  printf '%s|%s|%s|%s\n' "$date" "$slug" "$title" "$description" >> "$MANIFEST"
  post_count=$((post_count + 1))
done

# ---------------------------------------------------------------
# Step 2: rebuild blog/index.html from the manifest.
#
# Posts are sorted by date, newest first. The HTML shell mirrors
# the article template so the header, styling and footer stay
# consistent across the whole blog.
# ---------------------------------------------------------------

{
  cat <<'HTML_HEAD'
<!DOCTYPE html>
<html lang="de">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Blog — onisin OS</title>
  <meta name="description" content="Beiträge rund um onisin OS, KI-gestützte Anwendungsentwicklung und Datensouveränität.">
  <link rel="stylesheet" href="blog.css">
</head>
<body>

<header class="site">
  <div class="wrap">
    <div class="brand">
      <span class="dot"></span>
      <a href="/">onisin OS</a>
    </div>
    <nav class="primary">
      <a href="/#how">Wie es funktioniert</a>
      <a href="/#security">Sicherheit</a>
      <a href="/blog/" class="active">Blog</a>
      <a href="https://docs.onisin.com">Docs</a>
      <a class="gh-link" href="https://github.com/frankvschrenk/onisin"
         target="_blank" rel="noopener" aria-label="onisin OS on GitHub">
        <svg viewBox="0 0 16 16" xmlns="http://www.w3.org/2000/svg"
             fill="currentColor" aria-hidden="true">
          <path d="M8 0C3.58 0 0 3.58 0 8c0 3.54 2.29 6.53 5.47 7.59.4.07.55-.17.55-.38 0-.19-.01-.82-.01-1.49-2.01.37-2.53-.49-2.69-.94-.09-.23-.48-.94-.82-1.13-.28-.15-.68-.52-.01-.53.63-.01 1.08.58 1.23.82.72 1.21 1.87.87 2.33.66.07-.52.28-.87.51-1.07-1.78-.2-3.64-.89-3.64-3.95 0-.87.31-1.59.82-2.15-.08-.2-.36-1.02.08-2.12 0 0 .67-.21 2.2.82.64-.18 1.32-.27 2-.27.68 0 1.36.09 2 .27 1.53-1.04 2.2-.82 2.2-.82.44 1.1.16 1.92.08 2.12.51.56.82 1.27.82 2.15 0 3.07-1.87 3.75-3.65 3.95.29.25.54.73.54 1.48 0 1.07-.01 1.93-.01 2.2 0 .21.15.46.55.38A8.01 8.01 0 0 0 16 8c0-4.42-3.58-8-8-8Z"/>
        </svg>
        <span>GitHub</span>
      </a>
    </nav>
  </div>
</header>

<section class="blog-hero">
  <div class="wrap">
    <h1>Blog</h1>
    <p class="lead">
      Gedanken zu onisin OS, KI-gestützter Anwendungsentwicklung und
      dazu, warum Daten nicht das Unternehmen verlassen müssen, um
      nützlich zu sein.
    </p>
  </div>
</section>

<div class="wrap">
HTML_HEAD

  if [[ "$post_count" -eq 0 ]]; then
    cat <<'HTML_EMPTY'
  <div class="post-list-empty">
    <p>Noch keine Beiträge. Bald mehr an dieser Stelle.</p>
  </div>
HTML_EMPTY
  else
    echo '  <ul class="post-list">'
    # Sort by date descending (newest first). The separator is '|'
    # which safely never appears inside a title in practice.
    sort -r "$MANIFEST" | while IFS='|' read -r date slug title description; do
      date_human="$(
        LC_TIME=de_DE.UTF-8 date -j -f "%Y-%m-%d" "$date" "+%-d. %B %Y" 2>/dev/null \
          || echo "$date"
      )"
      cat <<HTML_ITEM
    <li>
      <a class="post-link" href="articles/$slug.html">
        <div class="post-meta">$date_human</div>
        <h2>$title</h2>
        <p class="teaser">$description</p>
      </a>
    </li>
HTML_ITEM
    done
    echo '  </ul>'
  fi

  cat <<'HTML_FOOT'
</div>

<footer class="site">
  <div class="wrap">
    <div>© 2026 Frank &amp; Tristan von Schrenk · onisin OS ist source-available.</div>
    <div>
      <a href="https://docs.onisin.com">Docs</a>
      &nbsp;·&nbsp;
      <a href="https://docs.onisin.com/license.html">License</a>
    </div>
  </div>
</footer>

</body>
</html>
HTML_FOOT
} > "$INDEX"

echo
echo "Built $post_count post(s)."
echo "Open: $INDEX"
