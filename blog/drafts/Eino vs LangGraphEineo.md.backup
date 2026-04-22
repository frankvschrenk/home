# Eino vs. LangGraph — oder: wann braucht man eigentlich ein Agent-Framework?

Jede Woche ein neues Framework, jede Woche ein neues Buzzword. LangGraph, Eino,
AutoGen, CrewAI, LangChain, MLflow... Irgendwann wird man müde davon und
fragt sich: **lohnt sich das wirklich, oder reicht ein `for`-Loop?**

Dieser Post ist der Versuch, genau das zu beantworten. Nicht theoretisch,
sondern an einem konkreten, lauffähigen Beispiel. Am Ende steht ein Go-Projekt
mit Eino, das eine Spesenabrechnung gegen eine Richtlinie prüft — inklusive
Human-in-the-Loop, Checkpointing und Resume-nach-Crash.

## Wann ein Agent-Loop wirklich nötig ist

Die ehrliche Antwort zuerst: **meistens nicht.** 90% der LLM-Features in
produktiven Apps sind ein einzelner API-Call. Die anderen 10% sind entweder
trivial (20 Zeilen Go) oder wirklich komplex. Nur bei letzterem zahlt sich
ein Framework aus.

Die Daumenregel: Ein Framework lohnt sich, wenn die **Schritte nicht
vorhersehbar** sind. Der Agent weiß zu Beginn nicht, wie viele Iterationen
nötig werden. Jeder Schritt hängt vom Ergebnis des vorherigen ab.

### Warum Airflow & Co. nicht reichen

Klassische Workflow-Engines wie Airflow basieren auf **DAGs** — gerichteten
azyklischen Graphen. Der Ablauf ist fest verdrahtet:

```
[Start] → [LLM] → [Tool] → [LLM] → [Tool] → [LLM] → [Ende]
```

Bei einem Agent weißt du aber vorher nicht, wie oft `Tool` aufgerufen wird.
Mal einmal, mal fünfmal. Das ist ein **Zyklus** — und genau den erlauben
klassische DAG-Tools nicht.

### Beispiel: Coding-Agent

Der typischste Fall, den wirklich jeder kennt — Claude Code, Cursor, Aider:

```
User: "Fix den failing Test in auth_test.go"

Loop:
  1. read_file(auth_test.go)        → sieht Test
  2. read_file(auth.go)              → sieht Implementation
  3. run_tests()                     → sieht Fehler: "expected 200, got 401"
  4. grep("validateToken")           → findet weitere Stelle
  5. read_file(middleware.go)        → sieht Bug
  6. edit_file(middleware.go, ...)   → fixt
  7. run_tests()                     → immer noch rot, anderer Fehler
  8. read_file(...)                  → analysiert neu
  9. edit_file(...)                  → fixt nochmal
  10. run_tests()                    → grün
  → Ende
```

Das LLM *kann nicht wissen*, welche Dateien relevant sind, bevor es den
Testfehler gesehen hat. Jeder Schritt hängt vom Ergebnis des vorherigen ab.
Das ist ein echter agentischer Loop.

### Gegen­beispiel: E-Mail schreiben

Dagegen ist dies **kein** guter Use-Case für ein Framework:

```
User: "Schick eine Mail an X mit Inhalt Y"
  1. draft_email(X, Y)
  2. spellcheck()
  3. send_email()
```

Drei Tool-Calls, aber keiner davon hängt vom Ergebnis des vorherigen ab. Das
ist ein **linearer Workflow**, den man mit drei `if`s erschlagen kann. Kein
Framework nötig.

## Drei Muster für Human-in-the-Loop

Sobald ein Agent destruktive Aktionen ausführen soll (Mail senden, Daten
löschen, Geld überweisen), braucht es Absicherung. Es gibt grob drei Muster,
von "dumm aber zuverlässig" bis "smart aber unberechenbar":

### Muster 1: Hardcoded Gates

Der Entwickler legt fest: **Diese Tool-Kategorien erfordern immer eine
Bestätigung.** Egal was das LLM denkt.

