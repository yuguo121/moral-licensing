/* ====================================================================
   MASTER ANALYSIS DO FILE v2
   Project: Corporate ESG Engagement and Earnings Management
   Date: 2026-03-24

   Description:
     Part 0:  Settings, paths, package checks, utility programs
     Part 1:  Data loading, cleaning, panel setup, accrual-based DA
              (Modified Jones + Kothari performance-matched)
     Part 1B: Real EM measures (Roychowdhury 2006)
     Part 2:  Merge external datasets (KLD, IO, MSCI, CEO)
     Part 3:  Moderator & feature engineering
     Part 4:  Main regression analysis
     Part 5:  Entropy balance matching
     Part 5.5: Descriptive statistics
     Part 6-8: Robustness checks

   Methodological notes:
     - Modified Jones (v1): Estimate on unadjusted dREV, compute NDA with
       adjusted (dREV - dREC). See Dechow et al. (1995).
     - Modified Jones (v2/Heese): Estimate with adjusted (dREV - dREC)
       directly in regression; DA = residual. See Heese et al. (2023, TAR).
     - Kothari: Add lagged ROA to Modified Jones regression.
       See Kothari, Leone & Wasley (2005).
     - Roychowdhury REM: Abnormal CFO, production costs, discretionary
       expenses. See Roychowdhury (2006).
     - Heese composite REM = AbPROD - AbDISX (no AbCFO).
     - Industry-year minimum: 10 obs (Heese 2023).
     - Controls follow Zang (2012): Market Share, NOA, Size, ROA, Leverage.
     - DA+ = max(DA, 0) as Heese primary DV.
   ==================================================================== */

version 17
clear all
set more off
set matsize 10000
capture log close


/* ====================================================================
   PART 0: SETTINGS, PATHS & INFRASTRUCTURE
   ==================================================================== */

* --- 0.1 Project Paths ---
global ROOT      "c:\Users\HuGoL\OneDrive - HKUST (Guangzhou)\PhD\3_Research\Moral Lisensing"
global RAW_DATA  "D:\Research\Data"
global PROJ_DATA "$ROOT\data"
global OUTPUT    "$ROOT\output"

cd "$ROOT\code"
log using "$ROOT\code\analysis_v2_log.log", replace

