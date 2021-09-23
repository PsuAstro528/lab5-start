### A Pluto.jl notebook ###
# v0.16.0

using Markdown
using InteractiveUtils

# ╔═╡ 0cac30f1-9101-4ba3-accc-52621bc1d16f
begin
	using PlutoUI, PlutoTest, PlutoTeachingTools

	using BenchmarkTools
	using JETTest
	using UnPack
	using Profile,ProfileSVG, FlameGraphs, Plots
	using LazyArrays
	using Random
	Random.seed!(123)
	eval(Meta.parse(code_for_check_type_funcs))
end;

# ╔═╡ f37ba7bb-0484-4a53-bc8b-94b06d685ac0
md"""
# Astro 528, Lab 5, Exercise 2
# Type Stability & Code Inspection
"""

# ╔═╡ 9e04db5d-0662-4a39-af3b-85e68f948ebc
md"""
In this exercise, we'll get a tour of Julia's profiling and code inspection capabilities.  Then, we'll compare many implementations of one simple function, `calc_χ²` that computes the χ² for a simulated dataset of stellar radial velocities when using a Keplerian orbital model.  We'll use these tool to recognize opportunities for improving it's efficiency.

As before, the code is in `src/calc_rv.jl` (which includes `src/kepler_eqn.jl`), so we'll need to load that into Pluto.
"""

# ╔═╡ 0835d14d-f0c3-4467-bdd6-056b52a2fe09
begin
	KeplerEqn = ingredients("./src/calc_rv.jl")
    import .KeplerEqn: calc_ecc_anom, calc_rv_keplerian
end;

# ╔═╡ 4b21be10-87ef-4926-b946-ef0f3fc0dce2
md"""
## Generate simulated data
First, we'll set the true model parameters and generate simulated observations.
"""

# ╔═╡ 104828fd-61d1-48af-879c-719b95cc1074
begin
	P = 100.0
	K = 10.0
	ecc = rand()
	ω = 2π*rand()
	M0 = 2π*rand()
	param_true = [P,K,ecc,ω,M0]
end;

# ╔═╡ 950621c4-b1e2-4481-bdae-c434fc0bfb7d
num_obs = 100

# ╔═╡ e36ebf1c-a750-40b4-8815-8bb3dee3910f
begin
	times = 365*10*rand(num_obs)
	rvs_true = calc_rv_keplerian.(times,P,K,ecc,ω,M0)
	σ_rvs = 2*ones(num_obs)
	rvs_obs = rvs_true .+ σ_rvs .* randn(num_obs)
end;

# ╔═╡ 23fc85fb-8384-43cb-9bc1-f8c14b08699b
md"## Naive implementation of `calc_χ²`"

# ╔═╡ bcdf14f8-a414-4314-9524-4ce071d41e22
md"""
Here, we'll write a quick and dirty function of the model parameters that calculates and returns χ².
"""

# ╔═╡ e3186d2e-be3e-4beb-a7b6-fbd3e0b01e0c
function calc_χ²_v0(P,K,e,ω,M0)
	# WARNING: Using global variables: times, rvs_obs, σ_rvs
	@assert length(times) == length(rvs_obs) == length(σ_rvs)
	rvs_pred = calc_rv_keplerian.(times,P,K,e,ω,M0)
	Δrv = rvs_pred.-rvs_obs
	χ² = sum(((rvs_pred.-rvs_obs)./σ_rvs).^2)
end

# ╔═╡ 10d7fdda-0a11-4be8-a939-3628494a781e
md"""
Notice that it's using the data in `times`, `rvs_obs` and `σ_rvs`, even though they're not passed as function arguements.  Therefore, the function will look for those variables in the scope of wherever it's called from.  In this case, we'll call it from the notebook, and we've defined the variables in the code cell above.

We can see how julia gradually compiles our code by using macros for *code inspection*.  `@code_lowered` shows the result of the first step which does not make use of type information.
"""

# ╔═╡ 6ac7900b-cff2-4b5c-b3b5-bf55ba1f5951
@code_lowered calc_χ²_v0(P,K,ecc,ω,M0)

# ╔═╡ 9729eafe-ffcd-4619-aa93-cec5ed258c4d
md"## Finding Type Instability"

# ╔═╡ 9bb610b1-9e89-45e7-85a1-9c8475f27a8a
md"""
The compiler's next step is to make use of the type information and other variables that can be inferred at compile time to generate code that makes use of specific types  being used wherever possible.  We can see this with `@code_warntype`.  Since it calls the LLVM compiler, we need to put its output into a terminal.
"""

# ╔═╡ 3f0edfc5-cf3d-4f06-a89f-18f18cebc736
with_terminal() do
	calc_χ²_v0
	@code_warntype calc_χ²_v0(P,K,ecc,ω,M0)
end

# ╔═╡ 84c568c0-2a26-4e9d-9129-6cc120e919f7
md"""
While there is a lot here, we can be on the lookout for variables labeled '::ANY', meaning the compiler can't infer what type they'll have.  As a result, future calculations that depend on these variables can not be optimized for the specific types.  In this case, `times`, `rvs_obs`, and `σ_rvs` have type Any.  This causes `rvs_pred`, `Δrv` and `χ²` to also have type Any."""

