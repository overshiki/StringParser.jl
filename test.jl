include("src/parser.jl")

test() = begin 
    content = open("example.txt", "r") do io 
        read(io, String)
    end
    content = map(String, split(content, "\n"))
    @show content[1]

    parser = SepMulti(" ", nothing)
    p = string_parse(content[1], parser)
    @show p.content
end

test()