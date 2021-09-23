"""
   `ecc_anom_init_guess_danby(mean_anomaly, eccentricity)`

Returns initial guess for the eccentric anomaly for use by itterative solvers of Kepler's equation for bound orbits.

Based on "The Solution of Kepler's Equations - Part Three"
Danby, J. M. A. (1987) Journal: Celestial Mechanics, Volume 40, Issue 3-4, pp. 303-312 (1987CeMec..40..303D)
"""
function ecc_anom_init_guess_danby(M::Real, ecc::Real)
	@assert -2π<= M <= 2π
	@assert 0 <= ecc <= 1.0
    if  M < zero(M)
		M += 2π
	end
    E = (M<π) ? M + 0.85*ecc : M - 0.85*ecc
end;

"""
   `update_ecc_anom_laguerre(eccentric_anomaly_guess, mean_anomaly, eccentricity)`

Update the current guess for solution to Kepler's equation

Based on "An Improved Algorithm due to Laguerre for the Solution of Kepler's Equation"
   Conway, B. A.  (1986) Celestial Mechanics, Volume 39, Issue 2, pp.199-211 (1986CeMec..39..199C)
"""
function update_ecc_anom_laguerre(E::Real, M::Real, ecc::Real)
  (es, ec) = ecc .* sincos(E)
  F = (E-es)-M
  Fp = one(M)-ec
  Fpp = es
  n = 5
  root = sqrt(abs((n-1)*((n-1)*Fp*Fp-n*F*Fpp)))
  denom = Fp>zero(E) ? Fp+root : Fp-root
  return E-n*F/denom
end;

"""
   `calc_ecc_anom( mean_anomaly, eccentricity )`
   `calc_ecc_anom( param::Vector )``
	Estimates eccentric anomaly for given 'mean_anomaly' and 'eccentricity'.
If passed a parameter vector, param[1] = mean_anomaly and param[2] = eccentricity.
Optional parameter `tol` specifies tolerance (default 1e-8)
"""
function calc_ecc_anom end
function calc_ecc_anom(mean_anom::Real, ecc::Real; tol::Real = 1.0e-8)
	@assert 0 <= ecc <= 1.0
	@assert 1e-16 <= tol < 1
  	M = rem2pi(mean_anom,RoundNearest)
    E = ecc_anom_init_guess_danby(M,ecc)
	local E_old
    max_its_laguerre = 200
    for i in 1:max_its_laguerre
       E_old = E
       E = update_ecc_anom_laguerre(E_old, M, ecc)
       if abs(E-E_old) < tol break end
    end
    return E
end

function calc_ecc_anom(param::Vector; tol::Real = 1.0e-8)
	@assert length(param) == 2
	calc_ecc_anom(param[1], param[2], tol=tol)
end
