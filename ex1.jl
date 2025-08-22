### A Pluto.jl notebook ###
# v0.20.17

using Markdown
using InteractiveUtils

# This Pluto notebook uses @bind for interactivity. When running this notebook outside of Pluto, the following 'mock version' of @bind gives bound variables a default value (instead of an error).
macro bind(def, element)
    #! format: off
    return quote
        local iv = try Base.loaded_modules[Base.PkgId(Base.UUID("6e696c72-6542-2067-7265-42206c756150"), "AbstractPlutoDingetjes")].Bonds.initial_value catch; b -> missing; end
        local el = $(esc(element))
        global $(esc(def)) = Core.applicable(Base.get, el) ? Base.get(el) : iv(el)
        el
    end
    #! format: on
end

# ╔═╡ 8b184833-59d9-4958-8460-369b1ea19b9e
using Printf

# ╔═╡ 0cac30f1-9101-4ba3-accc-52621bc1d16f
begin
	using PlutoUI, PlutoTest, PlutoTeachingTools, PlutoLinks
	using BenchmarkTools
	using Profile, ProfileCanvas 
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
First, we'll demonstrate the syntax for how to load code from another file into a Pluto notebook.  This can be useful for many reasons, particularly as you build larger projects.  Pluto is nice for the code that you're actively tinkering with.  But once you have your functions working and tested, it's likely wise to move them to an external file (or even a package, as we'll see later).  In this case, it'll make it easier to sort through all the information provided by the profiler, since we can filter the results to only show lines of code from the file with code that we're interested in profiling.
"""

# ╔═╡ 0d25c024-ab14-44bb-85bf-15a86152e7a1
begin
	KeplerEqn = @ingredients "./src/calc_rv.jl"  # provided by PlutoLinks.jl 
	import .KeplerEqn: calc_ecc_anom, calc_rv_keplerian
end

# ╔═╡ d1fae43a-b6a7-4ae2-aa5c-e495d59f5e77
md"""
Next, we'll demonstrate the syntax for using Julia's profiler.
"""

# ╔═╡ 1e4df7eb-d8de-4bae-912e-c2360f530b76
with_terminal() do
	calc_ecc_anom(π/4,0.5)     # Make sure our function is avaliable & compiled
	Profile.clear()  # Clear the data stored by the profiler
	@profile calc_ecc_anom(π/4,0.5)
	Profile.print()
end

# ╔═╡ 3f55c815-65a2-4950-8b2f-bc6d19e606c6
md"""
The odds are that you got a warning message that there were no samples collected.  Julia uses a *statistical* profiler, meaning that it doesn't count every time a line is executed, but rather it checks what line of code is being executed every so often.  `calc_ecc_anom` returned so quickly that the profiler didn't get a chance to figure out where it was spending its time.  In this case, it's so fast that we can't make the delay between samples fast enough, so we'll combine both of the suggestions from the warning message to get usable profiling data.  We'll create a function that makes it easy to profile our function by calling it many times with a smaller delay.
"""

# ╔═╡ 10b4e800-5415-4e4a-a5e0-43bb0e778f26
function profile_calc_ecc_anom(n::Integer=1)
	@assert n>=1
	calc_ecc_anom(π/4,0.5)     # Make sure our function is avaliable & compiled
	for i in 1:n 		              # Accumulate data over multiple function calls
		mean_anom = 2π*rand()     # Generate random input values
		ecc = rand()
		# Actually run profiler on one call
		@profile calc_ecc_anom(mean_anom,ecc)
	end
	Profile.retrieve()
end

# ╔═╡ 116dca0d-a949-42d4-ac78-bcd9d2d2d9e8
md"""
Now we'll run the profile on `calc_ecc_anom` (and save the results two ways to compare below.)
"""

# ╔═╡ b355695e-354b-48c0-a415-8f0c74c88265
begin
	Profile.clear()
	Profile.init(delay=1e-7) 
	retrieve_prof_calc_ecc_anom = profile_calc_ecc_anom(10^5);
	# Print a human-readable version to a file for use below
	filename1, file1 = mktemp() 
	Profile.print(IOContext(file1, :displaysize => (24, 500)) )
	close(file1)
end

# ╔═╡ 5297dcb2-974a-4bdc-a78d-d353299db2bc
md"""
First, we'll look at the default behavior (what you get if you run `Profile.print()`)
"""

# ╔═╡ cce0518b-68fc-43a7-866a-d02febcf9901
Profile.print(retrieve_prof_calc_ecc_anom..., )

# ╔═╡ b2eb6f46-8707-4f46-ada1-dd309a4b4cab
md"""
You should see lots of data above.  Each line of output corresponds to one line of code.  On the right of each line is the file containing the relevant code, the line number and a  function.  The number immediately to the left of the text is the number of times that the profiles checked in and found that the computer was executing that line of code *including* any computations in functions that resulted from it.  

