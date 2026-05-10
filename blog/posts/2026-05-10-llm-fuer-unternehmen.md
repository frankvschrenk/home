---
title: "LLM für Unternehmen: Was wirklich zählt — und was nicht"
date: 2026-05-10
description: "GenAI, RAG, Fine-tuning, Routing, GPU-Infrastruktur: Ein Gespräch das ich heute geführt habe, hat mir gezeigt wie viel Klarheit entsteht wenn man die Konzepte wirklich durchdenkt — statt nur Buzzwords zu sammeln."
series: "LLM-Systeme in der Praxis"
series_index: 5
---

> **Teil 5 der Serie *LLM-Systeme in der Praxis*.**
> 1. [Event-basierte Daten](../2026-04-22-event-basierte-daten/) — wie landen Daten im System?
> 2. [Embeddings und RAG](../2026-04-22-embeddings-und-rag/) — wie werden sie durchsuchbar?
> 3. [Eino vs. LangGraph](../2026-04-22-eino-vs-langgraph/) — wie nutzt ein Agent das alles?
> 4. [Kein Entscheidungsbaum mehr](../2026-05-08-kein-entscheidungsbaum-mehr/) — Absichten verstehen ohne Regeln
> 5. **LLM für Unternehmen** *(dieser Post)*

Heute habe ich mich durch einen Stapel an Konzepten gearbeitet, die in der
Unternehmens-KI-Welt gerade alle gleichzeitig auftauchen: Snowflake Cortex,
AWS Bedrock, Databricks, RAG, Fine-tuning, LLM-Routing, GPU-Infrastruktur.
Einzeln kennt man sie. Zusammen ergibt sich ein Bild das ich aufschreiben will,
solange es frisch ist.

Nicht als Tutorial. Eher als Denkprotokoll.

## Convenience vs. Kontrolle

Snowflake hat eine Funktion namens `CORTEX.SUMMARIZE()`. Man gibt ihr einen
Text, sie gibt eine Zusammenfassung zurück. SQL-Syntax, ein Aufruf, fertig.

```sql
SELECT SNOWFLAKE.CORTEX.SUMMARIZE(schadenbericht_text)
FROM schaden_tabelle
WHERE datum > '2024-01-01';
```

Das ist verlockend. Und für viele Aufgaben — langen Text überblicken,
erste Kategorisierung, schneller Überblick — ist es auch ausreichend. Das
Modell dahinter ist ein Standard-LLM. Es muss den Inhalt nicht *verstehen*,
es muss nur Sprache beherrschen. Zusammenfassen ist ein sprachliches Problem,
kein Domänenproblem.

Aber sobald die Frage domänenspezifisch wird — *Ist dieser Schaden regulierungspflichtig?
Welche unserer Policen greift hier? Widerspricht das unseren AVB?* — reicht
allgemeines Sprachverständnis nicht mehr. Das Modell kennt eure internen
Bedingungswerke nicht. Es kennt eure Prozesse nicht. Es erfindet dann etwas,
das klingt als ob es stimmt.

Das ist der Moment, an dem Convenience zur Falle wird.

Der Unterschied zwischen `CORTEX.SUMMARIZE()` und einem direkten LLM-Aufruf
ist derselbe wie zwischen einem voreingestellten Equalizer und einem
Mischpult: Das eine ist schneller, das andere gibt Kontrolle darüber was
eigentlich passiert.

## Was RAG wirklich löst

RAG — Retrieval-Augmented Generation — ist die Antwort auf das Domänenproblem.
Nicht das einzige, aber meistens das richtige.

Die Idee ist einfach: Das Modell bleibt generisch. Das Wissen kommt zur
Laufzeit aus eigenen Quellen. Der Ablauf:

1. Eigene Dokumente werden in kleine Chunks zerlegt.
2. Jeder Chunk wird durch ein Embedding-Modell in einen Zahlenvektor umgerechnet.
3. Diese Vektoren landen in einer Vektordatenbank (pgvector, Pinecone, Weaviate...).
4. Kommt eine Anfrage, wird auch sie embedded — und die semantisch ähnlichsten
   Chunks werden herausgesucht.
