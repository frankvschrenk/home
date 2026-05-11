---
title: "Warum wir NATS überall einsetzen — und nicht bereuen"
date: 2026-05-11
description: "oos, oosd, oosai, oosgql — jede Schicht von onisin OS redet über NATS. Keine HTTP-Clients, keine Load Balancer, kein Service Mesh. Dieser Artikel erklärt warum wir das so entschieden haben, und was wir dabei gelernt haben."
---

Wenn man zum ersten Mal in den Quellcode von onisin OS schaut, fällt etwas auf:
Es gibt keine HTTP-Clients zwischen den Services. Kein `fetch("http://oosai:8080/event")`,
keine base URLs in Konfigurationsdateien, keinen Reverse Proxy der Requests verteilt.

Stattdessen sieht man das überall:

```typescript
// oosgql/src/command-handler.ts
for await (const msg of nats.subscribe("oos.cmd.gql.query")) {
    const result = await graphql({ schema: host.current(), source: query });
    nats.publish(msg.reply, sc.encode(JSON.stringify(result)));
}
```

```typescript
// oosai/src/event-listener.ts
for await (const msg of nats.subscribe("oos.events.police")) {
    void processEventNotification(sql, embed, mapping, sc.decode(msg.data));
}
```

Das ist kein Zufall und kein Experiment. Das ist eine bewusste, durchgezogene
Entscheidung — und dieser Artikel erklärt warum.

---

## Die eigentliche Frage hinter "Warum NATS?"

Die häufige Antwort auf diese Frage lautet: "NATS ist schnell." Das stimmt. Millionen
Nachrichten pro Sekunde, Latenz im Mikrosekundenbereich, Server-Binary unter 20 MB.
Aber Geschwindigkeit war für uns nicht der Hauptgrund.

Der Hauptgrund war: **Wir wollten Services schreiben, nicht Infrastruktur verwalten.**

REST zwingt dich, sehr früh sehr viele Entscheidungen zu treffen. Wo läuft Service B?
Auf welchem Port? Mit welchem TLS-Zertifikat? Wie verteilst du Last auf drei Instanzen?
Was passiert wenn Service B kurz nicht erreichbar ist — retry, circuit breaker, timeout?

Das sind keine schlechten Fragen. Aber sie sind — wenn du ein kleines, fokussiertes
System baust — die falschen Fragen zu Beginn.

---

## Standort-Unabhängigkeit, ohne es zu merken

In onisin OS weiß `oos` (das Desktop-Frontend) nicht, wo `oosgql` läuft. Es kennt
nicht seine IP-Adresse, nicht seinen Port, nicht mal ob er gerade lokal oder in einem
Container betrieben wird. Es kennt nur einen Subject-Namen:

```
oos.cmd.gql.query
```

Das ist alles. NATS übernimmt das Routing vollständig.

In der klassischen Welt braucht Service A eine Konfiguration für Service B. In der
NATS-Welt braucht Service A nur den Namen des Themas. Der Unterschied klingt klein,
ist es aber nicht: Wenn `oosgql` auf eine andere Maschine umzieht, eine neue
Instanz dazukommt oder der Prozess kurz neustartet — kein einziger Client muss
angepasst werden.

Das ist Location Transparency. Nicht als Konzept aus einem Buch, sondern als gelebte
Realität im täglichen Betrieb.

---

## Request-Reply fühlt sich synchron an — ist es aber nicht

Einer der häufigsten Einwände gegen Message-Systeme lautet: "Aber ich brauche manchmal
eine Antwort. Ich kann nicht einfach Nachrichten abfeuern und hoffen."

NATS kennt das Muster. Es heißt Request-Reply, und es ist in die Library eingebaut:

```typescript
// Client-Seite: Anfrage stellen
const response = await nats.request("oos.cmd.gql.query", payload, { timeout: 5000 });
const result   = JSON.parse(sc.decode(response.data));
```

```typescript
// Server-Seite: Anfrage beantworten
for await (const msg of nats.subscribe("oos.cmd.gql.query")) {
    const result = await runQuery(msg.data);
    nats.publish(msg.reply, sc.encode(JSON.stringify(result)));
}
```

Das fühlt sich im Code wie ein normaler Funktionsaufruf an. Was im Hintergrund
passiert ist trotzdem grundlegend anders als bei HTTP: NATS hält keine
dauerhafte TCP-Verbindung zwischen Client und Server offen. Es vermittelt
nur das Paket. Wenn der Server kurz überlastet ist, staut sich nichts auf
beiden Seiten auf — NATS managed die Warteschlange.

Das macht das System wesentlich unanfälliger für kaskadierende Ausfälle.
Service A wird nicht träge, weil Service B gerade langsam ist.

---

## Pub/Sub für den Rest

Nicht jede Kommunikation braucht eine Antwort. `oosai` zum Beispiel muss wissen,
wenn ein neues Event in der Datenbank landet — aber es muss dafür nichts
zurückschicken. Reine Benachrichtigung.

```typescript
// oosai/src/event-listener.ts — keine Antwort nötig
for await (const msg of nats.subscribe("oos.events.police")) {
    void processEventNotification(sql, embed, mapping, sc.decode(msg.data));
}
```

