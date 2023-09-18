abstract type FileType end

mutable struct RecorderFile{T<:FileType}
    filename::String
end

filename(recorder_file::RecorderFile) = recorder_file.filename

"""
    Recorder(filename; primal_variables=[], dual_variables=[], filterfn=(model)-> termination_status(model) == MOI.OPTIMAL)

Recorder of optimization problem solutions.
"""
mutable struct Recorder{T<:FileType}
    recorder_file::RecorderFile{T}
    recorder_file_input::RecorderFile{T}
    primal_variables::Vector{VariableRef}
    dual_variables::Vector{ConstraintRef}
    filterfn::Function

    function Recorder{T}(
        filename::String;
        filename_input::String=filename * "_input_",
        primal_variables=[],
        dual_variables=[],
        filterfn=(model) -> termination_status(model) == MOI.OPTIMAL,
    ) where {T<:FileType}
        return new{T}(RecorderFile{T}(filename), RecorderFile{T}(filename_input), primal_variables, dual_variables, filterfn)
    end
end

filename(recorder::Recorder) = filename(recorder.recorder_file)

filename_input(recorder::Recorder) = filename(recorder.recorder_file_input)

function set_primal_variable!(recorder::Recorder, p::Vector{VariableRef})
    recorder.primal_variables = p
end

function set_dual_variable!(recorder::Recorder, p::Vector)
    recorder.dual_variables = p
end

abstract type AbstractProblemIterator end

"""
    ProblemIterator(ids::Vector{UUID}, pairs::Dict{VariableRef, Vector{Real}})

Iterator for optimization problem instances.
"""
struct ProblemIterator{T<:Real} <: AbstractProblemIterator
    model::JuMP.Model
    ids::Vector{UUID}
    pairs::Dict{VariableRef,Vector{T}}
    function ProblemIterator(
        ids::Vector{UUID}, pairs::Dict{VariableRef,Vector{T}}
    ) where {T<:Real}
        model = JuMP.owner_model(first(keys(pairs)))
        for (p, val) in pairs
            @assert length(ids) == length(val)
        end
        return new{T}(model, ids, pairs)
    end
end

function ProblemIterator(pairs::Dict{VariableRef,Vector{T}}) where {T<:Real}
    ids = [uuid1() for _ in 1:length(first(values(pairs)))]
    return ProblemIterator(ids, pairs)
end

"""
    save(problem_iterator::ProblemIterator, filename::String, file_type::Type{T})

Save optimization problem instances to a file.
"""
function save(
    problem_iterator::ProblemIterator, filename::String, file_type::Type{T}
) where {T<:FileType}
    return save(
        (;
            id=problem_iterator.ids,
            zip(
                Symbol.(name.(keys(problem_iterator.pairs))), values(problem_iterator.pairs)
            )...,
        ),
        filename,
        file_type,
    )
end

"""
    update_model!(model::JuMP.Model, p::VariableRef, val::Real)

Update the value of a parameter in a JuMP model.
"""
function update_model!(model::JuMP.Model, p::VariableRef, val)
    return MOI.set(model, POI.ParameterValue(), p, val)
end

"""
    update_model!(model::JuMP.Model, pairs::Dict, idx::Integer)

Update the values of parameters in a JuMP model.
"""
function update_model!(model::JuMP.Model, pairs::Dict, idx::Integer)
    for (p, val) in pairs
        update_model!(model, p, val[idx])
    end
end

"""
    solve_and_record(problem_iterator::ProblemIterator, recorder::Recorder, idx::Integer)

Solve an optimization problem and record the solution.
"""
function solve_and_record(
    problem_iterator::ProblemIterator, recorder::Recorder, idx::Integer
)
    model = problem_iterator.model
    update_model!(model, problem_iterator.pairs, idx)
    optimize!(model)
    if recorder.filterfn(model)
        record(recorder, problem_iterator.ids[idx])
        return 1
    end
    return 0
end

"""
    solve_batch(problem_iterator::AbstractProblemIterator, recorder)

Solve a batch of optimization problems and record the solutions.
"""
function solve_batch(
    problem_iterator::AbstractProblemIterator, recorder
)
    successfull_solves =
        sum(
            solve_and_record(problem_iterator, recorder, idx) for
            idx in 1:length(problem_iterator.ids)
        ) / length(problem_iterator.ids)

    @info "Recorded $(successfull_solves * 100) % of $(length(problem_iterator.ids)) problems"
    return successfull_solves
end
