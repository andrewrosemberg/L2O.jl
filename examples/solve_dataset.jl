################################################################
###################### Dataset Generation ######################
################################################################

using Distributed
using Random

##############
# Load Functions
##############

@everywhere l2o_path = dirname(@__DIR__)

@everywhere import Pkg

@everywhere Pkg.activate(l2o_path)

@everywhere Pkg.instantiate()

########## SCRIPT REQUIRED PACKAGES ##########

@everywhere using L2O
@everywhere using UUIDs
@everywhere import ParametricOptInterface as POI
@everywhere using JuMP
@everywhere using UUIDs
@everywhere using Arrow

## SOLVER PACKAGES ##

@everywhere using Gurobi
# @everywhere using Ipopt

@everywhere POI_cached_optimizer() = Gurobi.Optimizer()

@everywhere filetype = ArrowFile


########## PARAMETERS ##########
model_file = joinpath(l2o_path, "examples/powermodels/data/6468_rte/input/6468_rte_SOCWRConicPowerModel_POI_load.mof.json") # ACPPowerModel SOCWRConicPowerModel DCPPowerModel
input_file = joinpath(l2o_path, "examples/powermodels/data/6468_rte/input/6468_rte_POI_load_input_7f284054-d107-11ee-3fe9-09f5e129b1ad")

save_path = joinpath(l2o_path, "examples/powermodels/data/6468_rte/output/SOCWRConicPowerModel")
case_name = split(split(model_file, ".mof.")[1], "/")[end]
processed_output_files = [file for file in readdir(save_path; join=true) if occursin(case_name, file)]
ids = Vector(Arrow.Table(processed_output_files).id)
batch_size = 200

########## SOLVE ##########

problem_iterator_factory, num_batches = load(model_file, input_file, filetype; batch_size=batch_size, ignore_ids=ids)

@sync @distributed for i in 1:num_batches
    batch_id = uuid1()
    problem_iterator = problem_iterator_factory(i)
    set_optimizer(problem_iterator.model, () -> POI_cached_optimizer())
    output_file = joinpath(save_path, "$(case_name)_output_$(batch_id)")
    recorder = Recorder{filetype}(output_file; filterfn= (model) -> true, model=problem_iterator.model)
    successfull_solves = solve_batch(problem_iterator, recorder)
    @info "Solved $(length(successfull_solves)) problems"
    compress_batch_arrow(save_path, case_name; keyword_all="output", batch_id=string(batch_id), keyword_any=[string(batch_id)])
end
