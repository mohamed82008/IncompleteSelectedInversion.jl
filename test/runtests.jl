using IncompleteSelectedInversion
using Base.Test

T = IncompleteSelectedInversion

@testset "errors" begin
    Ap = [1,2]
    Ai = [2]
    @test_throws Exception T.checkmat(Ap,Ai)

    Ap = [1,3]
    Ai = [1]
    @test_throws Exception T.checkmat(Ap,Ai)

    Ap = [1,3]
    Ai = [1,2]
    Av = [1]
    @test_throws Exception T.checkmat(Ap,Ai,Av)
end

@testset "iterate_jkp" begin
    srand(42)
    for i = 1:100
        n = rand(1:100)
        fill = rand(1:20)
        A = I + sprand(n,n,min(1.,fill/n))
        Ap,Ai = A.colptr,A.rowval

        jvals = Int[]
        iter = T.iterate_jkp(Ap,Ai)
        for (j,kpvals) in iter
            push!(jvals,j)
            kvals = Int[]
            for (k,pvals) in kpvals
                push!(kvals,k)
                ivals = Int[]
                for p in pvals
                    push!(ivals,Ai[p])
                end
                @test ivals == j-1+find(A[j:end,k])
            end
            @test sort(kvals) == find(A[j,1:j-1])
        end
        @test sort(jvals) == collect(1:n)
    end
end

@testset "symbolic_ldlt" begin
    srand(42)
    for i = 1:100
        n = rand(1:100)
        fill = rand(1:20)
        A = I + sprand(n,n,min(1.,0.5*fill/n)); A += A'

        Ap,Ai,Av = unpacksparse(A)
        Fp,Fi = symbolic_ldlt(Ap,Ai)
        F = packsparse(Fp,Fi,ones(Bool,length(Fi)))
        F̂ = tril(lufact(full(A),Val{false}).factors .!= 0)
        @test (F == F̂) == true
    end
end

@testset "symbolic_cldlt" begin
    srand(42)
    for i = 1:100
        n = rand(1:100)
        fill = rand(1:20)
        A = I + sprand(n,n,min(1.,0.5*fill/n)); A += A'

        Ap,Ai,Av = unpacksparse(A)
        Fp,Fi = symbolic_cldlt(Ap,Ai,n)
        F = packsparse(Fp,Fi,ones(Bool,length(Fi)))
        F̂ = tril(lufact(full(A),Val{false}).factors .!= 0)
        @test (F == F̂) == true
    end
end

@testset "numeric" begin
    srand(42)
    for T in (Float32,Float64,Complex64,Complex128)
        for (cconj,ctransp) in ((conj,ctranspose),(identity,transpose))
            for i = 1:25
                n = rand(1:100)
                fill = rand(1:20)
                A = 4I + sprand(T,n,n,min(1.,0.5*fill/n)); A += ctransp(A)

                Ap,Ai,Av = unpacksparse(A)
                Fp,Fi = symbolic_ldlt(Ap,Ai)
                Fv = numeric_ldlt(Ap,Ai,Av,Fp,Fi; conj = cconj)
                F = packsparse(Fp,Fi,Fv)
                L = tril(F,-1) + I; D = Diagonal(F);
                @test L*D*ctransp(L) ≈ A
            end
        end
    end
end

@testset "τldlt" begin
    srand(42)
    for T in (Float32,Float64,Complex64,Complex128)
        for (cconj,ctransp) in ((conj,ctranspose),(identity,transpose))
            for i = 1:25
                n = rand(1:100)
                fill = rand(1:20)
                A = 4I + sprand(T,n,n,min(1.,0.5*fill/n)); A += ctransp(A)

                Ap,Ai,Av = unpacksparse(A)
                Fp,Fi,Fv = τldlt(Ap,Ai,Av, 0.0; conj = cconj)
                F = packsparse(Fp,Fi,Fv)
                L = tril(F,-1) + I; D = Diagonal(F);
                @test L*D*ctransp(L) ≈ A
            end
        end
    end
end

@testset "selinv" begin
    srand(42)
    for T in (Float32,Float64,Complex64,Complex128)
        for (cconj,ctransp) in ((conj,ctranspose),(identity,transpose))
            for i = 1:25
                n = rand(1:100)
                fill = rand(1:20)
                A = 4I + sprand(T,n,n,min(1.,0.5*fill/n)); A += ctransp(A)
                Ap,Ai,Av = A.colptr,A.rowval,A.nzval

                Fp,Fi,Fv = ldlt(Ap,Ai,Av; conj=cconj)
                Bv = selinv(Fp,Fi,Fv; conj=cconj)
                B = packsparse(Fp,Fi,Bv)
                B̂ = inv(full(A))
                @test vecnorm((Bi == 0 ? zero(T) : Bi - B̂i for (Bi,B̂i) in zip(B,B̂)),Inf)/vecnorm(B̂,Inf) < sqrt(eps(real(T)))
            end
        end
    end
end

