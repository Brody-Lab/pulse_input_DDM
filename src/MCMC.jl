"""
"""
struct DDMProblem
    data::Dict{Any,Any}
end


"""
"""
struct neuralDDMProblem
    data::Array{Dict{Any,Any},1}
end


"""
"""
function (problem::DDMProblem)(θ)
    pz, pd = θ
    @unpack data = problem
    compute_LL(collect(pz), collect(pd), data)
end


"""
"""
function (problem::neuralDDMProblem)(θ,f_str)
    pz, py = θ
    @unpack data = problem
    compute_LL(collect(pz), collect(py), data, f_str)
end


"""
"""
function problem_transformation(problem::DDMProblem)

    tz = as((as(Real, 0., 2.), as(Real, 8., 30.),
            as(Real, -5, 5), as(Real, 0., 100.), as(Real, 0., 2.5),
            as(Real, 0.01, 1.2), as(Real, 0.005, 1.)))

    td = as((as(Real, -30., 30.), as(Real, 0., 1.)))

    as((tz,td))
end


"""
"""
struct latent{T1,T2,T3,T4,T5,T6,T7}
    σ2_i::T1
    B::T2
    λ::T3
    σ2_a::T4
    σ2_s::T5
    ϕ::T6
    τ_ϕ::T7
end


"""
"""
struct choice{T1,T2}
    bias::T1
    lapse::T2
end


"""
"""
struct inputs
    L::Vector{Float64}
    R::Vector{Float64}
    T::Float64
    nT::Int
    nL::Vector{Int}
    nR::Vector{Int}
    dt
end


"""
"""
struct choiceDDM <: ContinuousUnivariateDistribution
    pz
    pd
    inputs
end


"""
    rand()

My function!
"""
function rand(dist::choiceDDM; dtMC::Float64=1e-4, rng::Int = 1, use_bin_center::Bool=false)

    @unpack pz, pd, inputs = dist
    @unpack σ2_i, B, λ, σ2_a, σ2_s, ϕ, τ_ϕ = pz
    @unpack bias, lapse = pd
    @unpack L, R, T = inputs
    binned = bin_clicks(T,L,R; dt=dtMC)
    pz = vcat(σ2_i, B, λ, σ2_a, σ2_s, ϕ, τ_ϕ)
    pd = vcat(bias, lapse)

    sample_choice_single_trial(L, R, binned..., pz, pd; use_bin_center=use_bin_center, dtMC=dtMC, rng=rng)

end

#for pmap over same stimulus
#rand(dist::choiceDDM, N::Int) = [rand(dist) for i in 1:N]


#=
"""
"""
function rand(dist::choiceDDM; dtMC::Float64=1e-4, rng::Int = 1, use_bin_center::Bool=false)

    Random.seed!(rng)
    pmap((L,R,T,rng) -> rand(dist,L,R,T; dtMC=dtMC, use_bin_center=use_bin_center, rng=rng),
        L,R,T,shuffle(1:length(T)))

end
=#


"""
"""
function logpdf(d::TT, choice::Bool; n::Int=53) where {TT<:choiceDDM}

    @unpack pz, pd, inputs = d
    @unpack σ2_i, B, λ, σ2_a, σ2_s, ϕ, τ_ϕ = pz
    @unpack bias, lapse = pd
    @unpack L, R, T, nT, nL, nR, dt = inputs

    P,M,xc,dx = initialize_latent_model(σ2_i, B, λ, σ2_a, n, dt, L_lapse=lapse/2, R_lapse=lapse/2)

    LL_single_trial!(λ, σ2_a, σ2_s, ϕ, τ_ϕ, P, M, dx, xc, L, R, nT, nL, nR, choice, bias, n, dt)

end