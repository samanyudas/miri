---------------------------- MODULE EngineLifecycle ----------------------------
(***************************************************************************)
(* How Miri starts, stops, restarts, and quits its engine.                  *)
(*                                                                          *)
(* Each action is one job on the main actor, or one event of the operating  *)
(* system, so nothing else runs inside an action. The comment above each     *)
(* operator names the Swift code that it describes. The coverage record and *)
(* sync commit live in .claude/skills/verify-engine-lifecycle/SKILL.md.      *)
(***************************************************************************)
EXTENDS Naturals, Sequences, FiniteSets

CONSTANT Mutant  \* "none" checks the code as it is. Other values break one rule on purpose.

Mutants == {"none", "restart_without_waiting", "stop_reports_stopped_early", "no_kill_timer"}
ASSUME Mutant \in Mutants

Ids == 1..3        \* Process identities. An identity is reused only after the process is gone.
Limit == 3         \* CrashPolicy.limit. The model assumes that every crash is inside CrashPolicy.window.
MaxPending == 3    \* Bound: Step drops any step that leaves more than 3 stop completions waiting.

VARIABLE s
vars == <<s>>

Init == s = [
    \* AppDelegate (Sources/Miri/App.swift) and AppModel.launch.
    app |-> "launching",          \* "launching", "open", "quitting", "quit"
    \* AppModel (Sources/Miri/AppModel.swift).
    stoppedByUser |-> FALSE,      \* Set below from the saved value, which can be either.
    polling |-> FALSE,            \* setupPoll != nil
    blockersShown |-> FALSE,      \* !startBlockers.isEmpty
    blocked |-> FALSE,            \* What refreshSetup would find: a setup check blocks start.
    \* EngineSupervisor (Sources/MiriCore/Engine.swift).
    engine |-> "stopped",         \* EngineState without its payload: "stopped", "running", "restarting", "failed"
    proc |-> 0,                   \* process, or 0 for nil
    stopRequested |-> FALSE,
    completions |-> <<>>,         \* stopCompletions: "none" or "quitReply"
    restartArmed |-> FALSE,       \* pendingRestart exists and is not cancelled
    killArmed |-> FALSE,          \* A kill timer from stop() waits for the current process.
    crashes |-> 0,                \* policy.crashes.count, capped at Limit
    restartAfterStop |-> FALSE,
    \* The operating system.
    alive |-> {},                 \* Engine processes that run.
    exitQueued |-> {},            \* Processes that ended. Their onExit job waits for the main actor.
    \* Ghost variables. They change no behavior.
    wantsStopped |-> FALSE,       \* Your last Start, Stop, or Restart was a Stop.
    launchedWhileStopped |-> FALSE
  ] \/ s = [
    app |-> "launching", stoppedByUser |-> TRUE, polling |-> FALSE, blockersShown |-> FALSE,
    blocked |-> FALSE, engine |-> "stopped", proc |-> 0, stopRequested |-> FALSE,
    completions |-> <<>>, restartArmed |-> FALSE, killArmed |-> FALSE, crashes |-> 0,
    restartAfterStop |-> FALSE, alive |-> {}, exitQueued |-> {}, wantsStopped |-> TRUE, launchedWhileStopped |-> FALSE
  ]

Free(t) == CHOOSE i \in Ids : i \notin t.alive \cup t.exitQueued /\ i # t.proc

(***************************************************************************)
(* EngineSupervisor, Sources/MiriCore/Engine.swift.                         *)
(* Each operator maps one state record to the next, in the order the Swift  *)
(* code runs. `ok` says whether launcher.launch succeeds.                    *)
(***************************************************************************)

\* Launch a process now, with no guard. Body of start() after its guard.
Launch(t, ok) ==
  LET u == [t EXCEPT !.restartArmed = FALSE, !.stopRequested = FALSE] IN
  IF ok
  THEN LET i == Free(u) IN
       [u EXCEPT !.proc = i, !.alive = @ \cup {i}, !.engine = "running",
                 !.launchedWhileStopped = @ \/ u.wantsStopped]
  ELSE [u EXCEPT !.engine = "failed"]

\* start(), Engine.swift:78. `guard process == nil else { return }`.
SupStart(t, ok) == IF t.proc # 0 THEN t ELSE Launch(t, ok)

\* Runs stopCompletions in order. AppDelegate's completion replies to
\* applicationShouldTerminate, and the app exits inside that reply.
RECURSIVE RunAll(_, _, _)
RunAll(t, cs, ok) ==
  IF cs = <<>> THEN t
  ELSE IF Head(cs) = "quitReply" THEN [t EXCEPT !.app = "quit"]
  ELSE RunAll(t, Tail(cs), ok)