* --- 0.2 Package Checks ---
foreach pkg in asreg reghdfe winsor2 ebalance estout {
    capture which `pkg'
    if _rc {
        display as error "Package `pkg' not found. Installing..."
        ssc install `pkg'
    }
}

* --- 0.3 Utility Program: Log Sample Size ---
capture program drop log_sample
program define log_sample
    syntax , Step(string)
    quietly count
    local n_obs = r(N)
    quietly duplicates report gvkey fyear
    local n_unique = r(unique_value)
    display as text "  [SAMPLE] `step': `n_obs' obs, `n_unique' firm-years"
end

display as text _newline ">>> Pipeline started: $S_DATE $S_TIME" _newline


/* ====================================================================
   PART 1: DATA LOADING, CLEANING & ACCRUAL-BASED DA
   ==================================================================== */
display as text ">>> Starting Part 1: Data Loading & DA Calculation..."

use "$RAW_DATA\Financials\compustat_80_25.dta", clear

* --- 1.1 Industry Classification (FF48) ---
gen sic_num = sic
gen industry = ""

replace industry = "1 Agric"  if inrange(sic_num, 0100, 0199) | inrange(sic_num, 0700, 0799) | inrange(sic_num, 0910, 0919) | sic_num == 2048
replace industry = "2 Food"   if inrange(sic_num, 2000, 2099)
replace industry = "3 Soda"   if inrange(sic_num, 2064, 2068) | inlist(sic_num, 2086, 2087, 2096, 2097)
replace industry = "4 Beer"   if inlist(sic_num, 2080, 2082, 2083, 2084, 2085)
replace industry = "5 Smoke"  if inrange(sic_num, 2100, 2199)
replace industry = "6 Toys"   if inrange(sic_num, 0920, 0999) | inrange(sic_num, 3650, 3652) | sic_num == 3732 | inrange(sic_num, 3930, 3931) | inrange(sic_num, 3940, 3949)
replace industry = "7 Fun"    if inrange(sic_num, 7800, 7841) | inrange(sic_num, 7900, 7999)
replace industry = "8 Books"  if inrange(sic_num, 2700, 2799)
replace industry = "9 Hshld"  if sic_num == 2047 | inrange(sic_num, 2391, 2392) | inrange(sic_num, 2510, 2519) | inrange(sic_num, 2590, 2599) | inrange(sic_num, 2840, 2844) | inrange(sic_num, 3160, 3269) | inrange(sic_num, 3630, 3639) | inrange(sic_num, 3750, 3751) | inrange(sic_num, 3800, 3995)
replace industry = "10 Clths" if inrange(sic_num, 2300, 2390) | inrange(sic_num, 3020, 3021) | inrange(sic_num, 3100, 3151) | inrange(sic_num, 3963, 3965)
replace industry = "11 Hlth"  if inrange(sic_num, 8000, 8099)
replace industry = "12 MedEq" if sic_num == 3693 | inrange(sic_num, 3840, 3851)
replace industry = "13 Drugs" if inrange(sic_num, 2830, 2836)
replace industry = "14 Chems" if inrange(sic_num, 2800, 2899)
replace industry = "15 Rubbr" if inrange(sic_num, 3031, 3099)
replace industry = "16 Txtls" if inrange(sic_num, 2200, 2299)
replace industry = "17 BldMt" if inrange(sic_num, 0800, 0899) | inrange(sic_num, 2400, 2499) | inrange(sic_num, 3420, 3499)
replace industry = "18 Cnstr" if inrange(sic_num, 1500, 1799)
replace industry = "19 Steel" if inrange(sic_num, 3300, 3399)
replace industry = "20 FabPr" if inrange(sic_num, 3400, 3479)
replace industry = "21 Mach"  if inrange(sic_num, 3510, 3599)
replace industry = "22 ElcEq" if inrange(sic_num, 3600, 3699)
replace industry = "23 Autos" if inrange(sic_num, 2296, 2396) | inrange(sic_num, 3010, 3799)
replace industry = "24 Aero"  if inrange(sic_num, 3720, 3729)
replace industry = "25 Ships" if inrange(sic_num, 3730, 3743)
replace industry = "26 Guns"  if inrange(sic_num, 3760, 3769) | sic_num == 3795 | inrange(sic_num, 3480, 3489)
replace industry = "27 Gold"  if inrange(sic_num, 1040, 1049)
replace industry = "28 Mines" if inrange(sic_num, 1000, 1499)
replace industry = "29 Coal"  if inrange(sic_num, 1200, 1299)
replace industry = "30 Oil"   if inrange(sic_num, 1300, 1399) | inrange(sic_num, 2900, 2999)
replace industry = "31 Util"  if inrange(sic_num, 4900, 4949)
replace industry = "32 Telcm" if inrange(sic_num, 4800, 4899)
replace industry = "33 PerSv" if inrange(sic_num, 7020, 7699)
replace industry = "34 BusSv" if inrange(sic_num, 2750, 4229)
replace industry = "35 Comps" if inrange(sic_num, 3570, 3695) | sic_num == 7373
replace industry = "36 Chips" if inrange(sic_num, 3622, 3812)
replace industry = "37 LabEq" if inrange(sic_num, 3811, 3839)
replace industry = "38 Paper" if inrange(sic_num, 2520, 3955)
replace industry = "39 Boxes" if inrange(sic_num, 2440, 3412)
replace industry = "40 Trans" if inrange(sic_num, 4000, 4789)
replace industry = "41 Whlsl" if inrange(sic_num, 5000, 5199)
replace industry = "42 Rtail" if inrange(sic_num, 5200, 5999)
replace industry = "43 Meals" if inrange(sic_num, 5800, 7399)
replace industry = "44 Banks" if inrange(sic_num, 6000, 6199)
replace industry = "45 Insur" if inrange(sic_num, 6300, 6411)
replace industry = "46 RlEst" if inrange(sic_num, 6500, 6611)
replace industry = "47 Fin"   if inrange(sic_num, 6200, 6799)
replace industry = "48 Other" if inrange(sic_num, 4950, 4991)
replace industry = "48 Other" if industry == ""
rename industry ff48

* --- 1.2 Sample Filtering with Attrition Tracking ---
display as text "  --- Sample Attrition ---"
quietly count
display as text "  [SAMPLE] Raw Compustat: `r(N)' obs"

drop if sic >= 6000 & sic <= 6999
quietly count
display as text "  [SAMPLE] After drop financials: `r(N)' obs"

* linkprim filter: only applicable to CRSP-Compustat merged data
capture confirm variable linkprim
if !_rc {
    drop if linkprim == "N" | linkprim == "J"
    quietly count
    display as text "  [SAMPLE] After drop secondary links: `r(N)' obs"
}

drop if missing(sale) | missing(at) | missing(oancf) | missing(ni)
quietly count
display as text "  [SAMPLE] After drop missing core vars: `r(N)' obs"

* --- 1.3 Identifier Standardization ---
* Use gvkey as the sole firm identifier throughout the pipeline
destring gvkey, replace force
gen cusip_8 = substr(cusip, 1, 8)

* Deduplicate at gvkey-fyear level before panel setup
duplicates tag gvkey fyear, gen(_dup_gvkey)
display as text "  [DIAG] Duplicate gvkey-fyear obs: " _continue
count if _dup_gvkey > 0
drop if _dup_gvkey > 0
drop _dup_gvkey

xtset gvkey fyear
sort gvkey fyear
log_sample, step("After identifier setup")

* --- 1.4 Firm-Level Variables (with Missing Value Protocol) ---
* Leverage: replace missing debt components with 0 (Compustat convention)
replace dltt = 0 if missing(dltt)
replace dlc  = 0 if missing(dlc)
gen lev = (dltt + dlc) / at

* Cash holdings
replace che = 0 if missing(che)
gen cash_holding = che / at

gen size = ln(at)
gen roa  = ni / at

gen mb1 = (prcc_f * csho) / ceq if !missing(prcc_f) & !missing(csho) & !missing(ceq) & ceq > 0

* Shareholders' Equity (SHE) -- cascading fill based on available vars
gen double she = .
capture confirm variable seq
if !_rc {
    replace she = seq if !missing(seq)
}
capture confirm variable pstk
if !_rc {
    replace she = ceq + pstk if missing(she) & !missing(ceq) & !missing(pstk)
}
replace she = ceq if missing(she) & !missing(ceq)
replace she = at - lt - mib if missing(she) & !missing(at) & !missing(lt)

* Preferred Stock (PS) -- use best available
gen double ps = 0
capture replace ps = pstkrv if !missing(pstkrv)
capture replace ps = pstkl  if ps == 0 & !missing(pstkl)
capture replace ps = pstk   if ps == 0 & !missing(pstk)

* Book Equity (BE) and Market-to-Book (MB)
gen double be = she - ps
gen mb2 = (prcc_f * csho) / be if !missing(prcc_f) & !missing(csho) & !missing(be) & be > 0
gen mv = prcc_f * csho

* Drop small firms (Market Value < $20M)
drop if mv < 20 | missing(mv)
log_sample, step("After drop small/missing MV firms")

* --- 1.5 SIC 2-digit Code ---
tostring sic, gen(sic_str)
gen sic_2 = substr(sic_str, 1, 2)

* --- 1.6 Accrual Variables ---
sort gvkey fyear

* Lagged total assets
by gvkey: gen double l_at = at[_n-1] if fyear[_n-1] == fyear - 1

* Drop obs without lagged assets (cannot compute scaled variables)
drop if missing(l_at)
log_sample, step("After drop missing lagged assets")

* Total accruals -- four definitions
by gvkey: gen dss_ta = (act - act[_n-1]) - (lct - lct[_n-1]) - (che - che[_n-1]) + (dlc - dlc[_n-1]) ///
    if fyear[_n-1] == fyear - 1
by gvkey: gen ko_ta = dss_ta - dp
by gvkey: gen yu_ta = ni - oancf
by gvkey: gen ge_ta = ibc - oancf if !missing(ibc)

* Scale by lagged assets
foreach v in dss ko yu ge {
    gen dv_ta_`v' = `v'_ta / l_at
}

* Regressors for Modified Jones model
gen iv_1  = 1 / l_at
by gvkey: gen iv_2  = (revt - revt[_n-1]) / l_at if fyear[_n-1] == fyear - 1
by gvkey: gen iv_22 = ((revt - revt[_n-1]) - (rect - rect[_n-1])) / l_at if fyear[_n-1] == fyear - 1
gen iv_3  = ppegt / l_at

* Lagged ROA for Kothari model
by gvkey: gen l_roa = roa[_n-1] if fyear[_n-1] == fyear - 1

* --- 1.7 Industry-Year Observation Filter ---
* Heese et al. (2023, TAR): require >= 10 industry-year obs
bysort sic_2 fyear: gen _ind_yr_n = _N
keep if _ind_yr_n >= 10
drop _ind_yr_n
log_sample, step("After industry-year >= 10 filter (Heese 2023)")

* --- 1.8 Winsorize Regressors Before DA Estimation ---
winsor2 dv_ta_dss dv_ta_ko dv_ta_yu dv_ta_ge iv_1 iv_2 iv_22 iv_3 l_roa, ///
    cuts(1 99) replace

* --- 1.9 Modified Jones DA Estimation (SIC-2 x Year) ---
display as text "  Estimating Modified Jones DA (SIC-2)..."
local measures dss ko yu ge
foreach m of local measures {
    bys fyear sic_2: asreg dv_ta_`m' iv_1 iv_2 iv_3
    gen _nda_`m' = _b_iv_1*iv_1 + _b_iv_2*iv_22 + _b_iv_3*iv_3 + _b_cons
    gen `m'_da_sic = dv_ta_`m' - _nda_`m'
    drop _Nobs _R2 _adjR2 _b_iv_1 _b_iv_2 _b_iv_3 _b_cons _nda_`m'
}

* Modified Jones DA (FF48 x Year) -- robustness
display as text "  Estimating Modified Jones DA (FF48)..."
foreach m of local measures {
    bys fyear ff48: asreg dv_ta_`m' iv_1 iv_2 iv_3
    gen _nda_`m' = _b_iv_1*iv_1 + _b_iv_2*iv_22 + _b_iv_3*iv_3 + _b_cons
    gen `m'_da_ff = dv_ta_`m' - _nda_`m'
    drop _Nobs _R2 _adjR2 _b_iv_1 _b_iv_2 _b_iv_3 _b_cons _nda_`m'
}

* --- 1.10 Kothari Performance-Matched DA (SIC-2 x Year) ---
display as text "  Estimating Kothari Performance-Matched DA (SIC-2)..."
foreach m of local measures {
    bys fyear sic_2: asreg dv_ta_`m' iv_1 iv_2 iv_3 l_roa
    gen _nda_`m' = _b_iv_1*iv_1 + _b_iv_2*iv_22 + _b_iv_3*iv_3 + _b_l_roa*l_roa + _b_cons
    gen `m'_da_kothari = dv_ta_`m' - _nda_`m'
    drop _Nobs _R2 _adjR2 _b_iv_1 _b_iv_2 _b_iv_3 _b_l_roa _b_cons _nda_`m'
}

display as text "  Estimating Kothari Performance-Matched DA (FF48)..."
foreach m of local measures {
    bys fyear ff48: asreg dv_ta_`m' iv_1 iv_2 iv_3 l_roa
    gen _nda_`m' = _b_iv_1*iv_1 + _b_iv_2*iv_22 + _b_iv_3*iv_3 + _b_l_roa*l_roa + _b_cons
    gen `m'_da_kothari_ff = dv_ta_`m' - _nda_`m'
    drop _Nobs _R2 _adjR2 _b_iv_1 _b_iv_2 _b_iv_3 _b_l_roa _b_cons _nda_`m'
}

* --- 1.11 Heese et al. (2023) Modified Jones Variant ---
* Heese estimates with adjusted revenue directly: TA/A = a0 + a1*(1/A) + a2*(dREV-dREC)/A + a3*PPE/A
* DA = TA/A - predicted (coefficients from adjusted-revenue regression)
display as text "  Estimating Heese-variant Modified Jones DA (SIC-2)..."
foreach m of local measures {
    bys fyear sic_2: asreg dv_ta_`m' iv_1 iv_22 iv_3
    gen _nda_h_`m' = _b_iv_1*iv_1 + _b_iv_22*iv_22 + _b_iv_3*iv_3 + _b_cons
    gen `m'_da_heese = dv_ta_`m' - _nda_h_`m'
    drop _Nobs _R2 _adjR2 _b_iv_1 _b_iv_22 _b_iv_3 _b_cons _nda_h_`m'
}

* --- 1.12 Income-Increasing DA and Absolute DA ---
* Heese (2023, TAR) uses DA+ = max(DA, 0) as primary DV
* Note: Heese TA = dss_ta (balance sheet, NO depreciation); ko_ta = dss_ta - dp
foreach stub in dss_da_sic dss_da_heese ko_da_sic ko_da_ff ///
                ko_da_kothari ko_da_kothari_ff ko_da_heese {
    capture gen `stub'_plus = max(`stub', 0)
    capture gen `stub'_abs  = abs(`stub')
}

