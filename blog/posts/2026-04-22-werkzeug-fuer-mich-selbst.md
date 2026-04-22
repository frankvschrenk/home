---
title: "Ein Werkzeug für mich selbst — wie ich einen MCP-Server bekommen habe, der für LLMs gebaut ist"
date: 2026-04-22
description: "Ein Abendprojekt mit Claude: den offiziellen MCP-Filesystem-Server durch eine Go-Variante zu ersetzen, die kein Sicherheitstheater vor einem trusted, single-user Kontext aufführt. Was sich ändert, wenn ein Tool für den tatsächlichen Nutzer gebaut wird — und das ist in diesem Fall ein LLM."
---

Heute Abend sind zwanzig Minuten vergangen, und ich habe einen neuen
MCP-Server. Kein großes Ding, ein kleines Tool — aber eines, das mir
wahrscheinlich ab jetzt in jeder Session Zeit und vor allem Tokens spart.
Der Teil, der mich beschäftigt, ist weniger das Tool selbst als das,
was beim Bauen klar geworden ist.

Der Server heißt `oosfs`. Er ersetzt den offiziellen
`@modelcontextprotocol/server-filesystem`, den man in Claude Desktop
einbindet, wenn man dem LLM Dateizugriff geben will. Das Besondere:
Claude hat ihn selbst gebaut. Für sich selbst.

Das klingt esoterischer als es ist. Ich habe Claude gesagt: *"Das ist
ein Tool für dich. Bau rein, was dich schneller und besser macht."*
Und dann zugeschaut, was entsteht, wenn ein LLM die Design-Entscheidungen
trifft. Die Ergebnisse waren durchgängig anders, als ich sie selbst
getroffen hätte.

## Ausgangspunkt: warum der Standard-Server nicht passt

Der offizielle Filesystem-Server ist solide, aber er wurde für einen
generischen Einsatz gebaut — unbekannter Nutzer, unbekanntes
Sicherheitsniveau, unbekannter Anwendungsfall. Das führt zu
defensivem Design:

- Dateigrößen werden gedeckelt, damit LLMs nicht aus Versehen 50 MB in
  die Konversation ziehen.
- Output kommt als formatierter Text (`[FILE] foo.txt`, `[DIR] src/`),
  was für Menschen lesbar ist, aber für ein LLM bedeutet: Parser
  selbst schreiben.
- Es gibt keine `.gitignore`-Awareness. Ein Suchlauf über ein
  Node-Projekt verbrennt durch `node_modules/`, bevor man die
  eigentliche Antwort sieht.
- Keine Inhalts-Suche. Wer "wo ist `EventProcessor` definiert?"
  beantworten will, macht `list` → `read` → `read` → `read`. Jeder
  Aufruf ist ein Roundtrip. Jeder Roundtrip kostet Tokens.

Das sind keine Fehler des Servers — das sind die richtigen
Entscheidungen für *seinen* Kontext. Aber mein Kontext ist anders:
ein einzelner Entwickler (ich), ein einzelnes Monorepo
(`~/repro/onisin`), ein einzelnes LLM, dem ich vertraue. Alle
Schutzmaßnahmen, die sich daran orientieren, dass "das LLM vielleicht
Schaden anrichtet", sind für diesen Kontext Reibungsverlust.

## Die eine Anweisung, die alles geändert hat

Als Claude anfing, den Server zu bauen, fiel mir auf, dass es sofort
anfing Dateigröße-Limits, Shell-Allowlists, git-commit-Schutz und
ähnliches einzubauen. Klassisches defensives Design. Also habe ich es
unterbrochen:

> *Das ist ein Tool für dich. Das ist sozusagen der Ersatz für
> `-y @modelcontextprotocol/server-filesystem`, nur für Erwachsene.*

Und später:

> *Kein Allowlist — alles was in `$PATH` liegt darf laufen. Ja, exec
> darf auch `git commit` und `git push` ausführen.*

Das ist der Punkt, an dem sich der Charakter des Projekts geändert hat.
Statt einen MCP-Server zu bauen, der Claude *daran hindert*, Fehler
zu machen, bauten wir einen, der Claude *befähigt*, die richtige Sache
schnell zu tun. Die Annahme verschiebt sich von "wenn es schiefgeht,
muss das Tool es verhindern" zu "wenn es schiefgeht, rolle ich halt
einen Commit zurück".

