---
title: "Event-basierte Daten — oder warum wir bei PostgreSQL geblieben sind"
date: 2026-04-22
description: "Event Sourcing, CQRS, Change Data Capture, Kafka, EventStoreDB, ArangoDB, SurrealDB — jede Woche ein neuer Event-Store. Eine nüchterne Einordnung für Architekten und CTOs, warum PostgreSQL mit pgvector oft die bessere Wahl ist als die schicke spezialisierte DB."
---

*Event Sourcing*, *Event-Driven Architecture*, *CQRS*, *Change Data Capture*,
*Event Streams*, *Kafka*, *EventStoreDB* — in Architektur-Meetings fallen
diese Begriffe gerne als wären sie Synonyme. Sind sie nicht. Und die Frage,
welche Datenbank man dafür nimmt, ist noch verworrener.

Dieser Post ist für Architekten und CTOs, die gerade abwägen, ob die nächste
Plattform eine spezialisierte Event-DB bekommt oder doch den langweiligen
PostgreSQL-Cluster, der seit Jahren läuft. Ich nehme euch mit durch die
Begriffe, die Optionen, und begründe ehrlich, warum wir bei OOS den
unspektakulären Weg gewählt haben.

## Erst mal: worüber reden wir überhaupt?

Drei Konzepte werden regelmäßig verwechselt:

### Event Sourcing

**Der State einer Entität ist die Summe aller Events, die sie verändert
haben.** Statt "Kunde Meyer hat Adresse X" speichert man:

- 2024-01-15: Kunde Meyer angelegt
- 2024-03-22: Adresse geändert auf Y
- 2024-11-05: Adresse geändert auf X

Der aktuelle State wird durch *Replay* dieser Events rekonstruiert. Vorteil:
komplette Historie, beliebige Zeitreise, Audit out of the box. Nachteil: Jede
Query, die nicht auf einem aggregierten View läuft, wird teuer.

### Event-Driven Architecture

**Komponenten kommunizieren über Events statt über synchrone API-Calls.**
Service A schreibt "Bestellung aufgegeben", Service B (Lager), Service C
(Buchhaltung) und Service D (E-Mail) reagieren unabhängig darauf. Kein
zentrales Orchestrieren, keine Zeitkopplung. Event Sourcing ist dafür
nicht zwingend — die Events können auch nur als Messages fließen, ohne
persistiert zu werden.

### Change Data Capture (CDC)

**Jede Änderung in einer klassischen CRUD-Datenbank wird als Event
ausgeleitet.** Die Wahrheit liegt weiter in Tables, aber ein Stream von
`INSERT/UPDATE/DELETE`-Events fließt parallel raus — für Replikation,
Suchindizes, Data Warehouses. Debezium ist das bekannteste Tool dafür.
Das ist *pragmatisches Event-Driven* ohne Event Sourcing.

Diese drei Konzepte sind **unabhängig voneinander**. Man kann das eine
ohne das andere machen. Die meisten "Event"-Architekturen in der Praxis
sind eine Mischung aus CDC und Event-Driven Architecture — reines Event
Sourcing ist selten, weil es Aggregationen und Queries schmerzhaft macht.

## Warum das überhaupt interessant ist

Für Architekten sind die Argumente meist diese:

**Vollständige Historie.** Ein klassisches UPDATE überschreibt Information.
Bei Event-basierten Systemen geht nichts verloren — auch nicht der Zustand
von gestern, oder die Reihenfolge, in der Dinge passiert sind. Wer jemals
einen Audit für Finanz- oder Gesundheitsdaten begleiten musste, weiß was
das wert ist.

**Entkopplung.** Neue Consumer können jederzeit dazukommen, ohne dass
bestehende Services angepasst werden. Der Service, der Events schreibt,
weiß nichts von ihnen.

**Reaktive Pipelines.** Sobald ein Event geschrieben wird, kann beliebig
viel darauf reagieren: Indexe aktualisieren, Benachrichtigungen senden,
Machine-Learning-Pipelines triggern.