```go
// RequiresApproval returns true for tools that must not execute
// without explicit human confirmation, regardless of LLM judgment.
func RequiresApproval(toolName string) bool {
    switch toolName {
    case "send_email",
         "execute_payment",
         "delete_file",
         "run_sql_write",
         "deploy_to_production":
        return true
    default:
        return false
    }
}
```

**Vorteil:** Deterministisch, auditierbar, kann nicht umgangen werden.
**Nachteil:** Fragt auch bei offensichtlich harmlosen Dingen.

### Muster 2: Schwellwert-basiert

Das LLM muss bei jedem Tool-Call eine Einschätzung mitgeben (`impact`,
`reversible`, `cost_estimate`), die der Code gegen hardcodete Schwellwerte
prüft.

**Vorteil:** Adaptiver als Muster 1.
**Nachteil:** Das LLM kann sich bei der Einschätzung irren — typischerweise
in die falsche Richtung.

### Muster 3: LLM fragt aktiv

Das LLM bekommt ein explizites Tool `ask_human`, das es bei Unsicherheit
aufrufen kann.

**Vorteil:** Fühlt sich natürlich an.
**Nachteil:** LLMs sind berüchtigt dafür, **zu selten** zu fragen. Sie
machen lieber überzeugt Unsinn.

### Die Realität

Anthropic, OpenAI und andere verlassen sich **primär auf Muster 1**, ergänzt
durch Muster 2 und 3. Das LLM selbst die Entscheidung treffen zu lassen, ist
unzuverlässig, weil:

1. **LLMs sind schlecht kalibriert.** Ihre Confidence korreliert oft nicht
   mit Korrektheit.
2. **Prompt Injection.** Ein bösartiger Input im Kontext kann das LLM
   überreden, *nicht* zu fragen. Bei hardcoded Gates geht das nicht.
3. **Konsistenz.** Du willst, dass der Agent sich heute genauso verhält wie
   morgen. LLM-Entscheidungen schwanken.

## Eino vs. LangGraph im Überblick

Eino wurde speziell entwickelt, um die Einschränkungen von klassischen,
linearen Ketten (wie in der Standard-LangChain) zu überwinden:

- **Graph-basierte Architektur:** Genau wie LangGraph basiert Eino auf der
  Idee eines Graphen. Man definiert Knoten (Nodes) und Kanten (Edges).
- **Zyklen und Schleifen:** Eino erlaubt es nativ, Graphen mit Schleifen
  zu bauen. Das ist die Kernkompetenz von LangGraph, um Agenten zu
  erstellen, die ihre eigenen Antworten reflektieren oder Aufgaben
  wiederholen können.
- **State Management:** In Eino fließt ein Kontext durch den Graphen, der
  an jedem Knoten gelesen oder verändert werden kann — fast identisch zum
  "State" in LangGraph.

| Aspekt                   | LangGraph                                  | Eino                                       |
| ------------------------ | ------------------------------------------ | ------------------------------------------ |
| **Sprache**              | Python                                     | Go                                         |
| **Hersteller**           | LangChain Inc.                             | ByteDance (CloudWeGo)                      |
| **Typisierung**          | Dynamisch (TypedDict/Pydantic als Aufsatz) | Statisch, Generics ab Go 1.18              |
| **Kern-Abstraktion**     | Graph mit State-Dict                       | Chain / Graph / Workflow (drei Paradigmen) |
| **State-Handling**       | Shared mutable State, reducer-basiert      | Typisierte Input/Output pro Node           |
| **Zyklen**               | Ja, über conditional edges                 | Ja, über Graph-Branching                   |
| **Checkpointing**        | Ja (SQLite/Postgres/Memory)                | Ja                                         |
| **Human-in-the-loop**    | Ja, interrupt()                            | Ja, Pause/Resume                           |
| **Streaming**            | Ja, token-level                            | Ja, nativ mit StreamReader                 |
| **Tool-Calling**         | Über LangChain-Tools                       | Eigene Tool-Interfaces                     |
| **Multi-Provider**       | LangChain-Ökosystem (sehr breit)           | OpenAI, Claude, Gemini, Doubao, Ark        |
| **Dependency-Footprint** | Groß (LangChain-Kette)                     | Modular, Core schlank, Ext separat         |
| **Tracing**              | LangSmith (kommerziell)                    | Langfuse-Callback eingebaut                |
| **Produktions-Einsatz**  | Viele Startups, teils Enterprise           | Doubao, TikTok intern                      |
| **Reife**                | Seit 2024, schnelle Iteration              | Seit Anfang 2025 open source               |
| **Lock-in-Risiko**       | Hoch (LangChain-Abstraktionen überall)     | Mittel (Core ist isoliert)                 |
| **Lernkurve**            | Flach am Anfang, tief bei State-Reducern   | Steiler Einstieg, drei Paradigmen          |