# ╔═╡ e99f1365-4cce-4be2-b15a-ca68276e17c4
protip(md"Although, there aren't examples here, we should also be on the lookout for variables labeled '::Union{...}', indicating that the compiler was able to narrow down the possible types to a list, but couldn't identify one specific type.
")

# ╔═╡ a26208c9-0dfc-4db6-940b-540c0ff09a6c
md"""
In an effort to make it easier to find lines of code with type instability, the [JETTest.jl](https://aviatesk.github.io/JETTest.jl/dev/) package provides a macro `@report_dispatch`.
"""

# ╔═╡ 4d5fc84b-0471-4d20-bfe5-a4d0af538a78
with_terminal() do
	calc_χ²_v0
	@report_dispatch calc_χ²_v0(P,K,ecc,ω,M0)
end

# ╔═╡ 6cb5b0db-c8ca-4b21-bdb7-5b79718189e5
tip(md"Avoid using global variables, especially in performance-sensitive code!")

# ╔═╡ 78096a1e-8780-4c15-a29d-1e771ba7dab5
md"""
Having identified the presence of type instabilty, we'll now demonstrate a few different ways to eliminate it.
"""

# ╔═╡ c8c3b803-4595-429b-a7cb-6e805d95b289
md"## Option 1: Explicit types for global variables"

# ╔═╡ 5f5ccc4f-256d-4c7b-a789-85e3bfd3395a
md"""
Often, the easiest way to solve type instability is to provide explicit types for variables via [*type annotations*](https://docs.julialang.org/en/v1/manual/types/#Type-Declarations).  We'll demonstrate that in version 1a.
"""

# ╔═╡ 0e605739-1df3-45b4-9810-b3311e402bbc
function calc_χ²_v1a(P,K,e,ω,M0)
	# Promise what type the global variables will be
	t = times::Vector{Float64}
	obs  = rvs_obs::Vector{Float64}
	σ = σ_rvs::Vector{Float64}
	@assert length(t) == length(obs) == length(σ)
	rvs_pred = calc_rv_keplerian.(t,P,K,e,ω,M0)
	Δrv = rvs_pred - obs
	χ² = sum((Δrv./σ).^2)
end

# ╔═╡ 89d811d7-7ce7-4a5a-9be9-69f0612da017
md"""
Let's check that this still gives the same results and if it results in any type instabilities.
"""

# ╔═╡ 63833cdb-b8d5-40b0-ad5f-1897c5324f63
with_terminal() do
	calc_χ²_v1a
	println("Checking calc_χ²_v1a")
	@report_dispatch calc_χ²_v1a(P,K,ecc,ω,M0)
end

# ╔═╡ e0f0437c-e463-43b2-b680-a045d27db9c8
md"""
We can compare the runtime of the type unstable and type stable versions of the function below.
"""

# ╔═╡ d43f3834-ae39-46aa-bfd0-03ffd8ef0ce6
md"**Type unstable**"

# ╔═╡ 4bb63fd2-3f66-4a56-b3ea-c40379273f0f
begin
	calc_χ²_v0
	@benchmark calc_χ²_v0($P,$K,$ecc,$ω,$M0)
end

# ╔═╡ 8e7ab41d-6d97-4f9a-96a1-4348755c56c0
md"**Type stable**"

# ╔═╡ ce12316a-73a8-45ec-8c2f-5d920009516b
begin
	calc_χ²_v1a
	@benchmark calc_χ²_v1a($P,$K,$ecc,$ω,$M0)
end

# ╔═╡ 2c1cff43-2ac1-4b42-9db5-c75cdcc2f7cd
md"""
While we solved the type instability problem quickly, there are some disadvantages.  First, the names and types of the variables containing the data are hard coded.  This makes `calc_χ²_v1a` susceptive to unexpected behavior if the global variables change.  For example if someone set `rvs_obs` as `Float32`'s, they'd get an error message.   Not as generic as it could be.  In next sections we'll explore other programming patterns that solve the type stability issue, while also resulting in code that is more modular, more performant and easier to read, maintain and debug.
"""

# ╔═╡ e3eb842f-e470-4b3e-8da4-275427da841d
md"## Option 2: Pass all variables as parameters"

# ╔═╡ fae5b36d-5dc8-4027-8f7d-e2eb9531242c
md"""
The reason for type instability in `calc_χ²_v1a` was that the types of variables could change between calls.  We can eliminate the use of global variables by passing all variables to be used by a function as arguments.  For example,
"""

# ╔═╡ 43a4cbba-b1dc-4cc8-8a5c-0494b9be9343
md"""
### Option 2a: Pass each parameter separately
"""

# ╔═╡ d7a39507-966a-4c63-a10e-1ceee329e65a
function calc_χ²_v2a(t,rvs,σs,P,K,e,ω,M0)
	@assert length(t) == length(rvs) == length(σs)
	rvs_pred = calc_rv_keplerian.(t,P,K,e,ω,M0)
	Δrv = rvs_pred .- rvs
	χ² = sum((Δrv./σs).^2)
end

# ╔═╡ f82ff56a-a021-43fd-8a7b-cc0b2885982f
md"""
Let's test for accuracy and type stability.
"""

# ╔═╡ 1569124f-e948-4cae-8bc6-0076e3c214db
with_terminal() do
	calc_χ²_v2a
	@report_dispatch calc_χ²_v2a(times,rvs_obs,σ_rvs,P,K,ecc,ω,M0)
end

# ╔═╡ 6edf3258-07cd-4a2d-812c-4bbb71ee43a7
md"""
Let's check the results of `@code_warntype`
"""

# ╔═╡ 23afcd0c-e2ad-4cf2-9a7e-cdfdf6cb927e
with_terminal() do
	calc_χ²_v2a
	@code_warntype calc_χ²_v2a(times,rvs_obs,σ_rvs,P,K,ecc,ω,M0)
end

# ╔═╡ 01bc7388-0125-4ee5-8b20-14503846e2ea
md"""
Interestingly, there's still one variable with type `Any`.  It occurs when the assertion that the arrays have the same length is not met.  Therefore, it does not cascade to affect the types of future variables (unlike before).  `@report_dispatch` recognizes that assertions are almost always met, and this type instability will only impact our performance in the rare cases that the function is returning an error message.
"""

# ╔═╡ 013299b9-f22d-4a9c-9b24-09d6741646a9
md"""
### Option 2b: Simplify call signature by grouping parameters
"""

# ╔═╡ d7e2163d-d54c-46f9-a777-efdf56a1b7c4
md"""
This above pattern solved the type instability issue and also results in more modular and generic code.  However, functions that take eight parameters can be a little unwieldy.  More importantly, it's dangerous, since it requires that the person calling the function pass all the arguments in the correct order.  Therefore, we'll try a variation, where we reduce the number of function arguments by grouping them in a way that makes sense for our particular function.
"""

# ╔═╡ 5b79a4ed-c4ca-4f95-b5ea-df8f8bdb3652
function calc_χ²_v2b(data, param)
	# WARNING: assumes data & param contains the right parameters in the right order!
	@assert length(data) == 3
	@assert length(param) == 5
	(t,obs,σs) = data
	(P,K,e,ω,M0) = param
	@assert length(t) == length(obs) == length(σs)
	rvs_pred = calc_rv_keplerian.(t,P,K,e,ω,M0)
	Δrv = rvs_pred .- obs
	χ² = sum((Δrv./σs).^2)
end

# ╔═╡ 8ee2d7bf-06b7-414f-bf27-02347dbf826b
data_as_tuple = (times,rvs_obs,σ_rvs)

# ╔═╡ 958489d0-f256-4cfa-86e8-5a5b0e2c8b5b
param_as_tuple = (P,K,ecc,ω,M0)

# ╔═╡ cb34bcb1-938f-48ef-88a0-fc86b885cf0b
with_terminal() do
	calc_χ²_v2b
	data = (times,rvs_obs,σ_rvs)
	param = (P,K,ecc,ω,M0)
	@report_dispatch calc_χ²_v2b(data,param)
end

# ╔═╡ e44dd6aa-f4bd-417d-87db-0183b287925a
md"""
### Option 2c: Reduce risk of errors by using NamedTuples or Dictionary
"""

# ╔═╡ 26ca4413-1a2f-4b29-81af-4aaab018bbf2
md"""
In `calc_χ²_v2c` we still require users to order the various model parameters correctly when putting them into `param`.  To further reduce the risk of an error due to ordering variables, we can make use of a structure that assigns names to their elements, such as a [`Dict`](https://docs.julialang.org/en/v1/base/collections/#Dictionaries) (short for dictionary, also known as a hash table) or a [NamedTuple](https://docs.julialang.org/en/v1/base/base/#Core.NamedTuple).
"""

# ╔═╡ 1ccc18d1-0357-4b76-b275-a9443c585530
data_as_dict = Dict(:t=>times,:rvs=>rvs_obs,:σs=>σ_rvs)

# ╔═╡ 9576dd5a-7f41-43fb-aebb-777439655f85
param_as_named_tuple = (;P,K,e=ecc,ω,M0)

# ╔═╡ 82f53619-aa7b-4c61-9857-39b75b455b68
md"""
2a.  Create a variable `data_as_named_tuple` that is a `NamedTuple` with keys `t`, `rvs`, and `σs` and contains our simulated data.
"""

# ╔═╡ 0e5641d9-8d14-49ce-9c6c-e5edf1f9b27d
data_as_named_tuple = missing # TODO: replace with your code

# ╔═╡ 22b44c84-2b5d-47f2-a23d-e90f80a1021e
begin
        if !@isdefined(data_as_named_tuple)
                var_not_defined(:data_as_named_tuple)
        elseif ismissing(data_as_named_tuple)
                still_missing()
        elseif data_as_named_tuple != (;t=times,rvs=rvs_obs,σs=σ_rvs)
                keep_working(md"Please double check that.")
        else
                correct()
        end
end

# ╔═╡ 6252ba9a-44c4-4485-bf38-b89a9b52442e
md"""
2b.  Create a variable `param_as_dict` that is a `Dict` with keys `P`, `K`, `e`, `ω` and `M0` and contains our model parameters.
"""

# ╔═╡ cc1a13ee-7753-4433-a058-ee66ba5eacfe
param_as_dict = missing  # TODO:  replace with yoru code

# ╔═╡ 52dd0fba-6011-4179-b018-a6ea7de2f48a
begin
        if !@isdefined(param_as_dict)
                var_not_defined(:param_as_dict)
        elseif ismissing(param_as_dict)
                still_missing()
        elseif param_as_dict != Dict(:P=>P,:K=>K,:e=>ecc,:ω=>ω,:M0=>M0)
                keep_working()
        else
                correct()
        end
end

# ╔═╡ e28f45a4-63db-4bf4-b1d4-56b13faaa98f
md"""
The [UnPack.jl](https://github.com/mauro3/UnPack.jl) package contains a useful macro for extracting variables from collections like Dicts and NamedTuples.
"""

# ╔═╡ 8801443b-3e2a-4fbe-bfe1-3258a2df6df2
function calc_χ²_v2c(data, param)
	@unpack t,rvs,σs = data
	@unpack P,K,e,ω,M0 = param
	@assert length(t) == length(rvs) == length(σs)
	rvs_pred = calc_rv_keplerian.(t,P,K,e,ω,M0)
	Δrv = rvs_pred - rvs
	χ² = sum(((rvs_pred.-rvs)./σs).^2)
end

# ╔═╡ 150620fc-f1ed-4ad2-9cea-e2703114811d
md"""
We'll test for accuracy and type stability.
"""

# ╔═╡ c6914850-e34a-4a65-bc36-3c25f94bcd05
with_terminal() do
	calc_χ²_v2c
	@report_dispatch calc_χ²_v2c(data_as_named_tuple,param_as_named_tuple)
end

# ╔═╡ 1328f5d0-3c6e-4a6c-83c5-f9b5862850b6
with_terminal() do
	calc_χ²_v2c
	@report_dispatch calc_χ²_v2c(data_as_dict,param_as_dict)
end

# ╔═╡ bafb816a-7e43-48a5-8e1d-c47338cc546b
md"""
We can again inspect the typed code.
"""

# ╔═╡ d6e456e3-2a7a-45ab-9733-72730cef939d
with_terminal() do
	calc_χ²_v2c
	@code_warntype calc_χ²_v2c(data_as_named_tuple,param_as_dict)
end

# ╔═╡ 3564cc7e-05f2-41f1-8368-6098c5d60c5d
md"""
Yikes, it's grown much longer.  One might reasonably worry if our attempt to make safer code is costing us in terms of performance.  Let's check how much memory is being allocated by each version of our function, starting with our previous versions.
"""

# ╔═╡ 13623193-7cc4-40a7-ad46-622c489c2bd3
begin
	calc_χ²_v2a(times,rvs_obs,σ_rvs,P,K,ecc,ω,M0)
	@allocated calc_χ²_v2a(times,rvs_obs,σ_rvs,P,K,ecc,ω,M0)
end

# ╔═╡ 4154cea2-651c-4111-87ee-314c3859efc2
begin
	calc_χ²_v2b( data_as_tuple, param_as_tuple )
	@allocated calc_χ²_v2b( data_as_tuple, param_as_tuple )
end

# ╔═╡ 2c8adf6f-c24a-44a5-8dee-6e3577b0a4c6
md"2c.  How much memory allocation do you expect will be triggered by `calc_χ²_v2c` if we pass both data and parameters as `NamedTuple`'s?  What if we pass them both as `Dict`'s?"

# ╔═╡ 5bc32c34-c9ef-4d30-a8bc-056059bacc6a
response_2c = missing # Replace with md"Your Response"

# ╔═╡ 58942ba0-4ee1-4258-98a7-90fb019d90c0
md"""
Once you've made your guess, we'll try them both.
"""

# ╔═╡ 47eef67b-b8f0-4814-add0-5be91a804b10
if !ismissing(response_2c)
	calc_χ²_v2c(data_as_named_tuple,param_as_named_tuple)
	@allocated calc_χ²_v2c(data_as_named_tuple,param_as_named_tuple)
end

# ╔═╡ f430e061-4b07-4a1b-b10c-289511e22715
if !ismissing(response_2c)
	calc_χ²_v2c(data_as_dict,param_as_dict)
	@allocated calc_χ²_v2c(data_as_dict,param_as_dict)
end

# ╔═╡ 588f88bd-68e2-4fc8-bb45-098319ecc09b
md"2d.  How did the results compare to your predictions?  If they differed, how might you explain the difference?"

# ╔═╡ cd4dc17e-e7a3-4ca7-92ab-c00db1f7cf6a
response_2d = missing # Replace with md"Your Response"

# ╔═╡ 23492f0e-c3a2-4adc-8d64-913e770a31dd
display_msg_if_fail(check_type_isa(:response_2d,response_2d,Markdown.MD))

# ╔═╡ 5cf146f1-91ff-447b-af3c-4ef76145cd81
md"## Option 3: Pass custom structs"

# ╔═╡ 30edc01b-4fff-4a0a-8bfd-99d35c65fa68
md"""
The above pattern of using `Dict`'s or `NamedTuple`'s is pretty useful.  Sometimes it may be useful to create a custom type that will contain our variables.  This allows us to create convenience functions, such as non-trivial constructors that can check the inputs are valid.  It's a little more work, so I'll demonstrate below.
"""

# ╔═╡ e21c6438-127d-4d18-8f17-2a9fc4ab2ef6
struct RvParamKeplerian{T<:Number}
	P::T
	K::T
	e::T
	ω::T
	M0::T
end

# ╔═╡ 0ff5363b-666e-4100-90ea-67736762d3a5
param_custom = RvParamKeplerian(P,K,ecc,ω,M0)

# ╔═╡ f9d5666e-bcb6-4b67-9d01-9a05915bcfd3
md"""
One advantage of creating custom types is that we can implement multiple types that conform to a common interface.  This allows the programmer to try out different implementation strategies and easily swap them out.  To do that, we'll define an *[Abstract Type](https://docs.julialang.org/en/v1/manual/types/#man-abstract-types)*, and then provide at least one implementation of that abstract type.
"""

# ╔═╡ a3384734-5b15-4faf-b257-78309acea8b7
abstract type AbstractRvData end

# ╔═╡ 99cdd6a8-4351-45bc-9272-bf16ef8a944a
struct RvData_anys <: AbstractRvData
	t
	rvs
	σs
end

# ╔═╡ 1b617085-87d0-4368-8ae3-905b05967f82
rvdata_custom1 = RvData_anys(times,rvs_obs,σ_rvs)

# ╔═╡ 1f212400-7737-437a-b3ac-6b67d305ca24
md"""
Note that we can already use these custom types with our existing implementation of `calc_χ²_v2c`.
"""

# ╔═╡ a8bfd1e1-ca26-47d3-a43f-3ae8014e1c12
md"""
However, we can also write a version of `calc_χ²_v2d` that requires we pass custom structs.
"""

# ╔═╡ ff3514e5-fc61-4628-8f81-58a2243c3e92
function calc_χ²_v2d(data::AbstractRvData, p::RvParamKeplerian{T}) where { T<:Number}
	@assert length(data.t) == length(data.rvs) == size(data.σs,1)
	rvs_pred = calc_rv_keplerian.(data.t,p.P,p.K,p.e,p.ω,p.M0)
	Δrvs = rvs_pred-data.rvs
	#χ² = sum(((rvs_pred.-data.rvs)./data.σs).^2)
	χ² = sum((Δrvs./data.σs).^2)
end

# ╔═╡ 747d9462-bcad-4486-bab2-8f855d13da4c
md"""
This provides opportunities for specialization and more useful error messages.  For example compare the following error messages.
"""

# ╔═╡ b2a95cf0-f907-4a79-9edd-b2ca8700b727
calc_χ²_v2c(param_custom,rvdata_custom1)

# ╔═╡ 4fdfbe03-d9ae-44ef-b6eb-d16a89c1f7d8
md"""
The first error message tells about the first time the compiler recognized that there was a problem.  However, it's not obvious whether the problem is inside `calc_χ²_v2c` or in how we called `calc_χ²_v2c`.
The second error message makes it clear that we did not call `calc_χ²_v2d` with valid arguements.
"""

# ╔═╡ 3d7940e8-fe07-443e-8e5d-57330152a563
md"2e.  Do you expect to happen if we check calc_χ²_v2c for type instability with `@report_dispatch` when passing `rvdata_custom1` and `param_custom`?  What do you expect for memory allocations?"

# ╔═╡ 2f1dc64a-ede2-4963-9485-31feebfd0594
response_2e = missing # Replace with md"Your response"

# ╔═╡ 023f07b5-0b40-449f-87e9-195f208c8d1d
display_msg_if_fail(check_type_isa(:response_2e,response_2e,Markdown.MD))

# ╔═╡ aaf6db88-3c88-43ce-8710-5b22a4812687
md"2f.  How did the results comapre to your expectations?"

# ╔═╡ 8df1aedb-6451-4fcf-8f93-ec9a1df2f307
response_2f = missing # Replace with md"Your response"

# ╔═╡ 918b7df4-0960-40ad-ac88-4381c6e5ccfa
display_msg_if_fail(check_type_isa(:response_2f,response_2f,Markdown.MD))

# ╔═╡ 57e25af6-9947-439b-b80c-d107c6dcdc4e
md"### Inefficient structs"

# ╔═╡ c5a0b2f3-c038-4754-9683-958d1ed39c52
md"""
Our first implementation of a custom type for containing the RvData wasn't very efficient.  Below, I'll demonstrate three other inefficient custom structs and one efficient one.
"""

# ╔═╡ 65df57f8-1a4c-495d-81e1-0b57262737cc
struct RvData_abs_vec_anys <: AbstractRvData
	# WARNING:  Poor performance due to Abstract Collections of Abstract Types
	t::AbstractVector{Any}
	rvs::AbstractVector{Any}
	σs::AbstractVector{Any}
end

# ╔═╡ bd0da121-384f-48b3-981f-86269c7a2d78
struct RvData_vec_anys <: AbstractRvData
	# WARNING:  Poor performance due to collections of Abstract Types
	t::Vector{Any}
	rvs::Vector{Any}
	σs::Vector{Any}
end

# ╔═╡ 7f9bca89-bf70-42c6-9f97-8c2d929a7e52
struct RvData_abs_vec{T1<:Number, T2<:Number, T3<:Number} <: AbstractRvData
	# WARNING:  Poor performance due to Abstract Collections
	t::AbstractVector{T1}
	rvs::AbstractVector{T2}
	σs::AbstractVector{T3}
end

# ╔═╡ 4bb03619-f3d4-4249-a8ac-42070c941654
md"2g.  What do the above structures have in common that will result in reduced efficiency?"

# ╔═╡ 8beb5252-5f85-45e8-b23b-29de2437cbc3
response_2g = missing # Replace with md"Your response"

# ╔═╡ d5cb5c24-c384-4806-beb8-27c7516744c2
display_msg_if_fail(check_type_isa(:response_2g,response_2g,Markdown.MD))

# ╔═╡ f741b80b-d322-4fb2-bfc7-ad5d8d26350c
md"""
Now, let's compare the memory allocations for each version and check for type instabilities.
"""

# ╔═╡ 37648d4e-f776-47ec-89f2-22123dc6ae64
md"And we can compare the run-time performance when using different data structures."

# ╔═╡ 9ec85962-500a-41d3-b44a-c7e29b588d53
md"""
To avoid the above type instability and excess allocations seen above, we want to make our custom type contain only concrete types.  We can still keep our custom type generic by letting it take type parameters, as demonstrated below.
"""

# ╔═╡ 1fccacaf-ba57-4a1b-9e36-16ae2a655dab
md"### Custom struct with concrete types"

# ╔═╡ 5fe5b01a-6675-4314-88db-f6521b3d4e89
struct RvData_concrete_v1{T1<:Number, T2<:Number, T3<:Number} <: AbstractRvData
	t::Vector{T1}
	rvs::Vector{T2}
	σs::Vector{T3}
end

# ╔═╡ f10ed432-4b04-4dd5-bfe1-94c7d47165fb
md"""
Now our custom structure results in no type instability and no more memory allocations than before.  However, we could make our custom structure even more generic, as shown below.
"""

# ╔═╡ e9520732-40b8-4b16-82e9-cbb1e5b91486
md"### More generic concrete custom struct"

# ╔═╡ 37ca947a-594a-4340-b464-41b6a4670c86
md"""
We can make our custom struct even more generic, while maintaining type stabilitiy and avoiding exccess allocations as demonstrated below.  This can be useful for allowing us to pass a [view](https://docs.julialang.org/en/v1/base/arrays/#Views-(SubArrays-and-other-view-types)) into a pre-allocated arrays, potentially eliminating the need for copying data.
"""

# ╔═╡ 4adf7058-f572-4082-8f6b-2215f7feb83d
struct RvData_concrete_v2{T1<:Number, T2<:Number, T3<:Number,
				V1<:AbstractVector{T1}, V2<:AbstractVector{T2},
				V3<:AbstractVector{T3} } <: AbstractRvData
	t::V1
	rvs::V2
	σs::V3
end

# ╔═╡ b0d99a85-798d-45b2-83d0-318f5ddb9347
md"## Profiling our implementation"

# ╔═╡ 6e2a733c-7a9c-4e94-9a6b-eb04c4a90513
md"""
Thinking back to exercise 1, we found that sometimes the inside of a loop is repeatedly allocating and deallocating memory.  We got around this by pre-allocating memory and providing it as a workspace.  In `calc_periodogram`, we used a NamedTuple to contain spaces for multiple matrices and vectors.  We create a custom structure that includes pre-allocated workspaces.
"""

# ╔═╡ ffd21a68-03da-42cb-a1ae-171db4b58e98
md"""
Before we do that, let's profile our current implementation and look to see how much time is spent allocating memory.
"""

# ╔═╡ b78b5950-a9c2-4327-9880-05246fd8dd85
md"""
Let's jumpto the total time inside the `calc_χ²...` function and the time spent allocating arrays.
"""

# ╔═╡ 13935ef8-970d-4644-87ac-4ff87f04af08
md"2h.  What's the most we could improve the efficiency of our function by eliminating memory allocations?  Would it be worth writing a more sophisticated custom struct with that includes a preallocated workspace?"

# ╔═╡ 8ab7c2c3-58ed-42a7-9a81-e2b1bd8d62d2
response_2h = missing # md"Your response"

# ╔═╡ 99e7401a-2419-4a6b-9871-3c3ddb52357e
display_msg_if_fail(check_type_isa(:response_2h,response_2h,Markdown.MD))

# ╔═╡ 1073a216-8259-45d1-87c6-14e6b28ac62c
md"### Custom concrete struct with pre-allocated workspace"

# ╔═╡ 45a2d33d-3ef2-45b3-b1d7-713bc122cbeb
begin
	struct RvData_concrete_v3{T1<:Number, T2<:Number, T3<:Number, T4<:Number,
					V1<:AbstractVector{T1}, V2<:AbstractVector{T2},
					V3<:AbstractVector{T3}, V4<:AbstractVector{T4}
						} <: AbstractRvData
		t::V1
		rvs::V2
		σs::V3
		predict::V4
	end

	function RvData_concrete_v3(t::V1, rv::V2, σ::V3 )  where {
							T1<:Number, T2<:Number, T3<:Number,
							V1<:AbstractVector{T1}, V2<:AbstractVector{T2},
							V3<:AbstractVector{T3} }
		@assert length(t) == length(rv) == size(σ,1)
		WorkspaceT = promote_type(T1,T2,T3)
		ws1 = Vector{WorkspaceT}(undef,length(t))
		RvData_concrete_v3(t,rv,σ,ws1)
	end
end

# ╔═╡ abffb029-023c-4a28-ace8-5e5f469dce2b
md"We can now overload the calc_χ²_v2d function so that it can take advantage of the pre-allocated workspace, if we pass data in the form of a `RvData_concrete_v3`.  Note that the previous function will still be called if we pass some other form of AbstractRvData."

# ╔═╡ 0d12115d-b8fa-47f6-8e69-2050a82a5417
function calc_χ²_v2d(data::RvData_concrete_v3, p::RvParamKeplerian{T}) where { T<:Number}
	@assert length(data.t) == length(data.rvs) == size(data.σs,1)
	data.predict .= calc_rv_keplerian.(data.t,p.P,p.K,p.e,p.ω,p.M0)
	# Calling sum normally results in creating a temporary array
	#χ² = sum(((data.predict.-data.rvs)./data.σs).^2)
	# We can eliminate that unnecesary allocation using a a LazyArray
	χ² = sum(LazyArray(@~ ((data.predict.-data.rvs)./data.σs).^2))
end

# ╔═╡ 1fd3a0c6-5c31-4e86-b3b8-396bbf8ac23f
calc_χ²_v2d(param_custom,rvdata_custom1)

# ╔═╡ 81028a2b-360e-4b92-b8a4-6730b4dc9400
if !ismissing(response_2e)
	with_terminal() do
		calc_χ²_v2d,rvdata_custom1,param_custom
		@report_dispatch calc_χ²_v2d(rvdata_custom1,param_custom)
	end
end

# ╔═╡ 8f8c0e3a-239e-48dd-9a89-d01139330794
if !ismissing(response_2e)
	calc_χ²_v2d,rvdata_custom1,param_custom
	@allocated calc_χ²_v2d(rvdata_custom1,param_custom)
end

# ╔═╡ 274d3ddb-df22-4209-a6c4-baeb152a5d11
if !ismissing(response_2g)
	calc_χ²_v2d
	local data = RvData_abs_vec_anys(times,rvs_obs,σ_rvs)
	calc_χ²_v2d( data, param_custom)
	@allocated calc_χ²_v2d( data, param_custom)
end

# ╔═╡ fe46e288-c66c-4665-988d-12ab4f2abd25
if !ismissing(response_2g)
	calc_χ²_v2d
	local data = RvData_vec_anys(times,rvs_obs,σ_rvs)
	calc_χ²_v2d( data, param_custom)
	@allocated calc_χ²_v2d( data, param_custom)
end

# ╔═╡ f4b003a5-d861-4e4a-b9ea-b71184c3e3ed
if !ismissing(response_2g)
	calc_χ²_v2d
	local data = RvData_abs_vec(times,rvs_obs,σ_rvs)
	calc_χ²_v2d( data, param_custom)
	@allocated calc_χ²_v2d( data, param_custom)
end

# ╔═╡ 8373ffb0-15f2-40cf-bd2b-ce7f8be2107a
with_terminal() do
	calc_χ²_v2d, param_custom
	data = RvData_abs_vec_anys(times,rvs_obs,σ_rvs)
	@report_dispatch calc_χ²_v2d(data,param_custom)
end

# ╔═╡ fd8018c5-9bd7-4f9a-9ccd-afd2bc013b4a
with_terminal() do
	calc_χ²_v2d, param_custom
	data = RvData_vec_anys(times,rvs_obs,σ_rvs)
	@report_dispatch calc_χ²_v2d(data,param_custom)
end

# ╔═╡ 28a7f31b-4fda-41d2-acf0-045ee206f6dc
with_terminal() do
	calc_χ²_v2d, param_custom
	data = RvData_abs_vec(times,rvs_obs,σ_rvs)
	@report_dispatch calc_χ²_v2d(data,param_custom)
end

# ╔═╡ a1e928fd-ace2-4253-99d5-702b461f8528
let
	calc_χ²_v2d, param_custom
	data = RvData_anys(times,rvs_obs,σ_rvs)
	@benchmark calc_χ²_v2d($data,$param_custom)
end

# ╔═╡ 5f5191a9-a676-4040-8fd5-bf6e9bbff555
let
	calc_χ²_v2d, param_custom
	data = RvData_abs_vec_anys(times,rvs_obs,σ_rvs)
	@benchmark calc_χ²_v2d($data,$param_custom)
end

# ╔═╡ 91b7ebbe-54c3-4bae-8c0c-3de353858f86
let
	calc_χ²_v2d, param_custom
	data = RvData_vec_anys(times,rvs_obs,σ_rvs)
	@benchmark calc_χ²_v2d($data,$param_custom)
end

# ╔═╡ e3735e4b-7f60-4843-ac9b-36c8a46e3274
let
	calc_χ²_v2d, param_custom
	data = RvData_abs_vec(times,rvs_obs,σ_rvs)
	@benchmark calc_χ²_v2d($data,$param_custom)
end

# ╔═╡ a39267d2-60a0-4b91-b117-b0b51d7741d1
let
	calc_χ²_v2d, param_custom
	data = RvData_concrete_v1(times,rvs_obs,σ_rvs)
	param = RvParamKeplerian(P,K,ecc,ω,M0)
	@benchmark calc_χ²_v2d($data,$param_custom)
end

# ╔═╡ 1d212b01-788d-4292-948f-893bca319e9e
let
	calc_χ²_v2d, param_custom
	data = RvData_concrete_v2(times,rvs_obs,σ_rvs)
	param = RvParamKeplerian(P,K,ecc,ω,M0)
	@benchmark calc_χ²_v2d($data,$param_custom)
end

# ╔═╡ ce92c089-9ebe-4381-a55d-0b97b6b7010e
let
	data = RvData_concrete_v1(times,rvs_obs,σ_rvs)
	calc_χ²_v2d( data, param_custom)
	@allocated calc_χ²_v2d( data, param_custom)
end

# ╔═╡ 5e3f4691-e528-4b2d-a1b4-e6462bf26a5b
with_terminal() do
	calc_χ²_v2d
	data = RvData_concrete_v1(times,rvs_obs,σ_rvs)
	param = RvParamKeplerian(P,K,ecc,ω,M0)
	@report_dispatch calc_χ²_v2d(data,param_custom)
end

# ╔═╡ 6c62eeda-dc6a-4b4c-b7e6-5e08e3f66b31
let
	data = RvData_concrete_v2(times,rvs_obs,σ_rvs)
	calc_χ²_v2d( data, param_custom)
	@allocated calc_χ²_v2d( data, param_custom)
end

# ╔═╡ 46eee524-44c1-4589-b7a6-cad77dafa79c
with_terminal() do
	calc_χ²_v2d
	data = RvData_concrete_v2(times,rvs_obs,σ_rvs)
	param = RvParamKeplerian(P,K,ecc,ω,M0)
	@report_dispatch calc_χ²_v2d(data,param)
end

# ╔═╡ af904775-c711-4810-aab3-89bdf36e68df
begin
	data = RvData_concrete_v2(times,rvs_obs,σ_rvs)
	calc_χ²_v2d
    Profile.clear()
    Profile.init(delay=1/10^7)
    for i in 1:10^4
		@profile calc_χ²_v2d( RvData_concrete_v2(times,rvs_obs,σ_rvs), param_custom)
	end
    prof_results = Profile.retrieve()
end;

# ╔═╡ f7f7b175-7541-444c-b1f6-3973a96d616d
begin
   prof_filename = "calc_chisq.prof"
   open(prof_filename, "w") do s
        Profile.print(IOContext(s, :displaysize => (24, 500)),prof_results..., format=:tree )
    end
	prof_lines = readlines(prof_filename);
end;

# ╔═╡ f942d668-4535-4c80-81dc-882b1bcab2a2
prof_lines[occursin.(r"; calc_χ²",prof_lines)]

# ╔═╡ 9b4d7366-0648-48d2-9e30-83b95ccfecaa
prof_lines[occursin.(r"; Array$",prof_lines)]

# ╔═╡ ef05b082-fbba-49a7-8622-d552b64fef23
let
	calc_χ²_v2d
	data = RvData_concrete_v3(times,rvs_obs,σ_rvs)
	calc_χ²_v2d(data,param_custom)
	@allocated calc_χ²_v2d(data,param_custom)
end

# ╔═╡ da5c4f59-ea4b-4929-9d41-8b860a8abf18
with_terminal() do
	calc_χ²_v2d
	data = RvData_concrete_v3(times,rvs_obs,σ_rvs)
	@report_dispatch calc_χ²_v2d(data,param_custom)
end

# ╔═╡ b722af3e-8ced-429c-875e-4b83c9479160
md"**Concrete struct, without preallocating memory**"

# ╔═╡ be787cd6-6b32-4395-92d6-334e277708bb
let
	calc_χ²_v2d, param_custom
	data = RvData_concrete_v2(times,rvs_obs,σ_rvs)
	@benchmark calc_χ²_v2d($data,$param_custom)
end

# ╔═╡ 328db758-b0c1-482f-918c-98cc2c42c0f1
md"**Concrete struct, with preallocated memory**"

# ╔═╡ d6099494-9e9c-43c3-bf8d-99b8badd81c9
let
	calc_χ²_v2d, param_custom
	data = RvData_concrete_v3(times,rvs_obs,σ_rvs)
	@benchmark calc_χ²_v2d($data,$param_custom)
end

# ╔═╡ 4b5c5e9c-9cd0-45ee-bcba-2e4523308020
md"2i.  How did the change in performance by pre-allocating a workspace compare to your prediction in 2h?"

# ╔═╡ 5684bbdc-8b06-4051-8333-809172ea4a26
response_2i = missing # md"Your response"

# ╔═╡ 461a74d0-4e9d-44c0-93e1-6a91b91d04ab
display_msg_if_fail(check_type_isa(:response_2i,response_2i,Markdown.MD))

# ╔═╡ b0eccdc2-40bc-44d7-8a72-3e059a4214ab
md"# Helper Code"

# ╔═╡ 5898c143-9d1c-40bb-9783-2a13a11d42f0
ChooseDisplayMode()

# ╔═╡ d93a8dca-9c63-4551-87e8-9939a765bef1
TableOfContents(aside=true)

# ╔═╡ 35e533c3-8f81-4ea2-b6fc-3dbdca527d9f
function color_by_module(mod::Module)
        pm = FlameGraphs.pm
        (@isdefined Periodogram) && (mod === Periodogram || pm(mod) === Periodogram) && return colorant"purple"
        (@isdefined PeriodogramOrig) && (mod === PeriodogramOrig || pm(mod) === PeriodogramOrig) && return colorant"purple"
        (@isdefined KeplerEqn) && (mod === KeplerEqn || pm(mod) === KeplerEqn) && return colorant"green"
        (@isdefined PDMats) && (mod === PDMats || pm(mod) === PDMats) && return colorant"yellow"
        (@isdefined LinearAlgebra) && (mod === LinearAlgebra || pm(mod) === LinearAlgebra) && return colorant"cyan"
        (mod === PlutoRunner || pm(mod) === PlutoRunner) && return colorant"grey40"
    (mod === Core.Compiler || pm(mod) === Core.Compiler) && return colorant"gray60"
    (mod === Core || pm(mod) === Core) && return colorant"gray20"
    (mod === Base || pm(mod) === Base) && return colorant"lightblue"
    return nothing
end


# ╔═╡ 8c053ef8-e6d6-4aee-8246-ac6a7296aac6
ProfileSVG.view(data=prof_results,fontsize=14,width=700,StackFrameCategory(color_by_module))

# ╔═╡ 2c34baa9-2645-4e68-9134-8eb2605b7a26
begin
	calc_χ²_v0
	calc_χ²_v1a
	calc_χ²_v2a
	calc_χ²_v2b
	calc_χ²_v2c
	calc_χ²_v2d
	ready_to_test_calc_χ² = true
end

# ╔═╡ b1b43e7e-bae6-4b9d-a382-41b44ece2cab
ready_to_test_calc_χ² && @test calc_χ²_v1a(P,K,ecc,ω,M0) == calc_χ²_v0(P,K,ecc,ω,M0)

# ╔═╡ 43f8a33e-f1c7-4529-960e-9cf75979bba6
ready_to_test_calc_χ² && @test calc_χ²_v0(P,K,ecc,ω,M0) == calc_χ²_v2a(times,rvs_obs,σ_rvs,P,K,ecc,ω,M0)

# ╔═╡ ea771d50-e160-4302-b381-c97242b2d29e
ready_to_test_calc_χ² && @test calc_χ²_v0(P,K,ecc,ω,M0) == calc_χ²_v2b( data_as_tuple, param_as_tuple )

# ╔═╡ 3bfd59f7-ab68-4d87-876c-8043714b7c8b
begin
	data_as_dict, param_as_dict,
	ready_to_test_calc_χ² && @test calc_χ²_v0(P,K,ecc,ω,M0) == calc_χ²_v2c(data_as_dict,param_as_dict)
end

# ╔═╡ a0cc1184-5d51-4f88-91c0-68f222b8cbc6
begin
	data_as_named_tuple,param_as_named_tuple
	ready_to_test_calc_χ² && @test calc_χ²_v0(P,K,ecc,ω,M0) == calc_χ²_v2c(data_as_named_tuple,param_as_named_tuple)
end

# ╔═╡ 04727f53-ee16-4c66-bc6f-90a9c3a0390c
begin
	data_as_dict,param_as_named_tuple
	ready_to_test_calc_χ² && @test calc_χ²_v0(P,K,ecc,ω,M0) == calc_χ²_v2c(data_as_dict,param_as_named_tuple)
end

# ╔═╡ 5b0dfffb-f0e0-4bd0-96f5-531f410efbee
ready_to_test_calc_χ² && @test calc_χ²_v0(P,K,ecc,ω,M0) == calc_χ²_v2c(rvdata_custom1,param_custom)

# ╔═╡ 796f5bb7-e2b7-4206-b4d2-08a68d4f3b7d
ready_to_test_calc_χ² && @test calc_χ²_v0(P,K,ecc,ω,M0) == calc_χ²_v2d(rvdata_custom1,param_custom)

# ╔═╡ ff691624-c2a7-4af7-9952-4c882306056e
ready_to_test_calc_χ² && (@isdefined rvs_obs) && @test calc_χ²_v0(P,K,ecc,ω,M0) == calc_χ²_v2d(RvData_abs_vec_anys(times,rvs_obs,σ_rvs),param_custom)

# ╔═╡ 8f0ec35a-1ef1-4607-9151-290e4a2b1098
ready_to_test_calc_χ² && (@isdefined rvs_obs) && @test calc_χ²_v0(P,K,ecc,ω,M0) == calc_χ²_v2d(RvData_vec_anys(times,rvs_obs,σ_rvs),param_custom)

# ╔═╡ 1ad7145f-db2b-4d57-a2ce-13173bf1ba80
ready_to_test_calc_χ² && (@isdefined rvs_obs) && @test calc_χ²_v0(P,K,ecc,ω,M0) == calc_χ²_v2d(RvData_abs_vec(times,rvs_obs,σ_rvs),param_custom)

# ╔═╡ aac25f61-36d3-4d52-a3c5-353c451f065f
ready_to_test_calc_χ² && (@isdefined rvs_obs) &&
@test calc_χ²_v0(P,K,ecc,ω,M0) == calc_χ²_v2d(RvData_concrete_v1(times,rvs_obs,σ_rvs),param_custom)

# ╔═╡ 741c5677-5295-4499-9881-06830234a11c
ready_to_test_calc_χ² && (@isdefined rvs_obs) &&
@test calc_χ²_v0(P,K,ecc,ω,M0) == calc_χ²_v2d(RvData_concrete_v2(times,rvs_obs,σ_rvs),param_custom)

# ╔═╡ 32b9d72b-9cff-4857-a45b-1baa1949b046
let
	calc_χ²_v2d, RvData_concrete_v3 ,param_custom
	data = RvData_concrete_v3(times,rvs_obs,σ_rvs)
	ready_to_test_calc_χ² && (@isdefined rvs_obs) &&
	@test calc_χ²_v0(P,K,ecc,ω,M0) == calc_χ²_v2d(data,param_custom)
end


# ╔═╡ 00000000-0000-0000-0000-000000000001
PLUTO_PROJECT_TOML_CONTENTS = """
[deps]
BenchmarkTools = "6e4b80f9-dd63-53aa-95a3-0cdb28fa8baf"
FlameGraphs = "08572546-2f56-4bcf-ba4e-bab62c3a3f89"
JETTest = "a79fb612-4a80-4749-a9bd-c2faab13da61"
LazyArrays = "5078a376-72f3-5289-bfd5-ec5146d43c02"
Plots = "91a5bcdd-55d7-5caf-9e0b-520d859cae80"
PlutoTeachingTools = "661c6b06-c737-4d37-b85c-46df65de6f69"
PlutoTest = "cb4044da-4d16-4ffa-a6a3-8cad7f73ebdc"
PlutoUI = "7f904dfe-b85e-4ff6-b463-dae2292396a8"
Profile = "9abbd945-dff8-562f-b5e8-e1ebf5ef1b79"
ProfileSVG = "132c30aa-f267-4189-9183-c8a63c7e05e6"
Random = "9a3f8284-a2c9-5f02-9a11-845980a1fd5c"
UnPack = "3a884ed6-31ef-47d7-9d2a-63182c4928ed"

[compat]
BenchmarkTools = "~1.1.4"
FlameGraphs = "~0.2.5"
JETTest = "~0.1.4"
LazyArrays = "~0.21.20"
Plots = "~1.22.1"
PlutoTeachingTools = "~0.1.4"
PlutoTest = "~0.1.0"
PlutoUI = "~0.7.9"
ProfileSVG = "~0.2.1"
UnPack = "~1.0.2"
"""

# ╔═╡ 00000000-0000-0000-0000-000000000002
PLUTO_MANIFEST_TOML_CONTENTS = """
# This file is machine-generated - editing it directly is not advised

[[AbstractTrees]]
git-tree-sha1 = "03e0550477d86222521d254b741d470ba17ea0b5"
uuid = "1520ce14-60c1-5f80-bbc7-55ef81b5835c"
version = "0.3.4"

[[Adapt]]
deps = ["LinearAlgebra"]
git-tree-sha1 = "84918055d15b3114ede17ac6a7182f68870c16f7"
uuid = "79e6a3ab-5dfb-504d-930d-738a2a938a0e"
version = "3.3.1"

[[ArgTools]]
uuid = "0dad84c5-d112-42e6-8d28-ef12dabb789f"

[[ArrayLayouts]]
deps = ["FillArrays", "LinearAlgebra", "SparseArrays"]
git-tree-sha1 = "623a32b87ef0b85d26320a8cc7e57ded707aef64"
uuid = "4c555306-a7a7-4459-81d9-ec55ddd5c99a"
version = "0.7.5"

[[Artifacts]]
uuid = "56f22d72-fd6d-98f1-02f0-08ddc0907c33"

[[Base64]]
uuid = "2a0f44e3-6c83-55bd-87e4-b1978d98bd5f"

[[BenchmarkTools]]
deps = ["JSON", "Logging", "Printf", "Statistics", "UUIDs"]
git-tree-sha1 = "42ac5e523869a84eac9669eaceed9e4aa0e1587b"
uuid = "6e4b80f9-dd63-53aa-95a3-0cdb28fa8baf"
version = "1.1.4"

[[Bzip2_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "19a35467a82e236ff51bc17a3a44b69ef35185a2"
uuid = "6e34b625-4abd-537c-b88f-471c36dfa7a0"
version = "1.0.8+0"

[[Cairo_jll]]
deps = ["Artifacts", "Bzip2_jll", "Fontconfig_jll", "FreeType2_jll", "Glib_jll", "JLLWrappers", "LZO_jll", "Libdl", "Pixman_jll", "Pkg", "Xorg_libXext_jll", "Xorg_libXrender_jll", "Zlib_jll", "libpng_jll"]
git-tree-sha1 = "f2202b55d816427cd385a9a4f3ffb226bee80f99"
uuid = "83423d85-b0ee-5818-9007-b63ccbeb887a"
version = "1.16.1+0"

[[CodeTracking]]
deps = ["InteractiveUtils", "UUIDs"]
git-tree-sha1 = "9aa8a5ebb6b5bf469a7e0e2b5202cf6f8c291104"
uuid = "da1fd8a2-8d9e-5ec2-8556-3022fb5608a2"
version = "1.0.6"

[[ColorSchemes]]
deps = ["ColorTypes", "Colors", "FixedPointNumbers", "Random"]
git-tree-sha1 = "9995eb3977fbf67b86d0a0a0508e83017ded03f2"
uuid = "35d6a980-a343-548e-a6ea-1d62b119f2f4"
version = "3.14.0"

[[ColorTypes]]
deps = ["FixedPointNumbers", "Random"]
git-tree-sha1 = "024fe24d83e4a5bf5fc80501a314ce0d1aa35597"
uuid = "3da002f7-5984-5a60-b8a6-cbb66c0b333f"
version = "0.11.0"

[[Colors]]
deps = ["ColorTypes", "FixedPointNumbers", "Reexport"]
git-tree-sha1 = "417b0ed7b8b838aa6ca0a87aadf1bb9eb111ce40"
uuid = "5ae59095-9a9b-59fe-a467-6f913c188581"
version = "0.12.8"

[[Compat]]
deps = ["Base64", "Dates", "DelimitedFiles", "Distributed", "InteractiveUtils", "LibGit2", "Libdl", "LinearAlgebra", "Markdown", "Mmap", "Pkg", "Printf", "REPL", "Random", "SHA", "Serialization", "SharedArrays", "Sockets", "SparseArrays", "Statistics", "Test", "UUIDs", "Unicode"]
git-tree-sha1 = "4866e381721b30fac8dda4c8cb1d9db45c8d2994"
uuid = "34da2185-b29b-5c13-b0c7-acf172513d20"
version = "3.37.0"

[[CompilerSupportLibraries_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "e66e0078-7015-5450-92f7-15fbd957f2ae"

[[Contour]]
deps = ["StaticArrays"]
git-tree-sha1 = "9f02045d934dc030edad45944ea80dbd1f0ebea7"
uuid = "d38c429a-6771-53c6-b99e-75d170b6e991"
version = "0.5.7"

[[DataAPI]]
git-tree-sha1 = "bec2532f8adb82005476c141ec23e921fc20971b"
uuid = "9a962f9c-6df0-11e9-0e5d-c546b8b5ee8a"
version = "1.8.0"

[[DataStructures]]
deps = ["Compat", "InteractiveUtils", "OrderedCollections"]
git-tree-sha1 = "7d9d316f04214f7efdbb6398d545446e246eff02"
uuid = "864edb3b-99cc-5e75-8d2d-829cb0a9cfe8"
version = "0.18.10"

[[DataValueInterfaces]]
git-tree-sha1 = "bfc1187b79289637fa0ef6d4436ebdfe6905cbd6"
uuid = "e2d170a0-9d28-54be-80f0-106bbe20a464"
version = "1.0.0"

[[Dates]]
deps = ["Printf"]
uuid = "ade2ca70-3891-5945-98fb-dc099432e06a"

[[DelimitedFiles]]
deps = ["Mmap"]
uuid = "8bb1440f-4735-579b-a4ab-409b98df4dab"

[[Distributed]]
deps = ["Random", "Serialization", "Sockets"]
uuid = "8ba89e20-285c-5b6f-9357-94700520ee1b"

[[Downloads]]
deps = ["ArgTools", "LibCURL", "NetworkOptions"]
uuid = "f43a241f-c20a-4ad4-852c-f6b1247861c6"

[[EarCut_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "3f3a2501fa7236e9b911e0f7a588c657e822bb6d"
uuid = "5ae413db-bbd1-5e63-b57d-d24a61df00f5"
version = "2.2.3+0"

[[Expat_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "b3bfd02e98aedfa5cf885665493c5598c350cd2f"
uuid = "2e619515-83b5-522b-bb60-26c02a35a201"
version = "2.2.10+0"

[[FFMPEG]]
deps = ["FFMPEG_jll"]
git-tree-sha1 = "b57e3acbe22f8484b4b5ff66a7499717fe1a9cc8"
uuid = "c87230d0-a227-11e9-1b43-d7ebe4e7570a"
version = "0.4.1"

[[FFMPEG_jll]]
deps = ["Artifacts", "Bzip2_jll", "FreeType2_jll", "FriBidi_jll", "JLLWrappers", "LAME_jll", "Libdl", "Ogg_jll", "OpenSSL_jll", "Opus_jll", "Pkg", "Zlib_jll", "libass_jll", "libfdk_aac_jll", "libvorbis_jll", "x264_jll", "x265_jll"]
git-tree-sha1 = "d8a578692e3077ac998b50c0217dfd67f21d1e5f"
uuid = "b22a6f82-2f65-5046-a5b2-351ab43fb4e5"
version = "4.4.0+0"

[[FileIO]]
deps = ["Pkg", "Requires", "UUIDs"]
git-tree-sha1 = "3c041d2ac0a52a12a27af2782b34900d9c3ee68c"
uuid = "5789e2e9-d7fb-5bc7-8068-2c6fae9b9549"
version = "1.11.1"

[[FileWatching]]
uuid = "7b1f6079-737a-58dc-b8bc-7a2ca5c1b5ee"

[[FillArrays]]
deps = ["LinearAlgebra", "Random", "SparseArrays", "Statistics"]
git-tree-sha1 = "caf289224e622f518c9dbfe832cdafa17d7c80a6"
uuid = "1a297f60-69ca-5386-bcde-b61e274b549b"
version = "0.12.4"

[[FixedPointNumbers]]
deps = ["Statistics"]
git-tree-sha1 = "335bfdceacc84c5cdf16aadc768aa5ddfc5383cc"
uuid = "53c48c17-4a7d-5ca2-90c5-79b7896eea93"
version = "0.8.4"

[[FlameGraphs]]
deps = ["AbstractTrees", "Colors", "FileIO", "FixedPointNumbers", "IndirectArrays", "LeftChildRightSiblingTrees", "Profile"]
git-tree-sha1 = "99c43a8765095efa6ef76233d44a89e68073bd10"
uuid = "08572546-2f56-4bcf-ba4e-bab62c3a3f89"
version = "0.2.5"

[[Fontconfig_jll]]
deps = ["Artifacts", "Bzip2_jll", "Expat_jll", "FreeType2_jll", "JLLWrappers", "Libdl", "Libuuid_jll", "Pkg", "Zlib_jll"]
git-tree-sha1 = "21efd19106a55620a188615da6d3d06cd7f6ee03"
uuid = "a3f928ae-7b40-5064-980b-68af3947d34b"
version = "2.13.93+0"

[[Formatting]]
deps = ["Printf"]
git-tree-sha1 = "8339d61043228fdd3eb658d86c926cb282ae72a8"
uuid = "59287772-0a20-5a39-b81b-1366585eb4c0"
version = "0.4.2"

[[FreeType2_jll]]
deps = ["Artifacts", "Bzip2_jll", "JLLWrappers", "Libdl", "Pkg", "Zlib_jll"]
git-tree-sha1 = "87eb71354d8ec1a96d4a7636bd57a7347dde3ef9"
uuid = "d7e528f0-a631-5988-bf34-fe36492bcfd7"
version = "2.10.4+0"

[[FriBidi_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "aa31987c2ba8704e23c6c8ba8a4f769d5d7e4f91"
uuid = "559328eb-81f9-559d-9380-de523a88c83c"
version = "1.0.10+0"

[[GLFW_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Libglvnd_jll", "Pkg", "Xorg_libXcursor_jll", "Xorg_libXi_jll", "Xorg_libXinerama_jll", "Xorg_libXrandr_jll"]
git-tree-sha1 = "dba1e8614e98949abfa60480b13653813d8f0157"
uuid = "0656b61e-2033-5cc2-a64a-77c0f6c09b89"
version = "3.3.5+0"

[[GR]]
deps = ["Base64", "DelimitedFiles", "GR_jll", "HTTP", "JSON", "Libdl", "LinearAlgebra", "Pkg", "Printf", "Random", "Serialization", "Sockets", "Test", "UUIDs"]
git-tree-sha1 = "c2178cfbc0a5a552e16d097fae508f2024de61a3"
uuid = "28b8d3ca-fb5f-59d9-8090-bfdbd6d07a71"
version = "0.59.0"

[[GR_jll]]
deps = ["Artifacts", "Bzip2_jll", "Cairo_jll", "FFMPEG_jll", "Fontconfig_jll", "GLFW_jll", "JLLWrappers", "JpegTurbo_jll", "Libdl", "Libtiff_jll", "Pixman_jll", "Pkg", "Qt5Base_jll", "Zlib_jll", "libpng_jll"]
git-tree-sha1 = "ef49a187604f865f4708c90e3f431890724e9012"
uuid = "d2c73de3-f751-5644-a686-071e5b155ba9"
version = "0.59.0+0"

[[GeometryBasics]]
deps = ["EarCut_jll", "IterTools", "LinearAlgebra", "StaticArrays", "StructArrays", "Tables"]
git-tree-sha1 = "58bcdf5ebc057b085e58d95c138725628dd7453c"
uuid = "5c1252a2-5f33-56bf-86c9-59e7332b4326"
version = "0.4.1"

[[Gettext_jll]]
deps = ["Artifacts", "CompilerSupportLibraries_jll", "JLLWrappers", "Libdl", "Libiconv_jll", "Pkg", "XML2_jll"]
git-tree-sha1 = "9b02998aba7bf074d14de89f9d37ca24a1a0b046"
uuid = "78b55507-aeef-58d4-861c-77aaff3498b1"
version = "0.21.0+0"

[[Glib_jll]]
deps = ["Artifacts", "Gettext_jll", "JLLWrappers", "Libdl", "Libffi_jll", "Libiconv_jll", "Libmount_jll", "PCRE_jll", "Pkg", "Zlib_jll"]
git-tree-sha1 = "7bf67e9a481712b3dbe9cb3dac852dc4b1162e02"
uuid = "7746bdde-850d-59dc-9ae8-88ece973131d"
version = "2.68.3+0"

[[Graphite2_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "344bf40dcab1073aca04aa0df4fb092f920e4011"
uuid = "3b182d85-2403-5c21-9c21-1e1f0cc25472"
version = "1.3.14+0"

[[Grisu]]
git-tree-sha1 = "53bb909d1151e57e2484c3d1b53e19552b887fb2"
uuid = "42e2da0e-8278-4e71-bc24-59509adca0fe"
version = "1.0.2"

[[HTTP]]
deps = ["Base64", "Dates", "IniFile", "Logging", "MbedTLS", "NetworkOptions", "Sockets", "URIs"]
git-tree-sha1 = "60ed5f1643927479f845b0135bb369b031b541fa"
uuid = "cd3eb016-35fb-5094-929b-558a96fad6f3"
version = "0.9.14"

[[HarfBuzz_jll]]
deps = ["Artifacts", "Cairo_jll", "Fontconfig_jll", "FreeType2_jll", "Glib_jll", "Graphite2_jll", "JLLWrappers", "Libdl", "Libffi_jll", "Pkg"]
git-tree-sha1 = "8a954fed8ac097d5be04921d595f741115c1b2ad"
uuid = "2e76f6c2-a576-52d4-95c1-20adfe4de566"
version = "2.8.1+0"

[[HypertextLiteral]]
git-tree-sha1 = "1e3ccdc7a6f7b577623028e0095479f4727d8ec1"
uuid = "ac1192a8-f4b3-4bfe-ba22-af5b92cd3ab2"
version = "0.8.0"

[[IndirectArrays]]
git-tree-sha1 = "c2a145a145dc03a7620af1444e0264ef907bd44f"
uuid = "9b13fd28-a010-5f03-acff-a1bbcff69959"
version = "0.5.1"

[[IniFile]]
deps = ["Test"]
git-tree-sha1 = "098e4d2c533924c921f9f9847274f2ad89e018b8"
uuid = "83e8ac13-25f8-5344-8a64-a9f2b223428f"
version = "0.5.0"

[[InteractiveUtils]]
deps = ["Markdown"]
uuid = "b77e0a4c-d291-57a0-90e8-8db25a27a240"

[[IterTools]]
git-tree-sha1 = "05110a2ab1fc5f932622ffea2a003221f4782c18"
uuid = "c8e1da08-722c-5040-9ed9-7db0dc04731e"
version = "1.3.0"

[[IteratorInterfaceExtensions]]
git-tree-sha1 = "a3f24677c21f5bbe9d2a714f95dcd58337fb2856"
uuid = "82899510-4779-5014-852e-03e436cf321d"
version = "1.0.0"

[[JET]]
deps = ["InteractiveUtils", "JuliaInterpreter", "LoweredCodeUtils", "MacroTools", "Pkg", "Revise"]
git-tree-sha1 = "a0aae98e5fda3f92e1aa001901fd086b54654122"
uuid = "c3a54625-cd67-489e-a8e7-0a5a0ff4e31b"
version = "0.4.6"

[[JETTest]]
deps = ["JET", "Test"]
git-tree-sha1 = "1f585a307beb8fdb3d7cd4c7a628ef81cf113ca6"
uuid = "a79fb612-4a80-4749-a9bd-c2faab13da61"
version = "0.1.4"

[[JLLWrappers]]
deps = ["Preferences"]
git-tree-sha1 = "642a199af8b68253517b80bd3bfd17eb4e84df6e"
uuid = "692b3bcd-3c85-4b1f-b108-f13ce0eb3210"
version = "1.3.0"

[[JSON]]
deps = ["Dates", "Mmap", "Parsers", "Unicode"]
git-tree-sha1 = "8076680b162ada2a031f707ac7b4953e30667a37"
uuid = "682c06a0-de6a-54ab-a142-c8b1cf79cde6"
version = "0.21.2"

[[JpegTurbo_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "d735490ac75c5cb9f1b00d8b5509c11984dc6943"
uuid = "aacddb02-875f-59d6-b918-886e6ef4fbf8"
version = "2.1.0+0"

[[JuliaInterpreter]]
deps = ["CodeTracking", "InteractiveUtils", "Random", "UUIDs"]
git-tree-sha1 = "e273807f38074f033d94207a201e6e827d8417db"
uuid = "aa1ae85d-cabe-5617-a682-6adf51b2e16a"
version = "0.8.21"

[[LAME_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "f6250b16881adf048549549fba48b1161acdac8c"
uuid = "c1c5ebd0-6772-5130-a774-d5fcae4a789d"
version = "3.100.1+0"

[[LZO_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "e5b909bcf985c5e2605737d2ce278ed791b89be6"
uuid = "dd4b983a-f0e5-5f8d-a1b7-129d4a5fb1ac"
version = "2.10.1+0"

[[LaTeXStrings]]
git-tree-sha1 = "c7f1c695e06c01b95a67f0cd1d34994f3e7db104"
uuid = "b964fa9f-0449-5b57-a5c2-d3ea65f4040f"
version = "1.2.1"

[[Latexify]]
deps = ["Formatting", "InteractiveUtils", "LaTeXStrings", "MacroTools", "Markdown", "Printf", "Requires"]
git-tree-sha1 = "a4b12a1bd2ebade87891ab7e36fdbce582301a92"
uuid = "23fbe1c1-3f47-55db-b15f-69d7ec21a316"
version = "0.15.6"

[[LazyArrays]]
deps = ["ArrayLayouts", "FillArrays", "LinearAlgebra", "MacroTools", "MatrixFactorizations", "SparseArrays", "StaticArrays"]
git-tree-sha1 = "1f93019153b4e9dab37e561b61f92b431f2ecedb"
uuid = "5078a376-72f3-5289-bfd5-ec5146d43c02"
version = "0.21.20"

[[LeftChildRightSiblingTrees]]
deps = ["AbstractTrees"]
git-tree-sha1 = "71be1eb5ad19cb4f61fa8c73395c0338fd092ae0"
uuid = "1d6d02ad-be62-4b6b-8a6d-2f90e265016e"
version = "0.1.2"

[[LibCURL]]
deps = ["LibCURL_jll", "MozillaCACerts_jll"]
uuid = "b27032c2-a3e7-50c8-80cd-2d36dbcbfd21"

[[LibCURL_jll]]
deps = ["Artifacts", "LibSSH2_jll", "Libdl", "MbedTLS_jll", "Zlib_jll", "nghttp2_jll"]
uuid = "deac9b47-8bc7-5906-a0fe-35ac56dc84c0"

[[LibGit2]]
deps = ["Base64", "NetworkOptions", "Printf", "SHA"]
uuid = "76f85450-5226-5b5a-8eaa-529ad045b433"

[[LibSSH2_jll]]
deps = ["Artifacts", "Libdl", "MbedTLS_jll"]
uuid = "29816b5a-b9ab-546f-933c-edad1886dfa8"

[[Libdl]]
uuid = "8f399da3-3557-5675-b5ff-fb832c97cbdb"

[[Libffi_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "761a393aeccd6aa92ec3515e428c26bf99575b3b"
uuid = "e9f186c6-92d2-5b65-8a66-fee21dc1b490"
version = "3.2.2+0"

[[Libgcrypt_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Libgpg_error_jll", "Pkg"]
git-tree-sha1 = "64613c82a59c120435c067c2b809fc61cf5166ae"
uuid = "d4300ac3-e22c-5743-9152-c294e39db1e4"
version = "1.8.7+0"

[[Libglvnd_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg", "Xorg_libX11_jll", "Xorg_libXext_jll"]
git-tree-sha1 = "7739f837d6447403596a75d19ed01fd08d6f56bf"
uuid = "7e76a0d4-f3c7-5321-8279-8d96eeed0f29"
version = "1.3.0+3"

[[Libgpg_error_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "c333716e46366857753e273ce6a69ee0945a6db9"
uuid = "7add5ba3-2f88-524e-9cd5-f83b8a55f7b8"
version = "1.42.0+0"

[[Libiconv_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "42b62845d70a619f063a7da093d995ec8e15e778"
uuid = "94ce4f54-9a6c-5748-9c1c-f9c7231a4531"
version = "1.16.1+1"

[[Libmount_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "9c30530bf0effd46e15e0fdcf2b8636e78cbbd73"
uuid = "4b2f31a3-9ecc-558c-b454-b3730dcb73e9"
version = "2.35.0+0"

[[Libtiff_jll]]
deps = ["Artifacts", "JLLWrappers", "JpegTurbo_jll", "Libdl", "Pkg", "Zlib_jll", "Zstd_jll"]
git-tree-sha1 = "340e257aada13f95f98ee352d316c3bed37c8ab9"
uuid = "89763e89-9b03-5906-acba-b20f662cd828"
version = "4.3.0+0"

[[Libuuid_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "7f3efec06033682db852f8b3bc3c1d2b0a0ab066"
uuid = "38a345b3-de98-5d2b-a5d3-14cd9215e700"
version = "2.36.0+0"

[[LinearAlgebra]]
deps = ["Libdl"]
uuid = "37e2e46d-f89d-539d-b4ee-838fcccc9c8e"

[[Logging]]
uuid = "56ddb016-857b-54e1-b83d-db4d58db5568"

[[LoweredCodeUtils]]
deps = ["JuliaInterpreter"]
git-tree-sha1 = "491a883c4fef1103077a7f648961adbf9c8dd933"
uuid = "6f1432cf-f94c-5a45-995e-cdbf5db27b0b"
version = "2.1.2"

[[MacroTools]]
deps = ["Markdown", "Random"]
git-tree-sha1 = "0fb723cd8c45858c22169b2e42269e53271a6df7"
uuid = "1914dd2f-81c6-5fcd-8719-6d5c9610ff09"
version = "0.5.7"

[[Markdown]]
deps = ["Base64"]
uuid = "d6f4376e-aef5-505a-96c1-9c027394607a"

[[MatrixFactorizations]]
deps = ["ArrayLayouts", "LinearAlgebra", "Printf", "Random"]
git-tree-sha1 = "1a0358d0283b84c3ccf9537843e3583c3b896c59"
uuid = "a3b82374-2e81-5b9e-98ce-41277c0e4c87"
version = "0.8.5"

[[MbedTLS]]
deps = ["Dates", "MbedTLS_jll", "Random", "Sockets"]
git-tree-sha1 = "1c38e51c3d08ef2278062ebceade0e46cefc96fe"
uuid = "739be429-bea8-5141-9913-cc70e7f3736d"
version = "1.0.3"

[[MbedTLS_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "c8ffd9c3-330d-5841-b78e-0817d7145fa1"

[[Measures]]
git-tree-sha1 = "e498ddeee6f9fdb4551ce855a46f54dbd900245f"
uuid = "442fdcdd-2543-5da2-b0f3-8c86c306513e"
version = "0.3.1"

[[Missings]]
deps = ["DataAPI"]
git-tree-sha1 = "bf210ce90b6c9eed32d25dbcae1ebc565df2687f"
uuid = "e1d29d7a-bbdc-5cf2-9ac0-f12de2c33e28"
version = "1.0.2"

[[Mmap]]
uuid = "a63ad114-7e13-5084-954f-fe012c677804"

[[MozillaCACerts_jll]]
uuid = "14a3606d-f60d-562e-9121-12d972cd8159"

[[NaNMath]]
git-tree-sha1 = "bfe47e760d60b82b66b61d2d44128b62e3a369fb"
uuid = "77ba4419-2d1f-58cd-9bb1-8ffee604a2e3"
version = "0.3.5"

[[NetworkOptions]]
uuid = "ca575930-c2e3-43a9-ace4-1e988b2c1908"

[[Ogg_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "7937eda4681660b4d6aeeecc2f7e1c81c8ee4e2f"
uuid = "e7412a2a-1a6e-54c0-be00-318e2571c051"
version = "1.3.5+0"

[[OpenSSL_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "15003dcb7d8db3c6c857fda14891a539a8f2705a"
uuid = "458c3c95-2e84-50aa-8efc-19380b2a3a95"
version = "1.1.10+0"

[[Opus_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "51a08fb14ec28da2ec7a927c4337e4332c2a4720"
uuid = "91d4177d-7536-5919-b921-800302f37372"
version = "1.3.2+0"

[[OrderedCollections]]
git-tree-sha1 = "85f8e6578bf1f9ee0d11e7bb1b1456435479d47c"
uuid = "bac558e1-5e72-5ebc-8fee-abe8a469f55d"
version = "1.4.1"

[[PCRE_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "b2a7af664e098055a7529ad1a900ded962bca488"
uuid = "2f80f16e-611a-54ab-bc61-aa92de5b98fc"
version = "8.44.0+0"

[[Parsers]]
deps = ["Dates"]
git-tree-sha1 = "438d35d2d95ae2c5e8780b330592b6de8494e779"
uuid = "69de0a69-1ddd-5017-9359-2bf0b02dc9f0"
version = "2.0.3"

[[Pixman_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "b4f5d02549a10e20780a24fce72bea96b6329e29"
uuid = "30392449-352a-5448-841d-b1acce4e97dc"
version = "0.40.1+0"

[[Pkg]]
deps = ["Artifacts", "Dates", "Downloads", "LibGit2", "Libdl", "Logging", "Markdown", "Printf", "REPL", "Random", "SHA", "Serialization", "TOML", "Tar", "UUIDs", "p7zip_jll"]
uuid = "44cfe95a-1eb2-52ea-b672-e2afdf69b78f"

[[PlotThemes]]
deps = ["PlotUtils", "Requires", "Statistics"]
git-tree-sha1 = "a3a964ce9dc7898193536002a6dd892b1b5a6f1d"
uuid = "ccf2f8ad-2431-5c83-bf29-c5338b663b6a"
version = "2.0.1"

[[PlotUtils]]
deps = ["ColorSchemes", "Colors", "Dates", "Printf", "Random", "Reexport", "Statistics"]
git-tree-sha1 = "2537ed3c0ed5e03896927187f5f2ee6a4ab342db"
uuid = "995b91a9-d308-5afd-9ec6-746e21dbc043"
version = "1.0.14"

[[Plots]]
deps = ["Base64", "Contour", "Dates", "Downloads", "FFMPEG", "FixedPointNumbers", "GR", "GeometryBasics", "JSON", "Latexify", "LinearAlgebra", "Measures", "NaNMath", "PlotThemes", "PlotUtils", "Printf", "REPL", "Random", "RecipesBase", "RecipesPipeline", "Reexport", "Requires", "Scratch", "Showoff", "SparseArrays", "Statistics", "StatsBase", "UUIDs"]
git-tree-sha1 = "4c2637482176b1c2fb99af4d83cb2ff0328fc33c"
uuid = "91a5bcdd-55d7-5caf-9e0b-520d859cae80"
version = "1.22.1"

[[PlutoTeachingTools]]
deps = ["LaTeXStrings", "Markdown", "PlutoUI", "Random"]
git-tree-sha1 = "e2b63ee022e0b20f43fcd15cda3a9047f449e3b4"
uuid = "661c6b06-c737-4d37-b85c-46df65de6f69"
version = "0.1.4"

[[PlutoTest]]
deps = ["HypertextLiteral", "InteractiveUtils", "Markdown", "Test"]
git-tree-sha1 = "3479836b31a31c29a7bac1f09d95f9c843ce1ade"
uuid = "cb4044da-4d16-4ffa-a6a3-8cad7f73ebdc"
version = "0.1.0"

[[PlutoUI]]
deps = ["Base64", "Dates", "InteractiveUtils", "JSON", "Logging", "Markdown", "Random", "Reexport", "Suppressor"]
git-tree-sha1 = "44e225d5837e2a2345e69a1d1e01ac2443ff9fcb"
uuid = "7f904dfe-b85e-4ff6-b463-dae2292396a8"
version = "0.7.9"

[[Preferences]]
deps = ["TOML"]
git-tree-sha1 = "00cfd92944ca9c760982747e9a1d0d5d86ab1e5a"
uuid = "21216c6a-2e73-6563-6e65-726566657250"
version = "1.2.2"

[[Printf]]
deps = ["Unicode"]
uuid = "de0858da-6303-5e67-8744-51eddeeeb8d7"

[[Profile]]
deps = ["Printf"]
uuid = "9abbd945-dff8-562f-b5e8-e1ebf5ef1b79"

[[ProfileSVG]]
deps = ["Colors", "FlameGraphs", "Profile", "UUIDs"]
git-tree-sha1 = "e4df82a5dadc26736f106f8d7fc97c42cc6c91ae"
uuid = "132c30aa-f267-4189-9183-c8a63c7e05e6"
version = "0.2.1"

[[Qt5Base_jll]]
deps = ["Artifacts", "CompilerSupportLibraries_jll", "Fontconfig_jll", "Glib_jll", "JLLWrappers", "Libdl", "Libglvnd_jll", "OpenSSL_jll", "Pkg", "Xorg_libXext_jll", "Xorg_libxcb_jll", "Xorg_xcb_util_image_jll", "Xorg_xcb_util_keysyms_jll", "Xorg_xcb_util_renderutil_jll", "Xorg_xcb_util_wm_jll", "Zlib_jll", "xkbcommon_jll"]
git-tree-sha1 = "ad368663a5e20dbb8d6dc2fddeefe4dae0781ae8"
uuid = "ea2cea3b-5b76-57ae-a6ef-0a8af62496e1"
version = "5.15.3+0"

[[REPL]]
deps = ["InteractiveUtils", "Markdown", "Sockets", "Unicode"]
uuid = "3fa0cd96-eef1-5676-8a61-b3b8758bbffb"

[[Random]]
deps = ["Serialization"]
uuid = "9a3f8284-a2c9-5f02-9a11-845980a1fd5c"

[[RecipesBase]]
git-tree-sha1 = "44a75aa7a527910ee3d1751d1f0e4148698add9e"
uuid = "3cdcf5f2-1ef4-517c-9805-6587b60abb01"
version = "1.1.2"

[[RecipesPipeline]]
deps = ["Dates", "NaNMath", "PlotUtils", "RecipesBase"]
git-tree-sha1 = "7ad0dfa8d03b7bcf8c597f59f5292801730c55b8"
uuid = "01d81517-befc-4cb6-b9ec-a95719d0359c"
version = "0.4.1"

[[Reexport]]
git-tree-sha1 = "45e428421666073eab6f2da5c9d310d99bb12f9b"
uuid = "189a3867-3050-52da-a836-e630ba90ab69"
version = "1.2.2"

[[Requires]]
deps = ["UUIDs"]
git-tree-sha1 = "4036a3bd08ac7e968e27c203d45f5fff15020621"
uuid = "ae029012-a4dd-5104-9daa-d747884805df"
version = "1.1.3"

[[Revise]]
deps = ["CodeTracking", "Distributed", "FileWatching", "JuliaInterpreter", "LibGit2", "LoweredCodeUtils", "OrderedCollections", "Pkg", "REPL", "Requires", "UUIDs", "Unicode"]
git-tree-sha1 = "1947d2d75463bd86d87eaba7265b0721598dd803"
uuid = "295af30f-e4ad-537b-8983-00126c2a3abe"
version = "3.1.19"

[[SHA]]
uuid = "ea8e919c-243c-51af-8825-aaa63cd721ce"

[[Scratch]]
deps = ["Dates"]
git-tree-sha1 = "0b4b7f1393cff97c33891da2a0bf69c6ed241fda"
uuid = "6c6a2e73-6563-6170-7368-637461726353"
version = "1.1.0"

[[Serialization]]
uuid = "9e88b42a-f829-5b0c-bbe9-9e923198166b"

[[SharedArrays]]
deps = ["Distributed", "Mmap", "Random", "Serialization"]
uuid = "1a1011a3-84de-559e-8e89-a11a2f7dc383"

[[Showoff]]
deps = ["Dates", "Grisu"]
git-tree-sha1 = "91eddf657aca81df9ae6ceb20b959ae5653ad1de"
uuid = "992d4aef-0814-514b-bc4d-f2e9a6c4116f"
version = "1.0.3"

[[Sockets]]
uuid = "6462fe0b-24de-5631-8697-dd941f90decc"

[[SortingAlgorithms]]
deps = ["DataStructures"]
git-tree-sha1 = "b3363d7460f7d098ca0912c69b082f75625d7508"
uuid = "a2af1166-a08f-5f64-846c-94a0d3cef48c"
version = "1.0.1"

[[SparseArrays]]
deps = ["LinearAlgebra", "Random"]
uuid = "2f01184e-e22b-5df5-ae63-d93ebab69eaf"

[[StaticArrays]]
deps = ["LinearAlgebra", "Random", "Statistics"]
git-tree-sha1 = "3240808c6d463ac46f1c1cd7638375cd22abbccb"
uuid = "90137ffa-7385-5640-81b9-e52037218182"
version = "1.2.12"

[[Statistics]]
deps = ["LinearAlgebra", "SparseArrays"]
uuid = "10745b16-79ce-11e8-11f9-7d13ad32a3b2"

[[StatsAPI]]
git-tree-sha1 = "1958272568dc176a1d881acb797beb909c785510"
uuid = "82ae8749-77ed-4fe6-ae5f-f523153014b0"
version = "1.0.0"

[[StatsBase]]
deps = ["DataAPI", "DataStructures", "LinearAlgebra", "Missings", "Printf", "Random", "SortingAlgorithms", "SparseArrays", "Statistics", "StatsAPI"]
git-tree-sha1 = "8cbbc098554648c84f79a463c9ff0fd277144b6c"
uuid = "2913bbd2-ae8a-5f71-8c99-4fb6c76f3a91"
version = "0.33.10"

[[StructArrays]]
deps = ["Adapt", "DataAPI", "StaticArrays", "Tables"]
git-tree-sha1 = "2ce41e0d042c60ecd131e9fb7154a3bfadbf50d3"
uuid = "09ab397b-f2b6-538f-b94a-2f83cf4a842a"
version = "0.6.3"

[[Suppressor]]
git-tree-sha1 = "a819d77f31f83e5792a76081eee1ea6342ab8787"
uuid = "fd094767-a336-5f1f-9728-57cf17d0bbfb"
version = "0.2.0"

[[TOML]]
deps = ["Dates"]
uuid = "fa267f1f-6049-4f14-aa54-33bafae1ed76"

[[TableTraits]]
deps = ["IteratorInterfaceExtensions"]
git-tree-sha1 = "c06b2f539df1c6efa794486abfb6ed2022561a39"
uuid = "3783bdb8-4a98-5b6b-af9a-565f29a5fe9c"
version = "1.0.1"

[[Tables]]
deps = ["DataAPI", "DataValueInterfaces", "IteratorInterfaceExtensions", "LinearAlgebra", "TableTraits", "Test"]
git-tree-sha1 = "1162ce4a6c4b7e31e0e6b14486a6986951c73be9"
uuid = "bd369af6-aec1-5ad0-b16a-f7cc5008161c"
version = "1.5.2"

[[Tar]]
deps = ["ArgTools", "SHA"]
uuid = "a4e569a6-e804-4fa4-b0f3-eef7a1d5b13e"

[[Test]]
deps = ["InteractiveUtils", "Logging", "Random", "Serialization"]
uuid = "8dfed614-e22c-5e08-85e1-65c5234f0b40"

[[URIs]]
git-tree-sha1 = "97bbe755a53fe859669cd907f2d96aee8d2c1355"
uuid = "5c2747f8-b7ea-4ff2-ba2e-563bfd36b1d4"
version = "1.3.0"

[[UUIDs]]
deps = ["Random", "SHA"]
uuid = "cf7118a7-6976-5b1a-9a39-7adc72f591a4"

[[UnPack]]
git-tree-sha1 = "387c1f73762231e86e0c9c5443ce3b4a0a9a0c2b"
uuid = "3a884ed6-31ef-47d7-9d2a-63182c4928ed"
version = "1.0.2"

[[Unicode]]
uuid = "4ec0a83e-493e-50e2-b9ac-8f72acf5a8f5"

[[Wayland_jll]]
deps = ["Artifacts", "Expat_jll", "JLLWrappers", "Libdl", "Libffi_jll", "Pkg", "XML2_jll"]
git-tree-sha1 = "3e61f0b86f90dacb0bc0e73a0c5a83f6a8636e23"
uuid = "a2964d1f-97da-50d4-b82a-358c7fce9d89"
version = "1.19.0+0"

[[Wayland_protocols_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg", "Wayland_jll"]
git-tree-sha1 = "2839f1c1296940218e35df0bbb220f2a79686670"
uuid = "2381bf8a-dfd0-557d-9999-79630e7b1b91"
version = "1.18.0+4"

[[XML2_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Libiconv_jll", "Pkg", "Zlib_jll"]
git-tree-sha1 = "1acf5bdf07aa0907e0a37d3718bb88d4b687b74a"
uuid = "02c8fc9c-b97f-50b9-bbe4-9be30ff0a78a"
version = "2.9.12+0"

[[XSLT_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Libgcrypt_jll", "Libgpg_error_jll", "Libiconv_jll", "Pkg", "XML2_jll", "Zlib_jll"]
git-tree-sha1 = "91844873c4085240b95e795f692c4cec4d805f8a"
uuid = "aed1982a-8fda-507f-9586-7b0439959a61"
version = "1.1.34+0"

[[Xorg_libX11_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg", "Xorg_libxcb_jll", "Xorg_xtrans_jll"]
git-tree-sha1 = "5be649d550f3f4b95308bf0183b82e2582876527"
uuid = "4f6342f7-b3d2-589e-9d20-edeb45f2b2bc"
version = "1.6.9+4"

[[Xorg_libXau_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "4e490d5c960c314f33885790ed410ff3a94ce67e"
uuid = "0c0b7dd1-d40b-584c-a123-a41640f87eec"
version = "1.0.9+4"

[[Xorg_libXcursor_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg", "Xorg_libXfixes_jll", "Xorg_libXrender_jll"]
git-tree-sha1 = "12e0eb3bc634fa2080c1c37fccf56f7c22989afd"
uuid = "935fb764-8cf2-53bf-bb30-45bb1f8bf724"
version = "1.2.0+4"

[[Xorg_libXdmcp_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "4fe47bd2247248125c428978740e18a681372dd4"
uuid = "a3789734-cfe1-5b06-b2d0-1dd0d9d62d05"
version = "1.1.3+4"

[[Xorg_libXext_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg", "Xorg_libX11_jll"]
git-tree-sha1 = "b7c0aa8c376b31e4852b360222848637f481f8c3"
uuid = "1082639a-0dae-5f34-9b06-72781eeb8cb3"
version = "1.3.4+4"

[[Xorg_libXfixes_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg", "Xorg_libX11_jll"]
git-tree-sha1 = "0e0dc7431e7a0587559f9294aeec269471c991a4"
uuid = "d091e8ba-531a-589c-9de9-94069b037ed8"
version = "5.0.3+4"

[[Xorg_libXi_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg", "Xorg_libXext_jll", "Xorg_libXfixes_jll"]
git-tree-sha1 = "89b52bc2160aadc84d707093930ef0bffa641246"
uuid = "a51aa0fd-4e3c-5386-b890-e753decda492"
version = "1.7.10+4"

[[Xorg_libXinerama_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg", "Xorg_libXext_jll"]
git-tree-sha1 = "26be8b1c342929259317d8b9f7b53bf2bb73b123"
uuid = "d1454406-59df-5ea1-beac-c340f2130bc3"
version = "1.1.4+4"

[[Xorg_libXrandr_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg", "Xorg_libXext_jll", "Xorg_libXrender_jll"]
git-tree-sha1 = "34cea83cb726fb58f325887bf0612c6b3fb17631"
uuid = "ec84b674-ba8e-5d96-8ba1-2a689ba10484"
version = "1.5.2+4"

[[Xorg_libXrender_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg", "Xorg_libX11_jll"]
git-tree-sha1 = "19560f30fd49f4d4efbe7002a1037f8c43d43b96"
uuid = "ea2f1a96-1ddc-540d-b46f-429655e07cfa"
version = "0.9.10+4"

[[Xorg_libpthread_stubs_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "6783737e45d3c59a4a4c4091f5f88cdcf0908cbb"
uuid = "14d82f49-176c-5ed1-bb49-ad3f5cbd8c74"
version = "0.1.0+3"

[[Xorg_libxcb_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg", "XSLT_jll", "Xorg_libXau_jll", "Xorg_libXdmcp_jll", "Xorg_libpthread_stubs_jll"]
git-tree-sha1 = "daf17f441228e7a3833846cd048892861cff16d6"
uuid = "c7cfdc94-dc32-55de-ac96-5a1b8d977c5b"
version = "1.13.0+3"

[[Xorg_libxkbfile_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg", "Xorg_libX11_jll"]
git-tree-sha1 = "926af861744212db0eb001d9e40b5d16292080b2"
uuid = "cc61e674-0454-545c-8b26-ed2c68acab7a"
version = "1.1.0+4"

[[Xorg_xcb_util_image_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg", "Xorg_xcb_util_jll"]
git-tree-sha1 = "0fab0a40349ba1cba2c1da699243396ff8e94b97"
uuid = "12413925-8142-5f55-bb0e-6d7ca50bb09b"
version = "0.4.0+1"

[[Xorg_xcb_util_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg", "Xorg_libxcb_jll"]
git-tree-sha1 = "e7fd7b2881fa2eaa72717420894d3938177862d1"
uuid = "2def613f-5ad1-5310-b15b-b15d46f528f5"
version = "0.4.0+1"

[[Xorg_xcb_util_keysyms_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg", "Xorg_xcb_util_jll"]
git-tree-sha1 = "d1151e2c45a544f32441a567d1690e701ec89b00"
uuid = "975044d2-76e6-5fbe-bf08-97ce7c6574c7"
version = "0.4.0+1"

[[Xorg_xcb_util_renderutil_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg", "Xorg_xcb_util_jll"]
git-tree-sha1 = "dfd7a8f38d4613b6a575253b3174dd991ca6183e"
uuid = "0d47668e-0667-5a69-a72c-f761630bfb7e"
version = "0.3.9+1"

[[Xorg_xcb_util_wm_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg", "Xorg_xcb_util_jll"]
git-tree-sha1 = "e78d10aab01a4a154142c5006ed44fd9e8e31b67"
uuid = "c22f9ab0-d5fe-5066-847c-f4bb1cd4e361"
version = "0.4.1+1"

[[Xorg_xkbcomp_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg", "Xorg_libxkbfile_jll"]
git-tree-sha1 = "4bcbf660f6c2e714f87e960a171b119d06ee163b"
uuid = "35661453-b289-5fab-8a00-3d9160c6a3a4"
version = "1.4.2+4"

[[Xorg_xkeyboard_config_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg", "Xorg_xkbcomp_jll"]
git-tree-sha1 = "5c8424f8a67c3f2209646d4425f3d415fee5931d"
uuid = "33bec58e-1273-512f-9401-5d533626f822"
version = "2.27.0+4"

[[Xorg_xtrans_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "79c31e7844f6ecf779705fbc12146eb190b7d845"
uuid = "c5fb5394-a638-5e4d-96e5-b29de1b5cf10"
version = "1.4.0+3"

[[Zlib_jll]]
deps = ["Libdl"]
uuid = "83775a58-1f1d-513f-b197-d71354ab007a"

[[Zstd_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "cc4bf3fdde8b7e3e9fa0351bdeedba1cf3b7f6e6"
uuid = "3161d3a3-bdf6-5164-811a-617609db77b4"
version = "1.5.0+0"

[[libass_jll]]
deps = ["Artifacts", "Bzip2_jll", "FreeType2_jll", "FriBidi_jll", "HarfBuzz_jll", "JLLWrappers", "Libdl", "Pkg", "Zlib_jll"]
git-tree-sha1 = "5982a94fcba20f02f42ace44b9894ee2b140fe47"
uuid = "0ac62f75-1d6f-5e53-bd7c-93b484bb37c0"
version = "0.15.1+0"

[[libfdk_aac_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "daacc84a041563f965be61859a36e17c4e4fcd55"
uuid = "f638f0a6-7fb0-5443-88ba-1cc74229b280"
version = "2.0.2+0"

[[libpng_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg", "Zlib_jll"]
git-tree-sha1 = "94d180a6d2b5e55e447e2d27a29ed04fe79eb30c"
uuid = "b53b4c65-9356-5827-b1ea-8c7a1a84506f"
version = "1.6.38+0"

[[libvorbis_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Ogg_jll", "Pkg"]
git-tree-sha1 = "c45f4e40e7aafe9d086379e5578947ec8b95a8fb"
uuid = "f27f6e37-5d2b-51aa-960f-b287f2bc3b7a"
version = "1.3.7+0"

[[nghttp2_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "8e850ede-7688-5339-a07c-302acd2aaf8d"

[[p7zip_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "3f19e933-33d8-53b3-aaab-bd5110c3b7a0"

[[x264_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "4fea590b89e6ec504593146bf8b988b2c00922b2"
uuid = "1270edf5-f2f9-52d2-97e9-ab00b5d0237a"
version = "2021.5.5+0"

[[x265_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "ee567a171cce03570d77ad3a43e90218e38937a9"
uuid = "dfaa095f-4041-5dcd-9319-2fabd8486b76"
version = "3.5.0+0"

[[xkbcommon_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg", "Wayland_jll", "Wayland_protocols_jll", "Xorg_libxcb_jll", "Xorg_xkeyboard_config_jll"]
git-tree-sha1 = "ece2350174195bb31de1a63bea3a41ae1aa593b6"
uuid = "d8fb68d0-12a3-5cfd-a85a-d49703b185fd"
version = "0.9.1+5"
"""

# ╔═╡ Cell order:
# ╟─f37ba7bb-0484-4a53-bc8b-94b06d685ac0
# ╟─9e04db5d-0662-4a39-af3b-85e68f948ebc
# ╠═0835d14d-f0c3-4467-bdd6-056b52a2fe09
# ╟─4b21be10-87ef-4926-b946-ef0f3fc0dce2
# ╠═104828fd-61d1-48af-879c-719b95cc1074
# ╠═950621c4-b1e2-4481-bdae-c434fc0bfb7d
# ╠═e36ebf1c-a750-40b4-8815-8bb3dee3910f
# ╟─23fc85fb-8384-43cb-9bc1-f8c14b08699b
# ╟─bcdf14f8-a414-4314-9524-4ce071d41e22
# ╠═e3186d2e-be3e-4beb-a7b6-fbd3e0b01e0c
# ╟─10d7fdda-0a11-4be8-a939-3628494a781e
# ╠═6ac7900b-cff2-4b5c-b3b5-bf55ba1f5951
# ╟─9729eafe-ffcd-4619-aa93-cec5ed258c4d
# ╟─9bb610b1-9e89-45e7-85a1-9c8475f27a8a
# ╠═3f0edfc5-cf3d-4f06-a89f-18f18cebc736
# ╟─84c568c0-2a26-4e9d-9129-6cc120e919f7
# ╟─e99f1365-4cce-4be2-b15a-ca68276e17c4
# ╟─a26208c9-0dfc-4db6-940b-540c0ff09a6c
# ╠═4d5fc84b-0471-4d20-bfe5-a4d0af538a78
# ╟─6cb5b0db-c8ca-4b21-bdb7-5b79718189e5
# ╟─78096a1e-8780-4c15-a29d-1e771ba7dab5
# ╟─c8c3b803-4595-429b-a7cb-6e805d95b289
# ╟─5f5ccc4f-256d-4c7b-a789-85e3bfd3395a
# ╠═0e605739-1df3-45b4-9810-b3311e402bbc
# ╟─89d811d7-7ce7-4a5a-9be9-69f0612da017
# ╠═b1b43e7e-bae6-4b9d-a382-41b44ece2cab
# ╠═63833cdb-b8d5-40b0-ad5f-1897c5324f63
# ╟─e0f0437c-e463-43b2-b680-a045d27db9c8
# ╟─d43f3834-ae39-46aa-bfd0-03ffd8ef0ce6
# ╟─4bb63fd2-3f66-4a56-b3ea-c40379273f0f
# ╟─8e7ab41d-6d97-4f9a-96a1-4348755c56c0
# ╟─ce12316a-73a8-45ec-8c2f-5d920009516b
# ╟─2c1cff43-2ac1-4b42-9db5-c75cdcc2f7cd
# ╟─e3eb842f-e470-4b3e-8da4-275427da841d
# ╟─fae5b36d-5dc8-4027-8f7d-e2eb9531242c
# ╟─43a4cbba-b1dc-4cc8-8a5c-0494b9be9343
# ╠═d7a39507-966a-4c63-a10e-1ceee329e65a
# ╟─f82ff56a-a021-43fd-8a7b-cc0b2885982f
# ╟─43f8a33e-f1c7-4529-960e-9cf75979bba6
# ╠═1569124f-e948-4cae-8bc6-0076e3c214db
# ╟─6edf3258-07cd-4a2d-812c-4bbb71ee43a7
# ╠═23afcd0c-e2ad-4cf2-9a7e-cdfdf6cb927e
# ╟─01bc7388-0125-4ee5-8b20-14503846e2ea
# ╟─013299b9-f22d-4a9c-9b24-09d6741646a9
# ╟─d7e2163d-d54c-46f9-a777-efdf56a1b7c4
# ╠═5b79a4ed-c4ca-4f95-b5ea-df8f8bdb3652
# ╠═8ee2d7bf-06b7-414f-bf27-02347dbf826b
# ╠═958489d0-f256-4cfa-86e8-5a5b0e2c8b5b
# ╟─ea771d50-e160-4302-b381-c97242b2d29e
# ╠═cb34bcb1-938f-48ef-88a0-fc86b885cf0b
# ╟─e44dd6aa-f4bd-417d-87db-0183b287925a
# ╟─26ca4413-1a2f-4b29-81af-4aaab018bbf2
# ╠═1ccc18d1-0357-4b76-b275-a9443c585530
# ╠═9576dd5a-7f41-43fb-aebb-777439655f85
# ╟─82f53619-aa7b-4c61-9857-39b75b455b68
# ╠═0e5641d9-8d14-49ce-9c6c-e5edf1f9b27d
# ╟─22b44c84-2b5d-47f2-a23d-e90f80a1021e
# ╟─6252ba9a-44c4-4485-bf38-b89a9b52442e
# ╠═cc1a13ee-7753-4433-a058-ee66ba5eacfe
# ╟─52dd0fba-6011-4179-b018-a6ea7de2f48a
# ╠═e28f45a4-63db-4bf4-b1d4-56b13faaa98f
# ╠═8801443b-3e2a-4fbe-bfe1-3258a2df6df2
# ╟─150620fc-f1ed-4ad2-9cea-e2703114811d
# ╠═3bfd59f7-ab68-4d87-876c-8043714b7c8b
# ╠═a0cc1184-5d51-4f88-91c0-68f222b8cbc6
# ╠═04727f53-ee16-4c66-bc6f-90a9c3a0390c
# ╠═c6914850-e34a-4a65-bc36-3c25f94bcd05
# ╠═1328f5d0-3c6e-4a6c-83c5-f9b5862850b6
# ╟─bafb816a-7e43-48a5-8e1d-c47338cc546b
# ╠═d6e456e3-2a7a-45ab-9733-72730cef939d
# ╟─3564cc7e-05f2-41f1-8368-6098c5d60c5d
# ╠═13623193-7cc4-40a7-ad46-622c489c2bd3
# ╠═4154cea2-651c-4111-87ee-314c3859efc2
# ╟─2c8adf6f-c24a-44a5-8dee-6e3577b0a4c6
# ╠═5bc32c34-c9ef-4d30-a8bc-056059bacc6a
# ╟─58942ba0-4ee1-4258-98a7-90fb019d90c0
# ╠═47eef67b-b8f0-4814-add0-5be91a804b10
# ╠═f430e061-4b07-4a1b-b10c-289511e22715
# ╟─588f88bd-68e2-4fc8-bb45-098319ecc09b
# ╠═cd4dc17e-e7a3-4ca7-92ab-c00db1f7cf6a
# ╟─23492f0e-c3a2-4adc-8d64-913e770a31dd
# ╟─5cf146f1-91ff-447b-af3c-4ef76145cd81
# ╟─30edc01b-4fff-4a0a-8bfd-99d35c65fa68
# ╠═e21c6438-127d-4d18-8f17-2a9fc4ab2ef6
# ╠═0ff5363b-666e-4100-90ea-67736762d3a5
# ╟─f9d5666e-bcb6-4b67-9d01-9a05915bcfd3
# ╠═a3384734-5b15-4faf-b257-78309acea8b7
# ╠═99cdd6a8-4351-45bc-9272-bf16ef8a944a
# ╠═1b617085-87d0-4368-8ae3-905b05967f82
# ╟─1f212400-7737-437a-b3ac-6b67d305ca24
# ╠═5b0dfffb-f0e0-4bd0-96f5-531f410efbee
# ╟─a8bfd1e1-ca26-47d3-a43f-3ae8014e1c12
# ╠═ff3514e5-fc61-4628-8f81-58a2243c3e92
# ╟─796f5bb7-e2b7-4206-b4d2-08a68d4f3b7d
# ╟─747d9462-bcad-4486-bab2-8f855d13da4c
# ╠═b2a95cf0-f907-4a79-9edd-b2ca8700b727
# ╠═1fd3a0c6-5c31-4e86-b3b8-396bbf8ac23f
# ╟─4fdfbe03-d9ae-44ef-b6eb-d16a89c1f7d8
# ╟─3d7940e8-fe07-443e-8e5d-57330152a563
# ╠═2f1dc64a-ede2-4963-9485-31feebfd0594
# ╟─023f07b5-0b40-449f-87e9-195f208c8d1d
# ╠═81028a2b-360e-4b92-b8a4-6730b4dc9400
# ╠═8f8c0e3a-239e-48dd-9a89-d01139330794
# ╟─aaf6db88-3c88-43ce-8710-5b22a4812687
# ╠═8df1aedb-6451-4fcf-8f93-ec9a1df2f307
# ╟─918b7df4-0960-40ad-ac88-4381c6e5ccfa
# ╟─57e25af6-9947-439b-b80c-d107c6dcdc4e
# ╟─c5a0b2f3-c038-4754-9683-958d1ed39c52
# ╠═65df57f8-1a4c-495d-81e1-0b57262737cc
# ╟─ff691624-c2a7-4af7-9952-4c882306056e
# ╠═bd0da121-384f-48b3-981f-86269c7a2d78
# ╟─8f0ec35a-1ef1-4607-9151-290e4a2b1098
# ╠═7f9bca89-bf70-42c6-9f97-8c2d929a7e52
# ╟─1ad7145f-db2b-4d57-a2ce-13173bf1ba80
# ╟─4bb03619-f3d4-4249-a8ac-42070c941654
# ╠═8beb5252-5f85-45e8-b23b-29de2437cbc3
# ╟─d5cb5c24-c384-4806-beb8-27c7516744c2
# ╟─f741b80b-d322-4fb2-bfc7-ad5d8d26350c
# ╠═274d3ddb-df22-4209-a6c4-baeb152a5d11
# ╠═fe46e288-c66c-4665-988d-12ab4f2abd25
# ╠═f4b003a5-d861-4e4a-b9ea-b71184c3e3ed
# ╠═8373ffb0-15f2-40cf-bd2b-ce7f8be2107a
# ╠═fd8018c5-9bd7-4f9a-9ccd-afd2bc013b4a
# ╠═28a7f31b-4fda-41d2-acf0-045ee206f6dc
# ╟─37648d4e-f776-47ec-89f2-22123dc6ae64
# ╠═a1e928fd-ace2-4253-99d5-702b461f8528
# ╠═5f5191a9-a676-4040-8fd5-bf6e9bbff555
# ╠═91b7ebbe-54c3-4bae-8c0c-3de353858f86
# ╠═e3735e4b-7f60-4843-ac9b-36c8a46e3274
# ╠═a39267d2-60a0-4b91-b117-b0b51d7741d1
# ╠═1d212b01-788d-4292-948f-893bca319e9e
# ╟─9ec85962-500a-41d3-b44a-c7e29b588d53
# ╟─1fccacaf-ba57-4a1b-9e36-16ae2a655dab
# ╠═5fe5b01a-6675-4314-88db-f6521b3d4e89
# ╟─aac25f61-36d3-4d52-a3c5-353c451f065f
# ╠═ce92c089-9ebe-4381-a55d-0b97b6b7010e
# ╠═5e3f4691-e528-4b2d-a1b4-e6462bf26a5b
# ╟─f10ed432-4b04-4dd5-bfe1-94c7d47165fb
# ╟─e9520732-40b8-4b16-82e9-cbb1e5b91486
# ╟─37ca947a-594a-4340-b464-41b6a4670c86
# ╠═4adf7058-f572-4082-8f6b-2215f7feb83d
# ╟─741c5677-5295-4499-9881-06830234a11c
# ╠═6c62eeda-dc6a-4b4c-b7e6-5e08e3f66b31
# ╟─46eee524-44c1-4589-b7a6-cad77dafa79c
# ╟─b0d99a85-798d-45b2-83d0-318f5ddb9347
# ╟─6e2a733c-7a9c-4e94-9a6b-eb04c4a90513
# ╟─ffd21a68-03da-42cb-a1ae-171db4b58e98
# ╠═af904775-c711-4810-aab3-89bdf36e68df
# ╠═f7f7b175-7541-444c-b1f6-3973a96d616d
# ╟─8c053ef8-e6d6-4aee-8246-ac6a7296aac6
# ╟─b78b5950-a9c2-4327-9880-05246fd8dd85
# ╠═f942d668-4535-4c80-81dc-882b1bcab2a2
# ╠═9b4d7366-0648-48d2-9e30-83b95ccfecaa
# ╟─13935ef8-970d-4644-87ac-4ff87f04af08
# ╠═8ab7c2c3-58ed-42a7-9a81-e2b1bd8d62d2
# ╟─99e7401a-2419-4a6b-9871-3c3ddb52357e
# ╟─1073a216-8259-45d1-87c6-14e6b28ac62c
# ╠═45a2d33d-3ef2-45b3-b1d7-713bc122cbeb
# ╟─abffb029-023c-4a28-ace8-5e5f469dce2b
# ╠═0d12115d-b8fa-47f6-8e69-2050a82a5417
# ╟─32b9d72b-9cff-4857-a45b-1baa1949b046
# ╠═ef05b082-fbba-49a7-8622-d552b64fef23
# ╠═da5c4f59-ea4b-4929-9d41-8b860a8abf18
# ╟─b722af3e-8ced-429c-875e-4b83c9479160
# ╠═be787cd6-6b32-4395-92d6-334e277708bb
# ╟─328db758-b0c1-482f-918c-98cc2c42c0f1
# ╠═d6099494-9e9c-43c3-bf8d-99b8badd81c9
# ╟─4b5c5e9c-9cd0-45ee-bcba-2e4523308020
# ╠═5684bbdc-8b06-4051-8333-809172ea4a26
# ╟─461a74d0-4e9d-44c0-93e1-6a91b91d04ab
# ╟─b0eccdc2-40bc-44d7-8a72-3e059a4214ab
# ╟─5898c143-9d1c-40bb-9783-2a13a11d42f0
# ╠═d93a8dca-9c63-4551-87e8-9939a765bef1
# ╠═0cac30f1-9101-4ba3-accc-52621bc1d16f
# ╟─35e533c3-8f81-4ea2-b6fc-3dbdca527d9f
# ╟─2c34baa9-2645-4e68-9134-8eb2605b7a26
# ╟─00000000-0000-0000-0000-000000000001
# ╟─00000000-0000-0000-0000-000000000002