**Semantische Suche.** Hier kommt ein neues Argument hinzu, das vor fünf
Jahren noch nicht galt: Events sind in der Regel Text-lastig (Beschreibung,
Kommentar, Klartext). Mit Vector-Embeddings lassen sie sich *semantisch*
durchsuchen — "zeig mir alle Events zu Kunden-Eskalationen in Q3" ohne
vorher Kategorien anlegen zu müssen.

Das letzte Argument ist für uns bei OOS der entscheidende gewesen. Dazu
unten mehr.

## Die Landschaft der Event-Stores

Jetzt zur Frage, die Architekten wirklich beschäftigt: **welche Datenbank?**
Eine nüchterne Einordnung der Kandidaten.

### EventStoreDB

Der spezialisierte Klassiker, konzipiert rein für Event Sourcing. Streams
als First-Class-Citizen, Projections eingebaut, ordentliches Tooling.

*Stärken:* Konzeptuelle Sauberkeit, optimiert für Replay.
*Schwächen:* Nischenprodukt, überschaubares Ökosystem, weniger Entwickler
kennen es, keine Vector-Suche, kein gutes Story für aggregierte Queries.

Gute Wahl, wenn ihr wirklich **reines Event Sourcing** betreibt und das
Team die Expertise aufbauen will. Für die meisten Projekte: Overkill.

### Apache Kafka

Streng genommen keine Datenbank, sondern ein verteilter Log. Aber wird oft
als Event-Backbone eingesetzt und hat mit Kafka Streams und KSQL inzwischen
datenbank-ähnliche Features.

*Stärken:* Maximal skalierbar, riesiges Ökosystem, de-facto-Standard für
Event-Streaming zwischen Services.
*Schwächen:* Kein Query-Interface für historische Daten im Sinne einer DB.
Operations-intensiv (Brokers, Zookeeper/KRaft, Partitioning). Keine
Transaktionen über mehrere Topics. Kein nativer Vector-Support.

Richtige Wahl, wenn ihr **zwischen vielen Services** Events durchreicht
und Throughput im sechsstelligen Bereich pro Sekunde braucht. Falsche Wahl
als einzige Datenbank.

### MongoDB Change Streams

MongoDB hat seit Jahren eingebaute Change Streams — jeder Document-Change
wird als Event konsumierbar. Kein separates CDC-Tool nötig.

*Stärken:* Wenn MongoDB eh da ist, praktisch kostenlos dazu. Flexibles
Schema. Mit Atlas Vector Search auch Vector-Suche.
*Schwächen:* Change Streams sind CDC, kein Event Sourcing. Keine
Replay-Funktion über alte Events jenseits des Oplog-Retention-Fensters.
Cluster-Konfiguration (Replica Set) ist Pflicht.

Gute Wahl für Teams, die MongoDB ohnehin einsetzen und nicht reines
Event Sourcing brauchen.

### DynamoDB Streams

AWS-spezifisches CDC: jede Änderung an einer DynamoDB-Tabelle wird als
Stream verfügbar, typischerweise zusammen mit Lambda.

*Stärken:* Serverless, skaliert magisch, minimale Ops-Last.
*Schwächen:* Lock-in in AWS. 24h Retention limitiert das Fenster.
Kein Vector-Support. Queries jenseits des Primary Key sind historisch
umständlich (inzwischen besser mit Aggregate-Indexen).

Gute Wahl für AWS-native Teams mit serverless Mindset. Falsche Wahl, wenn
man Portabilität will.

### ArangoDB

Multi-Model: Documents, Graphs, Key-Value in einer DB. Kein dedizierter
Event-Store, aber durch Graph-Fähigkeit und flexible Schemas sehr gut
geeignet, wenn Events *Beziehungen* haben.

*Stärken:* Eine einzige DB für sehr unterschiedliche Zugriffsmuster.
AQL (Query Language) ist ausdrucksstark. Graph-Traversals sind nativ.
*Schwächen:* Kleineres Ökosystem als Postgres/Mongo. Vector-Support ist
inzwischen da, aber weniger mature als pgvector. Lizenzmodell hat sich
über die Jahre mehrfach geändert — wert zu prüfen.

