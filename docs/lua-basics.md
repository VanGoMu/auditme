# Lua Basics for Fluent Bit

## Introduction to Lua

Lua is a lightweight, embeddable scripting language. In Fluent Bit, Lua scripts are used to process and transform log records with custom logic.

## Basic Syntax

### Variables

```lua
-- Local variables (preferred in Fluent Bit)
local name = "John"
local age = 30
local is_active = true

-- Global variables (avoid in Fluent Bit)
global_var = "value"
```

### Data Types

```lua
-- Nil (no value)
local nothing = nil

-- Boolean
local is_true = true
local is_false = false

-- Numbers
local integer = 42
local float = 3.14

-- Strings
local text = "Hello, World!"
local multiline = [[
This is a
multiline string
]]

-- Tables (arrays and dictionaries)
local array = {1, 2, 3, 4}
local dict = {name = "Alice", age = 25}
```

### Comments

```lua
-- Single line comment

--[[
Multi-line
comment
]]
```

## Tables

Tables are Lua's main data structure (arrays, dictionaries, objects):

### Arrays (1-indexed!)

```lua
local fruits = {"apple", "banana", "orange"}

-- Access elements (starts at 1, not 0!)
local first = fruits[1]  -- "apple"
local second = fruits[2] -- "banana"

-- Get length
local count = #fruits    -- 3

-- Add element
fruits[4] = "grape"
table.insert(fruits, "mango")
```

### Dictionaries

```lua
local person = {
    name = "Bob",
    age = 30,
    city = "NYC"
}

-- Access values
local name = person.name      -- "Bob"
local age = person["age"]     -- 30

-- Add new key
person.email = "bob@example.com"
person["phone"] = "555-1234"
```

### Nested Tables

```lua
local data = {
    user = {
        name = "Alice",
        address = {
            city = "Paris",
            zip = "75001"
        }
    }
}

-- Access nested values
local city = data.user.address.city  -- "Paris"
```

## Control Structures

### If-Then-Else

```lua
local age = 18

if age < 18 then
    print("Minor")
elseif age >= 18 and age < 65 then
    print("Adult")
else
    print("Senior")
end
```

### Logical Operators

```lua
-- and, or, not
if age >= 18 and has_license then
    print("Can drive")
end

if is_admin or is_moderator then
    print("Has permissions")
end

if not is_banned then
    print("Welcome!")
end
```

### Loops

#### For Loop (numeric)

```lua
-- for i = start, end, step
for i = 1, 5 do
    print(i)  -- Prints 1, 2, 3, 4, 5
end

for i = 10, 1, -1 do
    print(i)  -- Prints 10, 9, 8, ..., 1
end
```

#### For Loop (iterate table)

```lua
local fruits = {"apple", "banana", "orange"}

-- Iterate array
for i, fruit in ipairs(fruits) do
    print(i, fruit)
    -- 1  apple
    -- 2  banana
    -- 3  orange
end

-- Iterate dictionary
local person = {name = "Bob", age = 30}
for key, value in pairs(person) do
    print(key, value)
    -- name  Bob
    -- age   30
end
```

#### While Loop

```lua
local count = 0
while count < 5 do
    print(count)
    count = count + 1
end
```

## Functions

### Basic Function

```lua
-- Define function
function greet(name)
    return "Hello, " .. name
end

-- Call function
local message = greet("Alice")  -- "Hello, Alice"
```

### Multiple Return Values

```lua
function get_user()
    return "Alice", 30, "alice@example.com"
end

local name, age, email = get_user()
```

### Anonymous Functions

```lua
local add = function(a, b)
    return a + b
end

local result = add(5, 3)  -- 8
```

## String Operations

### Concatenation

```lua
local first = "Hello"
local last = "World"
local message = first .. " " .. last  -- "Hello World"
```

### String Functions

```lua
local text = "Hello, World!"

-- Length
local len = #text              -- 13
local len2 = string.len(text)  -- 13

-- Uppercase/Lowercase
local upper = string.upper(text)  -- "HELLO, WORLD!"
local lower = string.lower(text)  -- "hello, world!"

-- Substring
local sub = string.sub(text, 1, 5)  -- "Hello"

-- Find (returns position)
local pos = string.find(text, "World")  -- 8

-- Replace
local new = string.gsub(text, "World", "Lua")  -- "Hello, Lua!"

-- Split by delimiter
function split(str, delimiter)
    local result = {}
    for match in (str .. delimiter):gmatch("(.-)" .. delimiter) do
        table.insert(result, match)
    end
    return result
end

local parts = split("a,b,c", ",")  -- {"a", "b", "c"}
```

### String Formatting

```lua
-- Format string
local name = "Alice"
local age = 30
local text = string.format("%s is %d years old", name, age)
-- "Alice is 30 years old"

-- Format numbers
local pi = 3.14159
local rounded = string.format("%.2f", pi)  -- "3.14"
```

