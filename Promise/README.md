<div align="center">

# ✦ Promise

### Asynchronous work, wrapped in a value that arrives later.

**A lightweight Promise implementation for Roblox Luau.**

[![Version](https://img.shields.io/badge/version-2.0.0-8b5cf6?style=for-the-badge)](#)
[![Platform](https://img.shields.io/badge/platform-Roblox-111827?style=for-the-badge&logo=roblox)](#)
[![Language](https://img.shields.io/badge/language-Luau-00A2FF?style=for-the-badge)](#)

**Start work now. Receive its result later. Keep your game thread moving.**

[Quick Start](#-quick-start) · [Combinators](#-promise-combinators) · [API](#-api-reference) · [Patterns](#-patterns--recipes) · [Internals](#-how-it-works)

</div>

---

## ⚡ What is Promise?

Some operations take time: a web request needs a response, a datastore call needs to finish, or several asynchronous tasks need to complete before the next step can begin.

A **Promise** represents a value that may become available in the future.

```lua
local promise = Promise.Promisify(fetchPlayerData, player.UserId)

-- Do other work while the operation runs.

local success, result = promise.Await()

if success then
    print("Loaded:", result)
else
    warn("Failed:", result)
end
```

Promise v2.0.0 provides:

- **Promises** — asynchronous results with resolve/reject states.
- **Deferreds** — externally controlled promises.
- **Promisify** — execute a function asynchronously and capture its result or error.
- **Combinators** — `All`, `AllSettled`, `Race`, and `Any`.
- **Generic types** — describe resolved and rejected values.
- **Simple tables** — no `setmetatable`-based promise objects.
- **Waiter cleanup** — callbacks are cleared after settlement.

> [!NOTE]
> This library intentionally does not implement JavaScript's full Promise API. `AndThen()` and `Catch()` do not return chained promises. They register callbacks and return nothing.

---

## 🚀 Quick Start

### 1. Install

Place the Promise ModuleScript and its `Thread` dependency in your Roblox project.

```text
YourFolder
├── Promise
└── Thread
```

The module expects:

```lua
local Thread = require(script.Parent:WaitForChild("Thread"))
```

Keep this dependency path intact, or update the require to match your project.

### 2. Require it

```lua
local Promise = require(path.to.Promise)
```

### 3. Create your first promise

```lua
local promise = Promise.Promise(function(resolve, reject)
    task.wait(2)
    resolve("Hello from the future!")
end)
```

The executor runs in a new thread. The promise is returned immediately.

```lua
local success, result = promise.Await()

if success then
    print(result)
else
    warn(result)
end
```

`Await()` yields the calling coroutine until the promise settles. It does not block the entire Roblox scheduler.

---

## 🧱 The two outcomes

Every promise has one of two completion outcomes.

### Fulfilled — `resolve(value)`

```lua
local promise = Promise.Promise(function(resolve, reject)
    resolve(100)
end)

promise.AndThen(function(value)
    print("Success:", value) -- 100
end)
```

### Rejected — `reject(reason)`

```lua
local promise = Promise.Promise(function(resolve, reject)
    reject("Something went wrong")
end)

promise.Catch(function(reason)
    warn("Rejected:", reason)
end)
```

A promise only accepts its **first** completion. Later calls to `resolve()` or `reject()` are ignored until the promise is reset.

---

## 🧭 Choose your style

### 1. Await — pause this coroutine

```lua
local success, result = promise.Await()

if success then
    print(result)
else
    warn(result)
end
```

Use this when the next lines depend on the result.

### 2. AndThen — react to either outcome

```lua
promise.AndThen(
    function(value)
        print("Resolved:", value)
    end,
    function(reason)
        warn("Rejected:", reason)
    end
)
```

Both callbacks are optional:

```lua
promise.AndThen(function(value)
    print("Only interested in success:", value)
end)
```

### 3. Catch — react only to rejection

```lua
promise.Catch(function(reason)
    warn("Promise failed:", reason)
end)
```

**Important:** `AndThen()` and `Catch()` are callback registration methods, not chain builders. They do not create or return a new promise.

---

## 🧰 Promise constructors

### `Promise.Promise(executor)`

Creates a promise and executes the supplied function in a new thread.

```lua
local promise = Promise.Promise(function(resolve, reject)
    local success, result = pcall(function()
        return 42
    end)

    if success then
        resolve(result)
    else
        reject(result)
    end
end)
```

The executor receives two functions:

| Callback | Meaning |
|---|---|
| `resolve(value)` | Fulfil the promise with a value |
| `reject(reason)` | Reject the promise with a reason |

If the executor throws an error, the promise is rejected with that error.

If the executor returns without calling either callback, the promise is completed automatically with:

```text
Promise executor completed without calling resolve or reject
```

> [!WARNING]
> If you start a separate thread inside the executor to resolve later, the executor itself must not return first. Otherwise, the automatic completion rule settles the promise before that separate thread resolves it. Use `Deferred` for externally controlled completion.

### `Promise.Deferred()`

Creates a promise whose resolve/reject functions are returned to you.

```lua
local deferred = Promise.Deferred()

-- Give the promise to another system.
local promise = deferred.Promise

task.delay(2, function()
    deferred.Resolve("Finished!")
end)

local success, result = promise.Await()
print(success, result)
```

Reject it from anywhere that holds the deferred:

```lua
deferred.Reject("Operation cancelled")
```

A Deferred contains:

| Field | Purpose |
|---|---|
| `Promise` | The promise consumers await or observe |
| `Resolve` | Completes it successfully |
| `Reject` | Completes it unsuccessfully |
| `Reset` | Resets the underlying promise |

**Deferred does not run a task for you.** Start your own work and call `Resolve` or `Reject` when it finishes.

### `Promise.Promisify(func, parameter)`

Runs a function in a new thread and converts its return value or thrown error into a promise outcome.

```lua
local function calculateCoins(userId)
    task.wait(1)

    if userId <= 0 then
        error("Invalid user ID")
    end

    return userId * 100
end

local promise = Promise.Promisify(calculateCoins, player.UserId)

promise.AndThen(
    function(coins)
        print("Coins:", coins)
    end,
    function(reason)
        warn("Calculation failed:", reason)
    end
)
```

The function is called with the supplied parameter. A successful return resolves the promise; an error rejects it.

---

## 🧩 Promise combinators

Why manage ten promises when one combined promise can represent the group?

### `Promise.All(promises)`

<badge>All must resolve</badge>

Fulfils when every input promise fulfils. Rejects as soon as an input promise rejects.

```lua
local promises = {
    Promise.Promisify(loadInventory, player.UserId),
    Promise.Promisify(loadSettings, player.UserId),
    Promise.Promisify(loadAchievements, player.UserId),
}

local success, results = Promise.All(promises).Await()

if success then
    local inventory = results[1]
    local settings = results[2]
    local achievements = results[3]
else
    warn("At least one operation failed:", results)
end
```

**Result order follows the input order**, not the order in which promises finish.

```text
Input:    [A, B, C]
Finished: [C, A, B]
Results:  [A, B, C]
```

An empty input resolves immediately with an empty table.

### `Promise.AllSettled(promises)`

<badge>Wait for every outcome</badge>

Waits until every input promise has either resolved or rejected. The combined promise resolves with a result entry for each input.

```lua
local results = Promise.AllSettled({
    Promise.Promisify(loadInventory, player.UserId),
    Promise.Promisify(loadSettings, player.UserId),
    Promise.Promisify(loadAchievements, player.UserId),
})

local success, outcomes = results.Await()

for index, outcome in outcomes do
    if outcome.success then
        print(index, "Resolved:", outcome.value)
    else
        warn(index, "Rejected:", outcome.reason)
    end
end
```

Each result has one of these shapes:

```lua
-- Fulfilled
{
    success = true,
    value = result,
}

-- Rejected
{
    success = false,
    reason = reason,
}
```

An empty input resolves immediately with an empty table.

### `Promise.Race(promises)`

<badge>First to settle wins</badge>

Settles with the outcome of the first input promise to resolve **or reject**.

```lua
local result = Promise.Race({
    Promise.Promisify(fetchPrimaryServer, player.UserId),
    Promise.Promisify(fetchBackupServer, player.UserId),
})

local success, value = result.Await()

if success then
    print("First result:", value)
else
    warn("First operation failed:", value)
end
```

The winner can be a success or a failure.

### `Promise.Any(promises)`

<badge>First success wins</badge>

Resolves with the first fulfilled promise. Rejections are collected. If every input rejects, the combined promise rejects with an array of rejection reasons.

```lua
local result = Promise.Any({
    Promise.Promisify(fetchPrimaryServer, player.UserId),
    Promise.Promisify(fetchBackupServer, player.UserId),
    Promise.Promisify(fetchCachedData, player.UserId),
})

local success, value = result.Await()

if success then
    print("Got data:", value)
else
    warn("Every source failed:")
    for index, reason in value do
        warn(index, reason)
    end
end
```

The rejection array preserves the original input order.

An empty input rejects immediately with an empty table.

### Combinator cheat sheet

| Method | Completes when | Combined outcome |
|---|---|---|
| `All` | Every promise fulfils, or one rejects | First rejection or ordered values |
| `AllSettled` | Every promise settles | Ordered outcome records |
| `Race` | First promise settles | First success or rejection |
| `Any` | First promise fulfils, or all reject | First success or ordered rejection reasons |

---

## 🔁 Resetting a promise

Promise v2 supports resetting a completed promise.

```lua
local deferred = Promise.Deferred()

deferred.Resolve("First result")

local success, result = deferred.Promise.Await()
print(result) -- First result

deferred.Reset()

deferred.Resolve("Second result")

local success2, result2 = deferred.Promise.Await()
print(result2) -- Second result
```

Reset clears the completion state so the promise can settle again.

> [!WARNING]
> Reset does not cancel or restart work. It also does not remove callbacks or waiters registered before the reset. Old waiters can remain pending until a later completion. Only reset when you understand the lifecycle of every consumer.

---

## 🍳 Patterns & recipes

### Run multiple independent operations

```lua
local resultPromise = Promise.All({
    Promise.Promisify(loadPlayerData, player.UserId),
    Promise.Promisify(loadStoreItems, player.UserId),
    Promise.Promisify(loadDailyRewards, player.UserId),
})

local success, results = resultPromise.Await()

if not success then
    warn("Loading failed:", results)
    return
end

local playerData, storeItems, dailyRewards =
    results[1], results[2], results[3]
```

All three operations begin independently. The caller waits for the combined result.

### Add a timeout to an operation

`Race()` can stop waiting after a time limit:

```lua
local operation = Promise.Promisify(fetchPlayerData, player.UserId)

local timeout = Promise.Promise(function(resolve)
    task.wait(10)
    resolve("Timed out")
end)

local success, result = Promise.Race({
    operation,
    timeout,
}).Await()

if success and result == "Timed out" then
    warn("The operation took too long")
elseif success then
    print("Data:", result)
else
    warn("Operation failed:", result)
end
```

**Important:** this only stops waiting for the original operation. It does not cancel it. The original operation may still finish later.

### Wrap a callback-based API with Deferred

```lua
local function getPlayerProfile(userId)
    local deferred = Promise.Deferred()

    SomeService:GetProfile(userId, function(profile)
        if profile then
            deferred.Resolve(profile)
        else
            deferred.Reject("Profile not found")
        end
    end)

    return deferred.Promise
end

local success, profile = getPlayerProfile(player.UserId).Await()
```

Useful for APIs that complete through callbacks instead of returning a value immediately.

### Observe a promise without yielding

```lua
local promise = Promise.Promisify(loadPlayerData, player.UserId)

promise.AndThen(function(data)
    print("Player data is ready")
end)

-- Continue doing other work here.
```

---

## 🧠 How it works

### 1. The executor starts in a separate thread

When you create a promise, its executor is scheduled through the `Thread` module. The caller receives the promise object without waiting for the executor to finish.

### 2. Completion is stored

The promise tracks:

```lua
local succeeded: boolean? = nil
local waiters = {}
local completionResult
```

The states are:

```text
nil    = Pending
true   = Fulfilled
false  = Rejected
```

Once settled, the first result is retained until the promise is reset.

### 3. Waiters are resumed

Consumers using `Await()` or registered callbacks are stored until completion.

When the promise settles:

- Waiting callbacks are scheduled.
- The waiter table is cleared.
- The completion state and result remain available.
- Future consumers receive the stored outcome immediately.

### 4. No metatable required

Promise v2 returns a simple table containing its public functions:

```lua
return {
    AndThen = AndThen,
    Catch = Catch,
    Await = Await,
    Reset = Reset,
}
```

Internal completion variables remain captured by local closures rather than being exposed as object fields.

---

## 🎯 Tips, tricks & footguns

### Use `.` instead of `:`

Promise v2 methods are stored as standalone functions in the returned table.

```lua
-- Correct
promise.Await()
promise.AndThen(onResolve, onReject)
promise.Catch(onReject)
promise.Reset()
```

Not:

```lua
-- Incorrect for this API
promise:Await()
promise:AndThen(onResolve, onReject)
```

The same applies to Deferred:

```lua
deferred.Resolve(value)
deferred.Reject(reason)
deferred.Reset()
```

### Remember that Await yields the current coroutine

```lua
local success, result = promise.Await()
```

This suspends the calling coroutine until completion. It does not freeze the entire game.

### Don't return from an executor before resolving

```lua
-- BAD
local promise = Promise.Promise(function(resolve)
    task.spawn(function()
        task.wait(2)
        resolve("Done")
    end)
end)
```

The executor returns immediately, so the promise's automatic completion logic settles it before the spawned task resolves.

Use Deferred:

```lua
-- GOOD
local deferred = Promise.Deferred()

task.spawn(function()
    task.wait(2)
    deferred.Resolve("Done")
end)

local promise = deferred.Promise
```

Or keep asynchronous work inside the executor:

```lua
local promise = Promise.Promise(function(resolve)
    task.wait(2)
    resolve("Done")
end)
```

### Don't expect JavaScript-style chaining

```lua
-- Not supported: AndThen returns nothing
local nextPromise = promise.AndThen(function(value)
    return value * 2
end)
```

Callbacks are notifications only. If you need another asynchronous stage, create a separate promise through your own function.

### Don't confuse Race with Any

- `Race` accepts the first success **or** rejection.
- `Any` ignores rejections until a success arrives, and rejects only if every input rejects.

### Don't mistake timeout for cancellation

A timeout built with `Race()` stops the caller from waiting. It does not terminate the losing operation.

### Be careful when resetting

Resetting a promise does not cancel existing work. Old waiters can be resumed by a later settlement. Avoid reusing a promise while previous consumers are still waiting unless that behaviour is intentional.

---

## 🧾 API reference

| API | Description | Returns |
|---|---|---|
| `Promise.Promise(executor)` | Creates and runs a promise executor | `Promise` |
| `Promise.Deferred()` | Creates externally controlled completion | `Deferred` |
| `Promise.Promisify(func, parameter)` | Runs a function asynchronously | `Promise` |
| `Promise.All(iterable)` | Waits for all fulfilments | `Promise` |
| `Promise.AllSettled(iterable)` | Waits for every settlement | `Promise` |
| `Promise.Race(iterable)` | First settlement wins | `Promise` |
| `Promise.Any(iterable)` | First fulfilment wins | `Promise` |

### Promise methods

| Method | Description |
|---|---|
| `promise.Await()` | Returns `success, result`; yields while pending |
| `promise.AndThen(onResolve?, onReject?)` | Registers completion callbacks |
| `promise.Catch(onReject)` | Registers a rejection callback |
| `promise.Reset()` | Clears the completion state |

### Deferred fields

| Field | Description |
|---|---|
| `deferred.Promise` | The associated Promise |
| `deferred.Resolve(value)` | Resolve externally |
| `deferred.Reject(reason)` | Reject externally |
| `deferred.Reset()` | Reset the associated Promise |

---

## 🧬 Generic types

Promise exposes generic types for resolved and rejected values.

```lua
local promise: Promise.Promise<number, string> =
    Promise.Promise(function(resolve, reject)
        if math.random() > 0.5 then
            resolve(100)
        else
            reject("Random failure")
        end
    end)
```

A Deferred can describe the same two result types:

```lua
local deferred: Promise.Deferred<number, string> =
    Promise.Deferred()

deferred.Resolve(100)
deferred.Reject("Something went wrong")
```

The generic types describe intended success and rejection values. When inference cannot determine a type automatically, annotate the variable or constructor's expected type.

---

## 🧪 Behaviour checklist

- [x] Executor runs in a separate thread.
- [x] Resolve and reject are first-completion-wins.
- [x] Executor errors become rejections.
- [x] Executor returning without completion triggers automatic rejection.
- [x] Await returns the completion status and result.
- [x] Callbacks registered before completion are invoked on settlement.
- [x] Callbacks registered after completion receive the stored outcome.
- [x] Waiter callbacks are cleared after settlement.
- [x] Deferred exposes external resolve/reject functions.
- [x] Promisify captures function returns and errors.
- [x] All, AllSettled, Race and Any are provided.
- [x] Reset allows the completion state to be reused.

The source notes report that memory-leak checks passed for callback cleanup after settlement. This is not a substitute for testing every consumer lifecycle, especially when using Reset.

---

## ❓ FAQ

<details>
<summary><strong>Does Await freeze the main thread?</strong></summary>

No. It yields the calling coroutine. Other scheduled work can continue.
</details>

<details>
<summary><strong>Why does my promise reject immediately when I use task.spawn?</strong></summary>

The executor returns before the spawned task resolves. Use Deferred for externally completed work, or perform the asynchronous work directly inside the executor.
</details>

<details>
<summary><strong>Does AndThen return another promise?</strong></summary>

No. This implementation intentionally uses callback registration without JavaScript-style chaining.
</details>

<details>
<summary><strong>Does Race cancel the losing promises?</strong></summary>

No. It settles the combined promise when the first input settles. Other operations continue independently.
</details>

<details>
<summary><strong>What happens if I resolve twice?</strong></summary>

Only the first resolve/reject call is accepted for the current completion cycle. Later calls are ignored until Reset.
</details>

<details>
<summary><strong>Does Deferred run my function?</strong></summary>

No. Deferred gives you external control over a Promise. You are responsible for starting the operation and calling Resolve or Reject.
</details>

---

<div align="center">

### Don't wait around for work. Represent it.

**Promise v2.0.0 — asynchronous results, without the ceremony.**

</div>