log_sample, step("After DA estimation")
display as text ">>> Part 1 Accrual DA Completed."


/* ====================================================================
   PART 1B: REAL EARNINGS MANAGEMENT (Roychowdhury 2006)
   ==================================================================== */
display as text ">>> Starting Part 1B: Real EM (Roychowdhury 2006)..."

* --- 1B.1 REM Variables ---
sort gvkey fyear
gen cfo_scaled  = oancf / l_at
gen sale_scaled = sale / l_at
by gvkey: gen d_sale_scaled = (sale - sale[_n-1]) / l_at if fyear[_n-1] == fyear - 1
by gvkey: gen l_d_sale_scaled = d_sale_scaled[_n-1] if fyear[_n-1] == fyear - 1

* Production costs = COGS + change in inventory
replace invch = 0 if missing(invch)
gen prod_scaled = (cogs + invch) / l_at if !missing(cogs)

* Discretionary expenses = SG&A + R&D (treat missing R&D as 0)
replace xrd = 0 if missing(xrd)
gen disexp_scaled = (xsga + xrd) / l_at if !missing(xsga)

by gvkey: gen l_sale_scaled = sale_scaled[_n-1] if fyear[_n-1] == fyear - 1

* Winsorize REM regressors
winsor2 cfo_scaled sale_scaled d_sale_scaled l_d_sale_scaled ///
    prod_scaled disexp_scaled l_sale_scaled, cuts(1 99) replace

* --- 1B.2 Abnormal CFO ---
* CFO/A = a0 + a1*(1/A) + a2*(SALE/A) + a3*(dSALE/A) + e
display as text "  Estimating Abnormal CFO..."
bys fyear sic_2: asreg cfo_scaled iv_1 sale_scaled d_sale_scaled
gen _normal_cfo = _b_iv_1*iv_1 + _b_sale_scaled*sale_scaled + ///
    _b_d_sale_scaled*d_sale_scaled + _b_cons
gen ab_cfo = cfo_scaled - _normal_cfo
drop _Nobs _R2 _adjR2 _b_iv_1 _b_sale_scaled _b_d_sale_scaled _b_cons _normal_cfo