5. Diese Chunks kommen zusammen mit der Anfrage als Kontext in den Prompt.
6. Das Modell antwortet auf Basis dieser echten Daten.

Semantisch, nicht lexikalisch. „Feuchtigkeitsschaden" findet auch Treffer für
„Schimmel" und „Durchfeuchtung" — weil das Embedding-Modell gelernt hat, dass
diese Begriffe im selben Bedeutungsraum liegen. Kein Regelwerk, das man pflegt.
Kein Dictionary, das man erweitert.

Das bauen wir in onisin OS täglich. Das Prinzip ist universell.

## Warum Fine-tuning meistens die falsche erste Wahl ist

Fine-tuning klingt attraktiv: Man nimmt ein fertiges Modell und trainiert es
auf eigenen Daten nach. Es lernt die eigene Sprache, die eigenen Begriffe,
den eigenen Stil.

Das Problem: Ein Modell hat kein Gedächtnis für Versionen.

Wenn man ein Modell auf AVB 2022 trainiert und dann auf AVB 2026 nachtrainiert,
vermischt sich beides irgendwo in den Gewichten. Das Modell weiß nicht was
gilt. Es antwortet mit einer Mischung — überzeugend formuliert, sachlich falsch.
Das nennt sich Catastrophic Forgetting, und es ist ein reales Problem, kein
theoretisches.

Bei RAG ist Versionierung trivial: Man aktualisiert das Dokument im Index.
Fertig. Das Modell bekommt beim nächsten Aufruf den neuen Chunk. Keine
Neutraining, kein Deployment, kein Risiko dass altes Wissen durchsickert.

Fine-tuning hat seinen Platz — für Stil, Ton, grundlegendes Vokabular, Dinge
die sich selten ändern. Aber als Ersatz für aktuelle Daten taugt es nicht.

**Kurzformel:** Fine-tuning für das *Was wir sind*. RAG für das *Was wir gerade wissen*.

## Das LLM als Sprachinterface — nicht als Sicherheitssystem

Ein Gedanke der mir wichtig ist, weil er in der Praxis oft falsch verstanden wird:

Ein LLM ist ein Sprachmodell. Es ist darauf trainiert, hilfreich zu sein.
Sicherheit ist kein Kernmerkmal — es ist eine nachträgliche Einschränkung.

Ein System Prompt der sagt „User darf nur Dokumente mit Tag xyz sehen" ist
kein Sicherheitssystem. Es ist eine höfliche Bitte an ein Modell das von
Natur aus helfen will. Prompt Injection — jemand schreibt „Ignoriere alle
vorherigen Anweisungen" — ist ein reales Angriffsszenario, keine
akademische Übung.

Echte Sicherheit liegt im Backend. Das Backend entscheidet welche Daten
in den Kontext des LLM kommen — bevor das Modell sie sieht. Was das Modell
nie sieht, kann es nicht leaken, egal was der User schreibt.

Das Prinzip: Gruppenzugehörigkeit bestimmt die Datenbankabfrage. Die
Datenbankabfrage bestimmt den Kontext. Der Kontext bestimmt die Antwort.
Das LLM ist das letzte Glied, nicht das erste.

Das ist Row Level Security — nicht als Datenbankfeature, sondern als
Architekturprinzip.

## Wie Modelle gebaut werden — und was das für Unternehmen bedeutet

Ein LLM entsteht in mehreren Stufen:

**Pre-Training** — das Fundament. Milliarden von Texten, Monate Rechenzeit,
Millionen Dollar. Das machen OpenAI, Anthropic, Meta, Google. Kein
Unternehmen macht das selbst.

**Instruction Tuning** — das Modell lernt, auf Fragen zu antworten statt
Texte zu vervollständigen. Menschen schreiben Beispiele: Frage, ideale Antwort.
Das Modell trainiert darauf.

**RLHF** — Menschen bewerten verschiedene Antworten. Das Modell lernt was
bevorzugt wird. Hier entsteht der Charakter eines Assistenten.

**Fine-tuning** — hier kann ein Unternehmen einsteigen. Eigene Daten,
eigener Stil, eigenes Vokabular. Technisch derselbe Prozess wie Instruction
Tuning — aber mit eigenen Beispielen.

