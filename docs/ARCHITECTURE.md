# Octo System Architecture

High-level skill interaction diagram showing how the five orchestration skills relate to each other, shared data stores, and autonomous agent sessions.

```mermaid
flowchart TD
    subgraph USER["User Commands"]
        direction LR
        ADD(["/add"])
        RUN(["/run &lt;id&gt;"])
        LS(["/ls"])
        NR(["/new-repo"])
        SYN(["/sync-template"])
    end

    subgraph DATA["Control Plane · .octo/"]
        direction TB
        CFG["config\nOCTO_WORKSPACE=..."]
        GRAPH["graph.yaml\nnode metadata (optional)"]
        TASKS[("tasks/&lt;id&gt;.md\nspec · steps · context")]
        RUNS[("runs/&lt;id&gt;/step-N/\npid · heartbeat · log · result.md")]
    end

    subgraph WORKSPACE["$OCTO_WORKSPACE (auto-scanned)"]
        direction LR
        REPO_A["repo-a/\n.git"]
        REPO_B["repo-b/\n.git"]
        REPO_N["..."]
    end

    subgraph SCRIPTS["Shell Scripts"]
        SCR_SPAWN["scripts/spawn.sh\ngit checkout · launch claude · record pid"]
        SCR_SCAFFOLD["scripts/scaffold.sh\ncopy template · substitute vars · git init"]
    end

    subgraph REMOTE["Inside Target Repo (per step)"]
        direction TB
        SESMD["session.md\ntask prompt + heartbeat + result path"]
        AGENT["Autonomous Claude\n(headless · 30 min limit)"]
        HB["heartbeat\nwritten every 60s"]
        PR["Pull Request"]
    end

    %% Discovery
    CFG -- "workspace path" --> ADD & RUN & LS & SYN
    WORKSPACE -- "scanned at runtime\nno registration" --> ADD & RUN & SYN
    GRAPH -- "template metadata\n(optional)" --> SYN & NR

    %% Task creation
    ADD -- "writes spec" --> TASKS

    %% Task listing
    LS -- "reads" --> TASKS
    LS -- "derives live status" --> RUNS

    %% Run lifecycle
    TASKS -- "reads spec + steps" --> RUN
    RUN -- "Case A: spawn\nwrites session.md" --> SESMD
    RUN -- "calls" --> SCR_SPAWN
    SCR_SPAWN -- "creates branch\nlaunches agent" --> AGENT
    SCR_SPAWN -- "creates" --> RUNS
    AGENT -- "reads" --> SESMD
    AGENT -- "writes every 60s" --> HB
    HB -- "stored in" --> RUNS
    AGENT -- "opens" --> PR
    AGENT -- "writes on done/fail" --> RUNS

    %% Run monitoring / recovery
    RUN -- "Case B: tail log\nCase C: detect crash\nCase D: collect result" --> RUNS
    RUN -- "crash detected:\nauto-archives · re-spawns" --> SCR_SPAWN
    RUN -- "all steps done:\nupdates status" --> TASKS

    %% Repo management
    NR -- "calls" --> SCR_SCAFFOLD
    SCR_SCAFFOLD -- "appends entry" --> GRAPH
    SCR_SCAFFOLD -- "creates repo" --> WORKSPACE
    SYN -- "diffs + optionally updates\ntemplate_version" --> GRAPH
```

## Lifecycle State Machine (per step)

```mermaid
stateDiagram-v2
    [*] --> pending : /add creates task
    pending --> running : /run spawns agent\n(Case A)
    running --> running : heartbeat written\nevery 60s
    running --> crashed : process dead\nno result.md\nheartbeat stale
    crashed --> running : /run detects crash\nauto-archives · re-spawns\n(Case C → Case A)
    running --> failed : agent writes\nresult.md status=failed
    failed --> running : /run offers retry\n(Case D → Case A)
    running --> success : agent writes\nresult.md status=success
    success --> [*] : all steps done\ntask status=success
```

## Data Flow Summary

| Phase | Actor | What changes |
| ----- | ----- | ------------ |
| **Queue** | `/add` | New `.octo/tasks/<id>.md` created (`status: pending`) |
| **Spawn** | `/run` Case A | `session.md` written to repo; branch created; agent launched; `pid` recorded |
| **Execute** | Autonomous Claude | Code committed; PR opened; `heartbeat` written every 60s; `result.md` written on done |
| **Monitor** | `/run` Case B | Reads `pid` liveness + heartbeat age; no writes |
| **Crash recovery** | `/run` Case C | Crashed run archived; fresh run spawned automatically |
| **Collect** | `/run` Case D | `result.md` parsed; task advances to next step or `status: success` |
| **Scaffold** | `/new-repo` | Template copied; git init; entry added to `graph.yaml`; auto-discovered thereafter |
| **Drift check** | `/sync-template` | Template diff shown; agent-setup files optionally overwritten; version bumped in `graph.yaml` |

## Discovery: No Registration Required

```mermaid
flowchart LR
    CFG[".octo/config\nOCTO_WORKSPACE=/Users/x/code"]
    SCAN["scan OCTO_WORKSPACE/*\nfor .git directories"]
    NODES["available nodes\nname=dirname · path=fullpath"]
    META[".octo/graph.yaml\noptional metadata"]

    CFG --> SCAN --> NODES
    META -. "template / version / depends_on" .-> NODES
```

Any repo created under `$OCTO_WORKSPACE` is immediately available to `/add`, `/run`, and `/sync-template` — no manual registration step, no drift between disk and config.
