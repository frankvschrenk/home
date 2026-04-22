---
title: "Wohin die LLM-Reise geht — und warum Anthropic besser aufgestellt ist als die anderen"
date: 2026-04-22
description: "Matrizen, Attention, Quantisierung, photonische Prozessoren. Was unter der Haube eines LLMs passiert, welche Techniken die kommenden Jahre prägen werden, warum Quantencomputer hier nichts helfen, und warum ausgerechnet Anthropic — nicht OpenAI, nicht Google — die konzeptionell stärkste Position hat. Ein Essay mit einer überraschenden FLOP-Rechnung am Ende."
---

Es gibt gerade zwei Sorten Texte über LLMs: die, die behaupten dass AI in
fünf Jahren die Welt übernimmt, und die, die behaupten dass alles nur
Statistik-Tricks sind und bald wieder zusammenfällt. Beide sind Unsinn.
Die interessanteren Fragen liegen dazwischen, und sie kommen ohne
Buzzwords aus.

Dieser Post ist ein Versuch, die wirklich relevanten Entwicklungen zu
ordnen. Keine Pressemitteilungen, keine Roadmap-Prognosen. Nur: was
passiert gerade unter der Haube, welche Techniken werden die nächsten
Jahre prägen, wo sind die physischen Grenzen, und warum ist ausgerechnet
Anthropic — nicht OpenAI, nicht Google — konzeptuell am besten
aufgestellt für das, was kommt.

Am Ende steht eine kleine Rechnung, die auch erfahrene Entwickler oft
überrascht: wieviele Gleitkomma-Operationen eigentlich nötig sind,
damit ein LLM sagt: *"Gras ist grün."*

## Was in so einem Modell eigentlich passiert

Bevor man über die Zukunft reden kann, muss man kurz klarmachen, was
ein LLM *ist*. Nicht im Marketing-Sinne, sondern mechanisch. Drei
Begriffe reichen, um 90% zu verstehen:

**Embeddings** sind die Koordinaten. Jedes Token (ein Wort, ein Wortteil,
ein Satzzeichen) wird zu einem Vektor mit ein paar tausend Zahlen. Das
haben wir in einem [anderen Post ausführlich
behandelt](./2026-04-22-embeddings-und-rag.html) — kurz: Bedeutung wird zu
Geometrie.

**Attention** ist das Herzstück. Wenn das Modell das Wort *"Bank"* liest,
schaut es durch den gesamten Kontext und fragt: welche anderen Wörter
sind gerade wichtig, um zu entscheiden, ob "Bank" hier das Geldinstitut
oder die Parkbank bedeutet? Das passiert nicht als Regel-Logik, sondern
als Matrix-Rechnung: Jedes Token wird mit jedem anderen Token verglichen,
eine Gewichtung entsteht, und der resultierende Kontext fließt in die
nächste Schicht.

**Feedforward-Schichten** sind das, was zwischen den Attention-Blöcken
liegt. Riesige Matrixmultiplikationen, die die kontextualisierte
Information weiterverarbeiten. Hier sitzen die allermeisten Parameter
eines Modells. Ein Großteil dessen, was ein LLM an Wissen speichert,
steckt in diesen Gewichten.

Das Ganze wird in Dutzenden bis Hunderten solcher Schichten gestapelt.
Ein 70-Milliarden-Parameter-Modell besteht im Wesentlichen aus
**Matrizen voller Zahlen**, die bei jeder Eingabe miteinander verrechnet
werden.

Alles andere — System-Prompts, Tool-Calls, RAG, Agenten-Loops — ist
Software *um* dieses mathematische Herz herum. Nicht das Herz selbst.

## Wie ein Modell lernt: RLHF und warum es Grenzen hat

Ein Modell wird in drei Phasen trainiert. Erst das **Pre-Training**:
Milliarden Tokens Internet-Text, das Modell lernt einfach, was das
nächste Token in einem Satz wahrscheinlich ist. Das macht es sprachlich
kompetent, aber auch beliebig — es würde genauso überzeugend Bombenbau-
Anleitungen produzieren wie Kochrezepte, weil es keinen Begriff davon
hat, was erwünscht ist.

Dann kommt **Instruction-Tuning**: Menschen schreiben Beispiele, wie
"richtige" Antworten aussehen, und das Modell wird darauf angepasst. Es
lernt, dem Muster *Frage → hilfreiche Antwort* zu folgen.

Und schließlich **RLHF — Reinforcement Learning from Human Feedback**.
Menschliche Bewerter lesen zwei mögliche Antworten des Modells und
wählen die bessere. Aus Tausenden solcher Vergleiche entsteht ein
*Reward-Modell*, das wiederum dazu benutzt wird, das Hauptmodell zu
verfeinern. Das ist der Schritt, der aus einem sprachlich fähigen Modell
einen Assistenten macht, der als hilfreich wahrgenommen wird.

