abstract type ArrowFile <: RecorderFile end

Base.string(::Type{ArrowFile}) = "arrow"

"""
    record(recorder::Recorder{ArrowFile}, model::JuMP.Model, id::T)

Record optimization problem solution to an Arrow file.
"""
function record(recorder::Recorder{ArrowFile}, model::JuMP.Model, id::T) where {T<:Integer}
    if !isfile(recorder.filename)
        Arrow.append(
            recorder.filename, (;
                id = T[], 
                zip(recorder.primal_variables, fill(Float64[], length(recorder.primal_variables)))..., 
                zip(Symbol.("dual_" .* string.(recorder.dual_variables)), fill(Float64[], length(recorder.dual_variables)))..., 
            )
        )
    end

    Arrow.append(
        recorder.filename, (;
            id = [id], 
            zip(recorder.primal_variables, [[MOI.get(model, MOI.VariablePrimal(), model[p])] for p in recorder.primal_variables])..., 
            zip(Symbol.("dual_" .* string.(recorder.dual_variables)), [[MOI.get(model, MOI.ConstraintDual(), model[p])] for p in recorder.dual_variables])..., 
        )
    )


end