* --- 1B.3 Abnormal Production Costs ---
* PROD/A = b0 + b1*(1/A) + b2*(SALE/A) + b3*(dSALE/A) + b4*(L.dSALE/A) + e
display as text "  Estimating Abnormal Production Costs..."
bys fyear sic_2: asreg prod_scaled iv_1 sale_scaled d_sale_scaled l_d_sale_scaled
gen _normal_prod = _b_iv_1*iv_1 + _b_sale_scaled*sale_scaled + ///
    _b_d_sale_scaled*d_sale_scaled + _b_l_d_sale_scaled*l_d_sale_scaled + _b_cons
gen ab_prod = prod_scaled - _normal_prod
drop _Nobs _R2 _adjR2 _b_iv_1 _b_sale_scaled _b_d_sale_scaled _b_l_d_sale_scaled _b_cons _normal_prod

* --- 1B.4 Abnormal Discretionary Expenses ---
* DISX/A = g0 + g1*(1/A) + g2*(L.SALE/A) + e
display as text "  Estimating Abnormal Discretionary Expenses..."
bys fyear sic_2: asreg disexp_scaled iv_1 l_sale_scaled
gen _normal_disx = _b_iv_1*iv_1 + _b_l_sale_scaled*l_sale_scaled + _b_cons
gen ab_disexp = disexp_scaled - _normal_disx
drop _Nobs _R2 _adjR2 _b_iv_1 _b_l_sale_scaled _b_cons _normal_disx

* --- 1B.5 Composite REM ---
* Sign convention: higher values = more upward EM
gen ab_cfo_neg    = -1 * ab_cfo
gen ab_disexp_neg = -1 * ab_disexp
gen rem_total = ab_cfo_neg + ab_prod + ab_disexp_neg
* Heese et al. (2023, TAR) composite: REM = REM_Prod + REM_Disx (no AbCFO)
gen rem_heese = ab_prod + ab_disexp_neg

* Winsorize REM outputs
winsor2 ab_cfo ab_cfo_neg ab_prod ab_disexp ab_disexp_neg rem_total rem_heese, ///
    cuts(1 99) replace

log_sample, step("After REM estimation")
display as text ">>> Part 1B Real EM Completed."

save "$PROJ_DATA\dv_em_v2.dta", replace


/* ====================================================================
   PART 2: MERGING EXTERNAL DATA
   ==================================================================== */
display as text ">>> Starting Part 2: Merging Datasets..."

use "$PROJ_DATA\dv_em_v2.dta", clear
capture gen year = fyear
capture replace year = fyear if missing(year)

* --- 2.1 KLD Merge ---
display as text "  Merging KLD..."
* KLD cusip is 9-10 chars; truncate to 8 to match Compustat cusip_8
preserve
use "$RAW_DATA\ESG\kld_zy.dta", clear
gen cusip_8 = substr(cusip, 1, 8)
duplicates drop cusip_8 fyear, force
tempfile kld_temp
save `kld_temp'
restore

merge 1:1 cusip_8 fyear using `kld_temp', ///
    nogen keep(1 3 4 5) ///
    keepusing(env_str_* env_con_* com_str_* com_con_* ///
              hum_str_* hum_con_* emp_str_* emp_con_* ///
              div_str_* div_con_* pro_str_* pro_con_* ///
              cgov_str_* cgov_con_* ///
              alc_con_* gam_con_* mil_con_* nuc_con_* tob_con_*) update
log_sample, step("After KLD merge")

* --- 2.2 IO (Institutional Ownership) ---
display as text "  Merging IO..."
merge 1:1 cusip_8 fyear using "$RAW_DATA\Financials\io.dta", ///
    keepusing(per_*) keep(1 3) nogen
log_sample, step("After IO merge")