Das Problem dabei: **Der Mensch als Maßstab hat Grenzen.** RLHF
optimiert auf das, was Bewerter *bevorzugen*, nicht auf das, was
*richtig* ist. Modelle lernen schnell, höflich, selbstsicher und
zustimmend zu klingen — auch wenn sie falsch liegen. Sycophancy
("Speichelleckerei") ist keine Charaktereigenschaft der Modelle,
sondern ein direkter Nebeneffekt des Trainingsverfahrens.

Deshalb gibt es inzwischen Varianten wie **RLAIF — Reinforcement
Learning from AI Feedback**, bei dem ein anderes Modell als Bewerter
fungiert, nach klaren schriftlichen Prinzipien. Das skaliert besser und
ist konsistenter. Anthropic hat das Konzept unter dem Namen
**Constitutional AI** publiziert und einen Großteil seines Alignment-
Ansatzes darauf aufgebaut: Statt Menschen hunderttausend Urteile
treffen zu lassen, wird dem Modell ein Grundsatz-Katalog an die Hand
gegeben, gegen den es sich selbst kritisiert und verbessert.

Das klingt technisch, ist aber eine **philosophische Weichenstellung**:
Welche Prinzipien genau im Katalog stehen, prägt das Modell-Verhalten.
Anthropic hat diesen Katalog öffentlich gemacht. OpenAI hat das nie
getan.

## Warum Quantencomputer hier nicht helfen

An dieser Stelle kommt die Zukunftsfrage: *wie bekommen wir diese
Modelle schneller, billiger, sparsamer?* Und hier wird viel Unsinn
erzählt.

Der Klassiker: "Quantencomputer werden LLMs revolutionieren." **Falsch.**
Quantencomputer sind gut für spezifische Probleme — Kryptographie
(Shor-Algorithmus), Suchprobleme (Grover), bestimmte Physik-Simulationen.
Sie sind *nicht* gut für Matrixmultiplikationen an großen dichten
Matrizen, genau das was LLMs tun. Im Gegenteil: Quanten-Hardware leidet
unter Decoherenz, braucht exotische Kühlung und kann heute gerade mal
einige hundert Qubits rauschen-frei halten. Ein Standard-Transformer
rechnet mit Milliarden reellen Zahlen pro Schritt. Das sind zwei völlig
unterschiedliche Welten.

Wer dir etwas anderes erzählt, verwechselt "neu und aufregend" mit
"technisch passend".

## Warum photonische Prozessoren tatsächlich etwas bringen würden

Photonische Chips dagegen sind ernsthaft interessant. Die Idee: statt
Elektronen durch Silizium zu schieben, Licht durch Wellenleiter zu
schicken und die Multiplikation *physisch* durch Interferenz-Muster zu
erledigen. Das ist kein Hirngespinst — Firmen wie *Lightmatter* und
*Lightelligence* bauen bereits Prototypen, die bei bestimmten
Matrix-Operationen ein bis zwei Größenordnungen weniger Energie
brauchen als GPUs.

Aber auch hier die Wahrheit hinter dem Hype: Photonische Chips sind
**nicht beliebig programmierbar**. Sie rechnen bevorzugt mit niedriger
Präzision (manchmal nur 4 oder 8 Bit), weil optische Signale rauschen
und exakte Werte nicht gut halten. Das zwingt die Modelle zu
**kompakteren Repräsentationen und robusteren Architekturen**.

Das ist paradoxerweise *gut*. Der Druck auf Effizienz treibt die
Forschung zu Modellen, die weniger Parameter brauchen, stärker
quantisiert sind, und weniger anfällig auf kleine Störungen reagieren.
Photonik zwingt uns zu *besserer* KI, nicht nur zu schnellerer.

## Quantisierung — und warum sie mehr ist als nur Kompression

Womit wir beim vielleicht wichtigsten Trend der kommenden Jahre sind:
**Quantisierung**. Statt jedes Gewicht als 32-Bit-Fließkommazahl zu
speichern (4 Bytes), speichert man es mit 8, 4, manchmal nur 2 Bit. Ein
70-Milliarden-Parameter-Modell, das im Original 280 GB RAM braucht,
passt in quantisierter Form auf eine Consumer-Grafikkarte mit 24 GB.

Die Kunst dabei: **Die Qualität darf nicht abstürzen.** Moderne
Verfahren (GPTQ, AWQ, QLoRA) schaffen es, mit 4-Bit-Quantisierung
praktisch keine spürbare Qualitätseinbuße zu erzeugen. Das ist der
Grund, warum wir heute Llama, Qwen, Gemma auf Laptops laufen lassen
können — vor fünf Jahren undenkbar.