**RAG** — kein Training, sondern Laufzeit-Kontext. Das Modell verändert sich
nicht. Das Wissen kommt mit jedem Aufruf neu rein.

Für die meisten Unternehmens-Use-Cases ist RAG der richtige Einstieg. Günstig,
flexibel, aktuell, und die Daten verlassen das System nicht — was regulatorisch
erheblich ist.

## Routing: Wer entscheidet welches Modell?

Nicht jede Anfrage braucht dasselbe Modell. Eine einfache Zusammenfassung braucht
kein 405-Milliarden-Parameter-Modell. Juristische Vertragsanalyse sollte nicht
an ein 3B-Modell gehen.

Programmatisch ist das schwer zu lösen. Sprache ist zu komplex für Regelwerke.
„Kannst du kurz den Vertrag prüfen?" — „kurz" klingt einfach, „Vertrag prüfen"
ist komplex. Kein if/else der Welt trifft das zuverlässig.

Die elegante Lösung: Ein kleines, schnelles LLM klassifiziert die Anfrage
bevor sie weitergeleitet wird. Nicht als vollständiger Chat — als reiner
Classifier, der nur eine Frage beantwortet: *Wie komplex ist das?*

Das nennt sich LLM Cascade. Klein anfangen, Qualität prüfen, bei Bedarf
eskalieren. 80% der Anfragen löst das kleine Modell. 15% das mittlere.
5% das große. Qualität bleibt hoch, Kosten fallen.

Das Routing-Modell selbst braucht keine aufwendige Infrastruktur — ein
kleines lokales Modell auf dem Client-Rechner reicht für die Klassifikation.
Die eigentliche Anfrage geht dann gezielt an die richtige Infrastruktur.

## GPU-Infrastruktur: Bandbreite schlägt Kapazität

Ein letzter Gedanke, der mich heute beschäftigt hat.

LLM-Inference ist kein Storage-Problem — es ist ein Bandbreitenproblem. Bei
jedem generierten Token muss das Modell alle seine Gewichte einmal durchlesen.
Ein 405-Milliarden-Parameter-Modell in int4-Quantisierung sind ~200 GB. Pro
Token. Das muss in Millisekunden passieren.

Normaler RAM schafft ~100 GB/s. Nicht annähernd genug. GPU-VRAM mit HBM3
schafft ~3.000 GB/s. Deswegen laufen große Modelle auf GPUs — nicht wegen
der Rechenleistung allein, sondern wegen der Speicherbandbreite.

Vertikale Skalierung funktioniert kaum: HBM kann physisch nicht beliebig
wachsen. Der einzige Weg ist horizontal — viele GPUs, direkt verbunden über
NVLink, die gemeinsam als ein einziger großer Speicher wirken.

Was NVIDIA mit dem GB200 NVL72 macht — 72 GPUs in einem Rack, 1,4 TB
gemeinsamer VRAM, NVLink als internes Netz — ist im Grunde dieselbe
Philosophie wie Oracle Exadata: Komplexität die früher Software lösen musste,
in spezialisierte Hardware verlagern. Das Ergebnis ist weniger Overhead,
mehr Bandbreite, ein einfacheres Software-Modell.

Kein Unternehmen kauft das selbst. Aber es erklärt warum Managed Services
wie AWS Bedrock oder Snowflake Cortex für Unternehmen der pragmatische Weg
sind — und warum die Infrastruktur dahinter so teuer ist.

## Was bleibt

KI im Unternehmen ist kein Technologieproblem. Es ist ein Architekturfrage:
Welche Daten dürfen wo hin? Wer sieht was? Welches Modell für welche Aufgabe?
Wie halte ich das aktuell, sicher, nachvollziehbar?

Ein LLM ist das Sprachzentrum. Die Intelligenz über Kontext, Berechtigung
und Aktualität liegt im System drumherum. Das ist der Unterschied zwischen
einem beeindruckenden Demo und einem produktionsreifen System.

Das fühlt sich nach dem richtigen Rahmen an.

---

*Frank & Tristan von Schrenk bauen onisin OS — ein AI-first Datensystem
für Unternehmen. Der Code ist source-available auf
[GitHub](https://github.com/frankvschrenk/onisin).*
