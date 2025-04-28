# Build a specific deno command with the options provided as args
function deno_command(args::Union{Symbol, AbstractString}...)
    BIN = Deno_jll.deno()
    first_arg = true
    for arg in args
        for piece in split(string(arg), " ")
            if first_arg
                first_arg = false
                # Eventually skip the `deno` if provided as first argument. Useful for directly pasting deno commands
                piece == "deno" && continue
            end
            push!(BIN.exec, piece)
        end
    end
    return BIN
end

# Run a specific command from directory `dir` and eventually redirecting stdin, stdout and stderr
function _run(cmd::Cmd; dir = pwd(), stdin = nothing, stdout = nothing, stderr = nothing, append = false, rethrow_errors = false)
    dir = abspath(dir)
    stderr_wrapped, io = stderr === devnull ? (true, IOBuffer()) : (false, stderr)
    cd(dir) do
        try
            run(pipeline(cmd; stdin, stdout, stderr = io, append))
        catch e
            command = join(cmd.exec, " ")
            if stderr_wrapped
                deno_error = String(take!(io)) |> Text
                @error "Error while trying to run the following deno command" command deno_error
            else
                @error "Error while trying to run the following deno command" command
            end
            rethrow_errors && rethrow(e)
        end
    end
    nothing
end

# This run a deno command from a target directory and providing all the arguments to the `deno` executable call
function _deno(args::Union{Symbol, AbstractString}...; dir = pwd(), stdin = nothing, stdout = nothing, stderr = nothing, append = false, rethrow_errors = false)
    _run(deno_command(args...); dir, stdin, stdout, stderr, append, rethrow_errors)
end