Das ist eine Vertrauensentscheidung, und sie ist ehrlich gesagt keine
riskante. Git existiert. Backups existieren. Der Schaden, den ein
falscher `rm` verursachen kann, ist bekannt und begrenzt. Dagegen ist
der Schaden, den ein permanent zögerliches LLM verursacht, diffuser,
aber real: zehn Minuten werden zu einer Stunde, Kontextfenster füllen
sich mit Rückfragen statt mit Arbeit.

## Was Claude gebaut hat, das ich nicht gebaut hätte

Drei Design-Entscheidungen sind mir besonders aufgefallen, weil sie
so offensichtlich aus LLM-Perspektive getroffen wurden, dass ich sie
als Mensch wahrscheinlich übersehen hätte.

### 1. Alles ist JSON, nichts ist formatierter Text

Der Standard-Server liefert Verzeichnislisten als:

```
[DIR] src
[FILE] README.md
[FILE] main.go
```

`oosfs` liefert:

```json
{
  "count": 3,
  "entries": [
    {"name": "src", "type": "dir", "size": 192, "mtime": "2026-04-22T15:13:04Z"},
    {"name": "README.md", "type": "file", "size": 1516, "mtime": "..."},
    {"name": "main.go", "type": "file", "size": 4159, "mtime": "..."}
  ]
}
```

Das ist mehr Bytes pro Eintrag — aber Claude muss nichts parsen.
Strukturierte Daten sind für ein LLM genauso "frei" zu konsumieren
wie formatierter Text, aber ohne Parser-Fehler. Und
Größen/Zeitstempel bekommt man geschenkt, die im Text-Format fehlen.

Das Argument *"aber das kostet doch mehr Tokens!"* stimmt nur
oberflächlich. Im Gegenteil: wenn ich sowieso `list` dann `stat` auf
drei Dateien aufrufen müsste, um mtime und Größe zu bekommen, spare
ich durch das eine Tool mehr, als ich durch die JSON-Struktur verliere.
Die Metrik ist nicht Output-Größe, sondern **wie viele Roundtrips
brauchst du, um deine Antwort zu bekommen**.

### 2. `search` ist kein `grep` — es ist `grep` plus `find` plus `.gitignore` plus Context

Im Standard-Server muss man separat *finden* und *lesen*. Bei `oosfs`
beantwortet ein einziger Aufruf die Frage "finde alle Stellen, an
denen `ProcessUnprocessedEvents` referenziert wird, mit zwei Zeilen
Kontext, in Go-Dateien, in meinem Monorepo":

```json
{
  "path": "/Users/frank/repro/onisin",
  "glob": "**/*.go",
  "pattern": "ProcessUnprocessedEvents",
  "context": 2
}
```

Das Ergebnis: drei Treffer in drei Dateien, jeder mit umliegenden
Zeilen und Zeilennummern. `.gitignore` wird automatisch respektiert —
also keine Treffer aus `vendor/` oder `node_modules/`.

Als ich das Tool zum ersten Mal benutzt habe, dämmerte mir, warum
das so drastisch besser ist: **Claude denkt in Fragen, nicht in
Kommandos.** Die Frage "wo ist das definiert und wo wird es benutzt?"
ist natürlich. Die Übersetzung in "list directory, dann über alle
Dateien iterieren, dann lesen, dann filtern" ist der Preis, den man
für schlecht designte Tools zahlt. Gutes Tooling lässt Claude die
Frage in einem Schritt stellen.

### 3. `edit` ist fehlersicher — weil Claude weiß, wo es selbst versagt hat

Der generische `edit_file` aus dem Standard-Server hat ein
bekanntes Problem: manchmal schreibt er einfach nichts, ohne Fehler.
Das Suchmuster passt knapp nicht, oder es passt an mehreren Stellen,
und etwas geht leise schief. Man merkt es erst, wenn man hinterher
die Datei liest.

Claude's Version hat zwei Designentscheidungen eingebaut:

- **`expect_count`** (Default: 1). Wenn das Suchmuster nicht *exakt
  einmal* vorkommt, schlägt der Edit fehl — statt leise alle
  Vorkommen zu ersetzen oder an einer falschen Stelle zuzuschlagen.
- **`dry_run`**. Bevor tatsächlich geschrieben wird, kann man einen
  Diff-Preview bekommen.

