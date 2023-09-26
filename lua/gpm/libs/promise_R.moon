if SERVER
    AddCSLuaFile!

string_format = string.format
tostring = tostring

lib = gpm.Table gpm, "promise", {
    VERSION: "2.0.0",
    PROMISE_PENDING: 0,
    PROMISE_REJECTED: 1,
    PROMISE_FULFILLED: 2
}

PROMISE_PENDING = lib.PROMISE_PENDING
PROMISE_REJECTED = lib.PROMISE_REJECTED
PROMISE_FULFILLED = lib.PROMISE_FULFILLED

STATE_NAMES = {
    [PROMISE_FULFILLED]: "fulfilled",
    [PROMISE_REJECTED]: "rejected",
    [PROMISE_PENDING]: "pending"
}

lib.STATE_NAMES = STATE_NAMES

class Promise
    __tostring: =>
        if @Result == nil
            return string_format( "Promise %p {<%s>}", @, STATE_NAMES[ @State ] )
        return string_format( "Promise %p {<%s>: %s}", @, STATE_NAMES[ @State ], tostring( @Result ) )

    new: =>
        @State = PROMISE_PENDING
        @Queue = {}

    IsPending: =>
        return @State == PROMISE_PENDING

    IsFulfilled: =>
        return @State == PROMISE_FULFILLED

    IsRejected: =>
        return @State == PROMISE_REJECTED

    Process: =>
        if @IsPending!
            return

        if not @Processed and #@Queue == 0
            if @IsRejected!
                ErrorNoHalt( "Unhandled promise error: " .. tostring( @Result ) .. "\n\n" )
            return

        @Processed = true


-- p = Promise!
-- print p


lib.New = Promise

return lib