\* stop(completion:), Engine.swift:104. A later stop cancels a restart that waits for the exit.
SupStop(t, c, ok) ==
  LET u == [t EXCEPT !.restartArmed = FALSE, !.restartAfterStop = FALSE] IN
  IF u.proc = 0
  THEN RunAll([u EXCEPT !.engine = "stopped"], <<c>>, ok)
  ELSE [u EXCEPT !.stopRequested = TRUE, !.completions = Append(@, c),
                 !.killArmed = (Mutant # "no_kill_timer"),
                 !.engine = IF Mutant = "stop_reports_stopped_early" THEN "stopped" ELSE @]

\* restartManually(), Engine.swift:93.
RestartManually(t, ok) ==
  LET u == [t EXCEPT !.crashes = 0] IN
  IF Mutant = "restart_without_waiting" /\ u.proc # 0
  THEN Launch(SupStop(u, "none", ok), ok)
  ELSE IF u.proc # 0 THEN [SupStop(u, "none", ok) EXCEPT !.restartAfterStop = TRUE] ELSE SupStart(u, ok)

\* exited(status:), Engine.swift:123. It clears process whichever process ended.
\* recoverWindows() runs here and changes nothing in this model.
\* After the stop completions it starts the engine if restartAfterStop was set,
\* unless a completion replied to the quit and the app exited.
Exited(t, ok) ==
  LET u == [t EXCEPT !.proc = 0, !.killArmed = FALSE] IN
  IF u.stopRequested
  THEN LET w == RunAll([u EXCEPT !.stopRequested = FALSE, !.engine = "stopped", !.completions = <<>>,
                                 !.restartAfterStop = FALSE], u.completions, ok)
       IN IF u.restartAfterStop /\ w.app # "quit" THEN SupStart(w, ok) ELSE w
  ELSE IF u.crashes + 1 >= Limit
  THEN [u EXCEPT !.crashes = Limit, !.engine = "failed"]
  ELSE [u EXCEPT !.crashes = @ + 1, !.engine = "restarting", !.restartArmed = TRUE]

(***************************************************************************)
(* AppModel, Sources/Miri/AppModel.swift.                                   *)
(***************************************************************************)

\* start(), AppModel.swift:361. refreshSetup() reads t.blocked.
\* While blocked, a supervisor that does not run is stopped, which cancels a pending crash restart.
AppStart(t, ok) ==
  LET u == [t EXCEPT !.stoppedByUser = FALSE, !.blockersShown = t.blocked] IN
  IF u.blocked
  THEN [IF u.engine # "running" THEN SupStop(u, "none", ok) ELSE u
        EXCEPT !.polling = TRUE]                   \* pollSetupUntilReady keeps a running poll.
  ELSE LET w == [u EXCEPT !.polling = FALSE] IN    \* setupPoll?.cancel(); setupPoll = nil
       IF w.engine = "running" THEN w ELSE RestartManually(w, ok)

\* cancelSetupPoll(), AppModel.swift:448.
CancelPoll(t) == [t EXCEPT !.polling = FALSE, !.blockersShown = FALSE]

\* stop(), AppModel.swift:378.
AppStop(t, ok) == SupStop(CancelPoll([t EXCEPT !.stoppedByUser = TRUE]), "none", ok)

\* restart(), AppModel.swift:390.
AppRestart(t, ok) == LET u == [t EXCEPT !.stoppedByUser = FALSE] IN
  IF u.engine = "running" THEN RestartManually(u, ok) ELSE AppStart(u, ok)

\* prepareToQuit(completion:), AppModel.swift:397, with AppDelegate's reply as the completion.
PrepareToQuit(t, ok) == SupStop(CancelPoll(t), "quitReply", ok)

(***************************************************************************)
(* Actions.                                                                 *)
(***************************************************************************)

Open == s.app = "open"
\* Every action sets the next state through Step. Step drops a step that leaves more than
\* MaxPending stop completions waiting, so that the state space stays finite.
Step(t) == s' = t /\ Len(t.completions) <= MaxPending
\* Records your command before the code runs, so the rules can compare the result with it.
You(command) == [s EXCEPT !.wantsStopped = (command = "stop")]

\* applicationDidFinishLaunching -> AppModel.launch(), AppModel.swift:100.
AppLaunches == s.app = "launching" /\ \E ok \in BOOLEAN :
  Step(IF s.stoppedByUser THEN [s EXCEPT !.app = "open"] ELSE AppStart([s EXCEPT !.app = "open"], ok))

\* The menu, the Settings sidebar, Settings > General, and Set Up Miri show Start only
\* while the engine is stopped and nothing blocks start.
\* Views.swift:88, SettingsWindow.swift:153, SettingsPages.swift:114, InitialSetup.swift:78.
YouPressStart == Open /\ s.engine = "stopped" /\ ~s.blockersShown /\ \E ok \in BOOLEAN : Step(AppStart(You("start"), ok))

\* Stop shows while the engine runs or restarts, or while it is stopped and Miri waits for setup.
\* Views.swift:78, :85, SettingsWindow.swift:147, :151, SettingsPages.swift:100.
YouPressStop == Open /\ (s.engine \in {"running", "restarting"} \/ (s.engine = "stopped" /\ s.blockersShown))
                /\ \E ok \in BOOLEAN : Step(AppStop(You("stop"), ok))

\* Restart is enabled only while the engine runs or has failed. While it restarts after a crash,
\* the menu and Settings > Diagnostics disable Restart, and the other places hide it.
\* Views.swift:76, :81, SettingsWindow.swift:149, SettingsPages.swift:89, :574, :608, InitialSetup.swift:83.
YouPressRestart == Open /\ s.engine \in {"running", "failed"} /\ \E ok \in BOOLEAN : Step(AppRestart(You("restart"), ok))

\* The Stop window manager shortcut, StopShortcut.swift, calls stopFromShortcut(), AppModel.swift:385.
YouPressStopShortcut == Open /\ ~s.stoppedByUser /\ \E ok \in BOOLEAN : Step(AppStop(You("stop"), ok))

\* keyboardLayoutChanged(), AppModel.swift:122. The model gives every change a new layout.
LayoutChanges == Open /\ \E ok \in BOOLEAN :
  Step(IF s.engine = "running" /\ ~s.stoppedByUser THEN RestartManually(s, ok) ELSE s)

\* Quit Miri or SIGTERM -> applicationShouldTerminate, App.swift:46. A second quit does nothing.
YouQuit == Open /\ \E ok \in BOOLEAN : Step(PrepareToQuit([s EXCEPT !.app = "quitting"], ok))

\* A setup check starts or stops blocking, such as Accessibility permission.
SetupChanges == s.app \in {"open", "quitting"} /\ Step([s EXCEPT !.blocked = ~@])

\* The engine process ends: a crash, a clean exit after interrupt(), or any other reason.
EngineEnds == s.app # "quit" /\ \E i \in s.alive :
  Step([s EXCEPT !.alive = @ \ {i}, !.exitQueued = @ \cup {i}])

\* The terminationHandler's main-actor job runs onExit, EngineProcess.swift:107.
ExitDelivered == s.app # "quit" /\ \E i \in s.exitQueued : \E ok \in BOOLEAN :
  Step(Exited([s EXCEPT !.exitQueued = @ \ {i}], ok))

\* stop()'s kill timer wakes after stopTimeout, Engine.swift:116. It kills only the same process.
KillTimerFires == s.app # "quit" /\ s.killArmed /\
  Step(IF s.proc \in s.alive
       THEN [s EXCEPT !.killArmed = FALSE, !.alive = @ \ {s.proc}, !.exitQueued = @ \cup {s.proc}]
       ELSE [s EXCEPT !.killArmed = FALSE])

\* pendingRestart wakes after restartDelay, Engine.swift:144.
RestartTimerFires == s.app # "quit" /\ s.restartArmed /\ \E ok \in BOOLEAN :
  Step(SupStart([s EXCEPT !.restartArmed = FALSE], ok))

\* pollSetupUntilReady() wakes after setupPollInterval, AppModel.swift:431.
PollTick == s.app # "quit" /\ s.polling /\ \E ok \in BOOLEAN :
  Step(IF s.blocked
       THEN [s EXCEPT !.blockersShown = TRUE]
       ELSE AppStart([s EXCEPT !.blockersShown = FALSE, !.polling = FALSE], ok))

\* The app has exited. Nothing more happens.
Quit == s.app = "quit" /\ UNCHANGED vars

Next ==
  AppLaunches \/ YouPressStart \/ YouPressStop \/ YouPressRestart \/ YouPressStopShortcut
  \/ LayoutChanges \/ YouQuit \/ SetupChanges \/ EngineEnds \/ ExitDelivered
  \/ KillTimerFires \/ RestartTimerFires \/ PollTick \/ Quit

\* Timers and onExit jobs run eventually. You, macOS settings, and the engine itself owe nothing.
Spec == Init /\ [][Next]_vars
        /\ WF_vars(ExitDelivered) /\ WF_vars(KillTimerFires)
        /\ WF_vars(RestartTimerFires) /\ WF_vars(PollTick) /\ WF_vars(AppLaunches)

(***************************************************************************)
(* Rules.                                                                   *)
(***************************************************************************)

\* No engine starts after you stop Miri, until you start or restart it.
StopStands == ~s.launchedWhileStopped

\* Miri's saved Stop matches your last Start, Stop, or Restart.
SavedStopMatches == s.stoppedByUser = s.wantsStopped

\* When Miri finishes quitting, no engine runs.
QuitLeavesNoEngine == s.app = "quit" => s.alive = {}

\* At most one engine process runs.
OneEngine == Cardinality(s.alive) <= 1

\* When the status says stopped or failed, no engine runs.
StoppedMeansNoEngine == s.engine \in {"stopped", "failed"} => s.alive = {}

\* While Miri waits for setup to start the engine, the status says it is waiting.
WaitingIsShown == (s.polling /\ s.engine \in {"stopped", "failed"}) => (s.engine = "stopped" /\ s.blockersShown)

\* A quit always finishes.
QuitFinishes == s.app = "quitting" ~> s.app = "quit"
=============================================================================
