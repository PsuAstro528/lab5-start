### A Pluto.jl notebook ###
# v0.16.0

using Markdown
using InteractiveUtils

# This Pluto notebook uses @bind for interactivity. When running this notebook outside of Pluto, the following 'mock version' of @bind gives bound variables a default value (instead of an error).
macro bind(def, element)
    quote
        local el = $(esc(element))
        global $(esc(def)) = Core.applicable(Base.get, el) ? Base.get(el) : missing
        el
    end
end

# ╔═╡ 8b184833-59d9-4958-8460-369b1ea19b9e
using Printf

# ╔═╡ 0cac30f1-9101-4ba3-accc-52621bc1d16f
begin
	using PlutoUI, PlutoTest, PlutoTeachingTools
	using BenchmarkTools
	using Profile,  ProfileSVG, FlameGraphs
	using Plots # just needed for colorant when color FlameGraphs
	using LinearAlgebra, PDMats # used by periodogram.jl
	using Statistics: mean, std    # used by periodogram.jl
	using Random
	Random.seed!(123)
	eval(Meta.parse(code_for_check_type_funcs))
end;

# ╔═╡ f37ba7bb-0484-4a53-bc8b-94b06d685ac0
md"""
# Astro 528, Lab 5, Exercise 1
# Profiling & Code Inspection
"""

# ╔═╡ 9e04db5d-0662-4a39-af3b-85e68f948ebc
md"""
In this exercise, we'll profile some functions that we've used in [Lab 4](https://psuastro528.github.io/lab4-start/): `calc_ecc_anom`, `calc_rv_keplerian`, and  `calc_periodogram`.
You may want to look at the source code and/or the help information for each of these functions to remind yourself of what they do.  In order to make the profiler outpus easier to read, the functions that we'll profile have been placed into separate files inside this repository's `src` directory.
"""

# ╔═╡ f80f430b-45d0-4b2a-8be6-e39aabccd6ae
md"## Example with efficient code"

# ╔═╡ 7fcc3f2a-cf98-4a95-a52e-518ca880f31d
md"""
First, we'll demonstrate the syntax for how to load code from another file into a Pluto notebook.
"""

# ╔═╡ 0d25c024-ab14-44bb-85bf-15a86152e7a1
begin
	KeplerEqn = ingredients("./src/calc_rv.jl")
	import .KeplerEqn: calc_ecc_anom, calc_rv_keplerian
end

# ╔═╡ d1fae43a-b6a7-4ae2-aa5c-e495d59f5e77
md"""
Next, we'll demonstrate the syntax for using Julia's profiler.
"""

# ╔═╡ 1e4df7eb-d8de-4bae-912e-c2360f530b76
with_terminal() do
	calc_ecc_anom    # Tell Pluto to make sure our function is avaliable
	Profile.clear()  # Clear the data stored by the profiler
	@profile calc_ecc_anom.(π/4,0.5)
	Profile.print()
end

# ╔═╡ 3f55c815-65a2-4950-8b2f-bc6d19e606c6
md"""
The odds are that you got a warning message that there were no samples collected.  Julia uses a *statistical* profiler, meaning that it doesn't count every time a line is executed, but rather it checks what line of code is being executed every so often.  `calc_ecc_anom` returned so quickly that the profiler didn't get a chance to figure out where it was spending its time.  In this case, it's so fast that we can't make the delay between samples fast enough, so we'll combine both of the suggestions from the warning message to get usable profiling data.
"""

# ╔═╡ f5c19252-5c37-4688-b1f8-e29afa006684
begin
	calc_ecc_anom    # Tell Pluto to make sure our function is avaliable
	Profile.clear()  # Clear the data stored by the profiler
	Profile.init(delay=1/10^7)    # Check what code is running every 0.1μs
	for i in 1:10^5               # Accumulate data over multiple function calls
		mean_anom = 2π*rand()     # Generate random input values
		ecc = rand()
		# Actually run profiler
		@profile calc_ecc_anom(mean_anom,ecc)
	end
	# Explicilty store profiling results to avoid confusion later on
	retrieve_prof_calc_ecc_anom = Profile.retrieve()
end;

# ╔═╡ cce0518b-68fc-43a7-866a-d02febcf9901
with_terminal() do
	retrieve_prof_calc_ecc_anom
	Profile.print(retrieve_prof_calc_ecc_anom...)
end