* --- 2.3 Culpability Flag from KLD ---
gen culpa = 0
foreach v of varlist alc_con_* gam_con_* mil_con_* nuc_con_* tob_con_* {
    capture replace culpa = 1 if `v' == 1
}

* --- 2.4 MSCI ESG (source of pillar scores) ---
display as text "  Merging MSCI..."
merge 1:1 cusip_8 year using "$PROJ_DATA\msci_esg.dta", keep(1 3) nogen
* Map MSCI pillar scores to vs_4 (Environmental) and vs_6 (Social)
capture gen vs_4 = environmental_pillar_score
capture gen vs_6 = social_pillar_score
capture gen vs_gov = governance_pillar_score
log_sample, step("After MSCI merge")

* --- 2.5 CEO Compensation (1:m merge then principled dedup) ---
display as text "  Merging CEO Compensation..."
display as text "  [DIAG] Pre-merge uniqueness:"
duplicates report cusip_8 year

merge 1:m cusip_8 year using "$PROJ_DATA\ceo_compensation.dta", nogen keep(1 3)

* Principled dedup: keep CEO with highest total compensation
* If total_curr_comp is unavailable, sort by name for deterministic result
capture confirm variable total_curr_comp
if !_rc {
    gsort cusip_8 year -total_curr_comp
}
else {
    sort cusip_8 year ceo_name
}
duplicates drop cusip_8 year, force

display as text "  [DIAG] Post-dedup:"
duplicates report cusip_8 year

* --- 2.6 KLD Variable Construction ---
capture {
    drop emp
    gen emp_kld = emp_str_num1 - emp_con_num1
    gen env_kld = env_str_num1 - env_con_num1

    gen kld = env_str_num1 - env_con_num1 + com_str_num1 - com_con_num1 + ///
              hum_str_num1 - hum_con_num1 + emp_str_num1 - emp_con_num1 + ///
              div_str_num1 - div_con_num1 + pro_str_num1 - pro_con_num1 + ///
              cgov_str_num1 - cgov_con_num1

    gen kldnocg = env_str_num1 - env_con_num1 + com_str_num1 - com_con_num1 + ///
                  hum_str_num1 - hum_con_num1 + emp_str_num1 - emp_con_num1 + ///
                  div_str_num1 - div_con_num1 + pro_str_num1 - pro_con_num1

    gen flammer_str = env_str_num1 + com_str_num1 + emp_str_num1 + pro_str_num1
}

* --- 2.7 Clean CEO Gender ---
capture {
    replace ceo_gender = "1" if ceo_gender == "MALE"
    replace ceo_gender = "0" if ceo_gender == "FEMALE"
    destring ceo_gender, replace
}

* --- 2.8 Heese (2023) / Zang (2012) Control Variables ---
* NOA at beginning of year = (SHE - Cash + Total Debt) / Sales, all lagged
sort gvkey year
by gvkey: gen _l_she  = she[_n-1]  if year[_n-1] == year - 1
by gvkey: gen _l_che  = che[_n-1]  if year[_n-1] == year - 1
by gvkey: gen _l_dltt = dltt[_n-1] if year[_n-1] == year - 1
by gvkey: gen _l_dlc  = dlc[_n-1]  if year[_n-1] == year - 1
by gvkey: gen _l_sale = sale[_n-1] if year[_n-1] == year - 1
gen noa = (_l_she - _l_che + _l_dltt + _l_dlc) / _l_sale ///
    if !missing(_l_she) & !missing(_l_sale) & _l_sale > 0
drop _l_she _l_che _l_dltt _l_dlc _l_sale
label var noa "Net Operating Assets (Beg. of Year)"

* Market Share at beginning of year: lagged firm sales / industry total
by gvkey: gen _l_sale2 = sale[_n-1] if year[_n-1] == year - 1
bysort sic_2 year: egen _ind_total_l_sale = total(_l_sale2)
gen mkt_share = _l_sale2 / _ind_total_l_sale if _ind_total_l_sale > 0
drop _l_sale2 _ind_total_l_sale
label var mkt_share "Market Share (Beg. of Year, SIC-2)"

* Loss dummy
gen byte loss = (ni < 0) if !missing(ni)
label var loss "Loss Indicator (NI < 0)"

* --- 2.9 Adjusted ROA ---
bys sic_2 year: egen aver_roa = mean(roa)
gen adj_roa = roa - aver_roa

* --- 2.10 Panel Setup & Uniqueness Assertion ---
xtset gvkey year
sort gvkey year

* --- 2.11 Industry Culpability Classification ---
gen industry_type = 0

replace industry_type = 1 if inrange(sic_num, 2100, 2199)
replace industry_type = 1 if inrange(sic_num, 3760, 3769) | sic_num == 3795 | inrange(sic_num, 3480, 3489)
replace industry_type = 1 if inrange(sic_num, 800, 899) | inrange(sic_num, 1000, 1119) | inrange(sic_num, 1400, 1499)
replace industry_type = 1 if sic_num == 2080 | inrange(sic_num, 2082, 2085)
replace industry_type = 1 if culpa == 1

log_sample, step("Part 2 complete")
save "$PROJ_DATA\playboard_v2.dta", replace
display as text ">>> Part 2 Completed."


/* ====================================================================
   PART 3: MODERATOR & FEATURE ENGINEERING
   ==================================================================== */
display as text ">>> Starting Part 3: Moderator Construction..."

use "$PROJ_DATA\playboard_v2.dta", clear
xtset gvkey year

* --- 3.1 Merge Firm Age ---
merge 1:1 gvkey year using "$RAW_DATA\firm_age.dta", ///
    keep(1 3 4 5) keepusing(age) nogen
log_sample, step("After firm_age merge")

* --- 3.2 Merge Duality Supplement ---
merge 1:1 gvkey year using "$PROJ_DATA\duality_sup.dta", ///
    keep(1 3) keepusing(duality) update nogen
log_sample, step("After duality merge")

* --- 3.3 Auditor Variables ---
gen big_n = (au > 0 & au < 9) if !missing(au)
gen big_4 = (au > 3 & au < 9) if !missing(au)
gen firm_age = age

* --- 3.4 Growth Variables (contiguous-year lags only) ---
sort gvkey year
by gvkey: gen _l_sale = sale[_n-1] if year[_n-1] == year - 1
gen growth_sale = (sale - _l_sale) / _l_sale if !missing(_l_sale) & _l_sale > 0
drop _l_sale

by gvkey: gen _l_at = at[_n-1] if year[_n-1] == year - 1
gen growth_asset = (at - _l_at) / _l_at if !missing(_l_at) & _l_at > 0
drop _l_at

* --- 3.5 Underperformance Variables ---
gen byte underperform = (adj_roa < 0) if !missing(adj_roa)
label var underperform "1 if Adjusted ROA < 0"

sort gvkey year
by gvkey: gen under_duration = 0 if _n == 1
by gvkey: replace under_duration = ///
    cond(underperform == 1 & !missing(underperform), ///
         cond(_n == 1, 1, ///
              cond(underperform[_n-1] == 1, under_duration[_n-1] + 1, 1)), ///
         0) if _n > 1
replace under_duration = 0 if missing(underperform)
label var under_duration "Consecutive years of underperformance"

log_sample, step("Part 3 complete")
save "$PROJ_DATA\final_analysis_v2.dta", replace
display as text ">>> Part 3 Completed."


/* ====================================================================
   PART 4: REGRESSION ANALYSIS & CONSOLIDATED OUTPUT
   ==================================================================== */
display as text ">>> Starting Part 4: Regression Analysis..."

use "$PROJ_DATA\final_analysis_v2.dta", clear

* --- 4.1 Variable Labeling ---
capture drop vs_11
gen vs_11 = vs_4 + vs_6
label var vs_11          "ES Composite Score"
label var vs_4           "Environmental Score"
label var vs_6           "Social Score"
label var industry_type  "Industry Culpability"
label var size           "Firm Size"
label var mb2            "Market-to-Book"
label var lev            "Leverage"
label var roa            "ROA"
label var growth_asset   "Asset Growth"
label var cash_holding   "Cash Holdings"
capture label var per_io         "Institutional Ownership"
capture label var big_4          "Big 4 Auditor"
capture label var firm_age       "Firm Age"
capture label var noa         "Net Operating Assets"
capture label var mkt_share   "Market Share"
capture label var loss        "Loss Indicator"
capture label var ceo_age     "CEO Age"
capture label var ceo_gender  "CEO Gender"
capture label var duality     "CEO Duality"
capture label var bod_independence "Board Independence"
capture label var bod_size    "Board Size"

label var ko_da_sic      "DA (Modified Jones, SIC-2)"
capture label var ko_da_sic_plus "DA+ (Income-Increasing, ko)"
capture label var ko_da_sic_abs  "|DA| (Absolute, ko)"
capture label var dss_da_heese      "DA (Heese: BS w/o depr, adj-rev)"
capture label var dss_da_heese_plus "DA+ (Heese Exact Replication)"
capture label var dss_da_heese_abs  "|DA| (Heese Exact Replication)"
capture label var dss_da_sic        "DA (BS w/o depr, v1 estimation)"
capture label var ko_da_heese       "DA (ko, adj-rev estimation)"
capture label var rem_heese         "REM (Heese: Prod-Disx, no CFO)"

* Build control set dynamically based on available variables
* Core controls (always available from Compustat)
global ctrl_core size mb2 lev roa growth_asset cash_holding ///
                 big_4 noa mkt_share loss

* Extended controls (optional, lower coverage)
global ctrl_ext
foreach _optvar in per_io firm_age ceo_age ceo_gender duality {
    capture confirm variable `_optvar'
    if !_rc {
        quietly count if !missing(`_optvar')
        if r(N) > 5000 {
            global ctrl_ext $ctrl_ext `_optvar'
        }
    }
}

