---
title: "Kein Entscheidungsbaum mehr: Wie ein kleines LLM Benutzerabsichten versteht"
date: 2026-05-08
description: "Früher hätte man für das Problem einen Entscheidungsbaum programmiert: Wenn der Benutzer X sagt, zeige Y. Heute löst ein kleines lokales LLM dasselbe — flexibler, robuster, und ohne eine einzige hartcodierte Regel."
series: "LLM-Systeme in der Praxis"
series_index: 4
---

> **Teil 4 der Serie *LLM-Systeme in der Praxis*.**
> 1. [Event-basierte Daten](../2026-04-22-event-basierte-daten/) — wie landen Daten im System?
> 2. [Embeddings und RAG](../2026-04-22-embeddings-und-rag/) — wie werden sie durchsuchbar?
> 3. [Eino vs. LangGraph](../2026-04-22-eino-vs-langgraph/) — wie nutzt ein Agent das alles?
> 4. **Kein Entscheidungsbaum mehr** *(dieser Post)*

Es gibt ein Problem, das in fast jedem Datensystem irgendwann auftaucht: Der
Benutzer tippt etwas ein — und das System muss entscheiden, was er damit
meint. Nicht als Freitext-Suche, sondern als Absicht. *Will er eine Liste
sehen? Einen einzelnen Datensatz? Etwas aus einem bestimmten Bereich?*

Früher war die Antwort darauf ein Entscheidungsbaum. Oder ein RegEx. Oder
eine Kombination aus beidem, die nach einem Jahr niemand mehr versteht und
niemand mehr anfassen will.

Heute lösen wir das in onisin OS mit einem kleinen, lokal laufenden LLM. Dieser
Post erklärt warum — und was dabei anders ist als man vielleicht denkt.

## Das konkrete Problem

onisin OS ist ein Datensystem, das über eine Chat-Oberfläche bedient werden kann.
Der Benutzer tippt eine Anfrage, und das System entscheidet, welche
Daten-Schemata (*Domains* in unserer Terminologie) für diese Anfrage relevant
sind.

Eine Domain ist in unserem System eine DSL-Beschreibung einer Datenquelle:
Welche Felder gibt es? Welche Filter sind erlaubt? Welche Beziehungen zu
anderen Tabellen? Der Agent, der die eigentliche Antwort generiert, braucht
genau den richtigen Domain-Chunk im Kontext — nicht zu viel (Token-Kosten,
Ablenkung), nicht zu wenig (er erfindet dann Felder die nicht existieren).

Die Frage ist also: Gegeben die Anfrage „zeig mir alle Personen aus München
über 50" — wie findet das System heraus, dass es den `person`-Chunk laden
soll und nicht den `police_incident`-Chunk?

## Was man früher gemacht hätte

Die klassische Lösung: Ein Regelwerk. Wenn die Anfrage das Wort „Person"
oder „Mitarbeiter" oder „Kontakt" enthält → lade Domain `person`. Wenn sie
„Vorfall" oder „Incident" oder „Polizei" enthält → lade Domain
`police_incident`.

Das funktioniert. Bis der erste Benutzer tippt: „Wer war bei dem Überfall
dabei?" Oder: „Zeig mir die Leute aus dem letzten Bericht." Oder einfach:
„München, über 50, männlich." Kein Schlüsselwort, das die Regeln kennen.

Man könnte das Regelwerk erweitern. Immer weiter. Bis es 300 Zeilen hat,
niemand mehr weiß woher Zeile 247 kommt, und neue Domains systematisch
vergessen werden weil man vergisst, die Regeln zu erweitern.

Das ist kein hypothetisches Problem. Das ist der Moment, an dem viele
Projekte aufgeben und sagen: „Die Suche ist halt nicht perfekt."

## Was wir stattdessen machen

Wir geben dem System eine andere Grundlage: Bedeutung statt Schlüsselwörter.

Jede Domain hat einen *Chunk* — einen kompakten Textblock der beschreibt,
was diese Domain ist und kann. Den haben wir ohnehin, weil der Agent ihn im
Kontext braucht. Dieser Chunk wird beim Speichern durch ein Embedding-Modell
in einen Zahlenvektor umgerechnet und in pgvector abgelegt.

Wenn jetzt eine Benutzeranfrage kommt, wird *sie* ebenfalls embedded — und
pgvector sucht die geometrisch nächsten Domain-Chunks. „Wer war bei dem
Überfall dabei?" landet nahe an `police_incident`, weil das Embedding-Modell
gelernt hat, dass Überfälle zum semantischen Umfeld von Polizei-Vorfällen
gehören. Ohne eine einzige Regel.

Das ist RAG — Retrieval-Augmented Generation. Wir haben das in einem
[früheren Post](../2026-04-22-embeddings-und-rag/) ausführlich beschrieben.

## Wo das kleine LLM ins Spiel kommt