# ╔═╡ fe3931f6-11cf-4853-8bc9-d621a3af29f9
md"""
Ok, now you should see lots of data.  Each line of output corresponds to one line of code.  On the right of each line is the file containing the relevant code, the line number and a  function.  The number immediately to the left of the text is the number of times that the profiles checked in and found that the computer was executing that line of code *including* any computations in functions that resulted from it.

This is a *tree view*, meaning that the lines are organized by what function calls what function.  The first several lines are because we're running inside a Pluto notebook.  Pluto wraps our cells in several functions to make it's reactive environment work.

Skip down to the line just below the line containing 'Profile.jl:28; macro expansion'.  That's where the work we're interested begins.  The number immediately to the left is the total number of profiler samples collected for our code (in this case `calc_ecc_anom`).

1a.  How many samples did you get for 'kepler\_eqn.jl:46; calc\_ecc\_anom'?
"""

# ╔═╡ 8894cd1c-5f94-4b07-94a0-757b2fdf75db
response_1a = missing # Replace with an integer

# ╔═╡ 640647b7-1388-41dd-9a9a-e440898be3ab
display_msg_if_fail(check_type_isa(:response_1a,response_1a,Integer))

# ╔═╡ 3005d8e2-f018-43eb-9759-8ee48fa9ea1a
md"""
1b.  Scroll down looking for other big numbers (e.g., at least a quarter of $response_1a).
Ignore any lines that refer to 'Profile.jl' or 'task.jl'.
Which line numer of code in kepler_eqn is taking the most time?
"""

# ╔═╡ 4fb20f7c-ba52-4381-b75d-1a726e62569c
response_1b = missing # Replace with an integer

# ╔═╡ 4a37d8c9-8766-4692-8c8d-4f14c67df4ee
begin
	if !@isdefined(response_1b)
		var_not_defined(:response_1b)
	elseif ismissing(response_1b)
		still_missing()
	elseif response_1b != 54
		keep_working(md"Please double check that.")
	else
		correct()
	end
end

# ╔═╡ 9d901dca-4660-43c8-9781-a87b02fd54e3
md"""
We can display the profiling results in other formats. For example, instead of the tree view, we can use a *flat view* and sort by the number of samples for that line of code.
"""

# ╔═╡ d1f872d2-0953-47d1-b4cc-e177496677b0
with_terminal() do
	Profile.print(retrieve_prof_calc_ecc_anom..., format=:flat, sortedby=:count)
end

# ╔═╡ dc0dce98-3824-44ef-bd58-d14c0a93f8ac
md"""
In this format, the first column contains the number of samples, the third colum contains the filename, the fourth column is the line number and the fifth column is the function within that line.

1c.  Scroll to the bottom of the above output, then go back up to find the first time (you see 'calc\_ecc\_anom' (starting from the bottom).  Look at the several lines above it (i.e., the lines of code account for a significant fraction of the total cost).  What line of code in 'update\_ecc\_anom\_laguerre' is taking the most time?
"""

# ╔═╡ ef76ab85-a2bd-4b5b-acc1-176eead528f5
response_1c = missing  # Replace with an integer

# ╔═╡ 23fbae8c-cf91-4946-b31d-86cd9c2acc65
begin
	if !@isdefined(response_1c)
		var_not_defined(:response_1c)
	elseif ismissing(response_1c)
		still_missing()
	elseif response_1c != 27
		keep_working(md"Please double check that.")
	else
		correct()
	end
end

# ╔═╡ 2869aaa6-9941-46b0-b240-cf9e39231525
md"1d. Look at the source code for 'update\_ecc\_anom\_laguerre'.  What is that line doing?"

# ╔═╡ 4ed00d92-eff3-4ff5-a97d-c844e7a48c67
response_1d = missing # Replace with md"Response"

# ╔═╡ 779d6fb0-4e6c-4e4b-9720-f26b0b77990d
display_msg_if_fail(check_type_isa(:response_1d,response_1d,Markdown.MD))

# ╔═╡ 182dc7ba-bb2d-4b95-b393-79b0860dd8d0
md"""
This is an example of a funciton with very little room for improvement.  Most of the time is being spent on computing sines, cosines, square roots and basic arithmetic.  Notably, we do *not* see significant time being devoted to memory allocations.  So it's unlikely that we'll be able to optimize this function further (unless we were to find a more efficient way to solve the problem by using a different algorithm).

Before we move on, we'll also try looking at a visual representation of the same data.
"""

