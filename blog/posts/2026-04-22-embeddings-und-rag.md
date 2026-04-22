---
title: "Warum Zahlen statt Texte? Embeddings und RAG verständlich erklärt"
date: 2026-04-22
description: "Warum verwandelt man Texte in Zahlen, bevor man sie durchsucht? Warum versteht Volltext-Suche keine Synonyme, und was macht ein LLM eigentlich anders? Eine Erklärung ohne Mathe, aber mit genug Tiefe, um Kolleg:innen und Kunden überzeugen zu können."
series: "LLM-Systeme in der Praxis"
series_index: 2
---

> **Teil 2 der Serie *LLM-Systeme in der Praxis*.** Drei Posts, die aufeinander
> aufbauen:
> 1. [Event-basierte Daten](./2026-04-22-event-basierte-daten.html) — wie landen Daten im System?
> 2. **Embeddings und RAG** *(dieser Post)* — wie werden sie durchsuchbar?
> 3. [Eino vs. LangGraph](./2026-04-22-eino-vs-langgraph.html) — wie nutzt ein Agent das alles?

Im vorherigen Post über Event-basierte Daten kam eine Frage vor, die ich in
Gesprächen immer wieder gestellt bekomme: **Warum verwandelt man einen Satz
wie "VPN connection broken since the latest Windows update" erst in eine
Zahlenreihe, bevor man ihn speichert? Warum reicht der Text nicht?**

Diese Frage ist völlig berechtigt. Und die ehrliche Antwort darauf — ohne
Mathe, aber mit genug Tiefe, um sie zu *verstehen* und nicht nur
nachzuplappern — ist erstaunlich selten zu finden.

Dieser Post ist für alle, die schon zehnmal gehört haben "wir machen RAG mit
pgvector" und nicken, aber im Inneren denken: *Was genau heißt das
eigentlich?* Für Kolleg:innen, für Kunden, für Chefs. Und ehrlich gesagt
auch für einen selbst, weil es gut tut, die Sache einmal von Grund auf
durchzudenken.

## Das Problem: Volltext-Suche versteht keine Bedeutung

Nehmen wir zwei Sätze:

- *"VPN connection broken since the latest Windows update."*
- *"Nach dem letzten Patch kommen viele User nicht mehr ins Firmennetz."*

Ein Mensch liest beide Sätze und sagt sofort: **Das ist dasselbe Problem.**
Jemand beschreibt, dass nach einem Windows-Update die VPN-Verbindung nicht
mehr funktioniert.

Eine klassische Volltext-Suche versagt hier komplett. Sie sucht nach
gemeinsamen Wörtern — und die beiden Sätze haben **kein einziges**. Kein
"VPN" im zweiten, kein "Patch" im ersten, nicht mal die Sprache ist gleich.
Für Postgres' eingebaute Volltext-Suche (`tsvector`, `GIN`-Indexe) sind das
zwei völlig fremde Datensätze.

Das ist kein theoretisches Problem. Das ist der Grund, warum Helpdesks mit
vollen Ticket-Datenbanken trotzdem doppelte Probleme parallel bearbeiten,
warum interne Wikis mit Tausenden Artikeln gefühlt nichts zu finden wissen,
und warum Kunden sich ärgern, wenn die Suche nichts Sinnvolles liefert,
obwohl die Antwort irgendwo steht.

Der Kern des Problems: **Volltext-Suche arbeitet mit Zeichen, nicht mit
Bedeutung.**

## Die Grundidee: Bedeutung als Koordinaten

Jetzt die entscheidende Wendung. Was wäre, wenn wir jedem Satz eine Art
*Adresse* zuweisen könnten — so, dass Sätze mit ähnlicher Bedeutung nah
beieinander liegen?

Stellen wir uns eine Landkarte vor. Nicht eine geografische, sondern eine
**Bedeutungs-Landkarte**. Auf dieser Karte liegen alle Sätze, die von
Netzwerkproblemen handeln, in einer Ecke. Sätze über Gehaltsabrechnung in
einer anderen. Sätze über Kaffee-Rezepte wieder woanders.

Wenn man einen neuen Satz dazulegt, bekommt er eine Position auf dieser
Karte. Die beiden VPN-Sätze von oben würden praktisch nebeneinander landen —
weil sie dieselbe Bedeutung haben, auch wenn sie andere Wörter benutzen.

Eine Suchanfrage funktioniert dann so: *"Gab es Probleme nach Windows-
Updates?"* bekommt ihre eigene Adresse auf der Karte. Man schaut: was liegt
in der Nähe? Das sind dann die relevanten Sätze — egal, welche Wörter sie
verwenden.