Mit HTTP müsste `oosai` aktiv pollen oder `oos` müsste eine Liste von Webhook-URLs
verwalten. Mit NATS ist es ein `publish()` auf der einen Seite und ein `subscribe()`
auf der anderen. Wer zuhört, ist dem Sender völlig egal.

Das gilt auch für `oosgql`, das beim Speichern einer Domain automatisch seinen
GraphQL-Schema-Cache invalidiert:

```
oos.domain.changed  →  oosgql reagiert, baut Schema neu
```

Keine direkte Abhängigkeit, kein HTTP-Aufruf, kein Contract zwischen den Services
außer dem Subject-Namen.

---

## Load Balancing ohne einen einzigen Load Balancer

Wenn wir in Zukunft mehrere Instanzen von `oosgql` betreiben wollen — etwa weil
das System unter Last steht — reicht es, eine zweite Instanz zu starten. NATS
verteilt die Requests automatisch via Queue Groups. Kein NGINX, kein HAProxy,
keine Ingress-Konfiguration in Kubernetes.

```
oosgql-1  ─┐
oosgql-2  ─┤──  subscriben beide "oos.cmd.gql.*"
oosgql-3  ─┘    → NATS verteilt Round-Robin
```

Das ist kein theoretischer Vorteil. Das ist eine Eigenschaft, die wir kostenlos
bekommen, weil wir uns von Anfang an auf NATS als Transport festgelegt haben.

---

## Die Subject-Hierarchie als lebende Dokumentation

Wer verstehen will, was ein Service tut, liest seine NATS-Subjects. In onisin OS
ist die Konvention konsequent:

```
oos.cmd.gql.query      — GraphQL-Abfrage ausführen
oos.cmd.gql.mutation   — Mutation ausführen (permission-gated)
oos.cmd.gql.view       — View-DSL-Quelle laden
oos.cmd.gql.domain     — Domain-DSL-Quelle laden
oos.cmd.event.refresh  — Event-Mappings neu laden
oos.events.<mapping>   — Event-Notification (Pub/Sub)
oos.domain.changed     — Domain wurde gespeichert
```

Das ist nicht nur Architektur. Das ist Dokumentation. Wer im Code nach
`oos.cmd.gql` sucht, sieht sofort welche Services darauf reagieren und welche
es aufrufen.

---

## Ist das noch ein Microservice?

Eine Frage die wir uns selbst gestellt haben: Wenn alle Services den gleichen
NATS-Server benutzen, ist das nicht wieder eine enge Kopplung — nur auf einer
anderen Ebene?

Die ehrliche Antwort: Ja, es gibt eine Kopplung. Der NATS-Server ist
ein Single Point of Failure. Aber er ist auch der einzige. Kein Service
kennt einen anderen Service direkt. Jeder kennt nur Subjects.

Der Unterschied zu einem Monolithen: Jeder Service lässt sich unabhängig
deployen, neustarten und skalieren. Kein Service blockiert einen anderen
beim Hochfahren. Wenn `oosai` abstürzt, können `oos` und `oosd` weiterarbeiten —
sie bekommen nur keine Event-Verarbeitung mehr.

Ob man das "Microservice" nennt oder nicht, ist uns ehrlich gesagt egal.
Es funktioniert.

---

## Was NATS nicht kann

Der Vollständigkeit halber: Es gibt Fälle wo wir NATS bewusst nicht einsetzen.

**Persistenz.** NATS hat JetStream für Durability — aber wir nutzen es noch nicht.
Wenn `oosai` gerade offline ist und ein Event reinkommt, geht die NATS-Nachricht
verloren. Deshalb gibt es in `oosai` einen Startup-Backfill, der unverarbeitete
Events aus der Datenbank nachholt. NATS at-most-once ist für uns derzeit ausreichend;
JetStream liegt als nächste Ausbaustufe parat.

**Externe Clients.** Das Browser-Frontend `apps/oos` (Electrobun) redet nicht direkt
mit NATS. Es geht über einen lokalen Bun-HTTP-Gateway, der intern NATS-Requests
feuert. Der Grund ist schlicht: WebSockets zu einem NATS-Server aus dem Browser-Kontext
sind unnötige Komplexität wenn ein einfacher HTTP-Tunnel genauso gut funktioniert.

**File-Transfers.** Große Binärdaten gehören nicht in NATS-Messages. Das wäre
Cargo-Kult.

---

## Fazit

NATS hat onisin OS nicht zu einem besseren Projekt gemacht, weil es schnell ist.
Es hat es besser gemacht, weil es uns erlaubt hat, über Services nachzudenken
statt über Infrastruktur.

Kein Service weiß wo der andere wohnt. Kein Load Balancer braucht Konfiguration.
Kein Webhook-Vertrag muss gepflegt werden. Und wenn wir morgen `oosgql` in drei
Instanzen aufteilen wollen, sind es drei Zeilen in einem Prozess-Manager — keine
Architekturdebatte.

Das ist der eigentliche Grund.