## Common Patterns in Fluent Bit

### 1. Basic Record Processing

```lua
function process_record(tag, timestamp, record)
    -- Add new field
    record["processed"] = true
    record["timestamp_str"] = os.date("%Y-%m-%d %H:%M:%S", timestamp)
    
    -- Modify existing field
    if record["level"] then
        record["level"] = string.upper(record["level"])
    end
    
    -- Return: code, timestamp, record
    -- code: 0 (keep), -1 (drop), 1 (modified)
    return 1, timestamp, record
end
```

### 2. Filtering Records

```lua
function filter_errors(tag, timestamp, record)
    -- Drop record if not an error
    if record["level"] ~= "error" then
        return -1, timestamp, record  -- Drop
    end
    
    -- Keep error records
    return 0, timestamp, record  -- Keep unchanged
end
```

### 3. Enriching Data

```lua
function add_metadata(tag, timestamp, record)
    -- Add hostname
    local hostname = os.getenv("HOSTNAME") or "unknown"
    record["hostname"] = hostname
    
    -- Add environment
    record["env"] = "production"
    
    -- Add month tag for bucket routing
    local date = os.date("*t", timestamp)
    record["month"] = string.format("%04d_%02d", date.year, date.month)
    
    return 1, timestamp, record
end
```

### 4. Parsing JSON

```lua
-- Fluent Bit automatically parses JSON if input is JSON
-- Access JSON fields directly:
function process_json(tag, timestamp, record)
    if record["response"] then
        local response = record["response"]
        record["status_code"] = response["status"]
        record["response_time"] = response["time"]
    end
    
    return 1, timestamp, record
end
```

### 5. Working with Time

```lua
function add_time_fields(tag, timestamp, record)
    -- Get date table from timestamp
    local date = os.date("*t", timestamp)
    
    -- Add individual components
    record["year"] = date.year
    record["month"] = date.month
    record["day"] = date.day
    record["hour"] = date.hour
    record["minute"] = date.min
    record["second"] = date.sec
    
    -- Add formatted strings
    record["date_str"] = os.date("%Y-%m-%d", timestamp)
    record["time_str"] = os.date("%H:%M:%S", timestamp)
    record["datetime"] = os.date("%Y-%m-%d %H:%M:%S", timestamp)
    
    -- Add month bucket for routing
    record["month_bucket"] = string.format("%04d_%02d", date.year, date.month)
    
    return 1, timestamp, record
end
```

## Error Handling

### Protected Call (pcall)

```lua
function safe_process(tag, timestamp, record)
    local success, result = pcall(function()
        -- Potentially dangerous operation
        local value = tonumber(record["count"])
        record["doubled"] = value * 2
    end)
    
    if not success then
        -- Handle error
        record["error"] = "Failed to process"
        return 1, timestamp, record
    end
    
    return 1, timestamp, record
end
```

## Important Notes for Fluent Bit

### 1. Function Signature

Fluent Bit Lua functions must follow this signature:

```lua
function function_name(tag, timestamp, record)
    -- Process record
    return code, timestamp, record
end
```

**Return codes:**
- `0`: Keep record unchanged
- `1`: Modified record (keep)
- `-1`: Drop record

### 2. Performance Tips

```lua
-- Bad: Creating new variables in loop
for i = 1, 1000 do
    local temp = process(i)
end

-- Good: Reuse variables
local temp
for i = 1, 1000 do
    temp = process(i)
end
```

### 3. Avoid Global State

```lua
-- Bad: Using global variables
function process(tag, timestamp, record)
    global_counter = global_counter + 1  -- Shared state!
end

-- Good: Use record fields
function process(tag, timestamp, record)
    record["count"] = (record["count"] or 0) + 1
end
```

## Quick Reference

```lua
-- Variables
local var = value

-- Tables
local arr = {1, 2, 3}
local dict = {key = "value"}

-- Conditions
if condition then
    -- code
elseif another_condition then
    -- code
else
    -- code
end

-- Loops
for i = 1, 10 do end
for k, v in pairs(table) do end

-- Functions
function name(params)
    return value
end

-- Strings
str1 .. str2                    -- Concatenate
string.upper(str)               -- Uppercase
string.lower(str)               -- Lowercase
string.sub(str, start, end)     -- Substring
string.format("%s", var)        -- Format

-- Time
os.date("*t", timestamp)        -- Get date table
os.date("%Y-%m-%d", timestamp)  -- Format date
os.time()                       -- Current timestamp
```

## Resources

- Lua Reference Manual: https://www.lua.org/manual/5.1/
- Fluent Bit Lua Filter: https://docs.fluentbit.io/manual/pipeline/filters/lua
- Learn Lua in 15 Minutes: https://tylerneylon.com/a/learn-lua/