Das ist der Kern von Vector-Suche. Und der "Vektor" ist nichts anderes als
die **Koordinaten eines Textes auf dieser Bedeutungs-Landkarte**.

## Warum Zahlen?

Hier kommt die Frage von oben zurück: *Warum dann nicht einfach den Text
speichern?*

Weil eine Landkarte mit Positionen nicht aus Wörtern bestehen kann, sondern
aus Koordinaten — also Zahlen.

Auf einer echten Landkarte ist eine Position `(48.1351, 11.5820)` —
Breitengrad und Längengrad von München. Zwei Zahlen. Auf unserer
Bedeutungs-Landkarte reichen zwei Zahlen aber nicht aus. Sprache ist viel zu
vielschichtig: Ist der Satz technisch oder umgangssprachlich? Positiv oder
negativ? Vergangenheit oder Zukunft? Geht es um Personen, Objekte, Prozesse?

Um all diese Dimensionen abzubilden, brauchen wir viele, viele "Achsen".
Typisch sind **384, 768 oder 1536 Dimensionen** pro Vektor. Das heißt: jeder
Satz bekommt nicht zwei, sondern zum Beispiel 768 Koordinaten.

Was da genau auf der Achse 47 oder 512 steckt, kann kein Mensch sagen — das
Modell hat diese Achsen während seines Trainings selbst "erfunden".
Wahrscheinlich ist Achse 47 irgendwas wie *"wie technisch ist der Text?"*
und Achse 512 etwas wie *"geht es um eine Person?"*, aber das sind nur
vage Analogien. Der Punkt ist: **Die Maschine hat einen Raum mit vielen
Dimensionen, in dem Bedeutung zu Koordinaten wird.**

Ein Embedding ist nichts anderes als dieser Koordinaten-Satz. Eine
Zahlenreihe wie:

```
[0.12, -0.88, 0.43, 0.02, 0.77, ..., 0.07, -0.34]
     → 768 oder mehr Einträge
```

Für den Menschen unleserlich. Für den Computer ein idealer Suchschlüssel.

## Nähe statt Gleichheit

Jetzt der zweite Aspekt: *wie misst man Nähe in so einem Raum?*

Auf einer zweidimensionalen Karte rechnet man Luftlinie: Pythagoras, Wurzel
aus der Summe der Differenzen zum Quadrat. In einem 768-dimensionalen Raum
geht das auch — aber das Standardmaß ist ein anderes: der **Winkel zwischen
zwei Vektoren**. Heißt *Cosine Similarity*.

Die Intuition: Zwei Pfeile, die in dieselbe Richtung zeigen, sind ähnlich,
egal wie lang sie sind. Das macht die Messung robust gegenüber Textlänge —
ein kurzer und ein langer Satz über dasselbe Thema zeigen in dieselbe
Richtung.

Für den Alltag in der Datenbank sieht das so aus:

```sql
SELECT text, 1 - (embedding <=> $1) AS score
FROM   events
ORDER  BY embedding <=> $1
LIMIT  5;
```

`<=>` ist der Cosine-Distanz-Operator von pgvector. Das ist wirklich alles:
"gib mir die fünf Einträge, deren Embedding am nächsten an diesem
Such-Embedding dran ist." Kein Fine-Tuning, keine Magie, keine Konfiguration.

## Wie lernt das Modell diese Landkarte?

Kurz — ohne Mathe, weil das den Rahmen sprengen würde, aber mit genug
Intuition, um es zu begreifen:

Ein Embedding-Modell wird auf gigantischen Mengen Text trainiert. Während
des Trainings bekommt es systematisch Beispiele, **welche Texte zusammen
gehören** und welche nicht. Etwa: "Diese beiden Absätze stammen aus
demselben Artikel — sie sollten ähnliche Embeddings bekommen." Oder:
"Dieser Satz ist eine Frage, das hier die passende Antwort — also nah
zueinander."

Über Milliarden solcher Trainingsschritte findet das Modell von selbst
Koordinaten, bei denen ähnliche Texte nah beieinander landen. Die 768
Dimensionen und die konkrete Bedeutung jeder einzelnen entstehen dabei
**emergent** — niemand programmiert sie hart.

Das Ergebnis ist ein eingefrorenes Modell, das für jeden neuen Text in
Millisekunden die Koordinaten ausspucken kann. `granite-embedding`, das
wir bei OOS einsetzen, ist so ein Modell. `nomic-embed-text`, OpenAI's
`text-embedding-3`, Googles `gemini-embedding` sind andere. Sie
unterscheiden sich in Größe, Geschwindigkeit, Sprachabdeckung und
Qualität, aber das Grundprinzip ist dasselbe.