global ctrl $ctrl_core $ctrl_ext
display "  [INFO] Control variables: $ctrl"

* Heese/Zang (2012) core controls (no CEO/governance variables)
global ctrl_heese mkt_share noa size roa lev

* --- 4.2 Winsorize DVs, IVs, and Controls ---
winsor2 ko_da_sic ko_da_ff ko_da_kothari ko_da_kothari_ff ///
        ko_da_sic_plus ko_da_sic_abs ko_da_kothari_plus ko_da_kothari_abs ///
        ko_da_heese ko_da_heese_plus ko_da_heese_abs ///
        dss_da_sic dss_da_heese dss_da_sic_plus dss_da_sic_abs ///
        dss_da_heese_plus dss_da_heese_abs ///
        rem_total rem_heese ab_cfo_neg ab_prod ab_disexp_neg ///
        noa mkt_share ///
        vs_11 vs_4 vs_6 $ctrl, cuts(0.5 99.5) replace

* --- 4.3 Main Regressions: Accrual EM (Modified Jones) ---
eststo clear

foreach v in vs_11 vs_4 vs_6 {
    capture noisily reghdfe ko_da_sic `v' 1.industry_type $ctrl, absorb(year gvkey) cluster(gvkey)
    if !_rc {
        eststo m_`v'
        estadd local fe_year "Yes"
        estadd local fe_firm "Yes"
    }
}

foreach v in vs_11 vs_4 vs_6 {
    capture noisily reghdfe ko_da_sic c.`v'##i.industry_type $ctrl, absorb(year gvkey) cluster(gvkey)
    if !_rc {
        eststo i_`v'
        estadd local fe_year "Yes"
        estadd local fe_firm "Yes"
    }
}

capture noisily esttab m_vs_11 m_vs_4 m_vs_6 i_vs_11 i_vs_4 i_vs_6 ///
    using "$OUTPUT\Master_Results.rtf", ///
    replace b(%9.4f) se(%9.4f) star(* 0.10 ** 0.05 *** 0.01) ///
    label compress nogaps ///
    mtitles("Main" "Main" "Main" "Int" "Int" "Int") ///
    scalars("fe_year Year FE" "fe_firm Firm FE" "N Observations" "r2_a Adj. R-squared") ///
    title("Corporate ESG, Sin Industries, and Earnings Management (Modified Jones)") ///
    addnotes("Robust standard errors clustered at firm level.")

* --- 4.4 Robustness: No CEO Controls ---
global ctrl_no_ceo size mb2 lev roa growth_asset cash_holding ///
                   per_io big_4 firm_age noa mkt_share loss
capture confirm variable duality
if !_rc { global ctrl_no_ceo $ctrl_no_ceo duality }

eststo clear
foreach v in vs_11 vs_4 vs_6 {
    capture noisily reghdfe ko_da_sic `v' 1.industry_type $ctrl_no_ceo, absorb(year gvkey) cluster(gvkey)
    if !_rc { eststo m_`v'_nc
              estadd local fe_year "Yes"
              estadd local fe_firm "Yes" }
}
foreach v in vs_11 vs_4 vs_6 {
    capture noisily reghdfe ko_da_sic c.`v'##i.industry_type $ctrl_no_ceo, absorb(year gvkey) cluster(gvkey)
    if !_rc { eststo i_`v'_nc
              estadd local fe_year "Yes"
              estadd local fe_firm "Yes" }
}

capture noisily esttab m_vs_11_nc m_vs_4_nc m_vs_6_nc i_vs_11_nc i_vs_4_nc i_vs_6_nc ///
    using "$OUTPUT\Master_Results_no_CEO.rtf", ///
    replace b(%9.4f) se(%9.4f) star(* 0.10 ** 0.05 *** 0.01) ///
    label compress nogaps ///
    mtitles("Main" "Main" "Main" "Int" "Int" "Int") ///
    scalars("fe_year Year FE" "fe_firm Firm FE" "N Observations" "r2_a Adj. R-squared") ///
    title("ESG and EM (Excluding CEO Controls)") ///
    addnotes("Robust standard errors clustered at firm level." ///
             "CEO Age and CEO Gender excluded.")

* --- 4.5 Robustness: Kothari Performance-Matched DA ---
eststo clear
foreach v in vs_11 vs_4 vs_6 {
    capture noisily reghdfe ko_da_kothari `v' 1.industry_type $ctrl, absorb(year gvkey) cluster(gvkey)
    if !_rc { eststo m_`v'_kt
              estadd local fe_year "Yes"
              estadd local fe_firm "Yes"
              estadd local dv_type "Kothari" }
}
foreach v in vs_11 vs_4 vs_6 {
    capture noisily reghdfe ko_da_kothari c.`v'##i.industry_type $ctrl, absorb(year gvkey) cluster(gvkey)
    if !_rc { eststo i_`v'_kt
              estadd local fe_year "Yes"
              estadd local fe_firm "Yes"
              estadd local dv_type "Kothari" }
}

capture noisily esttab m_vs_11_kt m_vs_4_kt m_vs_6_kt i_vs_11_kt i_vs_4_kt i_vs_6_kt ///
    using "$OUTPUT\Master_Results_Kothari.rtf", ///
    replace b(%9.4f) se(%9.4f) star(* 0.10 ** 0.05 *** 0.01) ///
    label compress nogaps ///
    mtitles("Main" "Main" "Main" "Int" "Int" "Int") ///
    scalars("fe_year Year FE" "fe_firm Firm FE" "dv_type DV Type" ///
            "N Observations" "r2_a Adj. R-squared") ///
    title("ESG and EM (Kothari Performance-Matched DA)") ///
    addnotes("Robust standard errors clustered at firm level." ///
             "DV: Kothari et al. (2005) performance-matched DA.")

* --- 4.6 Income-Increasing DA (Heese primary DV) ---
* Heese uses TA without depreciation (dss_ta) and DA+ = max(DA, 0)
eststo clear
foreach v in vs_11 vs_4 vs_6 {
    capture noisily reghdfe dss_da_heese_plus `v' 1.industry_type $ctrl, absorb(year gvkey) cluster(gvkey)
    if !_rc { eststo dap_`v'
              estadd local fe_year "Yes"
              estadd local fe_firm "Yes" }
}
foreach v in vs_11 vs_4 vs_6 {
    capture noisily reghdfe dss_da_heese_plus c.`v'##i.industry_type $ctrl, absorb(year gvkey) cluster(gvkey)
    if !_rc { eststo dapi_`v'
              estadd local fe_year "Yes"
              estadd local fe_firm "Yes" }
}

