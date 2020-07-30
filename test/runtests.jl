using Lints
using TensorOperations
using Test
using NPZ
using Serialization

path = joinpath(dirname(pathof(Lints)),"..","test")

Lints.libint2_init()
mol = Lints.Molecule(joinpath(path,"h2o.xyz"))

bas = Lints.BasisSet("6-31G*",mol)
bas_small = Lints.BasisSet("6-31G",mol)

#testing conventional integrals
nprim = Lints.max_nprim(bas)
l = Lints.max_l(bas)
S_engine = Lints.OverlapEngine(nprim,l)
T_engine = Lints.KineticEngine(nprim,l)
V_engine = Lints.NuclearEngine(nprim,l,mol)
eri = [Lints.ERIEngine(nprim,l) for i=1:Threads.nthreads()]

s = Lints.getsize(bas)
sz = Lints.getsize(S_engine,bas)
S = zeros(sz,sz)
T = zeros(sz,sz)
V = zeros(sz,sz)
I = zeros(sz,sz,sz,sz)


Lints.make_2D(S,S_engine,bas)
Lints.make_2D(T,T_engine,bas)
Lints.make_2D(V,V_engine,bas)
Lints.make_ERI(I,eri,bas)

_S = deserialize("S.dat")
_T = deserialize("T.dat")
_V = deserialize("V.dat")
_I = deserialize("I.dat")

__S = npzread("S.npy")
__T = npzread("T.npy")
__V = npzread("V.npy")
__I = npzread("I.npy")

@test isapprox(S,__S; atol=1E-12)
@test isapprox(T,__T; atol=1E-12)
@test isapprox(V,__V; atol=1E-12)
@test isapprox(I,__I; atol=1E-12)

#test that projector is working
P = Lints.projector(bas_small,bas)

#test DF integrals
bas = Lints.BasisSet("CC-PVDZ",mol)
bas_df = Lints.BasisSet("CC-PVDZ-RI",mol)

nprim = Lints.max_nprim(bas)
l = Lints.max_l(bas)

eri = [Lints.ERIEngine(nprim,l) for i=1:Threads.nthreads()]


nprim = max(Lints.max_nprim(bas_df),Lints.max_nprim(bas))
l = max(Lints.max_l(bas_df),Lints.max_l(bas))

df_eri = [Lints.DFEngine(nprim,l) for i=1:Threads.nthreads()]


dfsz = Lints.getsize(S_engine,bas_df)
sz = Lints.getsize(S_engine,bas)
pqP = zeros(dfsz,sz,sz)
J = zeros(dfsz,dfsz)
I = zeros(sz,sz,sz,sz)
Lints.make_b(pqP,df_eri,bas,bas_df)
Lints.make_j(J,df_eri[1],bas_df)
Lints.make_ERI(I,eri,bas)
Jh = J^(-1/2)
b = zeros(dfsz,sz,sz)
eri2 = zeros(sz,sz,sz,sz)
@tensor b[Q,p,q] = pqP[P,p,q]*Jh[P,Q]
@tensor eri2[p,q,r,s] = b[Q,p,q]*b[Q,r,s]
@test maximum(abs.(eri2 - I)) < 0.05


Lints.libint2_finalize()
