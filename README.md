# lua-lenses

**lua-lenses** is a powerful, functional-style library for **composable access and updates** of nested Lua tables. Inspired by Haskell’s lens concept, **lua-lenses** makes it easy to:

- Get deeply nested values without repetitive code.  
- Mutate or immutably update nested fields.  
- Compose smaller “paths” into larger ones.  
- Handle missing keys gracefully or strictly error out.  
- Optionally auto-create missing subtables.  
- Apply wildcard updates to arrays.

---

## Table of Contents

1. [Features](#features)  
2. [Installation](#installation)  
3. [Quick Start](#quick-start)  
4. [Detailed Usage](#detailed-usage)  
   - [String Paths](#string-paths)  
   - [Strict vs. Silent Mode](#strict-vs-silent-mode)  
   - [Immutable vs. In-Place Updates](#immutable-vs-in-place-updates)  
   - [Dynamic Keys](#dynamic-keys)  
   - [Wildcards](#wildcards)  
   - [Composition](#composition)  
5. [Examples](#examples)  
6. [Performance Considerations](#performance-considerations)  
7. [Contributing](#contributing)  
8. [License](#license)

---

## Features

- **Functional Lenses**: Focus on specific parts of nested tables using minimal code.  
- **String Path Support**: `lens.path("foo.bar.baz")` automatically splits the path on `.`.  
- **Strict or Silent**: Raise an error if a key does not exist (`strict=true`), or return `nil` silently.  
- **Mutable or Immutable**: Decide whether to mutate your table in-place or return a new (copied) version.  
- **Auto-Creation of Missing Keys**: Optionally build missing sub-tables on the fly with `createMissing=true`.  
- **Dynamic Keys**: Provide a **function** that derives the key at runtime.  
- **Wildcard Support**: Apply the same update to multiple keys (e.g., array indices).  
- **Simple Composition**: Chain multiple lenses with `lensA:and_then(lensB)` or a sugar operator like `lensA .. lensB`.

---

## Installation

You can install **lua-lenses** via [LuaRocks](https://luarocks.org/):

```bash
luarocks install lua-lenses
