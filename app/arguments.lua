-- Function to display an error message and exit
local function errorAndExit(message)
    print("Error: " .. message)
    os.exit(1)
end

-- Function to parse arguments
function parseArgs(args)
    -- Table to store options
    local options = {}

    local i = 1
    while i <= #args do
        if args[i] == "--output" then
            i = i + 1
            if i > #args then errorAndExit("Missing value for --output") end
            options.output = tostring(args[i])
        elseif args[i] == "--width" then
            i = i + 1
            if i > #args then errorAndExit("Missing value for --width") end
            options.width = tonumber(args[i])
            if not options.width or options.width % 1 ~= 0 then
                errorAndExit("Invalid value for --width, must be an integer")
            end
        elseif args[i] == "--height" then
            i = i + 1
            if i > #args then errorAndExit("Missing value for --height") end
            options.height = tonumber(args[i])
            if not options.height or options.height % 1 ~= 0 then
                errorAndExit("Invalid value for --height, must be an integer")
            end
        else
            errorAndExit("Unrecognized argument: " .. args[i])
        end
        i = i + 1
    end

    return options
end