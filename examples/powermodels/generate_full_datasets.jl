using TestEnv
TestEnv.activate()

using Arrow
using Flux
using HiGHS
using JuMP
using L2O
import ParametricOptInterface as POI
using Test
using UUIDs

# Paths
path_powermodels = joinpath(pwd(), "examples", "powermodels")
path = joinpath(path_powermodels, "data")
include(joinpath(path_powermodels, "pglib_datagen.jl"))

# Parameters
num_batches = 2
num_p = 10
filetype = ArrowFile

# Case name
case_name = "pglib_opf_case5_pjm"
case_file_path = joinpath(path, case_name)

# Create directory if it does not exist
if !isdir(case_file_path)
    mkdir(case_file_path)
end

# Generate dataset
batch_ids = Array{String}(undef, num_batches)
success_solves = 0.0
for i in 1:num_batches
    _success_solves, number_variables, number_loads, batch_id = generate_dataset_pglib(case_file_path, case_name; num_p=num_p, filetype=filetype)
    success_solves += _success_solves
    batch_ids[i] = batch_id
end
success_solves /= num_batches

# Load input and output data tables
file_ins = [joinpath(case_file_path, case_name * "_input_" * batch_id * "." * string(filetype)) for batch_id in batch_ids]
file_outs = [joinpath(case_file_path, case_name * "_output_" * batch_id * "." * string(filetype)) for batch_id in batch_ids]

input_table = Arrow.Table(file_ins)
output_table = Arrow.Table(file_outs)
