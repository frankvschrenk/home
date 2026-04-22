# Drafts

Hier liegen unveröffentlichte Entwürfe. Dateien in diesem Ordner
werden vom `build.sh` **nicht** verarbeitet – das Skript liest
ausschließlich `posts/*.md`.

## Workflow

1. Idee als `drafts/irgendwas.md` anfangen (kein Frontmatter nötig)
2. Wenn fertig: Datei nach `posts/` verschieben und den Namen in das
   Datumsschema bringen: `2026-04-25-mein-titel.md`
3. Frontmatter (`title`, `date`, `description`) ergänzen
4. `./build.sh` laufen lassen, `git push` – fertig.

Obsidian nimmt das Umbenennen und Verschieben übrigens ohne zu
murren hin; interne Links bleiben dabei automatisch korrekt.
