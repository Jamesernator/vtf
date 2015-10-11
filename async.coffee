"use strict"
module.exports = async = (gen_func) -> wrapper = (args...) ->
    # This wrapper returns a promise for the async function
    return new Promise (resolve, reject) -> # Create a promise for this event
        gen = gen_func(args...)
        iter = do -> # Create a new iterator which will be resumed whenever
                     # the currently active promise is resolved/rejected
            result = undefined # Start the generator with undefined
            loop
                try
                    # Attempt to get the next value
                    {value, done} = gen.next(result)
                catch err
                    # If an error happens we'll reject with that err
                    reject(err)
                if done
                    # If we're done then we can resolve our promise and exit
                    # with the finish value
                    resolve(value)
                    return # Exit completely

                # Whether the value is a promise or not we'll turn it into one
                # if it already was a promise this returns the same promise
                promise = Promise.resolve(value)
                try
                    # So try yielding and waiting for the promise to complete
                    # resuming here when its done
                    result = yield promise.then(iter.next.bind(iter))
                    .catch (err) ->
                        if err.constructor isnt Error
                            iter.throw(new Error(err))
                        else
                            iter.throw(err)

                    # If all went well the value of result will be passed
                    # back into the generator
                catch err
                    # If something bad happened we'll throw it to the generator
                    # to handle
                    try
                        # If this throws an error then error wasn't handled
                        # in our generator
                        gen.throw(err)
                    catch total_failure
                        # So we'll reject and call the entire async function
                        # as failed
                        reject(total_failure)
        iter.next() # Start our iterator

module.exports.main = (func) ->
    ### This is for calling a main function
        and displaying any error on failure
    ###
    do async ->
        try
            yield async(func)()
        catch err
            console.log err