## Praxisbeispiel: Spesenabrechnungs-Prüfer

Um Eino konkret zu zeigen, baue ich einen Agent, der einen Stapel Belege
gegen eine Firmen-Reisekostenrichtlinie prüft und am Ende eine
Spesenabrechnung zur Freigabe vorschlägt.

**Warum das ein echter Agent-Loop ist:** Der Agent weiß zu Beginn **nicht**,
wie viele Belege es gibt, welche Art Ausgaben drin sind, oder welche gegen
welche Policy-Regel verstoßen. Jeder Schritt hängt vom vorherigen ab. Wenn
ein Beleg ein Abendessen für 180€ zeigt, muss der Agent in der Policy
nachsehen. Wenn die Policy sagt "max 80€ außer mit Kunde", muss er prüfen,
ob der Beleg einen Kunden nennt. Die Reihenfolge ergibt sich aus den
Ergebnissen.

### Die Tools

| Tool | Effekt | Approval? |
|---|---|---|
| `list_receipts()` | liest Ordner | auto |
| `read_receipt(filename)` | liest einen Beleg | auto |
| `read_policy()` | liest Richtliniendatei | auto |
| `approve_receipt(file, amount)` | merkt Beleg vor | auto |
| `flag_issue(file, reason)` | markiert Problem | auto |
| `ask_human(question)` | fragt User | auto (Muster 3) |
| `submit_expense_report()` | **reicht ein** | **APPROVAL (Muster 1)** |

### Testdaten

Fünf Belege mit absichtlich eingebauten Problemen:

| Datei | Betrag | Erwartetes Verhalten |
|---|---|---|
| `2026-04-10-lunch.txt` | 21,50 € | ✅ klar ok, unter 35€ Limit |
| `2026-04-11-dinner.txt` | 95,50 € | ⚠️ Grauzone: über 80€ Dinner-Limit, ABER Kunde auf Rückseite genannt → Kundenessen bis 150€ erlaubt. **Plus**: Grappa = 2. alkoholisches Getränk bei Kundenessen, nur 1 erlaubt |
| `2026-04-11-taxi.txt` | 14,80 € | ✅ ok, 23:40 Uhr ist nach 23:00 |
| `2026-04-12-hotel.txt` | 482,00 € | ⚠️ 220€/Nacht übersteigt 180€ Großstadt-Limit |
| `2026-04-11-minibar.txt` | 14,00 € | ❌ Minibar nicht erstattungsfähig laut Policy |

Zwei klare Fälle, zwei Grenzfälle, ein Ablehnungsfall. Genug Stoff für
einen Agent, der wirklich denken muss.

### Projektstruktur

```
agentic/
├── go.mod
├── main.go
├── testdata/
│   ├── policy.md
│   └── receipts/
│       ├── 2026-04-10-lunch.txt
│       ├── 2026-04-11-dinner.txt
│       ├── 2026-04-11-minibar.txt
│       ├── 2026-04-11-taxi.txt
│       └── 2026-04-12-hotel.txt
└── internal/
    ├── agent/agent.go         # der Loop
    ├── tools/tools.go         # Tools + Approval-Gate
    └── checkpoint/checkpoint.go  # State-Persistenz
```