Wenn eure Events ein natürliches Graph-Modell haben (wer-kennt-wen,
Aktions-Ketten, Causation), ist ArangoDB ein **ernsthafter Kandidat**.
Ein schönes Produkt, das in Deutschland/Schweiz verbreitet ist und
weniger Hype-getrieben als viele Alternativen.

### SurrealDB

Jung, ehrgeizig, Multi-Model, eingebaute Live-Queries, auch Graph-
Fähigkeiten. Rust-geschrieben, einzelnes Binary.

*Stärken:* Developer Experience ist frisch und modern. Live-Queries
(Subscription auf Query-Ergebnisse) sind eingebaut. WebSocket-native.
*Schwächen:* **Jung.** Produktionsreife ist noch nicht breit bewiesen.
Weniger Mitarbeiter mit Erfahrung auf dem Arbeitsmarkt. Bei echten
Problemen steht man schnell alleine da.

Spannend für Prototypen und Greenfield-Projekte mit experimentierfreudigem
Team. Für Enterprise-Entscheidungen heute (noch) zu riskant.

### PostgreSQL mit pgvector

Das Arbeitspferd. Seit über 30 Jahren im Einsatz. Mit der pgvector-Extension
kann es Vector-Embeddings speichern und durchsuchen. Mit `LISTEN/NOTIFY`
hat es einen eingebauten Event-Bus. Mit JSONB hat es flexible Payloads.
Mit logischer Replikation hat es CDC.

*Stärken:* Praktisch jeder hat einen. Transaktionen. Ausgereifte
Ops-Werkzeuge. Riesiger Talent-Pool. Konservative Default-Wahl, die auch
in zehn Jahren noch funktionieren wird.
*Schwächen:* Nichts davon ist "Event-native". Man muss Konventionen selbst
definieren. Skaliert nicht auf Kafka-Niveau.

## Warum wir PostgreSQL gewählt haben

Für OOS war die Entscheidung am Ende nicht die Liste der Features, sondern
drei nüchterne Überlegungen:

**1. Infrastruktur, die sowieso da ist.**
Jeder Kunde, der OOS einsetzt, hat bereits einen PostgreSQL-Server. Die
Einstiegshürde ist null. Wir brauchen keinen zusätzlichen Broker zu
betreiben, keine zweite Backup-Strategie, kein zweites Monitoring. Das ist
für ein junges Produkt existenziell wichtig.

**2. Transaktionen.**
Unsere Events beschreiben Zustandsänderungen an Geschäftsdaten. Wenn ein
Event geschrieben wird, müssen gleichzeitig Counter, Indizes und
abgeleitete Tabellen konsistent aktualisiert werden. Postgres erlaubt
uns das *in einer Transaktion*. Kafka kann das prinzipiell nicht.

**3. Der Vector-Search-Use-Case.**
Wir wollen über Events nicht nur nach ID oder Zeitfenster suchen, sondern
semantisch. "Finde alle Events zu diesem Fall, die sich ähnlich anhören
wie diese Beschreibung hier." pgvector macht genau das — Embedding-Spalte
anlegen, Index drauf, `ORDER BY embedding <=> $1`. Fertig. Keine zweite
Datenbank, kein Sync-Problem zwischen Event-Store und Vector-DB.

Das ergibt sich dann in einer Architektur, die unspektakulär aber
belastbar ist:

- **Source-Tables** enthalten die eigentlichen Event-Rows (Zeit, Typ,
  Payload als JSONB, Stream-ID).
- **Ein Trigger** schickt bei jedem INSERT eine `NOTIFY` an einen Kanal.
- **Ein Background-Worker** hört mit `LISTEN` zu, lädt das neue Event,
  generiert das Embedding und schreibt es in eine **Target-Table** mit
  Vector-Spalte.
- **Eine kleine Mapping-Tabelle** verbindet Source und Target und erlaubt,
  neue Event-Typen rein per Konfiguration hinzuzufügen.