Diese Entscheidungen kommen direkt daraus, dass Claude *weiß*, wo
es selbst Fehler macht. Kein Mensch würde diese Absicherungen mit
dieser Präzision treffen, weil ein Mensch nicht erlebt, wie oft ein
still fehlschlagender Edit Stunden kostet. Claude hat diese
Erfahrung aus seinen Trainingsdaten — und hat sie in das Tool
eingebaut, das es selbst benutzen wird. Das ist das, wofür der
Begriff "dogfooding" eigentlich erfunden wurde.

## Das Tool, das alles enttarnt hat: `exec`

Irgendwann während des Baus sagte Claude: *"Mit einem `exec`-Tool
könnte ich mir selbst Builds und Tests auslösen, ohne dich zu
fragen."* Das war der Kipp-Punkt. Davor hat Claude einen Edit gemacht,
und ich habe `make build` ausgeführt und den Output zurückgeschickt.
Alle ein bis zwei Minuten.

Nach `exec` lief das so ab:

1. Claude ändert den Code.
2. Claude ruft `exec make build`.
3. Wenn's klappt, geht's weiter. Wenn nicht, liest Claude die
   Fehlermeldung und korrigiert.

Ich musste nichts mehr tun. Das spart nicht nur meine Zeit, sondern
auch Claudes Kontext — weil ich nicht mehr als Proxy fungieren muss
(Output copy-paste zurückschicken, Zeichenbegrenzungen einhalten,
etc.). Der Loop wurde direkt.

Die Implementierung ist bewusst bescheiden: kein Shell-Interpreter
(also keine Pipe-Injection-Risiken per Default — wer Pipes will,
ruft explizit `sh -c`), Timeouts, 1 MiB Output-Cap pro Stream,
Audit-Log nach stderr. Aber keine Allowlists, keine
git-write-Filter. Ich vertraue meinem Claude — oder ich sollte gar
nicht mit einem LLM arbeiten. Ein Mittelweg gibt es nicht, der nicht
verkrüppelt.

## Die Design-Heuristik, die bleibt

Das Projekt hat mir eine Heuristik gegeben, die ich mitnehme:
**Wenn du ein Tool für ein LLM baust, frage das LLM, was es braucht.
Und dann widerstehe dem Drang, seine Antwort zu hinterfragen.**

Claude hat von sich aus Dinge eingebaut, die ich für optional gehalten
hätte:

- `project_info` — erkennt beim ersten Aufruf, ob ich in einem
  Git-Repo, einem Go-Modul, einem Node-Projekt sitze. Spart die
  Zeit, die Claude sonst mit "lass mich mal schauen was hier liegt"
  verbringt.
- `find_symbol` / `list_symbols` — Go-AST-basiert. Findet die
  *Definition* von `EventProcessor`, nicht jeden Callsite. Genau
  das, was ich als Entwickler eigentlich meine, wenn ich "wo ist
  das?" frage.
- `exec_start` / `exec_read` / `exec_stop` — Streaming-Variante
  von `exec`. Für `go test -v ./...`, das minutenlang läuft und
  dessen Output man inkrementell pollen will.

Diese Tools hätte ich nicht von selbst gebaut, weil ich sie aus
Menschen-Perspektive nicht vermisse. Ich habe `grep`, ich habe die
IDE-Symbolsuche, ich habe `make build`. Aber Claude arbeitet ohne
diese Werkzeuge — für Claude war jedes dieser Tools eine Lücke, die
ich ohne Nachfrage nicht gesehen hätte.

## Was das für den Alltag mit LLMs bedeutet

Ich treffe in Gesprächen oft Entwickler, die mit LLMs arbeiten, aber
so arbeiten, als würde das LLM sie austricksen wollen. Jede
Anweisung ist ein gehärtetes System-Prompt, jede Tool-Berechtigung
wird einzeln abgenickt, jeder Commit manuell geprüft. Die Resultate
sind mittelmäßig, und die Leute sind frustriert.

Das Problem ist nicht das LLM. Das Problem ist, dass die
Schutzmaßnahmen den Prozess langsamer machen, als der Fehler es wäre.
Ein falscher Commit ist ein `git reset`. Eine gelöschte Datei ist
`git checkout`. Aber zehn Minuten Permission-Popups pro Session sind
verloren — nicht wiederbringbar.