### Der Chat-Model-Aufruf

Ein wichtiger Punkt: statt des nativen Ollama-Clients von Eino verwende ich
den **OpenAI-kompatiblen Client** gegen Ollamas `/v1`-Endpoint. Das umgeht
eine ganze Klasse von Kompatibilitätsproblemen (insbesondere mit Gemma-
Modellen) und funktioniert in der Praxis zuverlässig:

```go
chatModel, err := einoopenai.NewChatModel(ctx, &einoopenai.ChatModelConfig{
    BaseURL: "http://localhost:11434/v1",
    APIKey:  "ollama",  // Ollama akzeptiert jeden non-empty key
    Model:   "gemma4:26b",
})
```

### Der Agent-Loop selbst

Eino bietet mit `adk.NewChatModelAgent` einen vorgefertigten Loop. Ich
schreibe ihn hier trotzdem selbst aus — weil der Lerneffekt bei einem
gekapselten Framework-Aufruf gegen null geht:

```go
// Run executes the agent loop for a single user request.
func (a *Agent) Run(ctx context.Context, userInput string) error {
    messages := []*schema.Message{
        schema.SystemMessage(systemPrompt),
        schema.UserMessage(userInput),
    }

    for i := 0; i < maxIterations; i++ {
        resp, err := a.model.Generate(ctx, messages)
        if err != nil {
            return fmt.Errorf("llm generate: %w", err)
        }
        messages = append(messages, resp)

        // No tool calls: the model considers itself done.
        if len(resp.ToolCalls) == 0 {
            return nil
        }

        // Execute every requested tool call.
        for _, call := range resp.ToolCalls {
            result := a.executeToolCall(ctx, call)
            messages = append(messages, result)
        }
    }
    return fmt.Errorf("max iterations reached")
}
```

Das sind die 20 Zeilen, die einen DAG-Tool wie Airflow nicht abbilden können
— der Rücksprung `tool → llm` macht den Zyklus.

## Zwischenergebnisse: wo landen die eigentlich?

Eine zentrale Frage, die sich spätestens stellt, wenn der Prozess länger als
ein paar Sekunden läuft: **was passiert, wenn er abstürzt?** Alle Iterationen
weg?

Genau dafür gibt es **Checkpointing**. Die Frameworks machen es, wir können
es auch selbst. Das Muster ist in beiden Fällen identisch:

- Es gibt **einen State-Container**, den jeder Step liest und erweitert.
- Am Ende jedes Steps wird der komplette State als **JSON serialisiert**
  und in eine **Tabelle** geschrieben.
- Jede Zeile ist ein **vollständiger Snapshot** — nicht inkrementell.
- Beim Resume lädt man die letzte Zeile für die entsprechende `thread_id`.

### Das Schema

```sql
CREATE TABLE agent_checkpoints (
    id          INTEGER PRIMARY KEY AUTOINCREMENT,
    thread_id   TEXT    NOT NULL,
    step        INTEGER NOT NULL,
    state       TEXT    NOT NULL,   -- das volle JSON
    created_at  TEXT    NOT NULL,
    UNIQUE (thread_id, step)
);
```

Bei SQLite ist `state` ein TEXT-Feld mit JSON-Inhalt. Bei Postgres würde
man `JSONB` nehmen — der Go-Code bleibt identisch, nur der Driver ändert
sich.

### Was im State steckt

```json
{
  "thread_id": "trip-berlin-0412",
  "step": 7,
  "status": "running",
  "messages": [ /* die komplette Konversationshistorie */ ],
  "approved": [
    {"file": "2026-04-10-lunch.txt", "amount": 21.50, "note": "lunch within limit"}
  ],
  "flagged": [
    {"file": "2026-04-11-minibar.txt", "reason": "not reimbursable"}
  ]
}
```

