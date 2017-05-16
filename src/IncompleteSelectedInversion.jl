module IncompleteSelectedInversion

#immutable UnsafeArrayWrapper{T,N} <: AbstractArray{T,N}
#    data::Ptr{T}
#    dims::NTuple{N,Int}
#    IsbitsArrayWrapper(a::AbstractArray{T,N})
#end


#=
 Sorted subset of {1,...,n}.
 Used to represent the row indices of a single column in F.
=#
immutable SortedIntSet
    next::Vector{Int} 
    #=
     next[n+1] = first entry in the set
     If i is an element of the set, then next[i] is the 
     smallest j > i in the set, or n+1 if no such j exists.
    =#
    SortedIntSet(n) = new(Vector{Int}(n+1))
end

Base.start(s::SortedIntSet) = length(s.next)
Base.next(s::SortedIntSet,p) = s.next[p],s.next[p]
Base.done(s::SortedIntSet,p) = s.next[p] == length(s.next)

function init!(s::SortedIntSet,i)
    next = s.next
    n = length(next)-1
    next[n+1] = i
    next[i] = n+1
    return s
end

Base.insert!(s::SortedIntSet,i) = insert!(s,i,length(s.next))
function Base.insert!(s::SortedIntSet,i,p)
    next = s.next
    n = length(next)-1

    if !(1 <= i <= n); throw(BoundsError()); end
    if !(p == n+1 || 1 <= p <= i); throw(BoundsError()); end
    @inbounds begin
        while next[p] < i
            p = next[p]
        end
        if next[p] == i
            return false
        end
        next[p],next[i] = i,next[p]
        return true
    end
end




#=
 Iterate a sparse 
=#
function iterate_jkp(Ap,Ai)
    n = length(Ap)-1
    nextp = Vector{Int}(n)
    nextk = Vector{Int}(n)
    fill!(nextk,n+1)
    Iteration_jkp(Ap,Ai,nextp,nextk)
end

immutable Iteration_jkp{Ti}
    Ap::Vector{Ti}
    Ai::Vector{Ti}
    nextp::Vector{Int}
    nextk::Vector{Int}
end
immutable Iteration_kp{Ti}
    jkp::Iteration_jkp{Ti}
    j::Int
end

Base.start(jkp::Iteration_jkp) = 0
function Base.next(jkp::Iteration_jkp,j) 
    Ap = jkp.Ap
    Ai = jkp.Ai
    nextp = jkp.nextp
    nextk = jkp.nextk

    if j > 0
        for p in Ap[j]:Ap[j+1]-1
            i = Ai[p]
            if i > j
                nextp[j] = p
                nextk[i],nextk[j] = j,nextk[i]
                break
            end
        end
    end
    j += 1
    return (j,Iteration_kp(jkp,j)),j
end
Base.done(jkp::Iteration_jkp,j) = j == length(jkp.Ap)-1

Base.start(kp::Iteration_kp) = kp.jkp.nextk[kp.j]
function Base.next(kp::Iteration_kp,k)
    jkp = kp.jkp
    Ap = jkp.Ap
    Ai = jkp.Ai
    nextp = jkp.nextp
    nextk = jkp.nextk

    pp = nextp[k]
    kk = nextk[k]
    nextp[k] += 1
    if nextp[k] < Ap[k+1]
        i = Ai[nextp[k]]
        nextk[i],nextk[k] = k,nextk[i]
    end
    return (k,pp:Ap[k+1]-1),kk
end
Base.done(kp::Iteration_kp,k) = k > kp.j





function symbolic(Ap,Ai,c)
    Ti = eltype(Ap)
    n = length(Ap)-1

    # Return variables
    Fp = Vector{Ti}(n+1); Fp[1] = 1
    Fi = Vector{Ti}(0)
    Fl = Vector{Ti}(0)

    # Workspace for a single column
    Fji = SortedIntSet(n)
    Fjl = Vector{Int}(n)

    # Main algorithm
    for (j,kvals) in iterate_jkp(Fp,Fi)
        # Initialise column
        init!(Fji,j)
        Fjl[j] = 0 
        lasti = j
        for p in Ap[j]:Ap[j+1]-1
            i = Ai[p]
            if i <= j; continue; end
            insert!(Fji,i,lasti)
            Fjl[i] = 0 
            lasti = i
        end

        # Pull in updates
        for (k,pvals) in kvals
            lkj = Fl[first(pvals)]
            if lkj >= c; return; end
            lasti = n+1
            for p in pvals
                i = Fi[p]
                lik = Fl[p]
                Flij = lik + lkj + 1
                if Flij <= c
                    if insert!(Fji,i,lasti)
                        Fjl[i] = Flij
                    else
                        Fjl[i] = min(Fjl[i],Flij)
                    end
                    lasti = i
                end
            end
        end

        # Copy temporary column into F
        for i in Fji
            push!(Fi,i)
            push!(Fl,Fjl[i])
        end
        Fp[j+1] = length(Fi)+1
    end
    return Fp,Fi,Fl
end



end # module
