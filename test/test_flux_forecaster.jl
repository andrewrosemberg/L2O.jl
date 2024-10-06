"""
    test_flux_forecaster(file_in::AbstractString, file_out::AbstractString)

Test the Flux.jl forecaster using MLJ and MLJFlux to train the neural network.
"""
function test_flux_forecaster(file_in::AbstractString, file_out::AbstractString)
    @testset "Flux.jl & MLJ.jl" begin
        @test sprint(show, FullyConnected(1, [1], 1)) == "FullyConnected(\n     Layers: PairwiseFusion(vcat, Dense(1 => 1, relu), Dense(2 => 1)),\n     Pass-Through: Dense{typeof(identity), Matrix{Float32}, Vector{Float32}}[Dense(1 => 1)]\n)\n"

        # read input and output data
        input_data = CSV.read(file_in, DataFrame)
        output_data = CSV.read(file_out, DataFrame)

        # Separate input and output variables
        output_variables = output_data[!, Not([:id, :status, :primal_status, :dual_status])]
        input_features = innerjoin(input_data, output_data[!, [:id]]; on=:id)[!, Not(:id)] # just use success solves

        # Define model
        model = MultitargetNeuralNetworkRegressor(;
            builder=FullyConnectedBuilder([64, 32]),
            rng=123,
            epochs=20,
            optimiser=ConvexRule(
                Optimisers.Adam()
            ),
        )

        # Define the machine
        mach = machine(model, input_features, output_variables)
        fit!(mach; verbosity=2)

        # Make predictions
        predictions = predict(mach, input_features)
        @test predictions isa Tables.MatrixTable

        # Delete the files
        rm(file_in)
        rm(file_out)
    end
end

# Test the Flux.jl forecaster outside MLJ.jl
function test_fully_connected(;num_samples::Int=100, num_features::Int=10)
    X = rand(num_features, num_samples)
    y = rand(1, num_samples)

    model = FullyConnected(10, [10, 10], 1)

    # Train the model
    optimizer = Optimisers.Adam()
    opt_state = Optimisers.setup(optimizer, model)
    L2O.train!(model, Flux.mse, opt_state, X, y)

    # Make predictions
    predictions = model(X)
    @test predictions isa Array
end