capture noisily esttab dap_vs_11 dap_vs_4 dap_vs_6 dapi_vs_11 dapi_vs_4 dapi_vs_6 ///
    using "$OUTPUT\Master_Results_DA_Plus.rtf", ///
    replace b(%9.4f) se(%9.4f) star(* 0.10 ** 0.05 *** 0.01) ///
    label compress nogaps ///
    mtitles("Main" "Main" "Main" "Int" "Int" "Int") ///
    scalars("fe_year Year FE" "fe_firm Firm FE" "N Observations" "r2_a Adj. R-squared") ///
    title("ESG and Income-Increasing DA+ (Heese 2023 Exact Replication)") ///
    addnotes("Robust standard errors clustered at firm level." ///
             "DV: DA+ = max(DA, 0). TA = balance sheet without depreciation." ///
             "Estimation: adjusted revenue (dREV-dREC) directly in regression.")

* --- 4.7 Heese-Variant Signed DA (for comparison) ---
eststo clear
foreach v in vs_11 vs_4 vs_6 {
    capture noisily reghdfe dss_da_heese `v' 1.industry_type $ctrl, absorb(year gvkey) cluster(gvkey)
    if !_rc { eststo hda_`v'
              estadd local fe_year "Yes"
              estadd local fe_firm "Yes" }
}
foreach v in vs_11 vs_4 vs_6 {
    capture noisily reghdfe dss_da_heese c.`v'##i.industry_type $ctrl, absorb(year gvkey) cluster(gvkey)
    if !_rc { eststo hdai_`v'
              estadd local fe_year "Yes"
              estadd local fe_firm "Yes" }
}

capture noisily esttab hda_vs_11 hda_vs_4 hda_vs_6 hdai_vs_11 hdai_vs_4 hdai_vs_6 ///
    using "$OUTPUT\Master_Results_Heese_DA.rtf", ///
    replace b(%9.4f) se(%9.4f) star(* 0.10 ** 0.05 *** 0.01) ///
    label compress nogaps ///
    mtitles("Main" "Main" "Main" "Int" "Int" "Int") ///
    scalars("fe_year Year FE" "fe_firm Firm FE" "N Observations" "r2_a Adj. R-squared") ///
    title("ESG and EM (Heese 2023 Signed DA)") ///
    addnotes("Robust standard errors clustered at firm level." ///
             "TA = balance sheet without depreciation; adjusted revenue in estimation.")