# ╔═╡ 54fd03d0-9a90-429d-af80-824196cd40e6
begin  # dispaly configuration paramteres for ProfileSVG.view
	svg_fontsize = 14
	svg_width = 706
end;

# ╔═╡ 3a961a8b-7b61-48e8-b840-8ef6c5acafe8
ProfileSVG.view(data=retrieve_prof_calc_ecc_anom,fontsize=svg_fontsize,width=svg_width)

# ╔═╡ 049f048b-12ec-4ab3-891b-257c8b766a10
md"""
When interpretting such graphs, it can be helpful to specify how the cells will be color coded.  Here, we'll demonstrate how to color code cells by what module they're defined in.
"""

# ╔═╡ be9e0f8d-a424-4025-bb1e-baa876664633
md"""
Look in the tall part of the stack for the cell 'kepler\_eqn.jl:46; calc\_ecc\_anom' (just below the first lowest green cell).  Double click on that cell to zoom in on the time spent inside 'calc\_ecc\_anom'.  You can hover your mouse over other cells to see what line they refer to.
"""

# ╔═╡ 713265a1-2431-4e20-8e3d-965c924be1d1
md"""
1e. Which of the following operations is taking more of the computer's time?"""

# ╔═╡ c23f1cfb-de99-4119-ba00-14af073e33f1
@bind response_1e Radio(["subtraction","multiplication","division","trig functions","sqrt"])

# ╔═╡ 1c217bf9-5c67-42d7-8be7-b8b635a1ed93
begin
	if !@isdefined(response_1e)
		var_not_defined(:response_1e)
	elseif ismissing(response_1e)
		still_missing(md"Remember to respond to 1e.")
	elseif response_1e != "trig functions"
		keep_working(md"Please look again.")
	else
		correct()
	end
end

# ╔═╡ 6b5c76d9-da97-49a4-9d2c-5ae22e08b44a
md"## Example with an opportunity to improve efficiency"

# ╔═╡ e76ff922-f61f-4c80-836b-9cbbb0952d2d
md"""
Now, we'll consider two versions of functions to calculate a periodogram.  We'll use the profiler to help us find an opportunity to improve the efficiency of our code. First, we'll load two versions of the code into two modules named PeriodogramOrig (for the original code) and Periodogram (for the improved code).  This pattern of placing two versions of code to do the same thing in two different files can be very useful when optimizing code.  It allows you to keep the same function names, rather than changing them (and having to remember to update things consistently).  And it makes it easy to test that they give consistent results.
"""

# ╔═╡ b3d3f4c3-968d-4235-82b9-d6f9806109f8
begin
	PeriodogramOrig = ingredients("src/periodogram_orig.jl")
	calc_periodogram_orig = PeriodogramOrig.calc_periodogram
	Periodogram = ingredients("src/periodogram.jl")
	import .Periodogram: calc_periodogram
end

# ╔═╡ 3973c872-5817-4215-925a-b93e2186e33a
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

# ╔═╡ 78686ae5-4219-43b5-896b-3a86864ce049
ProfileSVG.view(data=retrieve_prof_calc_ecc_anom,StackFrameCategory(color_by_module))

# ╔═╡ 71205282-e4bc-479f-b7c0-db6783066d84
md"### Generate data to analyze"

# ╔═╡ 938e338e-9242-4343-accf-c9d5d1c0420a
md"""
Now, we'll generate a set of Keplerian orbital parameters and simulated data to use for profiling our code.
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

# ╔═╡ ffd9315b-d5ad-4636-ba2f-5380c22055d2
num_obs = 100;

# ╔═╡ b5f4992a-5233-4ade-8ca4-bf2e6da1a4ac
num_periods = 10000;

# ╔═╡ e36ebf1c-a750-40b4-8815-8bb3dee3910f
begin
	days_in_year = 365.2425
	times = 2*days_in_year*rand(num_obs)
	rvs_true = calc_rv_keplerian.(times,P,K,ecc,ω,M0)
	σ_rvs = 1*ones(num_obs)
	rvs_obs = rvs_true .+ σ_rvs .* randn(num_obs)
end;

# ╔═╡ 7cba065d-98b4-4e04-a3b4-76224878a0bd
md"### Profile original periodogram code"

# ╔═╡ c97e19e9-e818-432e-aaeb-618090372fad
if true
	calc_periodogram_orig(times,rvs_obs,σ_rvs,num_periods=num_periods)   # Make sure compiled before profiling
	Profile.clear()
	Profile.init(delay=1/10^5)
	for i in 1:10
		@profile calc_periodogram_orig(times,rvs_obs,σ_rvs,num_periods=num_periods)
	end
	# Explicitly store profiling results to avoid confusion later on
	retrieve_prof_periodogram_orig = Profile.retrieve()
end;

# ╔═╡ e54ae808-22f9-4ee5-9b75-d93aa56a8b3d
ProfileSVG.view(data=retrieve_prof_periodogram_orig,fontsize=svg_fontsize,width=svg_width,StackFrameCategory(color_by_module))

# ╔═╡ 74c3f2cb-6865-4cde-9c61-b75777854866


# ╔═╡ 488e83b4-4f5e-400f-85e2-f3b0716d7404
md"""
As before, there's about a dozen levels of functions at the bottom of the graph before we get to our function of interest, 'calc\_periodogram'.  Double click on the cell with 'calc\_periodogram' and line 31.  Look at how the code is spending its time.

