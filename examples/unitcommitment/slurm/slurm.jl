#= Julia code for launching jobs on the slurm cluster.

This code is expected to be run from an sbatch script after a module load julia command has been run.
It starts the remote processes with srun within an allocation.
If you get an error make sure to Pkg.checkout("CluterManagers").

==

# Make sure to compile a julia image before:

1)
julia --project=. -t1 --trace-compile=app/precompile.jl uc_dataset_generation.jl "dash" "dash" "case300" "2017-01-01" 2 0 true

2)
```julia

using PackageCompiler
using REPL; REPL.__init__()
create_sysimage(
    [
        "LinearAlgebra",
        "Gurobi",
        "L2O",
        "JuMP",
        "Logging",
        "JuMP",
        "UnitCommitment",
        "ParametricOptInterface",
        "DataFrames",
        "CSV",
        "UUIDs",
        "Arrow",
        "SparseArrays",
        "Statistics",
    ];
    sysimage_path="app/julia.so",
    precompile_statements_file="app/precompile.jl"
);
```

=#
try

	using Distributed, ClusterManagers
catch
	Pkg.add("ClusterManagers")
	Pkg.checkout("ClusterManagers")
end

using Distributed, ClusterManagers

np = 4 #
addprocs(SlurmManager(np), job_file_loc = ARGS[1], cpus_per_task=24, mem_per_cpu=12)

println("We are all connected and ready.")

include(ARGS[2])

# The Slurm resource allocation is released when all the workers have
# exited
for i in workers()
	rmprocs(i)
end