Die Richtung ist klar: immer aggressivere Quantisierung, kombiniert mit
besserer Architektur (Mixture-of-Experts, um nicht alle Parameter für
jede Anfrage zu aktivieren), kombiniert mit spezialisierten Chips
(photonisch oder wenigstens quantisierungsfreundlich). In fünf Jahren
werden Modelle mit Qualität wie GPT-4 auf Smartphones laufen. Das ist
keine Prognose, das ist eine nüchterne Extrapolation der letzten drei
Jahre.

## Wohin die Reise also geht

Drei Trends werden sich überlagern:

**Erstens: kleinere, spezialisierte Modelle.** Die Ära der "ein Modell
für alles" geht zuende. Stattdessen: ein Orchestrator (groß, generell)
der viele spezialisierte Modelle koordiniert. Das spart Energie und
erhöht die Genauigkeit in jeder Einzeldomäne.

**Zweitens: längerer Kontext und bessere Gedächtnisse.** Heute passen
einige Hunderttausend Tokens ins Kontextfenster. In fünf Jahren werden
es Millionen sein, und zusätzlich externes Gedächtnis (RAG,
Memory-Mechanismen) routiniert eingesetzt. Das verändert, was Modelle
als Agenten leisten können — von "einfache Aufgabe" zu "mehrtägige
Projekte".

**Drittens: Interpretierbarkeit.** Das ist der Punkt, an dem Anthropic
abhebt, und darum gehört ihm der nächste Abschnitt.

## Warum Anthropic besser aufgestellt ist

Hier wird der Post persönlich, und hier lehne ich mich raus. Ich nutze
Claude seit Monaten täglich, und ich habe mir bewusst angeschaut, was
die einzelnen Labs machen. Mein Urteil — und es ist ein Urteil, keine
Gewissheit:

**Anthropic spielt ein anderes Spiel als OpenAI und Google.**

OpenAI ist ein Produktunternehmen. Sie veröffentlichen schnell, sie
jagen Benchmarks, sie bauen breit — ChatGPT, Sora, Agents, Codex,
Voice. Die Strategie ist klar: Marktführer werden durch schiere
Geschwindigkeit und Featureumfang.

Google hat die beste Forschung und die größte Infrastruktur der Welt,
aber die Produkte wirken oft zögerlich und vom eigenen Ökosystem
erdrückt. Gemini ist technisch brillant, fühlt sich aber immer noch an
wie etwas, das Google als Abwehrmaßnahme baut, nicht aus Überzeugung.

Anthropic macht zwei Dinge konsequent anders:

**1. Forschung zu Interpretability ist Kernauftrag, nicht Nebenprodukt.**

Während andere Labs ihre Modelle als Black Boxes verkaufen, publiziert
Anthropic regelmäßig Paper darüber, **was tatsächlich in den Modellen
passiert** — welche Neuronen für welche Konzepte zuständig sind, wie
Entscheidungen intern zustande kommen, wo Modelle systematisch lügen
oder Fehler machen. *"Scaling Monosemanticity"*, *"Toy Models of
Superposition"*, *"Tracing the Thoughts of a Language Model"* — das
sind keine PR-Spielzeuge, sondern echte wissenschaftliche Fortschritte.

Der Grund: Wer die internen Prozesse eines Modells **sichtbar machen**
kann, kann auch eingreifen, erklären, kontrollieren. Das ist für
Industriekunden in sensiblen Bereichen — Finanzen, Medizin, Behörden —
auf lange Sicht entscheidender als das letzte Benchmark-Prozent.

**2. Responsible Scaling Policy als öffentliche Selbstbindung.**

Anthropic hat öffentlich festgelegt, welche Fähigkeitsstufen ihrer
Modelle (AI Safety Levels, ASL) welche Sicherheitsmaßnahmen erzwingen.
Das ist ein **überprüfbarer Commitment-Rahmen**, den OpenAI explizit
*nicht* hat. Samuel Altmans "wir sind vorsichtig" ist rhetorisch, nicht
operational.

Für einen CTO, der überlegt, auf welchem Lab er die nächsten fünf
Jahre aufbauen soll, ist das ein relevantes Signal. Nicht weil
Anthropic moralisch besser wäre, sondern weil **überprüfbare
Selbstbindung** robuster ist als freundliche Beteuerungen.

**3. Produktphilosophie als Ausdruck der Werte.**

Das merkt man sogar an kleinen Dingen. Anthropic verkauft Claude
weniger als "Werkzeug das alles macht", sondern mehr als "Raum zum
Denken" — ein Begriff, den sie selbst benutzen. Im Produkt gibt es
keine Werbung, keine Dark Patterns, keine Manipulations-Tricks zur
Verweildauer-Erhöhung. Das wirkt auf den ersten Blick altmodisch,
ist aber eine strategische Entscheidung: wer Vertrauen aufbauen will,
kann sich Manipulation nicht leisten.