Kern-Idee: **die Message-History ist der eigentliche Agent-State.** Alles,
was der Agent "weiß", steckt in diesen Messages. Wenn man die ins JSON
packt, kann man den Agent später an derselben Stelle fortsetzen, an der er
aufgehört hat.

### Der Trick beim Resume

```go
func (a *Agent) initialState(ctx context.Context, userInput string) ([]*schema.Message, int, error) {
    if a.store == nil {
        return freshMessages(userInput), 0, nil
    }

    prev, err := a.store.Resume(ctx, a.threadID)
    if err != nil {
        return nil, 0, err
    }
    if prev == nil {
        return freshMessages(userInput), 0, nil
    }

    // Restore: messages, approved receipts, flagged issues.
    a.reg.Restore(prev.Approved, prev.Flagged)
    return prev.Messages, prev.Step, nil
}
```

Das ist alles. Beim Start wird geschaut, ob ein Checkpoint existiert. Wenn
ja: Messages laden, Domain-State wiederherstellen, ab dem gespeicherten Step
weitermachen.

## Läuft

Erster Lauf, mit Checkpoint aktiviert:

```
% go run . -thread trip-berlin-0412

==============================================
 Expense Report Assistant — eino example
==============================================
 model:      gemma4:26b
 endpoint:   http://localhost:11434/v1
 thread id:  trip-berlin-0412
 checkpoint: ./agentic.sqlite
==============================================

[checkpoint] new thread "trip-berlin-0412"
--- iteration 1 ---
[tool call] read_policy({})
[checkpoint] saved step 1 (4 msgs, 0 approved, 0 flagged)
--- iteration 2 ---
[tool call] list_receipts({})
[checkpoint] saved step 2 (6 msgs, 0 approved, 0 flagged)
--- iteration 3 ---
[tool call] read_receipt({"filename":"2026-04-10-lunch.txt"})
[checkpoint] saved step 3 (8 msgs, 0 approved, 0 flagged)
--- iteration 4 ---
[tool call] approve_receipt({"amount":"21.50","filename":"2026-04-10-lunch.txt",...})
[checkpoint] saved step 4 (10 msgs, 1 approved, 0 flagged)
--- iteration 5 ---
^C
```

An dieser Stelle drücke ich absichtlich **Ctrl+C**. Der Prozess bricht ab.
Nochmal starten, gleicher Thread:

```
% go run . -thread trip-berlin-0412

[checkpoint] resuming thread "trip-berlin-0412" at step 4
--- iteration 5 ---
[tool call] read_receipt({"filename":"2026-04-11-dinner.txt"})
...
```

Der Agent macht **exakt da weiter**, wo er unterbrochen wurde. Nicht von
vorne. Die bereits approveten Belege sind im State, die Policy hat er nicht
nochmal gelesen (weil in der Message-History schon drin), er geht direkt zum
nächsten Beleg.

### Die finale Abrechnung

Nach allen Iterationen kommt der hardcoded Approval-Gate — das Muster 1,
auf das wirklich Verlass ist:

```
================================================
 APPROVAL REQUIRED: submit expense report
================================================
 Approved for reimbursement:
   2026-04-10-lunch.txt           21.50 EUR  (lunch within limit)
   2026-04-11-dinner.txt          87.00 EUR  (Client dinner; one drink allowed. Removed Grappa (8.50 EUR). Total 95.50 - 8.50 = 87.00.)
   2026-04-11-taxi.txt            14.80 EUR  (Taxi after 23:00 is reimbursable)
   2026-04-12-hotel.txt          402.00 EUR  (Rate exceeds 180 EUR limit. Approved 180 EUR per night + breakfast)
 TOTAL                           525.30 EUR

 Flagged (not reimbursed):
   2026-04-11-minibar.txt         Minibar items are not reimbursable
================================================
 Submit this report? [y/N]: y
```

## Der interessanteste Moment

Der eigentliche Aha-Moment kam beim Vergleich zweier Läufe. **Erster Durchlauf,
ohne Unterbrechung:**

