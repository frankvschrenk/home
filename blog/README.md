# onisin OS Blog

Minimal static blog. No framework, no build server, no Ruby.
Just Markdown files and a shell script that calls pandoc.

## Schreiben

Neuen Artikel anlegen:

```bash
cd blog/posts
touch 2026-04-25-mein-titel.md
```

Jeder Artikel braucht ein YAML-Frontmatter am Anfang:

```markdown
---
title: "Der sichtbare Titel"
date: 2026-04-25
description: "Ein bis zwei Sätze, die in der Übersicht als Teaser erscheinen."
---

Hier beginnt der eigentliche Inhalt, ganz normales Markdown.
```

Der Dateiname bestimmt die URL: `2026-04-25-mein-titel.md` wird zu
`/blog/articles/2026-04-25-mein-titel.html`. Das Datum im Dateinamen
ist Konvention (hilft beim Sortieren im Editor), ausschlaggebend für
die Reihenfolge auf der Übersichtsseite ist aber das `date:` im
Frontmatter.

## Bauen

```bash
cd blog
./build.sh
```

Das Skript:

1. rendert jede `posts/*.md` zu `articles/<slug>.html`
2. regeneriert `blog/index.html` mit der aktuellen Artikelliste,
   sortiert nach Datum (neueste zuerst)

## Veröffentlichen

`git add`, `git commit`, `git push`. GitHub Pages macht den Rest.
Da das gerenderte HTML committet wird, funktioniert die Seite auch
ohne jeglichen CI-Build.

## Voraussetzung

Einmal pandoc installieren:

```bash
brew install pandoc
```

## Artikel löschen

Markdown-Datei aus `posts/` entfernen, HTML-Datei aus `articles/`
entfernen, dann `./build.sh` erneut laufen lassen. Das Skript löscht
keine verwaisten HTML-Dateien automatisch — bewusst, damit du keine
Überraschungen erlebst.
