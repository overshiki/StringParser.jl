
len(vs::Vector{T}) where T = length(vs)
len(d::Dict) = length(d)

(++)(xlist::Vector{T}, ylist::Vector{T}) where T = begin 
    clist = T[]
    append!(clist, xlist)
    append!(clist, ylist)
    return clist
end 
concat(alist::Vector{Vector{T}}) where T = foldl(++, alist; init=T[])

unsqueeze(a::Array) = begin 
    nsize = foldl(append!, size(a); init=[1])
    return reshape(a, Tuple(nsize))
end
fullstack(vs::Vector{T}) where T<:Vector = begin
    return reduce(vcat, map(unsqueeze, map(fullstack, vs)))
end
fullstack(vs::Vector{T}) where T<:Real = vs