1f.  Look for some cells near the top that take a non-trivial fraction of the time and aren't doing math.  What is taking time and could be avoided (or at least significantly reduced)?
"""

# ╔═╡ 5e48f2ae-bfc8-4130-a831-fae02b331bf7
response_1f = missing  # Replace with md"Response"

# ╔═╡ 31f2d123-8a9a-45c6-9f80-569b070c54e4
display_msg_if_fail(check_type_isa(:response_1f,response_1f,Markdown.MD))

# ╔═╡ 990f6bc0-f8d0-4374-b28c-82664e24984a
hint(md"The function `similar` creates an uninitialized array with the same size and element type as its argument.  The function `Array` allocates memory for an array.")

# ╔═╡ e5d41d8f-3b62-434b-9491-98a017e90658
md"### Updated perodogram code"

# ╔═╡ 40d92503-c7ab-4bf7-af62-02b08a284c17
md"""
Based on analyzing the above profiling information, I decided to pre-allocate memory for the [design matrix](https://en.wikipedia.org/wiki/Design_matrix) used for the generalized linear least squares regression (in the case of a periodogram the design matrix contains the values of sin(2π×t/P) and cos(2π×t/P) at each observation time for the putative orbital period being considered).  After implementing that, I saw that there was still significant time spend allocating memory.  Therefore, I preallocated a total of three matrices and four vectors.  I updated the periodogram code to use *in-place* functions like [`mul!`](https://docs.julialang.org/en/v1/stdlib/LinearAlgebra/#LinearAlgebra.mul!), [`ldiv!`](https://docs.julialang.org/en/v1/stdlib/LinearAlgebra/#LinearAlgebra.ldiv!) and [`lu!`](https://docs.julialang.org/en/v1/stdlib/LinearAlgebra/#LinearAlgebra.lu!) so that calculations were written into an existing array/matrix, rather than allocating new memory for the result.
"""

# ╔═╡ 337d9aaf-e2f5-49cc-bd68-178d12110390
md"""
Before looking into any performance improvements, we should double check that we're still getting the same results.
"""

# ╔═╡ 2b93af3a-066b-443f-88c4-702b17e555b7
 begin
	result_orig = calc_periodogram_orig(times,rvs_obs,σ_rvs)
	result_new  = calc_periodogram(times,rvs_obs,σ_rvs)
	@test all(result_new.periodogram .== result_orig.periodogram) && all(result_new.predict .== result_orig.predict)
end

# ╔═╡ e16a4171-e82d-4c43-af26-1f183fd15b2f
md"""
Since we pre-allocated memory in order to reduce the memory being allocated, let's check to see if/how much of a difference our modifications made.
"""

# ╔═╡ e6ae2efe-d519-4c44-b706-a0ca95e6c050
calc_periodogram

# ╔═╡ 9de88c42-a73b-42f1-95be-e117b5beb77b
begin
	(calc_periodogram_orig, calc_periodogram )
	(times,rvs_obs,σ_rvs,num_periods)
	mem_pgram_orig = @allocated calc_periodogram_orig(times,rvs_obs,σ_rvs,num_periods=num_periods)
	mem_pgram_new  = @allocated calc_periodogram(times,rvs_obs,σ_rvs,num_periods=num_periods)
	mem_pgram_percent_str = @sprintf "%4.1f%c" mem_pgram_new/mem_pgram_orig*100 '%'
end;

# ╔═╡ 11bd6e51-6993-4b8e-945c-7e61ff970dd4
if @isdefined mem_pgram_percent_str
	md"""
	The new version only allocates $mem_pgram_percent_str as much memory as the original version!
	"""
end

# ╔═╡ cc4b05de-6d6a-4c61-bdca-a0f6992ecfca
md"Now, let's profile the updated periodogram code."

# ╔═╡ 2facd1bf-e9ac-46c1-9523-1244395a3e8b
if true
	calc_periodogram
	calc_periodogram(times,rvs_obs,σ_rvs,num_periods=num_periods)   # Make sure compiled before profiling
	Profile.clear()
	Profile.init(delay=1/10^5)
	for i in 1:10
		@profile calc_periodogram(times,rvs_obs,σ_rvs,num_periods=num_periods)
	end

	# Explicitly store profiling results to avoid confusion later on
	retrieve_prof_periodogram = Profile.retrieve()
end;

# ╔═╡ 63fbadee-2ad4-4f68-9ba1-5c9d0143eb1a
if @isdefined retrieve_prof_periodogram
	ProfileSVG.view(data=retrieve_prof_periodogram[1],
			fontsize=svg_fontsize,width=svg_width,StackFrameCategory(color_by_module))
end

# ╔═╡ 1d9033dd-e266-4192-930d-ef5be6780226
md"""
Double click on the cell with 'calc\_periodogram' and line 31.  Look at how the code is spending its time.

1g.  Do you notice any memory allocations inside calc_periodogram?  How does the time spent allocating memory compare to the original periodogram code?
"""

# ╔═╡ dba75149-3e4c-4046-8fc7-42e8bf7375a5
response_1g = missing  # Replace with md"Response"

# ╔═╡ a16b0dc3-56c4-4f1c-94f2-ab034bfc30f3
display_msg_if_fail(check_type_isa(:response_1g,response_1g,Markdown.MD))

# ╔═╡ e3fb296e-c338-460f-b73f-fc5a4ffe2368
md"Now, let's benchmark our original and updated periodogram functions."

# ╔═╡ c85762f2-6ad0-43aa-99a2-abd1e8249cdd
md"**Original Periodogram code**"

# ╔═╡ d30212db-5306-4d3c-a786-f568ca67725f
@benchmark calc_periodogram_orig($times,$rvs_obs,$σ_rvs,num_periods=$num_periods)

# ╔═╡ 9be239b8-6c91-47c7-97c6-c39cddd3bc5d
md"**Updated Periodogram code**"

# ╔═╡ 2c0adb00-71b6-483c-be10-f31642690184
(@isdefined calc_periodogram) &&
 @benchmark calc_periodogram($times,$rvs_obs,$σ_rvs,num_periods=$num_periods)

# ╔═╡ 7557b534-c348-44bd-8de2-557a290e1b59
md"1h.  How does the run time compare?"

# ╔═╡ 5d78bd1f-47b3-422c-ae34-11f5e2ae93c3
response_1h = missing # Replace with md"Response"

# ╔═╡ 5514f1a7-bc64-4042-8c5e-b3dc835ebd2d
display_msg_if_fail(check_type_isa(:response_1h,response_1h,Markdown.MD))

# ╔═╡ 0bf114a2-ec3a-4625-b60d-0287f447d2a4
md"For larger codes, sometimes the results are so big (or there is such a deep tree of functions), that you want the profiler output to be spread over more columns than the default.  Below, we'll see how to write the results to a file with a width of our choice."

# ╔═╡ 3d081d57-0bdb-448b-801f-b1a3bb8deb67
begin
	prof_periodogram_filename = "calc_periodogram.prof"
	open(prof_periodogram_filename, "w") do s
    	Profile.print(IOContext(s, :displaysize => (24, 500)),retrieve_prof_periodogram..., format=:tree )
	end
end

# ╔═╡ 5d715c51-147f-4a98-93cd-0c5fc2c51430
md"""
Once we've written the profiling results to a file, we can read each line and select the lines that refer to specific functions that we're specifically interested in.
"""

# ╔═╡ 3c9822b6-2643-4b0d-be1c-4716d701fbfa
prof_periodogram_lines = readlines(prof_periodogram_filename);

# ╔═╡ d253af17-92a7-4c62-a227-fb8cf9298939
prof_periodogram_lines[occursin.("calc_periodogram(",prof_periodogram_lines)]

# ╔═╡ 36de15f2-100d-4e21-8ca1-6a4b3a08a52d
prof_periodogram_lines[occursin.(r"; Array$",prof_periodogram_lines)]

# ╔═╡ ed673d82-55eb-4ba8-9e64-410ecc64e499
md"1i.  Based on the above results (be sure to click the triangles to expand the array of strings), estimate by the maximum percentage we could further speed up  `calc_periodogram`, if we were able to completely eliminate time spent allocating arrays."

# ╔═╡ 3d117fff-2447-4b3b-ab71-301b38e24d54
response_1i = missing  # Replace with md"Response"

# ╔═╡ 8a786af1-9902-4f58-ba58-4cf9dd3b9d3e
display_msg_if_fail(check_type_isa(:response_1i,response_1i,Markdown.MD))

# ╔═╡ 71ccf51e-2d8c-46d1-8b87-953bcbf8302f
md"Once you have a working serial implementation of your class project code, you'll wan to run a profiler on it to determine what are the most time consuming parts of the code.  That will help you identify what portions have the potential to give you a significant speed up."

# ╔═╡ 85ea82e9-35c6-41be-a575-ab823809eef7
md"Here's a good place to stop and move on to exercise 2.  If you have some extra time, then you could consider the following questions."

# ╔═╡ 10403496-5a93-4890-b399-93d6086ff3ee
md"## If you have time..."

# ╔═╡ 2ba5f81f-019b-4749-a0a2-35ead50dee5f
md"1j.  Do you think the difference in performance will become more or less significant if you increase 'num_periods' (the number of putative orbital periods searched)?  Try it.  Report what you find and try to explain your findings.
"

# ╔═╡ 1cd04b3f-3a4e-4c93-85f0-4a41773c4366
response_1j = missing  # Replace with md"Response"

# ╔═╡ 9bb894f5-6247-43b0-a632-0a034be4abe8
md"1k.  Do you think the difference in performance will become more or less significant if you increase 'num_obs' (the number of radial velocity observations)?  Try it.  Report what you find and try to explain your findings."

# ╔═╡ ca2acf91-28d1-4ddc-8150-f4eecef3dffa
response_1k = missing  # Replace with md"Response"

# ╔═╡ 2871b32a-180e-4d57-a1c8-44bc68ec1816
md"1l.  Can you think of a way to speed up the `calc_periodogram` by modifying the algorithm (to calculate the same values, perhaps with slightly different values due to round-off issues)?"

# ╔═╡ bc1e3f75-8d92-4311-877a-6a4d7f227830
response_1l = missing  # Replace with md"Response"

# ╔═╡ b0eccdc2-40bc-44d7-8a72-3e059a4214ab
md"# Helper Code"

# ╔═╡ 81d7a663-1079-4613-afd8-de95eb73f8ae
ChooseDisplayMode()

# ╔═╡ d93a8dca-9c63-4551-87e8-9939a765bef1
TableOfContents(aside=true)

# ╔═╡ 00000000-0000-0000-0000-000000000001
PLUTO_PROJECT_TOML_CONTENTS = """
[deps]
BenchmarkTools = "6e4b80f9-dd63-53aa-95a3-0cdb28fa8baf"
FlameGraphs = "08572546-2f56-4bcf-ba4e-bab62c3a3f89"
LinearAlgebra = "37e2e46d-f89d-539d-b4ee-838fcccc9c8e"
PDMats = "90014a1f-27ba-587c-ab20-58faa44d9150"
Plots = "91a5bcdd-55d7-5caf-9e0b-520d859cae80"
PlutoTeachingTools = "661c6b06-c737-4d37-b85c-46df65de6f69"
PlutoTest = "cb4044da-4d16-4ffa-a6a3-8cad7f73ebdc"
PlutoUI = "7f904dfe-b85e-4ff6-b463-dae2292396a8"
Printf = "de0858da-6303-5e67-8744-51eddeeeb8d7"
Profile = "9abbd945-dff8-562f-b5e8-e1ebf5ef1b79"
ProfileSVG = "132c30aa-f267-4189-9183-c8a63c7e05e6"
Random = "9a3f8284-a2c9-5f02-9a11-845980a1fd5c"
Statistics = "10745b16-79ce-11e8-11f9-7d13ad32a3b2"

[compat]
BenchmarkTools = "~1.1.4"
FlameGraphs = "~0.2.5"
PDMats = "~0.11.1"
Plots = "~1.22.1"
PlutoTeachingTools = "~0.1.4"
PlutoTest = "~0.1.0"
PlutoUI = "~0.7.9"
ProfileSVG = "~0.2.1"
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
git-tree-sha1 = "937c29268e405b6808d958a9ac41bfe1a31b08e7"
uuid = "5789e2e9-d7fb-5bc7-8068-2c6fae9b9549"
version = "1.11.0"

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

[[MacroTools]]
deps = ["Markdown", "Random"]
git-tree-sha1 = "5a5bc6bf062f0f95e62d0fe0a2d99699fed82dd9"
uuid = "1914dd2f-81c6-5fcd-8719-6d5c9610ff09"
version = "0.5.8"

[[Markdown]]
deps = ["Base64"]
uuid = "d6f4376e-aef5-505a-96c1-9c027394607a"

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

[[PDMats]]
deps = ["LinearAlgebra", "SparseArrays", "SuiteSparse"]
git-tree-sha1 = "4dd403333bcf0909341cfe57ec115152f937d7d8"
uuid = "90014a1f-27ba-587c-ab20-58faa44d9150"
version = "0.11.1"

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

[[SuiteSparse]]
deps = ["Libdl", "LinearAlgebra", "Serialization", "SparseArrays"]
uuid = "4607b0f0-06f3-5cda-b6b1-a6196a1729e9"

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
# ╟─f80f430b-45d0-4b2a-8be6-e39aabccd6ae
# ╟─7fcc3f2a-cf98-4a95-a52e-518ca880f31d
# ╠═0d25c024-ab14-44bb-85bf-15a86152e7a1
# ╟─d1fae43a-b6a7-4ae2-aa5c-e495d59f5e77
# ╠═1e4df7eb-d8de-4bae-912e-c2360f530b76
# ╟─3f55c815-65a2-4950-8b2f-bc6d19e606c6
# ╠═f5c19252-5c37-4688-b1f8-e29afa006684
# ╠═cce0518b-68fc-43a7-866a-d02febcf9901
# ╟─fe3931f6-11cf-4853-8bc9-d621a3af29f9
# ╠═8894cd1c-5f94-4b07-94a0-757b2fdf75db
# ╟─640647b7-1388-41dd-9a9a-e440898be3ab
# ╟─3005d8e2-f018-43eb-9759-8ee48fa9ea1a
# ╠═4fb20f7c-ba52-4381-b75d-1a726e62569c
# ╟─4a37d8c9-8766-4692-8c8d-4f14c67df4ee
# ╟─9d901dca-4660-43c8-9781-a87b02fd54e3
# ╠═d1f872d2-0953-47d1-b4cc-e177496677b0
# ╟─dc0dce98-3824-44ef-bd58-d14c0a93f8ac
# ╠═ef76ab85-a2bd-4b5b-acc1-176eead528f5
# ╟─23fbae8c-cf91-4946-b31d-86cd9c2acc65
# ╟─2869aaa6-9941-46b0-b240-cf9e39231525
# ╠═4ed00d92-eff3-4ff5-a97d-c844e7a48c67
# ╟─779d6fb0-4e6c-4e4b-9720-f26b0b77990d
# ╟─182dc7ba-bb2d-4b95-b393-79b0860dd8d0
# ╟─54fd03d0-9a90-429d-af80-824196cd40e6
# ╠═3a961a8b-7b61-48e8-b840-8ef6c5acafe8
# ╟─049f048b-12ec-4ab3-891b-257c8b766a10
# ╠═3973c872-5817-4215-925a-b93e2186e33a
# ╠═78686ae5-4219-43b5-896b-3a86864ce049
# ╟─be9e0f8d-a424-4025-bb1e-baa876664633
# ╟─713265a1-2431-4e20-8e3d-965c924be1d1
# ╟─c23f1cfb-de99-4119-ba00-14af073e33f1
# ╟─1c217bf9-5c67-42d7-8be7-b8b635a1ed93
# ╟─6b5c76d9-da97-49a4-9d2c-5ae22e08b44a
# ╟─e76ff922-f61f-4c80-836b-9cbbb0952d2d
# ╠═b3d3f4c3-968d-4235-82b9-d6f9806109f8
# ╟─71205282-e4bc-479f-b7c0-db6783066d84
# ╟─938e338e-9242-4343-accf-c9d5d1c0420a
# ╠═104828fd-61d1-48af-879c-719b95cc1074
# ╠═ffd9315b-d5ad-4636-ba2f-5380c22055d2
# ╠═b5f4992a-5233-4ade-8ca4-bf2e6da1a4ac
# ╠═e36ebf1c-a750-40b4-8815-8bb3dee3910f
# ╟─7cba065d-98b4-4e04-a3b4-76224878a0bd
# ╠═c97e19e9-e818-432e-aaeb-618090372fad
# ╠═e54ae808-22f9-4ee5-9b75-d93aa56a8b3d
# ╠═74c3f2cb-6865-4cde-9c61-b75777854866
# ╟─488e83b4-4f5e-400f-85e2-f3b0716d7404
# ╠═5e48f2ae-bfc8-4130-a831-fae02b331bf7
# ╟─31f2d123-8a9a-45c6-9f80-569b070c54e4
# ╟─990f6bc0-f8d0-4374-b28c-82664e24984a
# ╟─e5d41d8f-3b62-434b-9491-98a017e90658
# ╟─40d92503-c7ab-4bf7-af62-02b08a284c17
# ╟─337d9aaf-e2f5-49cc-bd68-178d12110390
# ╠═2b93af3a-066b-443f-88c4-702b17e555b7
# ╟─e16a4171-e82d-4c43-af26-1f183fd15b2f
# ╠═e6ae2efe-d519-4c44-b706-a0ca95e6c050
# ╠═9de88c42-a73b-42f1-95be-e117b5beb77b
# ╟─11bd6e51-6993-4b8e-945c-7e61ff970dd4
# ╟─cc4b05de-6d6a-4c61-bdca-a0f6992ecfca
# ╠═2facd1bf-e9ac-46c1-9523-1244395a3e8b
# ╠═63fbadee-2ad4-4f68-9ba1-5c9d0143eb1a
# ╟─1d9033dd-e266-4192-930d-ef5be6780226
# ╠═dba75149-3e4c-4046-8fc7-42e8bf7375a5
# ╟─a16b0dc3-56c4-4f1c-94f2-ab034bfc30f3
# ╟─e3fb296e-c338-460f-b73f-fc5a4ffe2368
# ╟─c85762f2-6ad0-43aa-99a2-abd1e8249cdd
# ╠═d30212db-5306-4d3c-a786-f568ca67725f
# ╟─9be239b8-6c91-47c7-97c6-c39cddd3bc5d
# ╠═2c0adb00-71b6-483c-be10-f31642690184
# ╟─7557b534-c348-44bd-8de2-557a290e1b59
# ╠═5d78bd1f-47b3-422c-ae34-11f5e2ae93c3
# ╟─5514f1a7-bc64-4042-8c5e-b3dc835ebd2d
# ╟─0bf114a2-ec3a-4625-b60d-0287f447d2a4
# ╠═3d081d57-0bdb-448b-801f-b1a3bb8deb67
# ╟─5d715c51-147f-4a98-93cd-0c5fc2c51430
# ╠═3c9822b6-2643-4b0d-be1c-4716d701fbfa
# ╠═d253af17-92a7-4c62-a227-fb8cf9298939
# ╠═36de15f2-100d-4e21-8ca1-6a4b3a08a52d
# ╟─ed673d82-55eb-4ba8-9e64-410ecc64e499
# ╠═3d117fff-2447-4b3b-ab71-301b38e24d54
# ╟─8a786af1-9902-4f58-ba58-4cf9dd3b9d3e
# ╟─71ccf51e-2d8c-46d1-8b87-953bcbf8302f
# ╟─85ea82e9-35c6-41be-a575-ab823809eef7
# ╟─10403496-5a93-4890-b399-93d6086ff3ee
# ╟─2ba5f81f-019b-4749-a0a2-35ead50dee5f
# ╠═1cd04b3f-3a4e-4c93-85f0-4a41773c4366
# ╟─9bb894f5-6247-43b0-a632-0a034be4abe8
# ╠═ca2acf91-28d1-4ddc-8150-f4eecef3dffa
# ╟─2871b32a-180e-4d57-a1c8-44bc68ec1816
# ╠═bc1e3f75-8d92-4311-877a-6a4d7f227830
# ╟─b0eccdc2-40bc-44d7-8a72-3e059a4214ab
# ╠═81d7a663-1079-4613-afd8-de95eb73f8ae
# ╠═d93a8dca-9c63-4551-87e8-9939a765bef1
# ╠═8b184833-59d9-4958-8460-369b1ea19b9e
# ╠═0cac30f1-9101-4ba3-accc-52621bc1d16f
# ╟─00000000-0000-0000-0000-000000000001
# ╟─00000000-0000-0000-0000-000000000002
