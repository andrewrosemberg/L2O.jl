using Downloads
using PowerModels
using JuMP, HiGHS
import ParametricOptInterface as POI

"""create ref for anonimous variables on model"""
function createvarrefs!(sp::JuMP.Model, pm::AbstractPowerModel)
    for listvarref in values(PowerModels.var(pm))
        for variableref in values(listvarref)
            if typeof(variableref) == JuMP.VariableRef
                sp[Symbol(name(variableref))] = variableref
            end
        end
    end
end

function generate_dataset_pglib(data_dir::String, case_name::String; download_files::Bool=true, filetype::Type{RecorderFile})
    case_file_path = joinpath(data_dir, case_name)
    if download_files && !isfile(case_file_path)
        Downloads.download(
            "https://raw.githubusercontent.com/power-grid-lib/pglib-opf/01681386d084d8bd03b429abcd1ee6966f68b9a3/" *
            case_name,
            case_file_path,
        )
    end

    # Read data
    network_data = PowerModels.parse_file(case_file_path)

    # The problem to iterate over
    model = Model(() -> POI.Optimizer(HiGHS.Optimizer()))

    # Link POI
    network_data["load"]["1"]["pd"] = p = @variable(model, _p in POI.Parameter(1.0))
    pm = instantiate_model(
        network_data,
        DCPPowerModel,
        PowerModels.build_opf;
        setting=Dict("output" => Dict("duals" => true)),
        jump_model=model,
    )

    num_p = 10
    problem_iterator = ProblemIterator(collect(1:num_p), Dict(p => collect(1.0:num_p)))

    createvarrefs!(model, pm)

    file = joinpath(data_dir, "test.$(string(filetype))")
    recorder = Recorder{filetype}(file, primal_variables=[Symbol("0_pg[$i]") for i in 1:5])
    return solve_batch(model, problem_iterator, recorder)
end

data_dir = joinpath(dirname(@__FILE__), "data")

case_name = "pglib_opf_case5_pjm.m"

success_solves = generate_dataset_pglib(data_dir, case_name; download_files=true, filetype=CSVFile)