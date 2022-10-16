include("utils.jl")

rm_strSpace(str::String)::String = begin 
    length(str)==0 && return str
    str[1]==' ' && return rm_strSpace(str[2:end])
    str[end]==' ' && return rm_strSpace(str[1:end-1])
    return str
end

const Maybe{T} = Union{T, Nothing}

abstract type StringParser end
const SuStringParser = Union{Real, String, StringParser}

struct Clause <: StringParser
    left::Char 
    right::Char
    content::Maybe{SuStringParser}
end
Clause(cl::Clause, content::Maybe{SuStringParser}) = Clause(cl.left, cl.right, content)

struct SingleParser <: StringParser
    func::Maybe{Function}
end

string_parse(line::String, parser::SingleParser) = begin 
    parser.func isa Nothing && return line 
    return parser.func(line)
end

struct SepTwo <: StringParser 
    sep::String
    left::Maybe{SuStringParser}
    right::Maybe{SuStringParser}
end
SepTwo(st::SepTwo, left::Maybe{SuStringParser}, right::Maybe{SuStringParser}) = SepTwo(st.sep, left, right)

struct SepMulti <: StringParser
    sep::String 
    content::Maybe{Union{StringParser, Vector{SuStringParser}}}
end
SepMulti(sm::SepMulti, content::Maybe{Union{StringParser, Vector{SuStringParser}}}) = SepMulti(sm.sep, content)


"""Monad bind: M [a] -> ([a] -> b) -> M b"""
mbind(x::Maybe{T}, f::Function) where T = begin
    x isa Nothing && return x 
    return f(x)
end


pass_bind(func::Function, x::Any, f::Maybe) = begin 
    f isa Nothing && return x 
    return func(x, f)
end

string_parse(str::String, parser::Clause) = begin 
    str = rm_strSpace(str)
    @assert str[1]==parser.left 
    @assert str[end]==parser.right
    return Clause(parser, pass_bind(string_parse, str[2:end-1], parser.content))
end


match_seq(str::String, sep::String) = str[1:min(length(sep), length(str))]==sep
find_sep_index(str::String, sep::String, index::Int)::Maybe{Int} = begin 
    length(str)==0 && return nothing
    match_seq(str, sep) && return index 
    return find_sep_index(str[2:end], sep, index+1)
end
find_unique_sep_index(str::String, sep::String)::Int = begin 
    maybe_index = find_sep_index(str, sep, 1)
    @assert mbind(maybe_index, i->find_sep_index(str[i+1:end], sep, 1)) isa Nothing 
    return maybe_index
end

string_parse(str::String, parser::SepTwo) = begin
    length(str)==0 && return str 
    # @show str, parser.sep
    str = rm_strSpace(str)
    index = find_unique_sep_index(str, parser.sep)
    left = str[1:index-1] |> rm_strSpace
    right = str[index+length(parser.sep):end] |> rm_strSpace
    return SepTwo(parser, pass_bind(string_parse, left, parser.left), pass_bind(string_parse, right, parser.right))
end


"""Tolerable chain: M [a] -> M [b] -> ([a] -> [b] -> c) -> M c"""
chain(x::Maybe{T1}, y::Maybe{T2}, f::Function, ::Val{:pass}) where {T1, T2} = begin 
    x isa Nothing && return y 
    y isa Nothing && return x 
    return f(x, y)
end

"""blocking chain: M [a] -> M [b] -> ([a] -> [b] -> c) -> M c"""
chain(x::Maybe{T1}, y::Maybe{T2}, f::Function, ::Val{:block}) where {T1, T2} = begin 
    x isa Nothing && return x
    y isa Nothing && return y
    return f(x, y)
end


"""
(⋄) is the Maybe{Vector} version of (++) operator
Note that we could not use (++) operator name here, since a::Vector ++ b::Vector is already defined, and actually the compiler can not distinguish between Vector and a Maybe{Vector}"""
(⋄)(s1::Maybe{Vector{String}}, s2::Maybe{Vector{String}}) = chain(s1, s2, (++), Val(:pass))
parse_sepmulti(str::String, sep::String)::Maybe = begin
    str = rm_strSpace(str)
    length(str)==0 && return nothing
    maybe_index = find_sep_index(str, sep, 1)
    return mbind(maybe_index, i-> [str[1:i-1]] ⋄ parse_sepmulti(str[i+1:end], sep))
end

string_parse(str::String, parser::SepMulti) = begin 
    str = rm_strSpace(str)
    @assert str[end]!==parser.sep 
    str = str*parser.sep
    content = parse_sepmulti(str, parser.sep)
    map_string_parse(xs::Vector{String}, ys::Vector{SuStringParser}) = map(1:length(xs)) do  i
        x, y = xs[i], ys[i]
        return string_parse(x, y)
    end

    map_string_parse(xs::Vector{String}, ys::StringParser) = map(1:length(xs)) do  i
        x = xs[i]
        return string_parse(x, ys)
    end

    return SepMulti(parser, Vector{SuStringParser}(chain(content, parser.content, map_string_parse, Val(:pass))))
end

