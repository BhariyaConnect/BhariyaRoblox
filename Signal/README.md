<div align="center">

# ⚡ Signal

### Tiny. Typed. Event-driven.

**A lightweight publish–subscribe module for Roblox Luau.**

[![Version](https://img.shields.io/badge/version-1.0.0-8b5cf6?style=for-the-badge)](#)
[![Platform](https://img.shields.io/badge/platform-Roblox-111827?style=for-the-badge&logo=roblox)](#)
[![Language](https://img.shields.io/badge/language-Luau-00A2FF?style=for-the-badge)](#)
[![Type System](https://img.shields.io/badge/types-Generic-16a34a?style=for-the-badge)](#)

<br/>

**Connect listeners. Fire events. Wake waiters. Keep your systems decoupled.**

[Getting Started](#-getting-started) ·
[Examples](#-examples) ·
[API](#-api-reference) ·
[How It Works](#-under-the-hood) ·
[Tips](#-tips-tricks--footguns)

</div>

---

## ✨ What is Signal?

Sometimes one part of your game needs to announce something, while several other parts need to react.

A player levels up. A round ends. A data value changes. A matchmaking queue updates.

You could make every system call every other system directly...

Or you could let them subscribe to an event.

**Signal is a small publish–subscribe module** that lets multiple callbacks and waiting threads listen to the same event without tightly coupling the systems that produce and consume it.

```text
                 ┌──────────────┐
                 │    Signal    │
                 └──────┬───────┘
                        │ Fire(...)
             ┌──────────┼──────────┐
             ▼          ▼          ▼
          Listener   Listener    Waiter
             A          B           C
```

## ⚡ Why Signal?

- **Generic Luau types** — type your event arguments and get better autocomplete.
- **Connect / Once / Wait** — three ways to listen, depending on what your code needs.
- **Circular doubly linked list** — connections are organized for constant-time unlinking.
- **Independent dispatch** — callbacks and waiters are scheduled independently.
- **Small API** — just the essentials, without a giant event framework.

> [!NOTE]
> Signal depends on the accompanying `Thread` module for callback dispatch. Waiters are resumed with `task.spawn`. You can replace the callback dispatcher with `task.spawn` or `task.defer` if you do not want the Thread dependency.

---

**Class 2 According to [Gohan's Signal Certifications & Classes](https://devforum.roblox.com/t/signal-certifications-classes-guide/4263792)**
```
--------------------------------------------------------------------------------------
🎓 | TESTING: Signal         |
--------------------------------------------------------------------------------------
⚪ | Scheduler Certification |
--------------------------------------------------------------------------------------
☑ | Create                   | Baseline: 1  ▶ {...} | Results: 1  ▶ {...}
☑ | Connect                  | Baseline: 9  ▶ {...} | Results: 9  ▶ {...}
☑ | Connect_Safety           | Baseline: 1  ▶ {...} | Results: 1  ▶ {...}
☑ | Connect_Unit             | Baseline: 1000  ▶ {...} | Results: 1000  ▶ {...}
☑ | Once                     | Baseline: 4  ▶ {...} | Results: 4  ▶ {...}
☑ | Once_Safety              | Baseline: 3  ▶ {...} | Results: 3  ▶ {...}
☑ | Once_Unit                | Baseline: 1000  ▶ {...} | Results: 1000  ▶ {...}
☑ | Wait                     | Baseline: 1  ▶ {...} | Results: 1  ▶ {...}
☑ | Wait_Safety              | Baseline: 2  ▶ {...} | Results: 2  ▶ {...}
☑ | Wait_Unit                | Baseline: 1000  ▶ {...} | Results: 1000  ▶ {...}
☑ | DisconnectAll_Connect    | Baseline: 0 {} | Results: 0 {}
☑ | DisconnectAll_Once       | Baseline: 0 {} | Results: 0 {}
☑ | DisconnectAll_Wait       | Baseline: 0 {} | Results: 0 {}
☑ | ConsecutiveReentrancy    | Baseline: 5  ▶ {...} | Results: 5  ▶ {...}
☑ | MultiSignalCNs           | Baseline: 7  ▶ {...} | Results: 7  ▶ {...}
☑ | MultiSignalNested        | Baseline: 10  ▶ {...} | Results: 10  ▶ {...}
☑ | MultiSignalDisconnectAll | Baseline: 1  ▶ {...} | Results: 1  ▶ {...}
--------------------------------------------------------------------------------------
✅ | Scheduler Certified     | 
--------------------------------------------------------------------------------------
⚪ | Speed Certification     |
--------------------------------------------------------------------------------------
☑ | Create         | -0.6μs  | Baseline: 0.7μs  ▶ {...} | Results: 0.0μs  ▶ {...}
☑ | Connect        | -0.7μs  | Baseline: 0.8μs  ▶ {...} | Results: 0.2μs  ▶ {...}
☑ | Once           | -0.5μs  | Baseline: 0.7μs  ▶ {...} | Results: 0.2μs  ▶ {...}
☑ | Fire_None      | -0.0μs  | Baseline: 0.1μs  ▶ {...} | Results: 0.1μs  ▶ {...}
☑ | Fire_One       | +0.2μs  | Baseline: 0.4μs  ▶ {...} | Results: 0.6μs  ▶ {...}
☑ | Fire_Many      | +0.4μs  | Baseline: 0.1μs  ▶ {...} | Results: 0.5μs  ▶ {...}
☑ | Fire_OneYield  | +0.2μs  | Baseline: 0.7μs  ▶ {...} | Results: 0.9μs  ▶ {...}
☑ | Fire_ManyYield | +0.6μs  | Baseline: 0.2μs  ▶ {...} | Results: 0.8μs  ▶ {...}
☑ | Disconnect     | -0.2μs  | Baseline: 0.3μs  ▶ {...} | Results: 0.1μs  ▶ {...}
☑ | DisconnectAll  | -13.3μs | Baseline: 14.2μs  ▶ {...} | Results: 0.9μs  ▶ {...}
--------------------------------------------------------------------------------------
✅ | Speed Certified         |
--------------------------------------------------------------------------------------
⚪ | Connected Certification |
--------------------------------------------------------------------------------------
☑ | Connect       | Baseline: 2  ▶ {...} | Results: 2  ▶ {...}
☑ | Once          | Baseline: 3  ▶ {...} | Results: 3  ▶ {...}
☑ | DisconnectAll | Baseline: 2  ▶ {...} | Results: 2  ▶ {...}
--------------------------------------------------------------------------------------
✅ | Connected Certified     |
--------------------------------------------------------------------------------------
⚪ | Snapshot Certification  |
--------------------------------------------------------------------------------------
☑ | BasicOrdering     | Baseline: 1  ▶ {...} | Results: 1  ▶ {...}
☑ | Disconnect        | Baseline: 4  ▶ {...} | Results: 4  ▶ {...}
☑ | DisconnectAll     | Baseline: 4  ▶ {...} | Results: 4  ▶ {...}
✖ | NestedConnections | Baseline: 3  ▶ {...} | Results: 4  ▶ {...}
✖ | ReentranceSafety  | Baseline: 6  ▶ {...} | Results: 6  ▶ {...}
--------------------------------------------------------------------------------------
❌ | NOT Snapshot Certified  |
--------------------------------------------------------------------------------------
⚪ | Synchronous Certification |
--------------------------------------------------------------------------------------
☑ | Connect      | Baseline: 3  ▶ {...} | Results: 3  ▶ {...}
☑ | Wait_Modify  | Baseline: 2  ▶ {...} | Results: 2  ▶ {...}
☑ | Wait_Chained | Baseline: 1  ▶ {...} | Results: 1  ▶ {...}
☑ | Fire         | Baseline: 2  ▶ {...} | Results: 2  ▶ {...}
--------------------------------------------------------------------------------------
✅ | Synchronous Certified   |
--------------------------------------------------------------------------------------
⚪ | Order Certification     |
--------------------------------------------------------------------------------------
☑ | Connect    | Baseline: 2  ▶ {...} | Results: 2  ▶ {...}
☑ | Once       | Baseline: 2  ▶ {...} | Results: 2  ▶ {...}
☑ | Wait       | Baseline: 2  ▶ {...} | Results: 2  ▶ {...}
☑ | Mixed      | Baseline: 12  ▶ {...} | Results: 12  ▶ {...}
☑ | Disconnect | Baseline: 10  ▶ {...} | Results: 10  ▶ {...}
--------------------------------------------------------------------------------------
✅ | Order Certified         |
--------------------------------------------------------------------------------------
✅ | Signal: Class 2         |
--------------------------------------------------------------------------------------
```

---

## 🚀 Getting Started

### 1. Install the modules

Place `Signal` and its `Thread` dependency in your project:

```text
Packages
├── Signal
└── Thread
```

The example assumes `Thread` is a sibling of `Signal`, matching the module's `script.Parent:WaitForChild("Thread")` lookup. Adjust the location or require path if your project uses a different hierarchy.

### 2. Require Signal

```lua
local Signal = require(game.ReplicatedStorage.Packages.Signal)
```

### 3. Create a signal

Signals can carry any number of arguments:

```lua
local PlayerLeveledUp = Signal()
```

For typed signals, provide the argument types:

```lua
local PlayerLeveledUp = Signal<number, number>()
--                    Signal<playerUserId, newLevel>
```

### 4. Connect a listener

```lua
local connection = PlayerLeveledUp:Connect(function(userId, newLevel)
    print(userId, "reached level", newLevel)
end)
```

### 5. Fire the event

```lua
PlayerLeveledUp:Fire(12345, 10)
```

That's it. Any connected listeners receive the arguments.

---

## 🧪 Examples

### The classic Connect

Use `Connect()` when a listener should keep receiving events until disconnected.

```lua
local CoinsChanged = Signal<number>()

local connection = CoinsChanged:Connect(function(coins)
    print("Player now has", coins, "coins")
end)

CoinsChanged:Fire(100)
CoinsChanged:Fire(250)

connection:Disconnect()
```

After `Disconnect()`, that connection is removed from the signal's active listener list.

### Listen exactly once

Use `Once()` for a callback that should only respond to the next fire.

```lua
local RoundStarted = Signal<string>()

RoundStarted:Once(function(mapName)
    print("The next round is on", mapName)
end)

RoundStarted:Fire("Desert") -- Runs the callback.
RoundStarted:Fire("Forest") -- Does not run it again.
```

The connection is disconnected before its callback is scheduled, so a re-entrant `Fire()` will not schedule that same `Once` connection again.

### Wait for an event

Sometimes a callback is overkill. Just wait until the event happens.

```lua
local MatchFound = Signal<string, number>()

task.spawn(function()
    local serverCode, playersFound = MatchFound:Wait()

    print("Match found:", serverCode, playersFound)
end)

-- Somewhere else:
MatchFound:Fire("ABC123", 8)
```

`Wait()` yields the current coroutine. The next `Fire()` resumes it with the fired arguments.

### Disconnect everything

Need to reset a system or clear all its listeners?

```lua
local connectionA = Changed:Connect(function()
    print("A")
end)

local connectionB = Changed:Connect(function()
    print("B")
end)

Changed:DisconnectAll()
```

All connections currently attached to the signal are marked disconnected and removed from the signal's active head/tail references.

Treat previously returned connection handles as obsolete after `DisconnectAll()`; do not keep using them as active subscriptions.

### Use it as a tiny state notification bus

```lua
local HealthChanged = Signal<number, number>()

local health = 100

HealthChanged:Connect(function(oldHealth, newHealth)
    print(`Health: {oldHealth} -> {newHealth}`)
end)

local function SetHealth(newHealth: number)
    local oldHealth = health
    health = math.clamp(newHealth, 0, 100)

    if health ~= oldHealth then
        HealthChanged:Fire(oldHealth, health)
    end
end

SetHealth(75)
SetHealth(40)
```

Signal does not manage state for you. It simply broadcasts the event and its arguments.

---

## 🧩 A practical example: round system

A round manager can announce events without knowing which systems are listening.

```lua
-- RoundSignals.lua
local Signal = require(path.to.Signal)

return {
    Started = Signal<string>(),
    Ended = Signal<string, number>(),
}
```

The round manager only fires events:

```lua
local RoundSignals = require(script.Parent.RoundSignals)

local function StartRound(mapName: string)
    -- Prepare the map, spawn players, etc.
    RoundSignals.Started:Fire(mapName)
end

local function EndRound(winnerName: string, duration: number)
    RoundSignals.Ended:Fire(winnerName, duration)
end
```

Other systems subscribe independently:

```lua
-- MusicController.lua
RoundSignals.Started:Connect(function(mapName)
    print("Start the music for", mapName)
end)
```

```lua
-- Analytics.lua
RoundSignals.Ended:Connect(function(winnerName, duration)
    print(winnerName, "won after", duration, "seconds")
end)
```

```lua
-- UIController.lua
task.spawn(function()
    local winnerName, duration = RoundSignals.Ended:Wait()
    print("Show results for", winnerName, duration)
end)
```

The round manager doesn't need references to the music controller, analytics module, or UI controller. That's the beauty of publish–subscribe.

---

## 📚 API reference

### `Signal<T...>()`

Creates a new signal.

```lua
local Changed = Signal<number, string>()
```

`T...` represents the variadic argument types passed to `Fire()` and received by callbacks and `Wait()`.

### `signal:Connect(callback)`

Adds a persistent callback listener.

```lua
local connection = Changed:Connect(function(value, label)
    print(value, label)
end)
```

**Returns:** `Connection<T...>`

### `signal:Once(callback)`

Adds a listener that is automatically disconnected when the signal fires.

```lua
local connection = Changed:Once(function(value, label)
    print(value, label)
end)
```

**Returns:** `Connection<T...>`

### `signal:Wait()`

Yields the current coroutine until the signal fires.

```lua
local value, label = Changed:Wait()
```

**Returns:** the arguments passed to the next `Fire()`.

Call it from a coroutine that is allowed to yield.

### `signal:Fire(...)`

Schedules all listeners that are connected when the signal is traversed.

```lua
Changed:Fire(42, "Answer")
```

Callbacks are dispatched through `Thread.Spawn`; waiters are resumed through `task.spawn`. `Fire()` does not wait for those scheduled callbacks to finish.

### `signal:DisconnectAll()`

Disconnects all currently attached connections.

```lua
Changed:DisconnectAll()
```

The signal remains usable. New connections can be added afterward.

### `connection:Disconnect()`

Disconnects a connection.

```lua
connection:Disconnect()
```

### `connection.Connected`

Indicates whether the connection is currently marked connected.

```lua
if connection.Connected then
    connection:Disconnect()
end
```

---

## 🧠 Under the hood

### Circular doubly linked list

Signal stores its connections in a circular doubly linked list. The signal itself acts as the sentinel node.

```text
                 ┌────────────────────────────┐
                 │                            │
                 ▼                            │
             ┌────────┐    ┌────────┐    ┌────────┐
             │ Signal │◄──►│   A    │◄──►│   B    │
             └────────┘    └────────┘    └────────┘
                 ▲                            │
                 │                            │
                 └───────────◄──►─────────────┘
```

Each connection knows its previous and next node.

That means disconnecting a known node only requires updating its two neighbours:

```lua
previous._next = next
next._previous = previous
```

No array shifting or searching for the connection's index is required.

### Why a circular list?

A normal singly linked list needs access to the previous node to unlink an item efficiently.

A doubly linked list stores both directions, making it possible to remove a known connection directly.

The circular sentinel also avoids special cases for the first and last connections.

### What happens when Fire is called?

At a high level:

1. Signal starts at its first connection.
2. It remembers the next node before dispatching the current one.
3. `Once` connections are disconnected.
4. Callback listeners are dispatched through `Thread.Spawn`.
5. Waiters are resumed through `task.spawn`.
6. Traversal continues until it reaches the signal sentinel again.

The dispatch calls are scheduled independently. Their completion order is not guaranteed by the order in which they were connected.

### Thread dependency

The module uses:

```lua
Thread.Spawn(connection._callback, ...)
```

for callback listeners, while waiters use:

```lua
task.spawn(connection._thread, ...)
```

If you prefer Roblox's built-in scheduler, the callback dispatch can be changed to:

```lua
task.spawn(connection._callback, ...)
```

Or, if deferred scheduling better fits your system:

```lua
task.defer(connection._callback, ...)
```

These schedulers have different timing behaviour, so choose deliberately rather than treating them as identical.

---

## 🎯 Tips, tricks & footguns

### ✅ Do this

- **Use typed signals.** `Signal<number, string>()` makes the expected event payload clear.
- **Keep events focused.** `CoinsChanged` is easier to understand than a generic `Updated` signal used for everything.
- **Disconnect temporary listeners.** Especially when objects, UI components, or player sessions are destroyed.
- **Use `Once()` for one-time events.** It handles automatic disconnection for you.
- **Use `Wait()` inside a task.** It yields the current coroutine until the event arrives.
- **Pass event data through `Fire()`.** Avoid making every listener reach into unrelated modules to discover what happened.

### ❌ Avoid this

#### Don't wait from a non-yieldable context

```lua
-- Run Wait() from a coroutine that is allowed to yield.
local result = Changed:Wait()
```

For example, use `task.spawn()` when you need an independent waiting task.

#### Don't forget that callbacks are asynchronous

```lua
Changed:Fire()

-- Do not assume every callback has completed here.
print("Fire returned")
```

`Fire()` schedules callbacks and waiters. It is not a synchronous broadcast that waits for every listener to finish.

#### Don't assume callback completion order

Listeners are scheduled in connection traversal order, but the scheduler decides when their work actually runs and finishes.

If one listener must finish before another starts, coordinate that dependency explicitly instead of relying on Signal's dispatch order.

#### Don't retain dead connections forever

Keep connection handles only as long as you need them. Disconnect temporary listeners and release references to old connection objects when their owning system is destroyed.

#### Don't confuse a signal with a state container

A signal tells listeners that something happened. It does not remember the last value.

If a listener connects after an event was fired, it will not automatically receive that old event.

For state-like behaviour, store the current value separately and use the signal to announce changes.

---

## ⚠️ Behaviour notes

A few implementation details are important when integrating Signal into a larger system:

- `Connect()` listeners remain attached until disconnected.
- `Once()` listeners are disconnected before their callback is dispatched.
- `Wait()` listens for the next fire and returns its arguments.
- `DisconnectAll()` clears the signal's active list and marks the existing connections disconnected.
- A listener added while `Fire()` is already traversing is not guaranteed to receive that same fire.
- A connection that is disconnected during another listener's callback may already have been selected as the traversal's next node. Do not rely on disconnecting another listener mid-fire to cancel an already-in-progress dispatch.
- The implementation wraps the dispatch/scheduling calls in `pcall`. Because callbacks execute in scheduled threads, this outer `pcall` should not be treated as a guarantee that errors thrown later inside callback bodies are caught.

---

## 🧪 Testing checklist

Before using Signal as a foundation for larger systems, test the cases that matter to your project:

- [ ] One listener receives one fire.
- [ ] Multiple listeners receive the same arguments.
- [ ] Variadic arguments are passed through correctly.
- [ ] `Once()` only receives one fire.
- [ ] `Wait()` resumes with all fired arguments.
- [ ] Disconnecting a listener prevents future fires from selecting it.
- [ ] `DisconnectAll()` allows fresh listeners to be connected afterward.
- [ ] A listener can disconnect itself while handling a fire.
- [ ] A listener can add another listener while handling a fire.
- [ ] Callback errors do not break unrelated scheduled work.
- [ ] Temporary listeners are disconnected when their owning objects are destroyed.

---

## 📦 Version

**Signal v1.0.0**

---

## 🤝 Contributing

Found a bug or have an improvement?

When reporting an issue, include:

- Signal version.
- A minimal reproduction.
- Expected behaviour.
- Actual behaviour.
- Relevant output or errors.
- Whether the issue involves `Connect`, `Once`, `Wait`, or disconnection during `Fire`.

Small, reproducible test cases make event-system bugs much easier to track down.

---

<div align="center">

### Less coupling. More reacting.

**Signal — let your systems talk without knowing each other.**

</div>
