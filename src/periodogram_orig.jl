using PDMats
import Statistics: mean, var
using LinearAlgebra

"""
   `calc_periodogram(times, y_obs, σ_ys; options...)`
Computes a periodogram for times, observations and uncertainties.

Inputs:
- times: obseration times
- y_obs: observed values at each time
- σ_ys:  measurement uncertainty at each time (may be either a Vector or positive definite matrix)
Optional parameters:

- period_min (2.0)
- period_max (4*span of times)
- num_periods (4000)

Output (as NamedTuple):
- period_grid: orbital periods searched
- periodogram: χ² for best fit given each orbital period
- period_best_fit: period searched resulting to minimum χ²
- coeff_best_fit: best-fit coefficients for period_best_fit
- phase_best_fit: orbital phase for period_best_fit at time = 0
- predict: predictions of best-fit model at each time
- rms: root mean square of predictions (of best-fit model) minus observations
"""
function calc_periodogram  end

function calc_periodogram(t::Vector, y_obs::Vector, σ_ys::Vector; kwargs...)
 	calc_periodogram(t, y_obs, PDiagMat(σ_ys.^2); kwargs...)
end

function calc_periodogram(t::Vector, y_obs::Vector, covar_mat::MT;
	    		period_min::Real = 2.0, period_max::Real = 4*(maximum(t)-minimum(t)), num_periods::Integer = 4000) where {
						T3<:Real, MT<:AbstractPDMat{T3} }
	period_grid =  1.0 ./ range(1.0/period_max, stop=1.0/period_min, length=num_periods)
	periodogram = map(p->-0.5*calc_χ²_general_linear_least_squares(calc_design_matrix_circ(p,t),covar_mat,y_obs),period_grid)
	period_fit = period_grid[argmax(periodogram)]
	design_matrix_fit = calc_design_matrix_circ(period_fit,t)
	coeff_fit = fit_general_linear_least_squares(design_matrix_fit,covar_mat,y_obs)
	phase_fit = atan(coeff_fit[1],coeff_fit[2])
	pred = design_matrix_fit * coeff_fit
	rms = sqrt(mean((y_obs.-pred).^2))
	return (;period_grid=period_grid, periodogram=periodogram, period_best_fit = period_fit, coeff_best_fit=coeff_fit, phase_best_fit=phase_fit, predict=pred, rms=rms )
end

# Internal routines called by calc_periodogram[]
function calc_design_matrix_circ!(result::AM, period::Real, times::AV) where { R1<:Real, AM<:AbstractMatrix{R1}, AV<:AbstractVector{R1} }
	n = length(times)
	@assert size(result,1) == n
	@assert 2<= size(result,2) <=3
	for i in 1:n
		( result[i,1], result[i,2] ) = sincos(2π/period .* times[i])
	end
	if size(result,2) == 3
		result[:,3] .= one(eltype(result))
	end
	return result
end

function calc_design_matrix_circ(period::Real, times::AV) where { R1<:Real, AV<:AbstractVector{R1} }
	n = length(times)
	dm = Array{promote_type(typeof(period),eltype(times))}(undef,n,3)
	calc_design_matrix_circ!(dm,period,times)
	return dm
end

function fit_general_linear_least_squares( design_mat::ADM, covar_mat::APD, obs::AA ) where { ADM<:AbstractMatrix, APD<:AbstractPDMat, AA<:AbstractArray }
	Xt_inv_covar_X = Xt_invA_X(covar_mat,design_mat)
	X_inv_covar_y =  design_mat' * (covar_mat \ obs)
	AB_hat = Xt_inv_covar_X \ X_inv_covar_y                            # standard GLS
end


function predict_general_linear_least_squares( design_mat::ADM, covar_mat::APD, obs::AA ) where { ADM<:AbstractMatrix, APD<:AbstractPDMat, AA<:AbstractArray }
	param = fit_general_linear_least_squares(design_mat,covar_mat,obs)
	design_mat * param
end

function calc_χ²_general_linear_least_squares( design_mat::ADM, covar_mat::APD, obs::AA ) where { ADM<:AbstractMatrix, APD<:AbstractPDMat, AA<:AbstractArray }
	pred = predict_general_linear_least_squares(design_mat,covar_mat,obs)
	invquad(covar_mat,obs-pred)
end
