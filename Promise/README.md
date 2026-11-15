<div align="center">

# ⚡ Promise

### Future values. Clean chains. No callback spaghetti.

[![Version](https://img.shields.io/badge/version-1.0.0-8b5cf6?style=for-the-badge)](#)
[![Platform](https://img.shields.io/badge/platform-Roblox-111827?style=for-the-badge&logo=roblox)](#)
[![Language](https://img.shields.io/badge/language-Luau-00A2FF?style=for-the-badge)](#)
[![API](https://img.shields.io/badge/API-Generic%20%26%20Chainable-16a34a?style=for-the-badge)](#)

**An asynchronous result wrapper for Luau, with typed resolve/reject values, chainable callbacks, yielding `Await()`, and externally controlled `Deferred` promises.**

[Quick Start](#-quick-start) · [Chaining](#-chaining-promises) · [Deferred](#-deferred-promises) · [API](#-api-reference) · [Tips](#-tips-tricks--gotchas)

</div>

---

## 🧠 What is a Promise?

Sometimes a function starts now, but its result arrives later.

Maybe you're loading player data, waiting for a remote response, initializing another system, or adapting an API that completes through callbacks.

You could pass callbacks around until your code looks like a plate of spaghetti.

Or you could return a **Promise**.

A Promise represents a result that may arrive in the future. It eventually settles as either:

- **Resolved** — the operation completed successfully.
- **Rejected** — the operation failed.

Once settled, its status and result are retained.

```text
                 New Promise
                      |
               +------+------+
               |             |
            Resolve        Reject
               |             |
               v             v
           SUCCESS         FAILURE
               |             |
               +------+------+
                      |
                 Settled once
```

## ✨ Features

- **Generic types** for resolve and reject values.
- **`AndThen()`** for success and failure callbacks.
- **`Catch()`** as a convenient rejection handler.
- **Chainable promises** — callbacks produce a new Promise.
- **`Await()`** to yield until the Promise settles.
- **`Deferred()`** for operations completed externally.
- **Single settlement** — later resolve/reject attempts are ignored.
- **Callback cleanup** after completion.
- **Thread module integration** for scheduling executor and callback work.

---

## 🚀 Quick Start

### 1. Install

Place the Promise ModuleScript alongside the required `Thread` module:

```text
Parent
├── Thread
└── Promise
```

The module requires:

```lua
local Thread = require(script.Parent:WaitForChild("Thread"))
```

If you do not want the custom Thread module, replace its scheduling calls with suitable `task.spawn` / `task.defer` equivalents while preserving the intended scheduling behaviour.

### 2. Require Promise

```lua
local Promise = require(path.to.Promise)
```

### 3. Create your first Promise

```lua
local function GetPlayerCoins(userId: number)
    return Promise.New(function(resolve, reject)
        local success, result = pcall(function()
            -- Replace this with your actual operation.
            return 250
        end)

        if success then
            resolve(result)
        else
            reject(result)
        end
    end)
end
```

The executor receives two callbacks:

```lua
resolve(...)
reject(...)
```

Call `resolve` when the operation succeeds, or `reject` when it fails. If the executor itself throws an error, the Promise catches it and rejects with that error.

### 4. Consume the result

```lua
GetPlayerCoins(12345):AndThen(
    function(coins)
        print("Player has", coins, "coins")
    end,
    function(reason)
        warn("Could not load coins:", reason)
    end
)
```

---

## 🔗 Chaining Promises

`AndThen()` attaches callbacks and returns a **new Promise**.

```lua
local result = Promise.New(function(resolve)
    resolve(10)
end)

local chained = result:AndThen(function(value)
    print("First step:", value)
    return value * 2
end)

chained:AndThen(function(value)
    print("Second step:", value)
end)
```

The callback's return value becomes the chained Promise's resolve value. If the callback throws an error, the chained Promise is rejected with that error.

### Handle both outcomes

```lua
local request = Promise.New(function(resolve, reject)
    local success = true

    if success then
        resolve("Data received")
    else
        reject("Request failed")
    end
end)

request:AndThen(
    function(data)
        print("Success:", data)
    end,
    function(reason)
        warn("Failure:", reason)
    end
)
```

### Catch errors

`Catch()` is a wrapper over `AndThen(nil, onReject)`.

```lua
request:Catch(function(reason)
    warn("Something went wrong:", reason)
end)
```

It only attaches a rejection callback and returns a chained Promise.

### Recover from a rejection

A rejection callback that completes successfully resolves the chained Promise.

```lua
local operation = Promise.New(function(_, reject)
    reject("Network unavailable")
end)

local recovered = operation:Catch(function(reason)
    warn(reason)
    return "Cached data"
end)

recovered:AndThen(function(value)
    print("Continuing with:", value)
end)
```

The original Promise remains rejected. The new chained Promise can resolve successfully.

---

## ⏳ Await: use a Promise like a yielding operation

Use `Await()` when the calling code is already running in a coroutine that is allowed to yield.

```lua
local promise = Promise.New(function(resolve)
    task.wait(2)
    resolve("Finished!")
end)

local success, result = promise:Await()

if success then
    print(result)
else
    warn(result)
end
```

`Await()` returns:

```lua
success, ...values
```

- `success == true`: the Promise resolved.
- `success == false`: the Promise rejected.

It yields the calling coroutine until the Promise settles. If it has already settled, the stored result is returned immediately.

> [!IMPORTANT]
> `Await()` yields the current coroutine. Do not call it from a context that cannot yield. The exact scheduling and resumption behaviour also depends on the supplied `Thread` module.

---

## 🧰 Deferred Promises

Sometimes the Promise should be created now, but completed somewhere else.

That's what `Deferred()` is for.

A Deferred gives you:
- A Promise that other code can observe.
- A `Resolve()` method.
- A `Reject()` method.
- A `Reset()` method to reuse it after a completed operation.

**The Deferred does not execute your operation.** You start the work yourself and signal its result when ready.

### Basic example

```lua
local deferred = Promise.Deferred<string, string>()

deferred.Promise:AndThen(
    function(value)
        print("Received:", value)
    end,
    function(reason)
        warn("Failed:", reason)
    end
)

task.delay(2, function()
    deferred:Resolve("Hello from the future")
end)
```

### Reject externally

```lua
local deferred = Promise.Deferred<number, string>()

task.delay(1, function()
    deferred:Reject("The operation timed out")
end)

local success, result = deferred.Promise:Await()

if success then
    print("Result:", result)
else
    warn("Reason:", result)
end
```

### Bridge a callback API

Deferred is useful when adapting an API that uses callbacks.

```lua
local function WaitForSomething()
    local deferred = Promise.Deferred<string, string>()

    SomeCallbackAPI(function(success, result)
        if success then
            deferred:Resolve(result)
        else
            deferred:Reject(result)
        end
    end)

    return deferred.Promise
end

WaitForSomething():AndThen(function(result)
    print(result)
end)
```

`SomeCallbackAPI` is a placeholder for your own callback-based API.

### Reuse a Deferred

```lua
local deferred = Promise.Deferred<number, string>()

local function RunOperation()
    deferred:Reset()

    task.delay(1, function()
        deferred:Resolve(100)
    end)

    return deferred.Promise
end
```

> [!WARNING]
> Call `Reset()` only after the previous operation has settled and before starting the next one. Do not reuse one Deferred for overlapping operations: its resolver/rejecter pair is shared, not a separate operation queue.

---

## 📚 API reference

### `Promise.New(executor)`

Creates a Promise and schedules its executor through the Thread module.

```lua
local promise = Promise.New(function(resolve, reject)
    -- Start work.
    resolve("Success")
    -- Or: reject("Failure")
end)
```

If the executor throws, the Promise is rejected with the thrown error. Only the first settlement is accepted; later resolve/reject attempts have no effect.

### `promise:AndThen(onResolve?, onReject?)`

Attaches optional callbacks for resolved and rejected outcomes.

```lua
local nextPromise = promise:AndThen(
    function(...)
        -- Handle resolved values.
        return ...
    end,
    function(...)
        -- Handle rejection values.
        return ...
    end
)
```

Returns a new Promise.

| Callback | When it runs |
|---|---|
| `onResolve` | Parent Promise resolves |
| `onReject` | Parent Promise rejects |

A callback's returned value resolves the chained Promise. An error thrown by a callback rejects it. If the corresponding callback is omitted, the parent outcome is forwarded.

### `promise:Catch(onReject)`

Convenience wrapper for rejection handling.

```lua
local recovered = promise:Catch(function(reason)
    warn(reason)
    return "Fallback"
end)
```

Returns a chained Promise.

### `promise:Await()`

Yields until the Promise settles.

```lua
local success, ...results = promise:Await()
```

Returns a success boolean followed by the stored resolve or reject values.

### `Promise.Deferred()`

Creates a Deferred object containing a Promise and external completion methods.

```lua
local deferred = Promise.Deferred<ResolveType, RejectType>()
```

| Member | Description |
|---|---|
| `deferred.Promise` | The Promise to observe |
| `deferred:Resolve(...)` | Resolve it externally |
| `deferred:Reject(...)` | Reject it externally |
| `deferred:Reset()` | Reset the completed Promise for reuse |

---

## 🧬 Type examples

Promise supports separate generic types for successful and rejected values.

```lua
local promise: Promise.Promise<number, string> =
    Promise.New(function(resolve, reject)
        resolve(100)
        -- Or reject("Something failed")
    end)
```

A Deferred can use the same distinction:

```lua
local deferred: Promise.Deferred<boolean, string> =
    Promise.Deferred<boolean, string>()
```

This makes the intended result and failure types visible to Luau's type checker and editor autocomplete.

---

## 🎯 Tips, tricks & gotchas

### ✅ Do

- **Reject with useful information.** Descriptive failures are easier to debug.
- **Use `Await()` for sequential coroutine code.** It can make async flows easier to read.
- **Use `AndThen()` for event-driven flows.** React without yielding the current function.
- **Use Deferred to bridge callback APIs.** It creates a clean boundary between callback-based and Promise-based code.
- **Keep one Deferred per in-flight operation.** Reuse only after the previous operation has completed.
- **Treat resolve/reject as one-shot signals.** The first one wins.

### ❌ Don't

#### Don't block a non-yieldable context

```lua
-- Avoid Await() where yielding is not allowed.
local success, result = promise:Await()
```

Use `AndThen()` if you cannot safely yield.

#### Don't expect both resolve and reject to run

```lua
local promise = Promise.New(function(resolve, reject)
    resolve("Done")
    reject("Too late") -- Ignored
end)
```

A Promise settles only once.

#### Remember that chains create new Promises

```lua
local nextPromise = promise:AndThen(function(value)
    return value + 1
end)
```

Attach to `nextPromise` to observe the transformed result, not the original Promise.

#### Don't reset a Deferred while old work is still running

An old callback could resolve the newly reset Promise. Keep operations separate or ensure the previous operation is fully finished before reuse.

---

## 🧪 Testing checklist

- [ ] Executor resolves successfully.
- [ ] Executor rejects successfully.
- [ ] Executor throws an error.
- [ ] Multiple resolve/reject attempts only settle once.
- [ ] `AndThen()` attached before completion runs.
- [ ] `AndThen()` attached after completion runs.
- [ ] Missing callbacks forward the parent outcome.
- [ ] A successful callback resolves the chained Promise.
- [ ] A throwing callback rejects the chained Promise.
- [ ] `Catch()` recovers from a rejection.
- [ ] `Await()` works before and after completion.
- [ ] Multiple awaiters receive the same settled outcome.
- [ ] Deferred resolves and rejects externally.
- [ ] Deferred is reset only after completion.
- [ ] Callback references are cleared after settlement.

---

## ⚙️ Scheduling

Promise delegates scheduling to your `Thread` module:

```lua
local Thread = require(script.Parent:WaitForChild("Thread"))
```

The implementation uses `Thread.Spawn()` for:
- Running Promise executors.
- Running callbacks attached to already-completed Promises.
- Dispatching callbacks when a Promise settles.

`Await()` resumes its waiting coroutine through `task.spawn()`.

If you replace the Thread module, preserve the expected scheduling behaviour. A custom scheduler can change when callbacks run and how work is interleaved.

---

## 🔍 Design notes

### Immutable after settlement

A Promise stores whether it completed, whether it resolved or rejected, and its result values. Further resolve/reject calls are ignored.

### Callback cleanup

After settlement, the implementation clears its waiter list:

```lua
table.clear(promise._waiters)
```

This releases references held by registered callbacks, allowing them to be garbage-collected when nothing else references them.

The result and completion status remain available for later `Await()` and `AndThen()` calls.

### Promise versus Deferred

| Promise | Deferred |
|---|---|
| Created with an executor | Created without user-supplied work |
| Executor starts through Thread | Caller starts the operation |
| Executor receives resolve/reject | Resolve/reject are exposed as methods |
| Best for wrapping async work | Best for external completion |

---

## ❓ FAQ

<details>
<summary><strong>Does Promise.New run the executor immediately?</strong></summary>

The executor is scheduled using `Thread.Spawn()`. Its exact start timing depends on the implementation of your Thread module.
</details>

<details>
<summary><strong>Can a Promise resolve more than once?</strong></summary>

No. The first call to resolve or reject settles it. Later attempts are ignored.
</details>

<details>
<summary><strong>Can I attach AndThen after a Promise has completed?</strong></summary>

Yes. The callback is scheduled with the stored outcome.
</details>

<details>
<summary><strong>Does Catch modify the original Promise?</strong></summary>

No. It returns a new chained Promise. The original Promise retains its original outcome.
</details>

<details>
<summary><strong>Does Deferred run my function?</strong></summary>

No. Deferred only exposes a Promise and its external resolve/reject methods. You run the operation yourself.
</details>

<details>
<summary><strong>Can I reuse a Deferred?</strong></summary>

The module provides `Reset()`. Use it only after the previous operation has settled and make sure no old asynchronous work can complete against the reset Deferred.
</details>

---

## 📦 Version

**Promise v1.0.0**

## 🤝 Contributing

When reporting an issue, include:
- The Promise and Thread module versions.
- A minimal reproduction.
- Expected versus actual callback order.
- Whether the Promise was pending or already completed when the callback was attached.
- Any errors thrown by the executor or callbacks.

---

<div align="center">

### Your result is on its way.

**Promise — write the flow, not the callback maze.**

</div>
