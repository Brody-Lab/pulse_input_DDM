"""
"""
function pack(x::Vector{TT}) where {TT <: Real}

    σ2_i, B, λ, σ2_a, σ2_s, ϕ, τ_ϕ, bias, lapse = x
    θ = θchoice(θz(σ2_i, B, λ, σ2_a, σ2_s, ϕ, τ_ϕ), bias,lapse)

end


"""
    unpack(θ)

Extract parameters related to the choice model from a struct and returns an ordered vector
```
"""
function unpack(θ::θchoice)

    @unpack θz, bias, lapse = θ
    @unpack σ2_i, B, λ, σ2_a, σ2_s, ϕ, τ_ϕ = θz
    x = collect((σ2_i, B, λ, σ2_a, σ2_s, ϕ, τ_ϕ, bias, lapse))

    return x

end


"""
    optimize_model(data; options=opt(), n=53, x_tol=1e-10, f_tol=1e-6, g_tol=1e-3,
        iterations=Int(2e3), show_trace=true)

Optimize model parameters. data is a struct that contains the binned clicks and the choices.
options is a struct that containts the initial values, boundaries,
and specification of which parameters to fit.

BACK IN THE DAY TOLS WERE: x_tol::Float64=1e-4, f_tol::Float64=1e-9, g_tol::Float64=1e-2

"""
function optimize(data::choicedata; options::opt=opt(), n::Int=53,
        x_tol::Float64=1e-10, f_tol::Float64=1e-6, g_tol::Float64=1e-3,
        iterations::Int=Int(2e3), show_trace::Bool=true, outer_iterations::Int=Int(1e1))

    @unpack fit, lb, ub, x0 = options

    lb, = unstack(lb, fit)
    ub, = unstack(ub, fit)
    x0,c = unstack(x0, fit)
    ℓℓ(x) = -loglikelihood(stack(x,c,fit), data; n=n)

    output = optimize(x0, ℓℓ, lb, ub; g_tol=g_tol, x_tol=x_tol,
        f_tol=f_tol, iterations=iterations, show_trace=show_trace)

    x = Optim.minimizer(output)
    x = stack(x,c,fit)
    θ = pack(x)
    model = choiceDDM(θ, data)
    converged = Optim.converged(output)

    println("optimization complete. converged: $converged \n")

    return model, options

end


"""
    loglikelihood(x, data; n=53)

A wrapper function that accepts a vector of mixed parameters, splits the vector
into two vectors based on the parameter mapping function provided as an input. Used
in optimization, Hessian and gradient computation.
"""
function loglikelihood(x::Vector{TT}, data; n::Int=53) where {TT <: Real}

    θ = pack(x)
    loglikelihood(θ, data; n=n)

end



"""
    loglikelihood(choiceDDM; n=53)

Computes the log likelihood for a set of trials consistent with the animal's choice on each trial.
```
"""
function loglikelihood(model::choiceDDM; n::Int=53)

    @unpack θ, data = model
    loglikelihood(θ, data; n=n)

end


"""
    gradient(model; options, n=53)
"""
function gradient(model::choiceDDM; n::Int=53)

    @unpack θ, data = model
    x = unpack(θ)
    ℓℓ(x) = -loglikelihood(x, data; n=n)

    ForwardDiff.gradient(ℓℓ, x)

end


"""
    Hessian(model; options, n=53)
"""
function Hessian(model::choiceDDM; n::Int=53)

    @unpack θ, data = model
    x = unpack(θ)
    ℓℓ(x) = -loglikelihood(x, data; n=n)

    ForwardDiff.hessian(ℓℓ, x)

end


"""
    CIs(H)
"""
function CIs(model::choiceDDM, H::Array{Float64,2})

    @unpack θ = model
    HPSD = Matrix(cholesky(Positive, H, Val{false}))

    if !isapprox(HPSD,H)
        @warn "Hessian is not positive definite. Approximated by closest PSD matrix."
    end

    CI = 2*sqrt.(diag(inv(HPSD)))

end


#=
"""
    LL_across_range(pz, pd, data)

"""
function LL_across_range(pz::Dict, pd::Dict, data::Dict, lb, ub; n::Int=53, state::String="final")

    fit_vec = combine_latent_and_observation(pz["fit"], pd["fit"])

    lb_vec = combine_latent_and_observation(lb[1], lb[2])
    ub_vec = combine_latent_and_observation(ub[1], ub[2])

    LLs = Vector{Vector{Float64}}(undef,length(fit_vec))
    xs = Vector{Vector{Float64}}(undef,length(fit_vec))

    ll_θ = compute_LL(pz[state], pd[state], data; n=n)

    for i = 1:length(fit_vec)

        println(i)

        fit_vec2 = falses(length(fit_vec))
        fit_vec2[i] = true

        p_opt, p_const = split_variable_and_const(combine_latent_and_observation(pz[state], pd[state]), fit_vec2)

        parameter_map_f(x) = split_latent_and_observation(combine_variable_and_const(x, p_const, fit_vec2))
        ll(x) = compute_LL([x], data, parameter_map_f) - (ll_θ - 1.92)

        xs[i] = range(lb_vec[i], stop=ub_vec[i], length=50)
        LLs[i] = map(x->ll(x), xs[i])

    end

    return LLs, xs

end

=#