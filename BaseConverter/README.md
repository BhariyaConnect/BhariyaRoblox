<div align="center">

# ◈ BaseConverter

### Turn big numbers into smaller strings.

**A compact Base-88 number encoder for Roblox Luau.**

[![Version](https://img.shields.io/badge/version-1.1.0-8b5cf6?style=for-the-badge)](#)
[![Platform](https://img.shields.io/badge/platform-Roblox-111827?style=for-the-badge&logo=roblox)](#)
[![Language](https://img.shields.io/badge/language-Luau-00A2FF?style=for-the-badge)](#)
[![Base](https://img.shields.io/badge/base-88-16a34a?style=for-the-badge)](#)

<br/>

**Why store `10000000` when you can store `GC7o`?**

BaseConverter converts integers into a compact Base-88 string representation and back again.

<br/>

[Getting Started](#-getting-started) ·
[Examples](#-usage) ·
[API](#-api-reference) ·
[How It Works](#-under-the-hood) ·
[Tips](#-tips-tricks--footguns)

</div>

---

## ✨ What is BaseConverter?

A lot of storage systems represent values as strings. That's convenient, but decimal numbers can take more characters than necessary.

BaseConverter gives each digit a much larger alphabet: **88 available characters instead of 10**.

For example:

| Number | Base-88 representation |
|---:|:---|
| `0` | `a` |
| `1` | `b` |
| `10` | `k` |
| `10000000` | `GC7o` |

The result is a small, dependency-free Luau module with two methods:

- `Encode(number)` → Base-88 string
- `Decode(string)` → number

It is intentionally focused: **numbers in, strings out; strings in, numbers out.**

> [!NOTE]
> BaseConverter is an encoding format, not encryption. Anyone who knows the character set can decode the values.

---

## 🚀 Getting Started

### 1. Install the module

Add `BaseConverter` to your Roblox project as a `ModuleScript`.

### 2. Require it

```lua
local BaseConverter = require(path.to.BaseConverter)
```

### 3. Encode a number

```lua
local encoded = BaseConverter.Encode(10000000)

print(encoded) -- GC7o
```

### 4. Decode it

```lua
local decoded = BaseConverter.Decode("GC7o")

print(decoded) -- 10000000
```

That's the whole API. No setup, no configuration, no dependencies.

---

## 🎮 Usage

### Encode and decode

```lua
local BaseConverter = require(path.to.BaseConverter)

local original = 123456789

local encoded = BaseConverter.Encode(original)
local decoded = BaseConverter.Decode(encoded)

print("Original:", original)
print("Encoded:", encoded)
print("Decoded:", decoded)
```

### Negative numbers

Negative values are supported. The module prefixes the encoded magnitude with `|`.

```lua
print(BaseConverter.Encode(-10000000))
-- |GC7o

print(BaseConverter.Decode("|GC7o"))
-- -10000000
```

The `|` character is deliberately not part of the Base-88 alphabet, so it can serve as the negative sign.

### Zero

Zero has a dedicated one-character representation:

```lua
print(BaseConverter.Encode(0)) -- a
print(BaseConverter.Decode("a")) -- 0
```

### Use it when saving data

```lua
local coins = 10000000

local storedCoins = BaseConverter.Encode(coins)

-- Save storedCoins using your chosen storage system.
-- Later, after reading it:

local loadedCoins = BaseConverter.Decode(storedCoins)
```

### Encode multiple values

```lua
local values = {
    Coins = 10000000,
    XP = 250000,
    Wins = 42,
}

local encoded = {}

for key, value in values do
    encoded[key] = BaseConverter.Encode(value)
end

local decoded = {}

for key, value in encoded do
    decoded[key] = BaseConverter.Decode(value)
end
```

If you are building a custom compact format, choose a delimiter that is not part of the character set. The module excludes spaces and `|` from its alphabet specifically so they remain available for surrounding formats.

---

## 📚 API Reference

### `BaseConverter.Encode(number)`

Converts a number into its Base-88 string representation.

```lua
local encoded = BaseConverter.Encode(10000000)
```

| Input | Output |
|---:|:---|
| `0` | `"a"` |
| `1` | `"b"` |
| `10` | `"k"` |
| `-10` | `"|k"` |
| `10000000` | `"GC7o"` |

The encoder determines the sign, converts the magnitude using repeated division and remainder operations, and prefixes `|` when the input is negative.

### `BaseConverter.Decode(string)`

Converts a Base-88 string back into a number.

```lua
local decoded = BaseConverter.Decode("GC7o")
```

- Recognizes the optional leading `|` negative sign.
- Converts each character using the reverse lookup table.
- Raises an error if a character is not in the alphabet.
- Returns the reconstructed numeric value.

### Module shape

```lua
return table.freeze({
    Encode = Encode,
    Decode = Decode
})
```

The returned API table is frozen, so its public methods cannot be replaced at runtime.

---

## 🧠 Under the hood

### Why Base-88?

In Base 10, each digit represents one of 10 possible values:

```text
0 1 2 3 4 5 6 7 8 9
```

BaseConverter uses 88 distinct characters:

```text
abcdefghijklmnopqrstuvwxyz
ABCDEFGHIJKLMNOPQRSTUVWXYZ
0123456789
!@#$%^&*()-_=+[]{};:, .<>?~
```

The actual character set contains no spaces; the visual grouping above is only for readability.

More possible values per digit means fewer digits are needed to represent the same integer.

### Encoding: repeated division

The encoder repeatedly divides the number by 88 and records each remainder.

```lua
while n > 0 do
    remainder = n % BASE
    n = math.floor(n / BASE)

    table.insert(result, CHARACTER_SET[remainder + 1])
end
```

The remainders are produced from least significant to most significant, which is why the result is concatenated in the order they were collected.

### Decoding: positional value

The decoder walks the string from right to left and rebuilds the value:

```lua
value = value * BASE + digit
```

Each step shifts the accumulated value one Base-88 position to the left, then adds the next digit.

### Reverse lookup

Instead of searching the character array every time, the module builds a reverse map once:

```lua
CHAR_TO_VALUE[char] = index - 1
```

That makes each character lookup a direct table access.

---

## 📏 Why can the output be shorter?

A decimal digit has 10 possible values. A Base-88 digit has 88.

For the same non-negative integer, a larger base generally needs fewer digits.

For example:

| Decimal value | Decimal digits | Base-88 digits |
|---:|---:|---:|
| `10000000` | 8 | 4 (`GC7o`) |

The exact storage savings depend on the value and on how the surrounding storage system accounts for string size.

> [!TIP]
> This is most useful when you store lots of integer values as text and the encoded representation is used consistently by both the writer and reader.

---

## 🎯 Tips, tricks & footguns

### ✅ Do this

- **Use integers.** The conversion algorithm is designed for whole-number values.
- **Keep the same alphabet.** Changing character order changes the meaning of every encoded value.
- **Use the matching decoder.** Data encoded with this alphabet must be decoded with the same alphabet and sign convention.
- **Keep the negative sign intact.** The leading `|` is part of the representation for negative numbers.
- **Test round trips.** Check that decoding an encoded value gives you the original value.
- **Version your stored format.** If you ever change the alphabet or encoding rules, make sure old data can still be decoded.

### ❌ Avoid this

#### Don't treat it as encryption

```lua
local hidden = BaseConverter.Encode(123456)
```

This is reversible encoding. It does not protect secrets or sensitive data.

#### Don't change the character order casually

```lua
-- Changing even one character's position changes the encoding format.
```

If the alphabet changes, previously stored strings may decode to different numbers.

#### Don't pass fractional values

The implementation is intended for integers. Fractional values are not validated or supported by the current encoder.

#### Don't pass arbitrary text to Decode

Invalid characters raise an error:

```lua
local value = BaseConverter.Decode("hello world")
```

Only strings composed of the Base-88 alphabet, optionally prefixed by `|`, are valid inputs.

### Number precision matters

Luau numbers use floating-point representation. Very large integers cannot all be represented exactly.

For exact round trips, keep values within the exact integer range of the numeric representation used by Luau (commonly up to `2^53 - 1` in magnitude, which is pretty big already).

If your application needs larger exact integers, use a dedicated big-integer representation rather than relying on a Luau number.

---

## 🧪 Testing checklist

A useful test set should cover:

- [ ] `0`
- [ ] Positive single-digit values
- [ ] Values around Base-88 boundaries (`87`, `88`, `89`)
- [ ] Large positive integers
- [ ] Negative values
- [ ] Values whose encoded form contains punctuation
- [ ] Invalid characters passed to `Decode`
- [ ] Round-trip equality for supported integer values

A simple round-trip test:

```lua
local testValues = {
    0,
    1,
    87,
    88,
    89,
    10000000,
    -1,
    -10000000,
}

for _, original in testValues do
    local encoded = BaseConverter.Encode(original)
    local decoded = BaseConverter.Decode(encoded)

    assert(decoded == original, string.format(
        "Round-trip failed: %s -> %s -> %s",
        tostring(original),
        encoded,
        tostring(decoded)
    ))
end

print("All BaseConverter tests passed!")
```

---

## ❓ FAQ

<details>
<summary><strong>Is this Base64?</strong></summary>

No. BaseConverter uses its own 88-character alphabet and positional numeral system. It is not Base64 and is not compatible with Base64 encoders or decoders.
</details>

<details>
<summary><strong>Does it support negative numbers?</strong></summary>

Yes. A leading `|` marks a negative value. The sign character is not part of the digit alphabet.
</details>

<details>
<summary><strong>Can I encode strings or tables?</strong></summary>

No. The module is intentionally limited to number-to-string and string-to-number conversion. Convert or serialize your data separately if you need to encode more complex structures.
</details>

<details>
<summary><strong>Can I use the output as a delimiter-safe value?</strong></summary>

The alphabet excludes spaces and `|`, so those characters are available for surrounding string formats. Make sure your chosen delimiter is not one of the 88 digit characters. For example use "," or "."
</details>

<details>
<summary><strong>Does a shorter string always mean fewer bytes?</strong></summary>

Not necessarily. The character count is shorter for many values, but actual storage size depends on the encoding and storage system. Measure the complete stored representation if storage savings matter.
</details>

---

## 📦 Version

**BaseConverter v1.1.0**

---

<div align="center">

### 88 characters. Fewer digits. Same number.

**BaseConverter — make your numbers compact.**

</div>