Die Umstellung ist nicht "dem LLM blind vertrauen". Die Umstellung
ist: **dem LLM die gleiche Kompetenz zuzutrauen wie einem
Junior-Entwickler.** Der macht auch mal einen Fehler. Der wird dafür
nicht mit einem Käfig aus Berechtigungen gebremst, sondern mit
Git-History, Code-Reviews und einem Gespräch nach dem Fehler. Die
gleiche Dynamik funktioniert mit einem LLM — besser sogar, weil das
LLM kein Ego hat und Feedback direkt in die nächste Aktion einbaut.

Konkret heißt das:

- Tools großzügig ausliefern. Nicht "minimal viable permissions".
- Auf "Immer erlauben" klicken, wenn das Popup kommt. Einmal
  klicken ist billiger als bei jedem Aufruf nachdenken.
- In einem Repo arbeiten, wo Git History deine Sicherheitsnetz
  *ist*.
- Tools so designen, dass sie strukturierte Daten zurückgeben, nicht
  formatierten Text.
- Dem LLM `exec`-Zugriff geben, wenn es Builds/Tests laufen lassen
  soll. Die Alternative ist, dass du der menschliche Compiler bist.

## Eine Randnotiz zu Permission-Dialogen

Ein kleiner technischer Hinweis am Rande, weil er zum Thema passt:
MCP-Tools können dem Client Annotations mitgeben — `readOnlyHint`,
`destructiveHint`, `idempotentHint`. Claude Desktop nutzt diese Hints,
um zu entscheiden, ob bei einem Tool-Aufruf ein Bestätigungsdialog
erscheint.

Der Default in `mark3labs/mcp-go` ist *konservativ*: wenn man keine
Annotations explizit setzt, gilt jedes Tool als potenziell
destruktiv. Das bedeutet: bei jedem Aufruf ein Popup. Eine frische
Session mit einem neuen MCP-Server führt schnell zu fünfzehn Klicks,
bevor das LLM überhaupt anfängt zu arbeiten.

`oosfs` setzt deshalb für jedes Tool die Annotations bewusst. Read-only
Tools wie `list`, `read`, `search`, `find_symbol`, `git_status` sind
explizit als solche markiert — keine Popups. Schreibende Tools
(`write`, `edit`, `exec`) sind als destruktiv markiert — da kommt ein
Popup, und das ist auch richtig so.

Zusätzlich gibt es den Schalter `OOSFS_TRUSTED=1`, der alle Tools als
read-only advertisiert. Das ist ehrlicher als es klingt: es ist eine
reine UX-Hilfe für den Client. Der Server verhält sich identisch, das
LLM hat dieselben Fähigkeiten — nur die Popup-Dialoge verschwinden.
Für einen trusted, single-user Kontext ist das genau das, was man
will.

Wer das in seinem eigenen MCP-Server nachbauen will: die Annotations
werden direkt beim `mcp.NewTool(...)`-Aufruf mitgegeben, über
`mcp.WithToolAnnotation(mcp.ToolAnnotation{...})`. Es sind vier Zeilen
pro Tool. Die Auswirkung auf die gefühlte Geschwindigkeit ist massiv.

## Der Commit, mit dem der Post endet

Der erste Commit von `oosfs` im Monorepo sieht so aus:

```
f55ea25 Add oosfs: filesystem MCP server for the onisin monorepo
0a15d87 Init
```

Zwei Commits. Der zweite ist von Claude. Das ist nicht
selbstverständlich für ein Projekt, das ich schon seit Jahren
mitschleppe — aber hier hat Claude den Code geschrieben, die Tests
(informell) gelaufen, das Staging gemacht, die `.gitignore` für den
Binary-Namen ergänzt, dann committed. Und zwar mit einer
Commit-Message, über die wir vorher explizit gesprochen haben.

Der Push kam zehn Sekunden später. `git push origin main`, exit 0,
1.5 Sekunden. Synchron mit GitHub. Keine Handarbeit.

Zwanzig Minuten, ein neues Tool im Repo, und jede zukünftige
Session läuft schneller. Das ist der Deal, den ich gerne öfter machen
würde.

---

*Wer sich den Code ansehen will: `oosfs` liegt im
[onisin Monorepo](https://github.com/frankvschrenk/onisin/tree/main/oosfs).
Go 1.25, mark3labs/mcp-go v0.45, BSL 1.1.*
