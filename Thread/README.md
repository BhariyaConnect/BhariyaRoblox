# Thread v1.0.0
- Based on New luau type solver.
- Uses generics for IntelliSense and easy autofill.
- Tiny module making the code easy to read by anyone.
- Use variables and methods with Pascal naming scheme only, camel or snake cases are for internal work and should not be used unless you know exactly what you are doing
- Stack based pool approach, adds new threads to end of list and removes from end of list.
- All functions are wrapped in pcall to avoid thread loss.
- Specifically avoids use of L1 cache and depends entirely on table based pool (This is based on my personal benchmarks)