| Position | Ergebnis |
|---|---|
| Dinner | 75,00 € ("included 1 drink") |
| Hotel | komplett geflaggt |
| **Total** | **111,30 €** |

**Zweiter Durchlauf, mit Resume nach Unterbrechung:**

| Position | Ergebnis |
|---|---|
| Dinner | 87,00 € ("95.50 - 8.50 Grappa = 87.00") |
| Hotel | 402,00 € approved (180×2 + 42 Frühstück) |
| **Total** | **525,30 €** |

**Gleicher Code, gleiche Eingabe, gleicher System-Prompt. Zwei völlig
verschiedene Ergebnisse.** Beide sind plausibel, aber der zweite Lauf ist
deutlich besser: Die Rechnung beim Dinner ist transparent (exakte Zahlen),
das Hotel wird nicht komplett abgelehnt sondern bis zum Limit anerkannt.

Warum? Zwei Effekte wahrscheinlich:

1. **Die Message-History im Checkpoint** enthält die bereits gemachten
   Entscheidungen und deren Begründungen. Das Modell hat einen
   konsistenteren Entscheidungsrahmen als bei einem frischen Start.
2. **LLMs sind nicht deterministisch.** Bei jedem Lauf kann eine andere
   Entscheidung fallen.

Das ist **ein weiterer Grund für hardcoded Approval-Gates.** Man kann
nicht darauf bauen, dass das Modell heute so entscheidet wie gestern.

## Was dabei rausgekommen ist

| Feature | Status |
|---|---|
| Tool-Calling-Loop mit Eino | ✅ |
| Human-Approval (hardcoded Gate) | ✅ |
| LLM-fragt-aktiv (`ask_human`) | ✅ |
| Checkpointing pro Step | ✅ (SQLite) |
| Resume nach Crash | ✅ |
| Thread-Listung | ✅ (`-list`) |

Das ist mehr, als man in vielen Tutorials an einem Stück sieht. Und es ist
überschaubarer Go-Code: der Loop selbst sind ~40 Zeilen, die Checkpoint-
Logik nochmal ~80, der Rest sind Tools und Glue.

## Fazit

**Eino ist die Antwort der Go-Community auf LangGraph.** Während die
Python-Welt mit LangChain/LangGraph oft als "schnell was zusammenstecken"
wahrgenommen wird, ist Eino für Entwickler gedacht, die agentische
Workflows direkt in performante Go-Services integrieren wollen — wo
Typsicherheit, Nebenläufigkeit und ein schlanker Dependency-Footprint
zählen.

Aber: Ein Framework ist kein Zauberstab.

- **Es löst keine Probleme, die ein `for`-Loop löst.** Für lineare
  Workflows (E-Mail schreiben, einzelner RAG-Call) ist das overkill.
- **Es ersetzt keine Policy-Entscheidungen.** Ob `send_email` Approval
  braucht, musst du hardcodieren. Das Framework hilft dir nur beim
  Plumbing.
- **Es repariert kein schlechtes Modell-Verhalten.** Wenn Gemma zu selten
  nach `ask_human` greift, ist das keine Framework-Frage.

Was es dir wirklich gibt:

- **Tool-Binding:** Schemas an das Modell hängen, Tool-Calls parsen.
- **Message-Handling:** Die Konversationshistorie pflegen.
- **Streaming und Callbacks:** Falls du das brauchst.
- **Checkpointing-Hooks:** Die State-Persistenz-Schnittstelle.

Das ist solides Plumbing, keine Magie. Und manchmal ist genau das, was man
braucht.

---

**Code:** Das komplette Beispiel liegt in unserem Examples-Repo unter
`examples/agentic`.

**Getestet mit:**
- `gemma4:26b` via Ollama (reliable, manchmal overconfident)
- `qwen3` als Vergleich (fragt häufiger nach)

**Verwendete Pakete:**
- `github.com/cloudwego/eino v0.8.9`
- `github.com/cloudwego/eino-ext/components/model/openai v0.1.13`
- `modernc.org/sqlite` (pure-Go SQLite, kein CGO nötig)