This is a *tree view*, meaning that the lines are organized by what function calls what function.  The first several lines are because we're running inside a Pluto notebook.  Pluto wraps our cells in several functions to make it's reactive environment work.  

We could skip down to the line just below the line containing 'Profile.jl#@#==#...:27; macro expansion' (The '...' shorthand for a string of letters and numbers that Pluto uses to identify which cell the code is in).  That's where the work we're interested begins.  The number immediately to the left is the total number of profiler samples collected for our code (in this case `calc_ecc_anom`).
"""

# ╔═╡ d304539f-8b95-446a-aa7e-51abdc109bc9
md"""
For larger codes, sometimes the results are so big (or there is such a deep tree of functions), that you want the profiler output to be spread over more columns than the default.  Already, many lines have some text replaced with '...' so that the text fits within a standard terminal width.  To make it easier for you, we'll write the profile results to a text file and specify that it should assume there can write very wide lines to the file.

It'll also make it easier to find what we're most interested in, if we 'filter' the results to keep only lines of code that we're interested in.  In this case, we'll focus on code from the file named 'kepler_eqn.jl'.  Click the rightarrow  below to display the full results of the selected lines.
"""

# ╔═╡ 093813dd-6709-4ccf-b467-173df6c965f7
md"""
Once we've written the profiling results to a file, we can read each line and select the lines that refer to specific functions that we're specifically interested in.
"""

# ╔═╡ 983f4e76-df19-4a18-9d52-41e112f364fb
profile_results_from_file = readlines(filename1)

# ╔═╡ bfe30f9c-439f-4040-be5c-7c3d6e3a3438
vcat(profile_results_from_file[1:2],filter(l->contains(l,"kepler_eqn.jl") , profile_results_from_file))

# ╔═╡ c35f9ce9-01ed-46d2-8732-6f6778449479
md"""
1a.  How many samples did you get for 'kepler\_eqn.jl:45; calc\_ecc\_anom' (the first time it appears and its largest value)?
"""

# ╔═╡ 8894cd1c-5f94-4b07-94a0-757b2fdf75db
response_1a = ""# missing # Replace with an integer

# ╔═╡ 640647b7-1388-41dd-9a9a-e440898be3ab
display_msg_if_fail(check_type_isa(:response_1a,response_1a,Integer))

# ╔═╡ 3005d8e2-f018-43eb-9759-8ee48fa9ea1a
md"""
1b.  Scroll down looking for other big numbers (e.g., at least a quarter of the value from 1a ($response_1a)).
(If you're looking at the raw results, then ignore any lines that refer to 'Profile.jl' or 'task.jl'.)
Which line numer of code in kepler_eqn is taking the most time?
"""

# ╔═╡ 4fb20f7c-ba52-4381-b75d-1a726e62569c
response_1b = ""#missing # Replace with an integer

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
Profile.print(IOContext(stdout, :displaysize => (24, 120)), retrieve_prof_calc_ecc_anom..., format=:flat, sortedby=:count)

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

# ╔═╡ 3a961a8b-7b61-48e8-b840-8ef6c5acafe8
let
	profile_calc_ecc_anom(10)
	ProfileCanvas.@profview profile_calc_ecc_anom(10^5) 
end

# ╔═╡ f43bd729-fedb-4638-8c97-fbfa6d70c049
md"""
Again, since this calculation was so fast, we see that most of the time (width) was taken by Pluto managing the work.  We're going to zoom in on the portion where it's actually evaluating our function.  Click once on the cell in the bottom right, so that cell now fill the width and it will shows more rows, deeper down the call stack. Look towards the bottom for one of the cells labeled macro expansion and click it once.  It'll zoom in again.  Now you should be able to see a cell on the right labeled `calc_ec..`.  Click the first (highest up) one of those.  

Now, you can see where the time for `calc_ecc_anom` is really going visually.  Hover over some of the longer cells to see the full function name, line number and number of samples collected for that line.  
"""

# ╔═╡ be9e0f8d-a424-4025-bb1e-baa876664633
md"""
Look in the tall part of the stack for the cell 'kepler\_eqn.jl:46; calc\_ecc\_anom' (just below the first lowest green cell).  Hover over that cell to zoom in on the time spent inside 'calc\_ecc\_anom'.  You can hover your mouse over other cells to see what line they refer to.
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
	PeriodogramOrig = @ingredients "src/periodogram_orig.jl"
	calc_periodogram_orig = PeriodogramOrig.calc_periodogram
	Periodogram = @ingredients "src/periodogram.jl"
	import .Periodogram: calc_periodogram
end

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
num_obs = 100;        # Number of simulated observations

# ╔═╡ b5f4992a-5233-4ade-8ca4-bf2e6da1a4ac
num_periods = 10000;  # Number of potential orbital periods to search

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

# ╔═╡ be711ea3-5f90-47bc-906a-4dd6bb470ccf
let
	calc_periodogram_orig(times,rvs_obs,σ_rvs,num_periods=10)  # make sure its compiled
	ProfileCanvas.@profview calc_periodogram_orig(times,rvs_obs,σ_rvs,num_periods=num_periods)
end

# ╔═╡ 488e83b4-4f5e-400f-85e2-f3b0716d7404
md"""
As before, there's over two dozen levels of functions at the top of the profile results before we get to our functions of interest, 'calc\_periodogram'.  Click on lower row, repeat and then look for the first cell labeled  'calc\_periodogram' and line 30.  Then click the last cell of equal width likely labeled '#3').  Look at how the code is spending its time.

1f.  Look for some cells near the bottom that take a non-trivial fraction of the time and aren't doing math.  What is taking time and could be avoided (or at least significantly reduced)?
"""

# ╔═╡ 5e48f2ae-bfc8-4130-a831-fae02b331bf7
response_1f = missing  # Replace with md"Response"

# ╔═╡ 31f2d123-8a9a-45c6-9f80-569b070c54e4
display_msg_if_fail(check_type_isa(:response_1f,response_1f,Markdown.MD))

# ╔═╡ 990f6bc0-f8d0-4374-b28c-82664e24984a
hint(md"""The function `similar` creates an uninitialized array with the same size and element type as its argument.  The function `Array` allocates memory for an array.
The results are color-coded to help us quickly find potential opportunities for improving our code's efficiency.
Yellow indicate a site of garbage collection, which is often triggered by memory allocation.  If we could reduce the ammount of temporary memory allocated by your code, then we could reduce the amount of time needed for garbage collection.
(FYI, red shows function calls resolved at run-time.  There shouldn't be any of that here.  But if you see that when profiling your own code, then it's good to ask whether that's something that could be implemented more efficiently.)
""")

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
	@test all(result_new.periodogram .≈ result_orig.periodogram) && all(result_new.predict .≈ result_orig.predict)
end

# ╔═╡ e16a4171-e82d-4c43-af26-1f183fd15b2f
md"""
Since we pre-allocated memory in order to reduce the memory being allocated, let's check to see if/how much of a difference our modifications made.
"""

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

# ╔═╡ 7acbbc8f-2e3e-43ab-80b8-c4938e296038
let
	calc_periodogram_results_small = calc_periodogram(times,rvs_obs,σ_rvs,num_periods=10) # Make sure compiled before profiling, can reduce number of periods so this doesn't take long
	@profview calc_periodogram(times,rvs_obs,σ_rvs,num_periods=num_periods) 
end

# ╔═╡ 1d9033dd-e266-4192-930d-ef5be6780226
md"""
Again, click on the bottom row, repate and click the cell with 'calc\_periodogram' and line 30.  Then click on the last row below with nearly the same width (likely labeled '#3'.  Look at how the code is spending its time.

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
let
	mem_pgram_orig
	#(@isdefined calc_periodogram_orig) && 
	@benchmark calc_periodogram_orig($times,$rvs_obs,$σ_rvs,num_periods=$num_periods)
end

# ╔═╡ 9be239b8-6c91-47c7-97c6-c39cddd3bc5d
md"**Updated Periodogram code**"

# ╔═╡ 2c0adb00-71b6-483c-be10-f31642690184
let
	mem_pgram_new
	@benchmark calc_periodogram($times,$rvs_obs,$σ_rvs,num_periods=$num_periods)
end

# ╔═╡ 7557b534-c348-44bd-8de2-557a290e1b59
md"1h.  How does the run time compare?"

# ╔═╡ 5d78bd1f-47b3-422c-ae34-11f5e2ae93c3
response_1h = missing # Replace with md"Response"

# ╔═╡ 5514f1a7-bc64-4042-8c5e-b3dc835ebd2d
display_msg_if_fail(check_type_isa(:response_1h,response_1h,Markdown.MD))

# ╔═╡ ed673d82-55eb-4ba8-9e64-410ecc64e499
md"1i.  Based on the above results, estimate by the maximum percentage we could further speed up  `calc_periodogram`, if we were able to completely eliminate time spent allocating arrays.   Is that likely to be worth our time to figure out how to implement such an optimization?"

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
LinearAlgebra = "37e2e46d-f89d-539d-b4ee-838fcccc9c8e"
PDMats = "90014a1f-27ba-587c-ab20-58faa44d9150"
PlutoLinks = "0ff47ea0-7a50-410d-8455-4348d5de0420"
PlutoTeachingTools = "661c6b06-c737-4d37-b85c-46df65de6f69"
PlutoTest = "cb4044da-4d16-4ffa-a6a3-8cad7f73ebdc"
PlutoUI = "7f904dfe-b85e-4ff6-b463-dae2292396a8"
Printf = "de0858da-6303-5e67-8744-51eddeeeb8d7"
Profile = "9abbd945-dff8-562f-b5e8-e1ebf5ef1b79"
ProfileCanvas = "efd6af41-a80b-495e-886c-e51b0c7d77a3"
Random = "9a3f8284-a2c9-5f02-9a11-845980a1fd5c"
Statistics = "10745b16-79ce-11e8-11f9-7d13ad32a3b2"

[compat]
BenchmarkTools = "~1.6.0"
PDMats = "~0.11.35"
PlutoLinks = "~0.1.6"
PlutoTeachingTools = "~0.4.5"
PlutoTest = "~0.2.2"
PlutoUI = "~0.7.71"
ProfileCanvas = "~0.1.6"
"""

# ╔═╡ 00000000-0000-0000-0000-000000000002
PLUTO_MANIFEST_TOML_CONTENTS = """
# This file is machine-generated - editing it directly is not advised

julia_version = "1.11.2"
manifest_format = "2.0"
project_hash = "84679115b50c2fd9afde01d74f62f2fb5abcd005"

[[deps.AbstractPlutoDingetjes]]
deps = ["Pkg"]
git-tree-sha1 = "6e1d2a35f2f90a4bc7c2ed98079b2ba09c35b83a"
uuid = "6e696c72-6542-2067-7265-42206c756150"
version = "1.3.2"

[[deps.ArgTools]]
uuid = "0dad84c5-d112-42e6-8d28-ef12dabb789f"
version = "1.1.2"

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
git-tree-sha1 = "5ac098a7c8660e217ffac31dc2af0964a8c3182a"
uuid = "da1fd8a2-8d9e-5ec2-8556-3022fb5608a2"
version = "2.0.0"

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

[[deps.Compiler]]
git-tree-sha1 = "382d79bfe72a406294faca39ef0c3cef6e6ce1f1"
uuid = "807dbc54-b67e-4c79-8afb-eafe4df6f2e1"
version = "0.1.1"

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

[[deps.JSON]]
deps = ["Dates", "Mmap", "Parsers", "Unicode"]
git-tree-sha1 = "31e996f0a15c7b280ba9f76636b3ff9e2ae58c9a"
uuid = "682c06a0-de6a-54ab-a142-c8b1cf79cde6"
version = "0.21.4"

[[deps.JuliaInterpreter]]
deps = ["CodeTracking", "InteractiveUtils", "Random", "UUIDs"]
git-tree-sha1 = "d8337622fe53c05d16f031df24daf0270e53bc64"
uuid = "aa1ae85d-cabe-5617-a682-6adf51b2e16a"
version = "0.10.5"

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
deps = ["CodeTracking", "Compiler", "JuliaInterpreter"]
git-tree-sha1 = "73b98709ad811a6f81d84e105f4f695c229385ba"
uuid = "6f1432cf-f94c-5a45-995e-cdbf5db27b0b"
version = "3.4.3"

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

[[deps.PDMats]]
deps = ["LinearAlgebra", "SparseArrays", "SuiteSparse"]
git-tree-sha1 = "f07c06228a1c670ae4c87d1276b92c7c597fdda0"
uuid = "90014a1f-27ba-587c-ab20-58faa44d9150"
version = "0.11.35"

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
git-tree-sha1 = "d852eba0cc08181083a58d5eb9dccaec3129cb03"
uuid = "295af30f-e4ad-537b-8983-00126c2a3abe"
version = "3.9.0"

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

[[deps.SuiteSparse]]
deps = ["Libdl", "LinearAlgebra", "Serialization", "SparseArrays"]
uuid = "4607b0f0-06f3-5cda-b6b1-a6196a1729e9"

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
# ╟─f80f430b-45d0-4b2a-8be6-e39aabccd6ae
# ╟─7fcc3f2a-cf98-4a95-a52e-518ca880f31d
# ╠═0d25c024-ab14-44bb-85bf-15a86152e7a1
# ╟─d1fae43a-b6a7-4ae2-aa5c-e495d59f5e77
# ╠═1e4df7eb-d8de-4bae-912e-c2360f530b76
# ╟─3f55c815-65a2-4950-8b2f-bc6d19e606c6
# ╠═10b4e800-5415-4e4a-a5e0-43bb0e778f26
# ╟─116dca0d-a949-42d4-ac78-bcd9d2d2d9e8
# ╠═b355695e-354b-48c0-a415-8f0c74c88265
# ╟─5297dcb2-974a-4bdc-a78d-d353299db2bc
# ╠═cce0518b-68fc-43a7-866a-d02febcf9901
# ╟─b2eb6f46-8707-4f46-ada1-dd309a4b4cab
# ╟─d304539f-8b95-446a-aa7e-51abdc109bc9
# ╟─093813dd-6709-4ccf-b467-173df6c965f7
# ╠═983f4e76-df19-4a18-9d52-41e112f364fb
# ╠═bfe30f9c-439f-4040-be5c-7c3d6e3a3438
# ╟─c35f9ce9-01ed-46d2-8732-6f6778449479
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
# ╠═3a961a8b-7b61-48e8-b840-8ef6c5acafe8
# ╟─f43bd729-fedb-4638-8c97-fbfa6d70c049
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
# ╠═be711ea3-5f90-47bc-906a-4dd6bb470ccf
# ╟─488e83b4-4f5e-400f-85e2-f3b0716d7404
# ╠═5e48f2ae-bfc8-4130-a831-fae02b331bf7
# ╟─31f2d123-8a9a-45c6-9f80-569b070c54e4
# ╟─990f6bc0-f8d0-4374-b28c-82664e24984a
# ╟─e5d41d8f-3b62-434b-9491-98a017e90658
# ╟─40d92503-c7ab-4bf7-af62-02b08a284c17
# ╟─337d9aaf-e2f5-49cc-bd68-178d12110390
# ╠═2b93af3a-066b-443f-88c4-702b17e555b7
# ╟─e16a4171-e82d-4c43-af26-1f183fd15b2f
# ╠═9de88c42-a73b-42f1-95be-e117b5beb77b
# ╟─11bd6e51-6993-4b8e-945c-7e61ff970dd4
# ╟─cc4b05de-6d6a-4c61-bdca-a0f6992ecfca
# ╠═7acbbc8f-2e3e-43ab-80b8-c4938e296038
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