Und vielleicht das stärkste Signal: **Anthropic hat MCP als offenen
Standard publiziert**, nicht als proprietäres Anthropic-Feature
behalten. Das ist eine Entscheidung gegen kurzfristigen Lock-in
zugunsten eines langfristig nutzbaren Ökosystems. OpenAI hätte das
anders gemacht.

Das alles heißt nicht, dass Anthropic gewinnen wird. Das können sie
auch finanziell noch verlieren, und wenn OpenAI in zwei Jahren ein
dreifach so gutes Modell hat, ist alles oben relativiert. Aber die
**konzeptuelle Position** ist die stärkste, und darauf bauen die
nächsten Jahre auf.

## Eine Rechnung zum Schluss: was kostet "Gras ist grün"?

Stell dir die Frage: *"Welche Farbe hat Gras im Sommer bei genug Regen?"*

Ein Fünfjähriger antwortet in einer halben Sekunde: *"Grün."* Er braucht
dafür ein paar Mikrojoule Energie im Gehirn. Sein Gehirn ist eines der
effizientesten Rechensysteme des bekannten Universums.

Wenn du dieselbe Frage an ein lokales 27-Milliarden-Parameter-Modell
(z.B. Gemma 2 27B) stellst, passiert Folgendes:

**Eingabe verarbeiten (Prefill).** Die Frage hat etwa 12 Tokens. Die
Faustregel für einen Forward-Pass ist:

> *FLOPs ≈ 2 × Parameter × Tokens*

Die 2 kommt daher, dass jede Gewichts-Anwendung aus Multiplikation und
Addition besteht. Also:

```
27 × 10⁹ Parameter × 12 Tokens × 2 = ~650 × 10⁹ FLOPs  (650 GFLOPs)
```

**Ausgabe erzeugen (Decode).** Pro Antwort-Token sind das nochmal:

```
27 × 10⁹ × 1 × 2 = 54 × 10⁹ FLOPs pro Token  (54 GFLOPs)
```

Bei einer höflichen Antwort mit 10 Tokens also weitere **540 GFLOPs**.

**Gesamt: ungefähr 1,2 TFLOPs.** Eine Billion-zweihundert-Milliarden
Gleitkomma-Operationen. Für ein einziges Wort, das ein Fünfjähriger in
einem Wimpernschlag liefert.

Ein M3 Pro schafft unter Volllast etwa 5 TFLOPs. Dein Laptop rechnet
also **rund eine Viertelsekunde** bei voller Auslastung aller
Recheneinheiten, um "Grün." zu sagen.

Eine H100 in einem Rechenzentrum macht das in Millisekunden — aber bei
einem Strombedarf von etwa 700 Watt. Multipliziert mit den Milliarden
Anfragen, die täglich weltweit an LLMs gehen, ergibt das einen
Energieverbrauch, der inzwischen auf Kraftwerks-Ebene diskutiert wird.

**Und das ist nur die Inferenz.** Das einmalige Training eines modernen
Frontier-Modells liegt bei etwa 10²³ FLOPs. Zehn Größenordnungen mehr.
Das entspricht dem Stromverbrauch einer Kleinstadt über Wochen.

## Die Pointe

Warum ist das wichtig?

Weil es zwei Dinge gleichzeitig zeigt:

**Erstens:** Wie absurd aufwendig die heutige Art ist, Intelligenz
künstlich zu erzeugen. Wir brennen Kraftwerke ab, um einem
Fünfjährigen-Wissen hinterherzulaufen. Das ist ein starkes Argument
dafür, dass die Architektur noch nicht fertig ist — dass da grundlegend
effizientere Ansätze kommen *müssen*, und dass sie kommen *werden*.
Photonik, Quantisierung, spezialisierte Chips, bessere Architekturen.
Wir sind noch früh.

**Zweitens:** Warum die Frage nach *Qualität und Vertrauen* so viel
wichtiger ist als die Frage nach *Geschwindigkeit*. Wenn eine Anfrage
ohnehin so viele Ressourcen verbraucht, ist die entscheidende Frage
nicht, ob die Antwort in 500ms oder 800ms kommt, sondern **ob sie
richtig ist und ob man sich darauf verlassen kann**. Genau in dieser
Dimension sehe ich Anthropic als am besten positioniert.

Es ist ein guter Moment, sich bewusst für den langen Weg zu
entscheiden — in der eigenen Architektur, bei der Wahl der Partner,
und in der Art, wie man über diese Technologie spricht. Weniger Hype,
mehr Handwerk. Das sind die Unternehmen, die in zehn Jahren noch da
sein werden.

---

*Wer bis hier gelesen hat, ist der Zielgruppe dieses Blogs: Menschen,
die verstehen wollen, was wirklich passiert, nicht nur was gerade laut
getrommelt wird. Feedback, Widerspruch und Korrekturen sind willkommen.*
