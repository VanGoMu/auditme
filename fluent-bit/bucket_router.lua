-- bucket_router.lua
-- Add monthly bucket information to records for InfluxDB routing

function add_monthly_bucket(tag, timestamp, record)
    -- Get current date from timestamp
    local date = os.date("*t", timestamp)
    
    -- Create month bucket tag in format: YYYY_MM (e.g., 2025_11)
    local month_bucket = string.format("%04d_%02d", date.year, date.month)
    record["month_bucket"] = month_bucket
    
    -- Get message and priority
    local message = tostring(record["message"] or "")
    local priority = tonumber(record["priority"]) or 7
    
    -- Extract service prefix from message (before first colon)
    local service_prefix = message:match("^([^:]+):")
    if service_prefix then
        record["message_service"] = service_prefix:gsub("^%s+", ""):gsub("%s+$", "")  -- trim spaces
    end
    
    -- Extract X11 log level indicators
    local x11_level = message:match("^%((%w+)%)")  -- Matches (II), (WW), (EE), etc.
    if x11_level then
        record["x11_level"] = x11_level
    end
    
    -- Categorize by event type (lowercase for pattern matching)
    local msg_lower = string.lower(message)
    
    -- Specific service patterns first (most specific patterns at top)
    -- Security-related events (check first as they're high priority)
    if msg_lower:match("password") 
        or msg_lower:match("authentication") 
        or msg_lower:match("sudo") 
        or msg_lower:match("su:")
        or msg_lower:match("login") 
        or msg_lower:match("pam_")
        or msg_lower:match("unauthorized")
        or msg_lower:match("permission denied")
        or msg_lower:match("access denied")
        or msg_lower:match("failed.*attempt")
        or msg_lower:match("security")
        or msg_lower:match("auth")
        or msg_lower:match("ssh")
        or msg_lower:match("session opened")
        or msg_lower:match("session closed") then
        record["category"] = "security"
    elseif msg_lower:match("iptables") or msg_lower:match("firewall") or msg_lower:match("nftables") then
        record["category"] = "firewall"
    elseif msg_lower:match("xinput") or msg_lower:match("xorg") or msg_lower:match("x11") or message:match("^%(") then
        record["category"] = "display"
    elseif msg_lower:match("mouse") or msg_lower:match("keyboard") or msg_lower:match("input device") then
        record["category"] = "input_device"
    elseif msg_lower:match("usb") or msg_lower:match("device") and msg_lower:match("id %d") then
        record["category"] = "hardware"
    elseif msg_lower:match("cpu") or msg_lower:match("processor") or msg_lower:match("core") then
        record["category"] = "cpu"
    elseif msg_lower:match("memory") or msg_lower:match("oom") or msg_lower:match("ram") or msg_lower:match("swap") then
        record["category"] = "memory"
    elseif msg_lower:match("disk") or msg_lower:match("filesystem") or msg_lower:match("mount") or msg_lower:match("storage") then
        record["category"] = "disk"
    elseif msg_lower:match("network") or msg_lower:match("eth") or msg_lower:match("link") or msg_lower:match("interface") then
        record["category"] = "network"
    elseif msg_lower:match("systemd") or msg_lower:match("service") or msg_lower:match("unit") then
        record["category"] = "service"
    elseif msg_lower:match("kernel") or msg_lower:match("driver") then
        record["category"] = "kernel"
    else
        record["category"] = "general"
    end
    
    -- Add severity level as text (easier for queries and visualization)
    local severity_map = {
        [0] = "emergency",
        [1] = "alert",
        [2] = "critical",
        [3] = "error",
        [4] = "warning",
        [5] = "notice",
        [6] = "info",
        [7] = "debug"
    }
    record["severity"] = severity_map[priority] or "unknown"
    
    -- Add boolean flags for efficient counting (1 or 0)
    record["is_critical"] = (priority >= 0 and priority <= 2) and 1 or 0
    record["is_error"] = (priority == 3) and 1 or 0
    record["is_warning"] = (priority == 4) and 1 or 0
    record["is_info"] = (priority >= 5 and priority <= 7) and 1 or 0
    
    -- Return: code 1 (modified), timestamp, record
    return 1, timestamp, record
end
