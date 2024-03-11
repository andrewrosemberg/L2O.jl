
include("./examples/multistage/simulate_multistage.jl")

function fast_hydro_thermal_subproblem()
    sp = JuMP.Model(() -> POI.Optimizer(HiGHS.Optimizer()))
    state_param_out =  @variable(sp, state_param_out in MOI.Parameter(1.0))
    state_param_in = @variable(sp, state_param_in in MOI.Parameter(1.0))
    @variables(sp, begin # recourse variables
        y >= 0
        p >= 0
        def >= 0
    end)
    uncertainty_param = @variable(sp, uncertainty_param in MOI.Parameter(1.0))
    @constraints(sp, begin
        p + y >= 6
        state_param_out <= state_param_in - y + uncertainty_param + def
    end)
    @objective(sp, Min, 5 * p + def * 30)
    return sp, [state_param_in], [state_param_out], [uncertainty_param]
end

function build_fast_hydro_thermal_multistage(; num_stages=2)
    subproblems = Vector{JuMP.Model}(undef, 2)
    state_params_in = Vector{Vector{VariableRef}}(undef, 2)
    state_params_out = Vector{Vector{VariableRef}}(undef, 2)
    uncertainty_samples = Vector{Dict{VariableRef, Vector{Float64}}}(undef, 2)
    
    for t in 1:num_stages
        subproblems[t], state_params_in[t], state_params_out[t], uncertainty_params = fast_hydro_thermal_subproblem()
        uncertainty_samples[t] = Dict(uncertainty_params .=> (t == 1 ? [[6.0]] : [[2.0, 10]]))
    end

    return subproblems, state_params_in, state_params_out, uncertainty_samples
end

function test_simulate_multistage(model = Dense(2, 1); num_samples=10)
    subproblems, state_params_in, state_params_out, uncertainty_samples = build_fast_hydro_thermal_multistage()
    initial_state = [0.0]
    objective_values = Array{Float64}(undef, num_samples)
    for i in 1:num_samples
        uncertainty_sample = sample(uncertainty_samples)
        states = simulate_states(
            initial_state, 
            uncertainty_sample, 
            [model for _ in 1:2]
        )
        objective_values[i] = simulate_multistage(
            subproblems, state_params_in, state_params_out, states, 
            uncertainty_sample
        )
    end
    return objective_values
end

using ChainRulesTestUtils

function test_rrule_simulate_multistage(model = Dense(2, 1))
    subproblems, state_params_in, state_params_out, uncertainty_samples = build_fast_hydro_thermal_multistage()
    initial_state = [0.0]
    test_rrule(simulate_multistage,
        subproblems, state_params_in, state_params_out, initial_state, 
        [model for _ in 1:2], 
        sample(uncertainty_samples)
    )
end
test_rrule_simulate_multistage()

# Test
using Statistics
objective_values = test_simulate_multistage()
mean(objective_values)

train_multistage(Dense(2, 1), [0.0], build_fast_hydro_thermal_multistage()...)