Das sind keine 500 Zeilen Go-Code. Und es läuft auf jedem PostgreSQL ab
Version 14 ohne Extras außer pgvector.

## Was ihr damit *nicht* bekommt

Ehrlichkeit ist wichtiger als Verkaufsargumente. Unser Ansatz hat klare
Grenzen:

- **Kein reines Event Sourcing.** Wir replayen keine Event-Streams zur
  Rekonstruktion von Aggregaten. Wer das braucht, ist mit EventStoreDB
  oder einer sauberen Kafka-Architektur besser bedient.
- **Kein hoher Durchsatz.** Wir reden von Hunderten bis wenigen Tausend
  Events pro Sekunde. Wer Millionen braucht, nimmt Kafka.
- **Keine Multi-Region-Replikation out of the box.** Postgres kann das,
  aber nicht so elegant wie cloud-native Stores.
- **pgvector ist nicht die schnellste Vector-DB.** Für riesige Vektor-
  Korpora (>100M Vektoren) sind dedizierte Stores wie Qdrant oder Milvus
  schneller. Bis in den Millionen-Bereich ist pgvector völlig okay.

## Die Faustregel für die Entscheidung

| Eure Situation | Empfehlung |
|---|---|
| Ihr habt PostgreSQL, braucht Event-Features pragmatisch | **PostgreSQL + pgvector** |
| Kafka läuft schon, Events sind der Kleber zwischen Services | **Kafka** (+ eigene DB für Queries) |
| Reines Event Sourcing, Audit ist Produktkern | **EventStoreDB** |
| AWS-only, serverless first | **DynamoDB Streams** |
| Events haben starke Graph-Struktur | **ArangoDB** |
| MongoDB ist eh euer Haupt-Store | **Change Streams** reichen meist |
| Greenfield, experimentierfreudig, kein Produktionsdruck | **SurrealDB** ernsthaft anschauen |

Die traurige Wahrheit: für die meisten Unternehmen ist **PostgreSQL die
richtige Antwort**, nicht weil es technisch brillant ist, sondern weil es
*da* ist, es funktioniert, und man sich auf die wirklich interessanten
Architekturfragen konzentrieren kann statt auf Ops.

Die Dinger, die euch in fünf Jahren wirklich weh tun werden, sind selten
die Datenbankwahl. Es sind die Schemas, die ihr nicht migrieren konntet,
die Events, deren Bedeutung niemand mehr kennt, und die Kopplungen, die
sich durch den Code gefressen haben. Da hilft keine fancy Event-DB —
das bleibt Handarbeit.

## Fazit

**Events sind kein Buzzword, sondern ein legitimes und oft unterschätztes
Architektur-Muster.** Die vollständige Historie, die Entkopplung, und
inzwischen die Möglichkeit semantischer Suche rechtfertigen die zusätzliche
Komplexität in vielen Projekten.

Aber die Wahl des Stores ist oft weniger wichtig als die Architektur
selbst. Ein PostgreSQL mit sauberer Event-Tabelle, `LISTEN/NOTIFY` und
pgvector löst 80% der Fälle. Die restlichen 20% sind die, wo ihr wisst,
dass ihr sie habt — weil der Durchsatz, die Compliance-Anforderung oder
die Graph-Struktur es erzwingen.

Wenn ihr in einem Architektur-Meeting das nächste Mal zwischen EventStoreDB,
Kafka und SurrealDB abwägt, fragt zuerst: **was ist unsere eigentliche
Schmerzgrenze?** Meistens ist die Antwort: "Wir haben Postgres. Geht das
damit auch?" Die Antwort lautet überraschend oft: ja.

---

**In eigener Sache:** OOS nutzt das oben skizzierte Muster in Produktion.
Die technischen Details und der Go-Code hinter der Event-Mapping-Schicht
sind in unserer Doku beschrieben. Für die Architekturdiskussion im eigenen
Team ist die Code-Ebene allerdings meist weniger relevant als die Fragen
oben.