Wichtig zu wissen: **Das Embedding-Modell ist nicht dasselbe wie ein LLM.**
Ein LLM (wie Claude oder GPT) erzeugt Text. Ein Embedding-Modell erzeugt
Koordinaten. Beide arbeiten intern mit ähnlicher Technik (Transformer-
Netzen), aber der Zweck ist unterschiedlich. Embedding-Modelle sind oft
10-100-mal kleiner und schneller.

## Wann passt es — und wann nicht

Zwei Vektoren sind nah, wenn sie **dieselbe Bedeutung** tragen. Klingt
einfach, hat aber Nuancen, die man kennen sollte, bevor man die Technik
produktiv einsetzt:

**Funktioniert gut:**

- Synonyme und Umschreibungen ("Auto" vs. "Fahrzeug")
- Sprachgrenzen (Deutsch/Englisch, bei multilingualen Modellen)
- Lange und kurze Texte über dasselbe Thema
- Tippfehler und umgangssprachliche Varianten ("email" vs. "Mail" vs. "E-Mail")

**Funktioniert schlecht:**

- Exakte Zahlen oder IDs ("Rechnung 12345" findet "Rechnung 12346" — ähnlich,
  aber falsch)
- Verneinungen werden oft übersehen ("VPN geht" und "VPN geht nicht" können
  sehr nah beieinander landen)
- Fachspezifische Abkürzungen, die das Modell im Training nie gesehen hat
- Sehr kurze Texte (ein einzelnes Wort hat kaum Kontext für Embeddings)

Deswegen ist Vector-Suche in der Praxis **fast nie allein im Einsatz**,
sondern kombiniert mit klassischer Suche (Keyword, Volltext, Filter). Das
nennt sich *Hybrid Search*: erst semantisch einen Top-Kandidaten-Pool holen,
dann mit exakten Filtern aussieben. So erwischt man die relevanten Treffer
und filtert Quatsch raus.

## Der Weg zum LLM: Retrieval-Augmented Generation

Jetzt haben wir verstanden, wie ein einzelner Satz zu Koordinaten wird und
wie man ähnliche findet. Aber was hat das mit großen Sprachmodellen zu tun?

Antwort: Alles. Das Muster heißt **RAG — Retrieval-Augmented Generation**.
Drei Schritte:

### Schritt 1: Retrieval (Wiederfinden)

Der Benutzer stellt eine Frage. Die Frage wird in ein Embedding verwandelt.
Die Datenbank liefert die Top-K ähnlichsten Dokumente zurück — typisch 3
bis 20 Stück.

```
"Gab es Probleme nach Windows-Updates?"
        │
        ▼  (granite-embedding)
   [0.31, -0.72, 0.15, ...]
        │
        ▼  (pgvector, SELECT ... ORDER BY embedding <=> $1)
   → 5 ähnlichste Event-Texte
```

### Schritt 2: Augmentation (Anreichern)

Die gefundenen Dokumente werden in den Prompt für das LLM eingebaut. Das
sieht ungefähr so aus:

```
Du bist ein Helpdesk-Assistent. Beantworte die Frage des Users
auf Basis der folgenden Events aus unserem Ticket-System:

---
EVENT 1: VPN connection broken since the latest Windows update.
         Multiple users affected.
EVENT 2: Nach Windows-Update 24H2 läuft der VPN-Client auf manchen
         Laptops nicht mehr.
EVENT 3: Hotfix KB5055521 behebt das VPN-Problem nach Update.
---

Frage: Gab es Probleme nach Windows-Updates?
```

Das ist das "Augmented" in RAG. Das LLM bekommt **Fakten mitgeliefert**,
die es sonst nicht wüsste.

### Schritt 3: Generation (Antworten)

Jetzt formuliert das LLM eine Antwort. Aber nicht aus seinem Trainingsdaten-
Gedächtnis, sondern aus dem Kontext, den wir ihm gerade hingelegt haben.
Zum Beispiel:

> *"Ja, nach dem Windows-Update 24H2 gab es Probleme mit dem VPN-Client.
> Mehrere User waren betroffen. Der Hotfix KB5055521 behebt das Problem."*

Das LLM hat die Information nicht *gewusst*. Es hat sie *gelesen und
zusammengefasst*. Genau das ist der Trick.

## Warum RAG und nicht Fine-Tuning?

Eine oft gestellte Anschluss-Frage: *Warum trainiert man das LLM nicht
einfach auf die eigenen Daten?* Das ginge technisch — nennt sich
Fine-Tuning. Aber:

- **Teuer.** Fine-Tuning kostet pro Durchlauf viel Rechenzeit, oft ein
  Vielfaches einer monatlichen API-Rechnung.
- **Langsam.** Man kann nicht jeden neuen Ticket-Eintrag sofort ins Modell
  backen. RAG sieht neue Daten sofort.
- **Weniger präzise.** Ein fine-getuntes Modell "weiß" Dinge, aber es kann
  nicht sagen, *woher* es das weiß. RAG kann die Quelle mitliefern
  ("das steht in Event 2").
- **Nicht mehr änderbar.** Was fein-getunt ist, bleibt drin. Wenn sich
  Inhalte ändern oder gelöscht werden, muss man neu trainieren. RAG: alte
  Datensätze aus der DB löschen, fertig.

Für **sich schnell ändernde Firmendaten** ist RAG fast immer die bessere
Wahl. Fine-Tuning macht Sinn, wenn man dem Modell **Stil oder Format**
beibringen will, nicht Fakten.

## Grenzen von RAG

Wer RAG produktiv einsetzt, stolpert irgendwann über diese Grenzen:

- **Kontext-Fenster.** LLMs können nur eine begrenzte Menge Text auf einmal
  lesen. Wer 50 Dokumente à 10 Seiten mitgibt, sprengt das Fenster. Deswegen
  gibt es *Chunking* — Dokumente in kleine Abschnitte zerlegen, nur die
  passendsten mitgeben.
- **Die Suche ist nur so gut wie die Embeddings.** Wenn das Embedding-Modell
  eure Fachbegriffe nicht kennt, findet es die relevanten Treffer schlicht
  nicht. Für Spezialdomänen (Medizin, Jura) lohnt sich manchmal ein
  domänenspezifisches Modell.
- **Halluzinationen.** Das LLM kann immer noch Dinge dazuerfinden, auch
  wenn die Quellen klar sind. Deshalb in sensiblen Kontexten: immer die
  Quelle anzeigen, nie blind der Antwort vertrauen.
- **Datenschutz.** Wer Kunden-Events in ein kommerzielles LLM schickt, hat
  ein Datenschutz-Problem. Deshalb setzen wir bei OOS auf lokale Modelle
  über Ollama — granite-embedding fürs Indexieren, Gemma oder Qwen fürs
  Generieren. Nichts verlässt die eigene Infrastruktur.

## Was nimmt man daraus mit?

Wenn ihr das nächste Mal jemandem erklären müsst, warum ihr Daten als
Vektoren speichert — das ist die Kurzfassung:

1. **Texte haben Bedeutung, nicht nur Wörter.** Volltext-Suche findet keine
   Synonyme, keine Umschreibungen, keine Sprachwechsel.
2. **Ein Embedding ist die Koordinate eines Textes auf einer Bedeutungs-
   Landkarte.** Ähnliche Texte liegen nah beieinander.
3. **Die Landkarte hat viele Dimensionen (hunderte),** weil Sprache zu
   vielschichtig für zwei Achsen ist.
4. **Ähnlichkeit misst man als Winkel zwischen Vektoren** — Cosine
   Similarity.
5. **RAG heißt: semantisch suchen, Treffer an ein LLM weitergeben, LLM
   formuliert die Antwort.** Das verbindet große Sprachmodelle mit
   eigenen Daten, ohne die Modelle neu trainieren zu müssen.

Das ist die ganze Geschichte. Ohne Mathe, ohne Transformer-Bilder, ohne
Matrix-Multiplikation. Wer das verstanden hat, kann in Architektur-
Meetings fundiert mitreden — und Kunden überzeugen, warum *"wir bauen
einen Chatbot auf euren Tickets"* keine Zauberei ist, sondern eine
überschaubare Pipeline aus Embedding-Modell, Vector-Store und LLM.

---

**Empfehlung fürs Weiterlesen:** Wer tiefer einsteigen will, findet bei
OpenAI, Anthropic und in der pgvector-Doku gute technische Ressourcen.
Für die Intuition hilft es aber oft mehr, einmal selbst zu spielen:
`ollama pull granite-embedding`, ein paar Sätze embedden lassen, Abstände
vergleichen. Nichts klärt schneller als 20 Zeilen Python oder Go.

---

**Zurück in der Serie:**
[← Teil 1 — Event-basierte Daten](./2026-04-22-event-basierte-daten.html)

**Weiter in der Serie:**
[Teil 3 — Eino vs. LangGraph →](./2026-04-22-eino-vs-langgraph.html)