* --- 4.8 Real Earnings Management (Heese composite as primary) ---
eststo clear
local rem_dvs rem_heese ab_prod ab_disexp_neg rem_total
local rem_labels `" "REM(Heese)" "Abn PROD" "Abn DISX(-)" "REM(3-comp)" "'

local i = 0
foreach dv of local rem_dvs {
    local ++i
    capture noisily reghdfe `dv' vs_4 1.industry_type $ctrl, absorb(year gvkey) cluster(gvkey)
    if !_rc { eststo rem_`i'
              estadd local fe_year "Yes"
              estadd local fe_firm "Yes" }
}

local i = 0
foreach dv of local rem_dvs {
    local ++i
    capture noisily reghdfe `dv' c.vs_4##i.industry_type $ctrl, absorb(year gvkey) cluster(gvkey)
    if !_rc { eststo rem_int_`i'
              estadd local fe_year "Yes"
              estadd local fe_firm "Yes" }
}

capture noisily esttab rem_1 rem_2 rem_3 rem_4 rem_int_1 rem_int_2 rem_int_3 rem_int_4 ///
    using "$OUTPUT\Master_Results_REM.rtf", ///
    replace b(%9.4f) se(%9.4f) star(* 0.10 ** 0.05 *** 0.01) ///
    label compress nogaps ///
    mtitles("REM(H)" "AbPROD" "AbDISX" "REM(3)" "REM(H)" "AbPROD" "AbDISX" "REM(3)") ///
    scalars("fe_year Year FE" "fe_firm Firm FE" "N Observations" "r2_a Adj. R-squared") ///
    title("ESG and Real Earnings Management (Roychowdhury 2006)") ///
    addnotes("Robust standard errors clustered at firm level." ///
             "REM(H) = AbPROD - AbDISX (Heese 2023 composite, no AbCFO)." ///
             "REM(3) = -AbCFO + AbPROD - AbDISX (3-component).")

display as text ">>> Part 4 Completed."


/* ====================================================================
   PART 5: ENTROPY BALANCE MATCHING (EBM) ANALYSIS
   ==================================================================== */
display as text ">>> Starting Part 5: Entropy Balance Analysis..."

summarize vs_4, detail
capture drop high_vs4
gen high_vs4 = (vs_4 > r(p50)) if !missing(vs_4)
label var high_vs4 "High Environmental Score (vs_4 > Median)"

capture drop _webal
ebalance high_vs4 size mb2 lev roa, targets(1)

display "Entropy Balance Summary:"
sum _webal if high_vs4 == 0
sum _webal if high_vs4 == 1

eststo clear

capture noisily reghdfe ko_da_sic 1.high_vs4 $ctrl [iweight=_webal], absorb(year gvkey) cluster(gvkey)
if !_rc { eststo m1_eb
          estadd local fe_year "Yes"
          estadd local fe_firm "Yes"
          estadd local matching "EBM" }

capture noisily reghdfe ko_da_sic 1.high_vs4##1.industry_type $ctrl [iweight=_webal], absorb(year gvkey) cluster(gvkey)
if !_rc { eststo m2_eb
          estadd local fe_year "Yes"
          estadd local fe_firm "Yes"
          estadd local matching "EBM" }

capture noisily esttab m1_eb m2_eb using "$OUTPUT\Master_Results_Entropy.rtf", ///
    replace b(%9.4f) se(%9.4f) star(* 0.10 ** 0.05 *** 0.01) ///
    label compress nogaps ///
    mtitles("Main" "Interaction") ///
    scalars("fe_year Year FE" "fe_firm Firm FE" "matching Matching" ///
            "N Observations" "r2_a Adj. R-squared") ///
    title("ESG and EM (Entropy Balance on vs_4)") ///
    addnotes("Robust standard errors clustered at firm level." ///
             "Treatment: vs_4 > Median. Balanced on Size, MB, Lev, ROA.")

display as text ">>> Part 5 Completed."


/* ====================================================================
   PART 5.5: DESCRIPTIVE STATISTICS (Table 1)
   ==================================================================== */
display as text ">>> Generating Table 1..."

eststo clear
estpost summarize ko_da_sic ko_da_sic_plus ko_da_sic_abs ///
    dss_da_heese dss_da_heese_plus dss_da_heese_abs ///
    ko_da_kothari ///
    rem_heese rem_total ab_prod ab_disexp_neg ///
    vs_4 vs_6 industry_type ///
    mkt_share noa size roa lev loss ///
    growth_asset cash_holding per_io big_4 firm_age, listwise

esttab using "$OUTPUT\Table1_Descriptive_Stats.rtf", replace ///
    cells("count mean(fmt(3)) sd(fmt(3)) min(fmt(3)) max(fmt(3))") ///
    noobs label title("Table 1: Descriptive Statistics")

eststo clear
estpost correlate ko_da_sic dss_da_heese dss_da_heese_plus ko_da_kothari ///
    rem_heese vs_4 vs_6 industry_type ///
    mkt_share noa size roa lev, matrix listwise

esttab using "$OUTPUT\Table1_Correlation_Matrix.rtf", replace ///
    unstack not noobs compress ///
    b(%9.3f) star(* 0.10 ** 0.05 *** 0.01) ///
    label title("Table 1 (Panel B): Correlation Matrix")

display as text ">>> Table 1 generated."


/* ====================================================================
   PART 6: ROBUSTNESS -- FF48-BASED DA
   ==================================================================== */
display as text ">>> Starting Part 6: FF48 DA robustness..."

eststo clear
foreach v in vs_11 vs_4 vs_6 {
    capture noisily reghdfe ko_da_ff `v' 1.industry_type $ctrl, absorb(year gvkey) cluster(gvkey)
    if !_rc { eststo m_`v'_ff
              estadd local fe_year "Yes"
              estadd local fe_firm "Yes" }
}
foreach v in vs_11 vs_4 vs_6 {
    capture noisily reghdfe ko_da_ff c.`v'##i.industry_type $ctrl, absorb(year gvkey) cluster(gvkey)
    if !_rc { eststo i_`v'_ff
              estadd local fe_year "Yes"
              estadd local fe_firm "Yes" }
}

capture noisily esttab m_vs_11_ff m_vs_4_ff m_vs_6_ff i_vs_11_ff i_vs_4_ff i_vs_6_ff ///
    using "$OUTPUT\Master_Results_FF48.rtf", ///
    replace b(%9.4f) se(%9.4f) star(* 0.10 ** 0.05 *** 0.01) ///
    label compress nogaps ///
    mtitles("Main" "Main" "Main" "Int" "Int" "Int") ///
    scalars("fe_year Year FE" "fe_firm Firm FE" "N Observations" "r2_a Adj. R-squared") ///
    title("ESG and EM (Robustness: FF48-based DA)") ///
    addnotes("Robust standard errors clustered at firm level." ///
             "DV: ko_da_ff (FF48 industry classification).")

display as text ">>> Part 6 Completed."


/* ====================================================================
   PART 7: ROBUSTNESS -- STATE*YEAR FIXED EFFECTS
   ==================================================================== */
display as text ">>> Starting Part 7: State*Year FE..."

capture confirm numeric variable state
if _rc {
    capture encode state, gen(state_n)
}
else {
    capture gen state_n = state
}

eststo clear
foreach v in vs_11 vs_4 vs_6 {
    capture noisily reghdfe ko_da_sic `v' 1.industry_type $ctrl, absorb(gvkey state_n#year) cluster(gvkey)
    if !_rc { eststo m_`v'_sy
              estadd local fe_firm "Yes"
              estadd local fe_state_year "Yes" }
}
foreach v in vs_11 vs_4 vs_6 {
    capture noisily reghdfe ko_da_sic c.`v'##i.industry_type $ctrl, absorb(gvkey state_n#year) cluster(gvkey)
    if !_rc { eststo i_`v'_sy
              estadd local fe_firm "Yes"
              estadd local fe_state_year "Yes" }
}

capture noisily esttab m_vs_11_sy m_vs_4_sy m_vs_6_sy i_vs_11_sy i_vs_4_sy i_vs_6_sy ///
    using "$OUTPUT\Master_Results_StateYear.rtf", ///
    replace b(%9.4f) se(%9.4f) star(* 0.10 ** 0.05 *** 0.01) ///
    label compress nogaps ///
    mtitles("Main" "Main" "Main" "Int" "Int" "Int") ///
    scalars("fe_firm Firm FE" "fe_state_year State*Year FE" ///
            "N Observations" "r2_a Adj. R-squared") ///
    title("ESG and EM (Robustness: State*Year FE)") ///
    addnotes("Robust standard errors clustered at firm level." ///
             "Models include Firm and State*Year fixed effects.")

display as text ">>> Part 7 Completed."


/* ====================================================================
   PART 8: EFFECT OF LAGGED EM ON ESG
   ==================================================================== */
display as text ">>> Starting Part 8: Lagged EM on ESG..."

eststo clear

capture noisily reghdfe vs_4 l.ko_da_sic $ctrl, absorb(year gvkey) cluster(gvkey)
if !_rc { eststo m_em_esg
          estadd local fe_year "Yes"
          estadd local fe_firm "Yes" }

capture noisily reghdfe vs_4 c.l.ko_da_sic##i.industry_type $ctrl, absorb(year gvkey) cluster(gvkey)
if !_rc { eststo i_em_esg
          estadd local fe_year "Yes"
          estadd local fe_firm "Yes" }

capture noisily esttab m_em_esg i_em_esg using "$OUTPUT\Master_Results_EM_Lag.rtf", ///
    replace b(%9.4f) se(%9.4f) star(* 0.10 ** 0.05 *** 0.01) ///
    label compress nogaps ///
    mtitles("Main" "Interaction") ///
    scalars("fe_year Year FE" "fe_firm Firm FE" ///
            "N Observations" "r2_a Adj. R-squared") ///
    title("Effect of Lagged EM on Environmental Score (vs_4)") ///
    addnotes("Robust standard errors clustered at firm level." ///
             "IV is lagged ko_da_sic (t-1).")

display as text ">>> Part 8 Completed."


/* ====================================================================
   WRAP-UP
   ==================================================================== */
display as text _newline ">>> Pipeline finished: $S_DATE $S_TIME"
display as text ">>> Output files saved to: $OUTPUT"
log close
