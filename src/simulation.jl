# """
#     sample(model::Model, n::Int)

# Draw n samples from a model.
# """
# function StatsBase.sample(model::Model, n::Int)
#     return reduce(vcat, [snap_rep(simulate(model), rep) for rep in 1:n])
# end


"""
    simulate(model::Model)

Run a model once.
"""
function simulate(model::Model, replicates::Int)
    sequences = permutations(collect(combinations(model.parameter_set.parties, 2)))
    sequence_data_list = DataFrame[]
    for (seq_idx, seq) in enumerate(sequences)
        rep_data_list = DataFrame[]
        for rep in 1:replicates
            model_tracker = deepcopy(model)
            step_data = snap(DataFrame(deepcopy(model_tracker.agents)), :step, 0)  # track initial configuration
            for (step, comb) in enumerate(seq)
                meeting = Meeting(model_tracker, comb)
                counter = 0
                for i in 1:10000  # TODO: write convergence criterion
                    negotiators = StatsBase.sample(meeting.participants, 2)
                    if Random.rand() < similarity(negotiators...)
                        assimilate!(negotiators...)
                        counter = 0
                    else
                        counter += 1
                        if counter > 100
                            print("break!")
                            break
                        end
                    end
                end
                next_step_data = DataFrame(deepcopy(model_tracker.agents))
                step_data = reduce(vcat, [step_data, snap(next_step_data, :step, step)])
            end  # endfor seq
            push!(rep_data_list, snap(deepcopy(step_data), :rep, rep))
        end  # endfor replicates
        push!(sequence_data_list, snap(reduce(vcat, rep_data_list), :seq, seq_idx))
    end  # endfor sequences
    data = reduce(vcat, sequence_data_list)
    return collect(sequences), data
end


function snap(data::DataFrame, scope::Symbol, val::Int)
    data[!, scope] .= val
    return data
end

# """
#     snap_rep(data::DataFrame, rep::Int)

# Make a snapshot of the simulation data in replicate rep.
# """
# function snap_rep(data::DataFrame, rep::Int)
#     data[!, :rep] .= rep
#     return data
# end


# """
#     snap_step(data::DataFrame, rep::Int)

# Make a snapshot of the simulation data in step `step`.
# """
# function snap_step(data::DataFrame, step::Int)
#     data[!, :step] .= step
#     return data
# end


"""
    assimilate!(sender::Agent, receiver::Agent)

Change one of the receiver's opinions to sender's opinion.
"""
function assimilate!(sender::Agent, receiver::Agent)
    i = Random.rand(1:length(sender.opinions))
    receiver.opinions[i] = StatsBase.mean([sender.opinions[i], receiver.opinions[i]])
    return receiver
end


"""
    similarity(sender::Agent, receiver::Agent)

Compute the ordinal similarity of two agents.
Argument names are chosen to match assimilate! function.
"""
function similarity(sender::Agent, receiver::Agent)
    absolute_difference = sum(abs.(sender.opinions .- receiver.opinions))
    highest_possible_difference = 2 * length(sender.opinions)
    return 1 - (absolute_difference / highest_possible_difference)
end
