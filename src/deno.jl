# Build a specific deno command with the options provided as args
function deno_command(args::Union{Symbol, AbstractString}...)
    BIN = Deno_jll.deno()
    for arg in args
        for piece in split(string(arg), " ")
            push!(BIN.exec, piece)
        end
    end
    return BIN
end

# Run a specific command from directory `dir` and eventually redirecting stdin, stdout and stderr
function _run(cmd::Cmd; dir = pwd(), stdin = nothing, stdout = nothing, stderr = nothing, append = false)
    dir = abspath(dir)
    cd(dir) do
        try
            run(pipeline(cmd; stdin, stdout, stderr, append))
        catch e
            command = join(cmd.exec, " ")
            @error "Error while trying to run a deno command" command
        end
    end
    nothing
end

# This run a deno command from a target directory and providing all the arguments to the `deno` executable call
function _deno(args::Union{Symbol, AbstractString}...; dir = pwd(), stdin = nothing, stdout = nothing, stderr = nothing, append = false)
    _run(deno_command(args...); dir, stdin, stdout, stderr, append)
end