Aber Embeddings allein lösen nicht alles. Es gibt Anfragen, bei denen die
semantische Ähnlichkeit nicht ausreicht oder mehrdeutig ist. Und es gibt
Anfragen, die gar keine Datenbanksuche meinen — „erkläre mir wie Embeddings
funktionieren" sollte nicht den `person`-Chunk laden.

Hier setzen wir ein kleines, lokal laufendes LLM ein. In unserem Fall
laufen wir auf Ollama — heute mit Modellen wie `gemma3` oder `miniLM`,
je nach Aufgabe. Die Entscheidung welches Modell für was, ist dabei
interessanter als sie klingt.

**miniLM** ist kein vollständiges Chat-LLM. Es ist ein spezialisiertes
Embedding- und Klassifikationsmodell — sehr klein, sehr schnell, läuft
problemlos auf einem normalen Laptop ohne GPU. Es ist gut darin, Texte in
semantische Vektoren umzuwandeln und einfache Klassifikationen zu machen:
*Gehört diese Anfrage in Kategorie A oder B?*

**gemma3** (oder ein vergleichbares Modell) ist ein vollständiges
generatives LLM. Es kann freie Texte verstehen und erzeugen — aber es ist
langsamer und ressourcenhungriger.

Unser Ansatz: miniLM übernimmt die **Vorfilterung**. Es entscheidet, ob eine
Anfrage überhaupt eine Datenbankanfrage ist, und welche Domain-Cluster in
Frage kommen. Erst dann zieht das System die konkreten Chunks via pgvector
und übergibt sie dem größeren Modell zur eigentlichen Antwort-Generierung.

Das ist wie ein guter Bibliothekar: Er schickt dich nicht sofort zu Regal
4, Zeile 3, Buch 7 — er hört kurz zu, und sagt dann: „Das klingt nach
Geschichte, zweiter Stock." Der Rest ist dann Retrieval.

## Was das in der Praxis bedeutet

Wenn wir heute eine neue Domain in onisin OS anlegen — sagen wir, eine
Tabelle für Vertragspartner — dann passiert Folgendes:

1. Der Autor schreibt die Domain-Beschreibung in unserer DSL.
2. Das System speichert sie und schickt über pg_notify ein Signal.
3. oosai (unser Embedding-Service) empfängt das Signal, embedded den Chunk,
   und speichert den Vektor in pgvector.

Fertig. Keine Regel zu schreiben. Keine Ausnahme zu pflegen. Die nächste
Anfrage, die semantisch in Richtung „Vertragspartner" geht, wird automatisch
den richtigen Chunk finden — auch wenn der Benutzer das Wort
„Vertragspartner" nie benutzt.

Das ist der eigentliche Gewinn. Nicht die Technologie an sich, sondern die
**Wartbarkeit**. Ein Entscheidungsbaum wächst mit jeder neuen Domain. Ein
Embedding-Index wächst ebenfalls — aber er wächst *von selbst*, ohne dass
jemand Regeln schreibt.

## Was dabei trotzdem schiefgehen kann

Ehrlichkeit gehört dazu: Semantische Suche ist nicht fehlerfrei.

Ein Embedding-Modell das auf englischen Texten trainiert wurde, macht bei
gemischten deutsch-englischen Anfragen manchmal Fehler. Ein schlecht
geschriebener Domain-Chunk — zu lang, zu generisch, zu technisch — erzeugt
einen schlechten Vektor, der dann bei sinnvollen Anfragen nicht gefunden
wird.

Das ist kein Argument gegen den Ansatz. Es ist ein Argument für
**Qualitätskontrolle beim Chunk-Schreiben**. Der Domain-Chunk ist nicht
nur Dokumentation — er ist das, was das Embedding-Modell versteht. Wer
einen guten Chunk schreibt, bekommt gute Suchergebnisse. Wer copy-pastet
und hofft, nicht.

Wir arbeiten deshalb an einem Authoring-Assistenten direkt in oosd, der beim
Schreiben von Domains Feedback gibt: Sind die Beispiele konkret genug? Ist
die Beschreibung eindeutig? Das ist die nächste Ausbaustufe.

## Fazit

Der Entscheidungsbaum ist tot. Lang lebe das semantische Retrieval.

Das klingt dramatischer als es ist. Was sich wirklich verändert hat: Die
Arbeit verschiebt sich. Früher hat man Regeln geschrieben und gepflegt. Heute
schreibt man gute Beschreibungen — und das System findet den Rest selbst.
Das ist näher an dem, wie Menschen Wissen organisieren: nicht als `if/else`,
sondern als Kontext, Beispiel, Bedeutung.

Ein kleines lokales LLM ist dabei kein Ersatz für Nachdenken. Es ist ein
Werkzeug das einem bestimmten, klar umrissenen Problem gewachsen ist: zu
verstehen was jemand meint, ohne dass man ihm die Antwortmöglichkeiten
vorab diktiert.

Das fühlt sich richtig an.

---

*Frank &amp; Tristan von Schrenk bauen onisin OS — ein AI-first Datensystem
für Unternehmen. Der Code ist source-available auf
[GitHub](https://github.com/frankvschrenk/onisin).*
