# Signal v1.0.0
- Based on New luau type solver
- Uses generics for IntelliSense and easy autofill
- Tiny module making the code easy to read by anyone
- Use variables and methods with Pascal naming scheme only, camel or snake cases are for internal work and should not be used unless you know exactly what you are doing
- Uses circular doubly linked list based approach to allow O(1) disconnects at abrupt indexes.
- All callers and waiters start as different threads at the same time (in order of their entrances), its upto the cpu scheduler to decide which one finishes first.
- All callbacks and waiters are wrapped in pcall adding error handling, so error in one call doesn't affect the others


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