# CL-FOREST

Unofficial bindings to [Rigetti Forest](http://forest.rigetti.com), a quantum computing service. These bindings are directly based off of the `forest` module of [pyQuil](https://github.com/rigetticomputing/pyquil).

Currently, this library is written for pedagogical example of the API, not for efficiency.

## Examples

Below are a few examples using the Rigetti Forest API.

Here we construct a [Bell pair](https://en.wikipedia.org/wiki/Bell_state), and measure the pair. The interesting property about Bell states is that they always measure to the same value. Here we measure the Bell pair 10 times.

```lisp
CL-FOREST> (run (quil "H 0"
                      "CNOT 0 1"
                      "MEASURE 0 [0]"
                      "MEASURE 1 [1]")
                '(0 1)
                10)

((0 0) (1 1) (1 1) (1 1) (1 1) (0 0) (0 0) (1 1) (0 0) (0 0))
```

Next, we show that a Bell pair is exactly the state `(|00> + |11>)/sqrt(2)` by looking directly at the wavefunction.

```lisp
CL-FOREST> (wavefunction (quil "H 0"
                               "CNOT 0 1"))

#(#C(0.7071067811865475d0 0.0d0) #C(0.0d0 0.0d0) #C(0.0d0 0.0d0)
  #C(0.7071067811865475d0 0.0d0))
```

We can recover the probabilities of each of these by computing the square modulus of each amplitude:

```lisp
CL-USER> (map 'vector (lambda (a) (expt (abs a) 2)) *)

#(0.4999999999999999d0 0.0d0 0.0d0 0.4999999999999999d0)
```

We see immediately that `|00>` and `|11>` both have a 50% chance of being observed.

## API Key

Before starting, you'll need to set your API key by setting the variable `cl-forest:*api-key*`.

```lisp
(setf cl-forest:*api-key* "<< YOUR API KEY >>")
```

You can check that it works by pinging the server:

```lisp
> (cl-forest:ping)
"pong 3696180851"
```

Once your API key is set, you can construct Quil programs (which are currently just represented as strings) conveniently using the `quil` function, and then use `run` or `wavefunction` to run that program.

