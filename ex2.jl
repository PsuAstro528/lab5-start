### A Pluto.jl notebook ###
# v0.20.17

using Markdown
using InteractiveUtils

# ╔═╡ 0cac30f1-9101-4ba3-accc-52621bc1d16f
begin
	using PlutoUI, PlutoTest, PlutoTeachingTools, PlutoLinks

	using BenchmarkTools
	using JET
	using UnPack
	using Profile, ProfileCanvas 
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
	KeplerEqn = @ingredients "./src/calc_rv.jl"
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
	#Δrv = rvs_pred.-rvs_obs
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
While there is a lot here, we can be on the lookout for variables labeled '::ANY', meaning the compiler can't infer what type they'll have.  As a result, future calculations that depend on these variables can not be optimized for the specific types.  In this case, `times`, `rvs_obs`, and `σ_rvs` have type Any.  This causes `rvs_pred`, `Δrv` and `χ²` to also have type Any.  """

# ╔═╡ e99f1365-4cce-4be2-b15a-ca68276e17c4
protip(md"Although, there aren't examples here, we should also be on the lookout for variables labeled '::Union{...}', indicating that the compiler was able to narrow down the possible types to a list, but couldn't identify one specific type.  If you're using a terminal that supports color, then it will indicate both `Any` and `Union` types in red, so they're easy to spot.
")

# ╔═╡ a26208c9-0dfc-4db6-940b-540c0ff09a6c
md"""
In an effort to make it easier to find lines of code with type instability, the [JET.jl](https://aviatesk.github.io/JET.jl/dev/) package provides a macro `@report_opt`.
"""

# ╔═╡ 4d5fc84b-0471-4d20-bfe5-a4d0af538a78
let
	calc_χ²_v0
	@report_opt calc_χ²_v0(P,K,ecc,ω,M0)
end

# ╔═╡ 95d97786-6048-4203-b154-4d3e120d8bed
md"""
It reports each time that julia is having to figure out types at runtime rather than at compile time ("runtime dispatch detected").  If you scroll to the right, you'll see the filename, cell id and line number within the cell (e.g., `calc_χ²_v0...ex2.jl#==#e3186d2e-be3e-4beb-a7b6-fbd3e0b01e0c:5` indicates line 5 of the cell defining `calc_χ²_v0` in the notebook 'ex2.jl').
"""

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
let
	calc_χ²_v1a
	@report_opt calc_χ²_v1a(P,K,ecc,ω,M0)
end

# ╔═╡ e0f0437c-e463-43b2-b680-a045d27db9c8
md"""
This time it shouldn't detect any runtime dispatch.  We can compare the runtime of the type unstable and type stable versions of the function below.
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
let
	calc_χ²_v2a
	@report_opt calc_χ²_v2a(times,rvs_obs,σ_rvs,P,K,ecc,ω,M0)
end

# ╔═╡ 6edf3258-07cd-4a2d-812c-4bbb71ee43a7
md"""
Again, it should show no runtime dispatches were necessary.  We could also see this almost as easily using `@code_warntype` (and noting there's not red `Any` or `Union` types).
"""

# ╔═╡ 23afcd0c-e2ad-4cf2-9a7e-cdfdf6cb927e
with_terminal() do
	calc_χ²_v2a
	@code_warntype calc_χ²_v2a(times,rvs_obs,σ_rvs,P,K,ecc,ω,M0)
end

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
let
	calc_χ²_v2b
	data = (times,rvs_obs,σ_rvs)
	param = (P,K,ecc,ω,M0)
	@report_opt calc_χ²_v2b(data,param)
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
		elseif typeof(data_as_named_tuple) <: Dict
                warning_box(md"Remember to use a `NamedTuple` rather than a `Dict` here.")

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
param_as_dict = missing  # TODO:  replace with your code

# ╔═╡ 52dd0fba-6011-4179-b018-a6ea7de2f48a
begin
        if !@isdefined(param_as_dict)
                var_not_defined(:param_as_dict)
        elseif ismissing(param_as_dict)
                still_missing()
		elseif typeof(param_as_dict) <: NamedTuple
                warning_box(md"Remember to use a `Dict` rather than a `NamedTuple` here.")
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
let
	calc_χ²_v2c
	@report_opt calc_χ²_v2c(data_as_named_tuple,param_as_named_tuple)
end

# ╔═╡ 1328f5d0-3c6e-4a6c-83c5-f9b5862850b6
let
	calc_χ²_v2c
	@report_opt calc_χ²_v2c(data_as_dict,param_as_dict)
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
The above pattern of using `Dict`'s or `NamedTuple`'s is pretty useful.  Sometimes it may be useful to create a custom type that will contain our variables.  This allows us to create convenience functions, such as non-trivial constructors that can check if the inputs are valid.  It's a little more work, so I'll demonstrate below.
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
The second error message makes it clear that we did not call `calc_χ²_v2d` with valid arguments.
"""

# ╔═╡ 3d7940e8-fe07-443e-8e5d-57330152a563
md"2e.  What do you expect to happen if we check `calc_χ²_v2d` for type instability with `@report_opt` when passing `rvdata_custom1` and `param_custom`?  What do you expect for memory allocations?"

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
Now our custom structure results in no type instability and no more memory allocations than before, and our performance to date (or at least comparable to it).  However, we could make our custom structure even more generic, as shown below.
"""

# ╔═╡ e9520732-40b8-4b16-82e9-cbb1e5b91486
md"### More generic concrete custom struct"

# ╔═╡ 37ca947a-594a-4340-b464-41b6a4670c86
md"""
We can make our custom struct even more generic, while maintaining type stability and avoiding excess allocations as demonstrated below.  This can be useful for allowing us to pass a [view](https://docs.julialang.org/en/v1/base/arrays/#Views-(SubArrays-and-other-view-types)) into a pre-allocated arrays, potentially eliminating the need for copying data.
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
Let's jump to the total time inside the `calc_χ²...` function and the time spent allocating arrays.
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
md"We can now overload the `calc_χ²_v2d` function so that it can take advantage of the pre-allocated workspace, if we pass data in the form of a `RvData_concrete_v3`.  Note that the previous function will still be called if we pass some other form of AbstractRvData."

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
	calc_χ²_v2d,rvdata_custom1,param_custom
	@report_opt calc_χ²_v2d(rvdata_custom1,param_custom)
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
let
	calc_χ²_v2d, param_custom
	data = RvData_abs_vec_anys(times,rvs_obs,σ_rvs)
	@report_opt calc_χ²_v2d(data,param_custom)
end

# ╔═╡ fd8018c5-9bd7-4f9a-9ccd-afd2bc013b4a
let
	calc_χ²_v2d, param_custom
	data = RvData_vec_anys(times,rvs_obs,σ_rvs)
	@report_opt calc_χ²_v2d(data,param_custom)
end

# ╔═╡ 28a7f31b-4fda-41d2-acf0-045ee206f6dc
let
	calc_χ²_v2d, param_custom
	data = RvData_abs_vec(times,rvs_obs,σ_rvs)
	@report_opt calc_χ²_v2d(data,param_custom)
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

# ╔═╡ ce92c089-9ebe-4381-a55d-0b97b6b7010e
let
	data = RvData_concrete_v1(times,rvs_obs,σ_rvs)
	calc_χ²_v2d( data, param_custom)
	@allocated calc_χ²_v2d( data, param_custom)
end

# ╔═╡ 5e3f4691-e528-4b2d-a1b4-e6462bf26a5b
let
	calc_χ²_v2d
	data = RvData_concrete_v1(times,rvs_obs,σ_rvs)
	param = RvParamKeplerian(P,K,ecc,ω,M0)
	@report_opt calc_χ²_v2d(data,param_custom)
end

# ╔═╡ a39267d2-60a0-4b91-b117-b0b51d7741d1
let
	calc_χ²_v2d, param_custom
	data = RvData_concrete_v1(times,rvs_obs,σ_rvs)
	param = RvParamKeplerian(P,K,ecc,ω,M0)
	@benchmark calc_χ²_v2d($data,$param_custom)
end

# ╔═╡ 6c62eeda-dc6a-4b4c-b7e6-5e08e3f66b31
let
	data = RvData_concrete_v2(times,rvs_obs,σ_rvs)
	calc_χ²_v2d( data, param_custom)
	@allocated calc_χ²_v2d( data, param_custom)
end

# ╔═╡ 46eee524-44c1-4589-b7a6-cad77dafa79c
let
	calc_χ²_v2d
	data = RvData_concrete_v2(times,rvs_obs,σ_rvs)
	param = RvParamKeplerian(P,K,ecc,ω,M0)
	@report_opt calc_χ²_v2d(data,param)
end

# ╔═╡ 1d212b01-788d-4292-948f-893bca319e9e
let
	calc_χ²_v2d, param_custom
	data = RvData_concrete_v2(times,rvs_obs,σ_rvs)
	param = RvParamKeplerian(P,K,ecc,ω,M0)
	@benchmark calc_χ²_v2d($data,$param_custom)
end

# ╔═╡ 9ec478b6-2762-45a4-b1b9-8d29d78aeb13
function profile_calc_χ²_v2d(data, param_custom; n::Integer=10^4)
	for i in 1:n
		calc_χ²_v2d( data, param_custom)
	end
end

# ╔═╡ 0046d996-9881-47a0-b4bd-b3f054e45ca1
let
	Profile.clear()
	#Profile.init(delay=1/10^8)
	data = RvData_concrete_v2(times,rvs_obs,σ_rvs)
	calc_χ²_v2d( data, param_custom)
	@profview profile_calc_χ²_v2d(data, param_custom)
end

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
	@report_opt calc_χ²_v2d(data,param_custom)
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
if !ismissing(data_as_dict) && !ismissing(param_as_dict)
	data_as_dict, param_as_dict,
	ready_to_test_calc_χ² && @test calc_χ²_v0(P,K,ecc,ω,M0) == calc_χ²_v2c(data_as_dict,param_as_dict)
end

# ╔═╡ a0cc1184-5d51-4f88-91c0-68f222b8cbc6
if !ismissing(data_as_named_tuple) && !ismissing(param_as_named_tuple)
	data_as_named_tuple,param_as_named_tuple
	ready_to_test_calc_χ² && @test calc_χ²_v0(P,K,ecc,ω,M0) == calc_χ²_v2c(data_as_named_tuple,param_as_named_tuple)
end

# ╔═╡ 04727f53-ee16-4c66-bc6f-90a9c3a0390c
if !ismissing(data_as_dict) && !ismissing(param_as_named_tuple)
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
	@test calc_χ²_v0(P,K,ecc,ω,M0) ≈ calc_χ²_v2d(data,param_custom)
end

# ╔═╡ 00000000-0000-0000-0000-000000000001
PLUTO_PROJECT_TOML_CONTENTS = """
[deps]
BenchmarkTools = "6e4b80f9-dd63-53aa-95a3-0cdb28fa8baf"
JET = "c3a54625-cd67-489e-a8e7-0a5a0ff4e31b"
LazyArrays = "5078a376-72f3-5289-bfd5-ec5146d43c02"
PlutoLinks = "0ff47ea0-7a50-410d-8455-4348d5de0420"
PlutoTeachingTools = "661c6b06-c737-4d37-b85c-46df65de6f69"
PlutoTest = "cb4044da-4d16-4ffa-a6a3-8cad7f73ebdc"
PlutoUI = "7f904dfe-b85e-4ff6-b463-dae2292396a8"
Profile = "9abbd945-dff8-562f-b5e8-e1ebf5ef1b79"
ProfileCanvas = "efd6af41-a80b-495e-886c-e51b0c7d77a3"
Random = "9a3f8284-a2c9-5f02-9a11-845980a1fd5c"
UnPack = "3a884ed6-31ef-47d7-9d2a-63182c4928ed"

[compat]
BenchmarkTools = "~1.6.0"
JET = "~0.9.19"
LazyArrays = "~2.6.2"
PlutoLinks = "~0.1.6"
PlutoTeachingTools = "~0.4.5"
PlutoTest = "~0.2.2"
PlutoUI = "~0.7.71"
ProfileCanvas = "~0.1.6"
UnPack = "~1.0.2"
"""

# ╔═╡ 00000000-0000-0000-0000-000000000002
PLUTO_MANIFEST_TOML_CONTENTS = """
# This file is machine-generated - editing it directly is not advised

julia_version = "1.11.2"
manifest_format = "2.0"
project_hash = "a9636a6461b543466fda206dbd273a3021eb3c34"

[[deps.AbstractPlutoDingetjes]]
deps = ["Pkg"]
git-tree-sha1 = "6e1d2a35f2f90a4bc7c2ed98079b2ba09c35b83a"
uuid = "6e696c72-6542-2067-7265-42206c756150"
version = "1.3.2"

[[deps.ArgTools]]
uuid = "0dad84c5-d112-42e6-8d28-ef12dabb789f"
version = "1.1.2"

[[deps.ArrayLayouts]]
deps = ["FillArrays", "LinearAlgebra", "StaticArrays"]
git-tree-sha1 = "120e392af69350960b1d3b89d41dcc1d66543858"
uuid = "4c555306-a7a7-4459-81d9-ec55ddd5c99a"
version = "1.11.2"
weakdeps = ["SparseArrays"]

    [deps.ArrayLayouts.extensions]
    ArrayLayoutsSparseArraysExt = "SparseArrays"

[[deps.Artifacts]]
uuid = "56f22d72-fd6d-98f1-02f0-08ddc0907c33"
version = "1.11.0"

[[deps.Base64]]
uuid = "2a0f44e3-6c83-55bd-87e4-b1978d98bd5f"
version = "1.11.0"

[[deps.BenchmarkTools]]
deps = ["Compat", "JSON", "Logging", "Printf", "Profile", "Statistics", "UUIDs"]
git-tree-sha1 = "e38fbc49a620f5d0b660d7f543db1009fe0f8336"
uuid = "6e4b80f9-dd63-53aa-95a3-0cdb28fa8baf"
version = "1.6.0"

[[deps.CodeTracking]]
deps = ["InteractiveUtils", "UUIDs"]
git-tree-sha1 = "062c5e1a5bf6ada13db96a4ae4749a4c2234f521"
uuid = "da1fd8a2-8d9e-5ec2-8556-3022fb5608a2"
version = "1.3.9"

[[deps.ColorTypes]]
deps = ["FixedPointNumbers", "Random"]
git-tree-sha1 = "67e11ee83a43eb71ddc950302c53bf33f0690dfe"
uuid = "3da002f7-5984-5a60-b8a6-cbb66c0b333f"
version = "0.12.1"
weakdeps = ["StyledStrings"]

    [deps.ColorTypes.extensions]
    StyledStringsExt = "StyledStrings"

[[deps.Compat]]
deps = ["TOML", "UUIDs"]
git-tree-sha1 = "0037835448781bb46feb39866934e243886d756a"
uuid = "34da2185-b29b-5c13-b0c7-acf172513d20"
version = "4.18.0"
weakdeps = ["Dates", "LinearAlgebra"]

    [deps.Compat.extensions]
    CompatLinearAlgebraExt = "LinearAlgebra"

[[deps.CompilerSupportLibraries_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "e66e0078-7015-5450-92f7-15fbd957f2ae"
version = "1.1.1+0"

[[deps.Dates]]
deps = ["Printf"]
uuid = "ade2ca70-3891-5945-98fb-dc099432e06a"
version = "1.11.0"

[[deps.Downloads]]
deps = ["ArgTools", "FileWatching", "LibCURL", "NetworkOptions"]
uuid = "f43a241f-c20a-4ad4-852c-f6b1247861c6"
version = "1.6.0"

[[deps.FileWatching]]
uuid = "7b1f6079-737a-58dc-b8bc-7a2ca5c1b5ee"
version = "1.11.0"

[[deps.FillArrays]]
deps = ["LinearAlgebra"]
git-tree-sha1 = "6a70198746448456524cb442b8af316927ff3e1a"
uuid = "1a297f60-69ca-5386-bcde-b61e274b549b"
version = "1.13.0"

    [deps.FillArrays.extensions]
    FillArraysPDMatsExt = "PDMats"
    FillArraysSparseArraysExt = "SparseArrays"
    FillArraysStatisticsExt = "Statistics"

    [deps.FillArrays.weakdeps]
    PDMats = "90014a1f-27ba-587c-ab20-58faa44d9150"
    SparseArrays = "2f01184e-e22b-5df5-ae63-d93ebab69eaf"
    Statistics = "10745b16-79ce-11e8-11f9-7d13ad32a3b2"

[[deps.FixedPointNumbers]]
deps = ["Statistics"]
git-tree-sha1 = "05882d6995ae5c12bb5f36dd2ed3f61c98cbb172"
uuid = "53c48c17-4a7d-5ca2-90c5-79b7896eea93"
version = "0.8.5"

[[deps.Format]]
git-tree-sha1 = "9c68794ef81b08086aeb32eeaf33531668d5f5fc"
uuid = "1fa38f19-a742-5d3f-a2b9-30dd87b9d5f8"
version = "1.3.7"

[[deps.Hyperscript]]
deps = ["Test"]
git-tree-sha1 = "179267cfa5e712760cd43dcae385d7ea90cc25a4"
uuid = "47d2ed2b-36de-50cf-bf87-49c2cf4b8b91"
version = "0.0.5"

[[deps.HypertextLiteral]]
deps = ["Tricks"]
git-tree-sha1 = "7134810b1afce04bbc1045ca1985fbe81ce17653"
uuid = "ac1192a8-f4b3-4bfe-ba22-af5b92cd3ab2"
version = "0.9.5"

[[deps.IOCapture]]
deps = ["Logging", "Random"]
git-tree-sha1 = "b6d6bfdd7ce25b0f9b2f6b3dd56b2673a66c8770"
uuid = "b5f81e59-6552-4d32-b1f0-c071b021bf89"
version = "0.2.5"

[[deps.InteractiveUtils]]
deps = ["Markdown"]
uuid = "b77e0a4c-d291-57a0-90e8-8db25a27a240"
version = "1.11.0"

[[deps.JET]]
deps = ["CodeTracking", "InteractiveUtils", "JuliaInterpreter", "JuliaSyntax", "LoweredCodeUtils", "MacroTools", "Pkg", "PrecompileTools", "Preferences", "Test"]
git-tree-sha1 = "c5bc131290ca461230634d6a44a69f3c9a8d8577"
uuid = "c3a54625-cd67-489e-a8e7-0a5a0ff4e31b"
version = "0.9.19"

    [deps.JET.extensions]
    JETCthulhuExt = "Cthulhu"
    JETReviseExt = "Revise"

    [deps.JET.weakdeps]
    Cthulhu = "f68482b8-f384-11e8-15f7-abe071a5a75f"
    Revise = "295af30f-e4ad-537b-8983-00126c2a3abe"

[[deps.JSON]]
deps = ["Dates", "Mmap", "Parsers", "Unicode"]
git-tree-sha1 = "31e996f0a15c7b280ba9f76636b3ff9e2ae58c9a"
uuid = "682c06a0-de6a-54ab-a142-c8b1cf79cde6"
version = "0.21.4"

[[deps.JuliaInterpreter]]
deps = ["CodeTracking", "InteractiveUtils", "Random", "UUIDs"]
git-tree-sha1 = "c47892541d03e5dc63467f8964c9f2b415dfe718"
uuid = "aa1ae85d-cabe-5617-a682-6adf51b2e16a"
version = "0.9.46"

[[deps.JuliaSyntax]]
git-tree-sha1 = "937da4713526b96ac9a178e2035019d3b78ead4a"
uuid = "70703baa-626e-46a2-a12c-08ffd08c73b4"
version = "0.4.10"

[[deps.LaTeXStrings]]
git-tree-sha1 = "dda21b8cbd6a6c40d9d02a73230f9d70fed6918c"
uuid = "b964fa9f-0449-5b57-a5c2-d3ea65f4040f"
version = "1.4.0"

[[deps.Latexify]]
deps = ["Format", "InteractiveUtils", "LaTeXStrings", "MacroTools", "Markdown", "OrderedCollections", "Requires"]
git-tree-sha1 = "52e1296ebbde0db845b356abbbe67fb82a0a116c"
uuid = "23fbe1c1-3f47-55db-b15f-69d7ec21a316"
version = "0.16.9"

    [deps.Latexify.extensions]
    DataFramesExt = "DataFrames"
    SparseArraysExt = "SparseArrays"
    SymEngineExt = "SymEngine"
    TectonicExt = "tectonic_jll"

    [deps.Latexify.weakdeps]
    DataFrames = "a93c6f00-e57d-5684-b7b6-d8193f3e46c0"
    SparseArrays = "2f01184e-e22b-5df5-ae63-d93ebab69eaf"
    SymEngine = "123dc426-2d89-5057-bbad-38513e3affd8"
    tectonic_jll = "d7dd28d6-a5e6-559c-9131-7eb760cdacc5"

[[deps.LazyArrays]]
deps = ["ArrayLayouts", "FillArrays", "LinearAlgebra", "MacroTools", "SparseArrays"]
git-tree-sha1 = "76627adb8c542c6b73f68d4bfd0aa71c9893a079"
uuid = "5078a376-72f3-5289-bfd5-ec5146d43c02"
version = "2.6.2"

    [deps.LazyArrays.extensions]
    LazyArraysBandedMatricesExt = "BandedMatrices"
    LazyArraysBlockArraysExt = "BlockArrays"
    LazyArraysBlockBandedMatricesExt = "BlockBandedMatrices"
    LazyArraysStaticArraysExt = "StaticArrays"

    [deps.LazyArrays.weakdeps]
    BandedMatrices = "aae01518-5342-5314-be14-df237901396f"
    BlockArrays = "8e7c35d0-a365-5155-bbbb-fb81a777f24e"
    BlockBandedMatrices = "ffab5731-97b5-5995-9138-79e8c1846df0"
    StaticArrays = "90137ffa-7385-5640-81b9-e52037218182"

[[deps.LibCURL]]
deps = ["LibCURL_jll", "MozillaCACerts_jll"]
uuid = "b27032c2-a3e7-50c8-80cd-2d36dbcbfd21"
version = "0.6.4"

[[deps.LibCURL_jll]]
deps = ["Artifacts", "LibSSH2_jll", "Libdl", "MbedTLS_jll", "Zlib_jll", "nghttp2_jll"]
uuid = "deac9b47-8bc7-5906-a0fe-35ac56dc84c0"
version = "8.6.0+0"

[[deps.LibGit2]]
deps = ["Base64", "LibGit2_jll", "NetworkOptions", "Printf", "SHA"]
uuid = "76f85450-5226-5b5a-8eaa-529ad045b433"
version = "1.11.0"

[[deps.LibGit2_jll]]
deps = ["Artifacts", "LibSSH2_jll", "Libdl", "MbedTLS_jll"]
uuid = "e37daf67-58a4-590a-8e99-b0245dd2ffc5"
version = "1.7.2+0"

[[deps.LibSSH2_jll]]
deps = ["Artifacts", "Libdl", "MbedTLS_jll"]
uuid = "29816b5a-b9ab-546f-933c-edad1886dfa8"
version = "1.11.0+1"

[[deps.Libdl]]
uuid = "8f399da3-3557-5675-b5ff-fb832c97cbdb"
version = "1.11.0"

[[deps.LinearAlgebra]]
deps = ["Libdl", "OpenBLAS_jll", "libblastrampoline_jll"]
uuid = "37e2e46d-f89d-539d-b4ee-838fcccc9c8e"
version = "1.11.0"

[[deps.Logging]]
uuid = "56ddb016-857b-54e1-b83d-db4d58db5568"
version = "1.11.0"

[[deps.LoweredCodeUtils]]
deps = ["JuliaInterpreter"]
git-tree-sha1 = "39240b5f66956acfa462d7fe12efe08e26d6d70d"
uuid = "6f1432cf-f94c-5a45-995e-cdbf5db27b0b"
version = "3.2.2"

[[deps.MIMEs]]
git-tree-sha1 = "c64d943587f7187e751162b3b84445bbbd79f691"
uuid = "6c6e2e6c-3030-632d-7369-2d6c69616d65"
version = "1.1.0"

[[deps.MacroTools]]
git-tree-sha1 = "1e0228a030642014fe5cfe68c2c0a818f9e3f522"
uuid = "1914dd2f-81c6-5fcd-8719-6d5c9610ff09"
version = "0.5.16"

[[deps.Markdown]]
deps = ["Base64"]
uuid = "d6f4376e-aef5-505a-96c1-9c027394607a"
version = "1.11.0"

[[deps.MbedTLS_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "c8ffd9c3-330d-5841-b78e-0817d7145fa1"
version = "2.28.6+0"

[[deps.Mmap]]
uuid = "a63ad114-7e13-5084-954f-fe012c677804"
version = "1.11.0"

[[deps.MozillaCACerts_jll]]
uuid = "14a3606d-f60d-562e-9121-12d972cd8159"
version = "2023.12.12"

[[deps.NetworkOptions]]
uuid = "ca575930-c2e3-43a9-ace4-1e988b2c1908"
version = "1.2.0"

[[deps.OpenBLAS_jll]]
deps = ["Artifacts", "CompilerSupportLibraries_jll", "Libdl"]
uuid = "4536629a-c528-5b80-bd46-f80d51c5b363"
version = "0.3.27+1"

[[deps.OrderedCollections]]
git-tree-sha1 = "05868e21324cede2207c6f0f466b4bfef6d5e7ee"
uuid = "bac558e1-5e72-5ebc-8fee-abe8a469f55d"
version = "1.8.1"

[[deps.Parsers]]
deps = ["Dates", "PrecompileTools", "UUIDs"]
git-tree-sha1 = "7d2f8f21da5db6a806faf7b9b292296da42b2810"
uuid = "69de0a69-1ddd-5017-9359-2bf0b02dc9f0"
version = "2.8.3"

[[deps.Pkg]]
deps = ["Artifacts", "Dates", "Downloads", "FileWatching", "LibGit2", "Libdl", "Logging", "Markdown", "Printf", "Random", "SHA", "TOML", "Tar", "UUIDs", "p7zip_jll"]
uuid = "44cfe95a-1eb2-52ea-b672-e2afdf69b78f"
version = "1.11.0"
weakdeps = ["REPL"]

    [deps.Pkg.extensions]
    REPLExt = "REPL"

[[deps.PlutoHooks]]
deps = ["InteractiveUtils", "Markdown", "UUIDs"]
git-tree-sha1 = "072cdf20c9b0507fdd977d7d246d90030609674b"
uuid = "0ff47ea0-7a50-410d-8455-4348d5de0774"
version = "0.0.5"

[[deps.PlutoLinks]]
deps = ["FileWatching", "InteractiveUtils", "Markdown", "PlutoHooks", "Revise", "UUIDs"]
git-tree-sha1 = "8f5fa7056e6dcfb23ac5211de38e6c03f6367794"
uuid = "0ff47ea0-7a50-410d-8455-4348d5de0420"
version = "0.1.6"

[[deps.PlutoTeachingTools]]
deps = ["Downloads", "HypertextLiteral", "Latexify", "Markdown", "PlutoUI"]
git-tree-sha1 = "85778cdf2bed372008e6646c64340460764a5b85"
uuid = "661c6b06-c737-4d37-b85c-46df65de6f69"
version = "0.4.5"

[[deps.PlutoTest]]
deps = ["HypertextLiteral", "InteractiveUtils", "Markdown", "Test"]
git-tree-sha1 = "17aa9b81106e661cffa1c4c36c17ee1c50a86eda"
uuid = "cb4044da-4d16-4ffa-a6a3-8cad7f73ebdc"
version = "0.2.2"

[[deps.PlutoUI]]
deps = ["AbstractPlutoDingetjes", "Base64", "ColorTypes", "Dates", "Downloads", "FixedPointNumbers", "Hyperscript", "HypertextLiteral", "IOCapture", "InteractiveUtils", "JSON", "Logging", "MIMEs", "Markdown", "Random", "Reexport", "URIs", "UUIDs"]
git-tree-sha1 = "8329a3a4f75e178c11c1ce2342778bcbbbfa7e3c"
uuid = "7f904dfe-b85e-4ff6-b463-dae2292396a8"
version = "0.7.71"

[[deps.PrecompileTools]]
deps = ["Preferences"]
git-tree-sha1 = "5aa36f7049a63a1528fe8f7c3f2113413ffd4e1f"
uuid = "aea7be01-6a6a-4083-8856-8a6e6704d82a"
version = "1.2.1"

[[deps.Preferences]]
deps = ["TOML"]
git-tree-sha1 = "0f27480397253da18fe2c12a4ba4eb9eb208bf3d"
uuid = "21216c6a-2e73-6563-6e65-726566657250"
version = "1.5.0"

[[deps.Printf]]
deps = ["Unicode"]
uuid = "de0858da-6303-5e67-8744-51eddeeeb8d7"
version = "1.11.0"

[[deps.Profile]]
uuid = "9abbd945-dff8-562f-b5e8-e1ebf5ef1b79"
version = "1.11.0"

[[deps.ProfileCanvas]]
deps = ["Base64", "JSON", "Pkg", "Profile", "REPL"]
git-tree-sha1 = "e42571ce9a614c2fbebcaa8aab23bbf8865c624e"
uuid = "efd6af41-a80b-495e-886c-e51b0c7d77a3"
version = "0.1.6"

[[deps.REPL]]
deps = ["InteractiveUtils", "Markdown", "Sockets", "StyledStrings", "Unicode"]
uuid = "3fa0cd96-eef1-5676-8a61-b3b8758bbffb"
version = "1.11.0"

[[deps.Random]]
deps = ["SHA"]
uuid = "9a3f8284-a2c9-5f02-9a11-845980a1fd5c"
version = "1.11.0"

[[deps.Reexport]]
git-tree-sha1 = "45e428421666073eab6f2da5c9d310d99bb12f9b"
uuid = "189a3867-3050-52da-a836-e630ba90ab69"
version = "1.2.2"

[[deps.Requires]]
deps = ["UUIDs"]
git-tree-sha1 = "62389eeff14780bfe55195b7204c0d8738436d64"
uuid = "ae029012-a4dd-5104-9daa-d747884805df"
version = "1.3.1"

[[deps.Revise]]
deps = ["CodeTracking", "FileWatching", "JuliaInterpreter", "LibGit2", "LoweredCodeUtils", "OrderedCollections", "REPL", "Requires", "UUIDs", "Unicode"]
git-tree-sha1 = "9bb80533cb9769933954ea4ffbecb3025a783198"
uuid = "295af30f-e4ad-537b-8983-00126c2a3abe"
version = "3.7.2"

    [deps.Revise.extensions]
    DistributedExt = "Distributed"

    [deps.Revise.weakdeps]
    Distributed = "8ba89e20-285c-5b6f-9357-94700520ee1b"

[[deps.SHA]]
uuid = "ea8e919c-243c-51af-8825-aaa63cd721ce"
version = "0.7.0"

[[deps.Serialization]]
uuid = "9e88b42a-f829-5b0c-bbe9-9e923198166b"
version = "1.11.0"

[[deps.Sockets]]
uuid = "6462fe0b-24de-5631-8697-dd941f90decc"
version = "1.11.0"

[[deps.SparseArrays]]
deps = ["Libdl", "LinearAlgebra", "Random", "Serialization", "SuiteSparse_jll"]
uuid = "2f01184e-e22b-5df5-ae63-d93ebab69eaf"
version = "1.11.0"

[[deps.StaticArrays]]
deps = ["LinearAlgebra", "PrecompileTools", "Random", "StaticArraysCore"]
git-tree-sha1 = "cbea8a6bd7bed51b1619658dec70035e07b8502f"
uuid = "90137ffa-7385-5640-81b9-e52037218182"
version = "1.9.14"

    [deps.StaticArrays.extensions]
    StaticArraysChainRulesCoreExt = "ChainRulesCore"
    StaticArraysStatisticsExt = "Statistics"

    [deps.StaticArrays.weakdeps]
    ChainRulesCore = "d360d2e6-b24c-11e9-a2a3-2a2ae2dbcce4"
    Statistics = "10745b16-79ce-11e8-11f9-7d13ad32a3b2"

[[deps.StaticArraysCore]]
git-tree-sha1 = "192954ef1208c7019899fbf8049e717f92959682"
uuid = "1e83bf80-4336-4d27-bf5d-d5a4f845583c"
version = "1.4.3"

[[deps.Statistics]]
deps = ["LinearAlgebra"]
git-tree-sha1 = "ae3bb1eb3bba077cd276bc5cfc337cc65c3075c0"
uuid = "10745b16-79ce-11e8-11f9-7d13ad32a3b2"
version = "1.11.1"
weakdeps = ["SparseArrays"]

    [deps.Statistics.extensions]
    SparseArraysExt = ["SparseArrays"]

[[deps.StyledStrings]]
uuid = "f489334b-da3d-4c2e-b8f0-e476e12c162b"
version = "1.11.0"

[[deps.SuiteSparse_jll]]
deps = ["Artifacts", "Libdl", "libblastrampoline_jll"]
uuid = "bea87d4a-7f5b-5778-9afe-8cc45184846c"
version = "7.7.0+0"

[[deps.TOML]]
deps = ["Dates"]
uuid = "fa267f1f-6049-4f14-aa54-33bafae1ed76"
version = "1.0.3"

[[deps.Tar]]
deps = ["ArgTools", "SHA"]
uuid = "a4e569a6-e804-4fa4-b0f3-eef7a1d5b13e"
version = "1.10.0"

[[deps.Test]]
deps = ["InteractiveUtils", "Logging", "Random", "Serialization"]
uuid = "8dfed614-e22c-5e08-85e1-65c5234f0b40"
version = "1.11.0"

[[deps.Tricks]]
git-tree-sha1 = "372b90fe551c019541fafc6ff034199dc19c8436"
uuid = "410a4b4d-49e4-4fbc-ab6d-cb71b17b3775"
version = "0.1.12"

[[deps.URIs]]
git-tree-sha1 = "bef26fb046d031353ef97a82e3fdb6afe7f21b1a"
uuid = "5c2747f8-b7ea-4ff2-ba2e-563bfd36b1d4"
version = "1.6.1"

[[deps.UUIDs]]
deps = ["Random", "SHA"]
uuid = "cf7118a7-6976-5b1a-9a39-7adc72f591a4"
version = "1.11.0"

[[deps.UnPack]]
git-tree-sha1 = "387c1f73762231e86e0c9c5443ce3b4a0a9a0c2b"
uuid = "3a884ed6-31ef-47d7-9d2a-63182c4928ed"
version = "1.0.2"

[[deps.Unicode]]
uuid = "4ec0a83e-493e-50e2-b9ac-8f72acf5a8f5"
version = "1.11.0"

[[deps.Zlib_jll]]
deps = ["Libdl"]
uuid = "83775a58-1f1d-513f-b197-d71354ab007a"
version = "1.2.13+1"

[[deps.libblastrampoline_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "8e850b90-86db-534c-a0d3-1478176c7d93"
version = "5.11.0+0"

[[deps.nghttp2_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "8e850ede-7688-5339-a07c-302acd2aaf8d"
version = "1.59.0+0"

[[deps.p7zip_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "3f19e933-33d8-53b3-aaab-bd5110c3b7a0"
version = "17.4.0+2"
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
# ╟─95d97786-6048-4203-b154-4d3e120d8bed
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
# ╟─e28f45a4-63db-4bf4-b1d4-56b13faaa98f
# ╠═8801443b-3e2a-4fbe-bfe1-3258a2df6df2
# ╟─150620fc-f1ed-4ad2-9cea-e2703114811d
# ╟─3bfd59f7-ab68-4d87-876c-8043714b7c8b
# ╟─a0cc1184-5d51-4f88-91c0-68f222b8cbc6
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
# ╟─9ec85962-500a-41d3-b44a-c7e29b588d53
# ╟─1fccacaf-ba57-4a1b-9e36-16ae2a655dab
# ╠═5fe5b01a-6675-4314-88db-f6521b3d4e89
# ╟─aac25f61-36d3-4d52-a3c5-353c451f065f
# ╠═ce92c089-9ebe-4381-a55d-0b97b6b7010e
# ╠═5e3f4691-e528-4b2d-a1b4-e6462bf26a5b
# ╠═a39267d2-60a0-4b91-b117-b0b51d7741d1
# ╟─f10ed432-4b04-4dd5-bfe1-94c7d47165fb
# ╟─e9520732-40b8-4b16-82e9-cbb1e5b91486
# ╟─37ca947a-594a-4340-b464-41b6a4670c86
# ╠═4adf7058-f572-4082-8f6b-2215f7feb83d
# ╟─741c5677-5295-4499-9881-06830234a11c
# ╠═6c62eeda-dc6a-4b4c-b7e6-5e08e3f66b31
# ╠═46eee524-44c1-4589-b7a6-cad77dafa79c
# ╠═1d212b01-788d-4292-948f-893bca319e9e
# ╟─b0d99a85-798d-45b2-83d0-318f5ddb9347
# ╟─6e2a733c-7a9c-4e94-9a6b-eb04c4a90513
# ╟─ffd21a68-03da-42cb-a1ae-171db4b58e98
# ╠═9ec478b6-2762-45a4-b1b9-8d29d78aeb13
# ╠═0046d996-9881-47a0-b4bd-b3f054e45ca1
# ╟─b78b5950-a9c2-4327-9880-05246fd8dd85
# ╟─13935ef8-970d-4644-87ac-4ff87f04af08
# ╠═8ab7c2c3-58ed-42a7-9a81-e2b1bd8d62d2
# ╟─99e7401a-2419-4a6b-9871-3c3ddb52357e
# ╟─1073a216-8259-45d1-87c6-14e6b28ac62c
# ╠═45a2d33d-3ef2-45b3-b1d7-713bc122cbeb
# ╟─abffb029-023c-4a28-ace8-5e5f469dce2b
# ╠═0d12115d-b8fa-47f6-8e69-2050a82a5417
# ╠═32b9d72b-9cff-4857-a45b-1baa1949b046
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
# ╟─2c34baa9-2645-4e68-9134-8eb2605b7a26
# ╟─00000000-0000-0000-0000-000000000001
# ╟─00000000-0000-0000-0000-000000000002
