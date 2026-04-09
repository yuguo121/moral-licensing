/* ====================================================================
   MASTER ANALYSIS v3 — regressions only
   Prerequisite: run Master_Merge_v3.do to build:
     $ROOT\data\processed\final_analysis_v3.dta
   ==================================================================== */

version 19.0
clear all
set more off
capture log close

global ROOT      "c:\Users\HuGoL\OneDrive - HKUST (Guangzhou)\PhD\3_Research\Moral Licensing"
global PROJ_DATA "$ROOT\data\processed"
global OUTPUT    "$ROOT\output"

cd "$ROOT\code"
log using "$ROOT\code\analysis_v3_log.log", replace

foreach pkg in reghdfe ivreghdfe winsor2 estout {
    capture which `pkg'
    if _rc {
        display as error "Package `pkg' not found. Installing..."
        ssc install `pkg'
    }
}

capture program drop run_loo_iv
program define run_loo_iv, rclass
    syntax, ESGVAR(name) DVVAR(name) CTRLS(string)

    tempvar sm cn iv_loo
    quietly bysort sic_2 year: egen double `sm' = total(`esgvar')
    quietly bysort sic_2 year: egen long `cn' = count(`esgvar')
    quietly gen double `iv_loo' = (`sm' - `esgvar') / (`cn' - 1) ///
        if `cn' > 1 & !missing(`esgvar')

    capture noisily ivreghdfe `dvvar' (`esgvar' = `iv_loo') `ctrls', ///
        absorb(gvkey year) cluster(gvkey)

    if _rc {
        return scalar ok = 0
        return scalar N_used = .
        return scalar F_kp = .
        return scalar b_esg = .
        return scalar se_esg = .
        return scalar t_esg = .
        return scalar p_esg = .
        exit
    }

    return scalar ok = 1
    return scalar N_used = e(N)
    capture return scalar F_kp = e(widstat)
    if _rc return scalar F_kp = .
    capture return scalar b_esg = _b[`esgvar']
    if _rc return scalar b_esg = .
    capture return scalar se_esg = _se[`esgvar']
    if _rc return scalar se_esg = .
    if missing(return(b_esg)) | missing(return(se_esg)) | return(se_esg) == 0 {
        return scalar t_esg = .
        return scalar p_esg = .
    }
    else {
        return scalar t_esg = return(b_esg) / return(se_esg)
        capture return scalar p_esg = 2 * ttail(e(df_r), abs(return(t_esg)))
        if _rc return scalar p_esg = .
    }
end

capture confirm file "$PROJ_DATA\final_analysis_v3.dta"
if _rc {
    display as error "Missing final_analysis_v3.dta — run Master_Merge_v3.do first."
    exit 601
}

display as text _newline ">>> Analysis v3 started: $S_DATE $S_TIME"

use "$PROJ_DATA\final_analysis_v3.dta", clear
xtset gvkey year


/* ====================================================================
   MAIN REGRESSIONS (Heese-aligned DV, current controls)
   ==================================================================== */
display as text _newline ">>> Main regressions..."

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
capture label var per_io "Institutional Ownership"
capture label var big_4  "Big 4 Auditor"
capture label var firm_age "Firm Age"
capture label var ceo_age "CEO Age"
capture label var ceo_gender "CEO Gender"
capture label var duality "CEO Duality"
label var noa            "Net Operating Assets"
label var mkt_share      "Market Share"
label var loss           "Loss Indicator"

capture label var da_dss     "DA, modified Jones; BS TA (no dep)"
capture label var da_ko      "DA; Jones TA incl. dep"
capture label var da_yu      "DA; NI-OANCF TA"
capture label var da_ge      "DA; IBC-OANCF TA"
capture label var da_dechow  "DA; IB-dCHE TA"
capture label var dss_da_heese "Same as da_dss"
label var rem_heese         "REM (Heese-aligned)"
capture label var ab_prod   "Abnormal Production Costs"
capture label var ab_disexp_neg "Abnormal Discretionary Expenses (-1)"

global ctrl_core size mb2 lev roa growth_asset cash_holding ///
                 big_4 noa mkt_share loss

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
global ctrl_heese mkt_share noa size roa lev

display as text "  [INFO] Control set: $ctrl"
display as text "  [INFO] Heese core in set: $ctrl_heese"

local wvars rem_heese ab_prod ab_disexp_neg vs_11 vs_4 vs_6 $ctrl
foreach s in dss ko yu ge dechow {
    capture confirm variable da_`s'
    if !_rc local wvars `wvars' da_`s'
}
local wvars_exist
foreach v of local wvars {
    capture confirm variable `v'
    if !_rc local wvars_exist `wvars_exist' `v'
}
winsor2 `wvars_exist', cuts(0.5 99.5) replace

eststo clear
foreach v in vs_11 vs_4 vs_6 {
    capture noisily reghdfe dss_da_heese `v' 1.industry_type $ctrl, absorb(year gvkey) cluster(gvkey)
    if !_rc {
        eststo da_`v'
        estadd local fe_year "Yes"
        estadd local fe_firm "Yes"
        estadd local dv_type "Heese-aligned signed DA"
    }
}
foreach v in vs_11 vs_4 vs_6 {
    capture noisily reghdfe dss_da_heese c.`v'##i.industry_type $ctrl, absorb(year gvkey) cluster(gvkey)
    if !_rc {
        eststo dai_`v'
        estadd local fe_year "Yes"
        estadd local fe_firm "Yes"
        estadd local dv_type "Heese-aligned signed DA"
    }
}

capture noisily esttab da_vs_11 da_vs_4 da_vs_6 dai_vs_11 dai_vs_4 dai_vs_6 ///
    using "$OUTPUT\Master_v3_Results_HeeseDA.rtf", ///
    replace b(%9.4f) se(%9.4f) star(* 0.10 ** 0.05 *** 0.01) ///
    label compress nogaps ///
    mtitles("Main" "Main" "Main" "Int" "Int" "Int") ///
    scalars("dv_type DV" "fe_year Year FE" "fe_firm Firm FE" "N Observations" "r2_a Adj. R-squared") ///
    title("v3 Main Results: ESG and Heese-Aligned Signed Discretionary Accruals") ///
    addnotes("Heese-preserved: balance-sheet accruals without depreciation; adjusted revenue in Modified Jones." ///
             "SIC-2 cells; clustered SE at firm level.")

eststo clear
foreach v in vs_11 vs_4 vs_6 {
    capture noisily reghdfe rem_heese `v' 1.industry_type $ctrl, absorb(year gvkey) cluster(gvkey)
    if !_rc {
        eststo rem_`v'
        estadd local fe_year "Yes"
        estadd local fe_firm "Yes"
        estadd local dv_type "Heese-aligned REM"
    }
}
foreach v in vs_11 vs_4 vs_6 {
    capture noisily reghdfe rem_heese c.`v'##i.industry_type $ctrl, absorb(year gvkey) cluster(gvkey)
    if !_rc {
        eststo remi_`v'
        estadd local fe_year "Yes"
        estadd local fe_firm "Yes"
        estadd local dv_type "Heese-aligned REM"
    }
}

capture noisily esttab rem_vs_11 rem_vs_4 rem_vs_6 remi_vs_11 remi_vs_4 remi_vs_6 ///
    using "$OUTPUT\Master_v3_Results_REM.rtf", ///
    replace b(%9.4f) se(%9.4f) star(* 0.10 ** 0.05 *** 0.01) ///
    label compress nogaps ///
    mtitles("Main" "Main" "Main" "Int" "Int" "Int") ///
    scalars("dv_type DV" "fe_year Year FE" "fe_firm Firm FE" "N Observations" "r2_a Adj. R-squared") ///
    title("v3 Main Results: ESG and Heese-Aligned Real Earnings Management") ///
    addnotes("REM = AbPROD + AbDISX(-). Discretionary expenses: SG&A + R&D (Compustat).")

display as text ">>> Main regressions completed."


/* ====================================================================
   LEAVE-ONE-OUT IV
   ==================================================================== */
display as text _newline ">>> Leave-one-out IV..."

tempname ivpost
postfile `ivpost' str18 dv str12 esg_score str12 spec ///
    double N_used F_kp b_esg se_esg t_esg p_esg using ///
    "$OUTPUT\Master_v3_IV_LOO_results.dta", replace

eststo clear
foreach esg in vs_11 vs_4 vs_6 {
    quietly run_loo_iv, esgvar(`esg') dvvar(dss_da_heese) ctrls("$ctrl")
    if r(ok) == 1 {
        eststo ivda_`esg'
        estadd local fe_year "Yes"
        estadd local fe_firm "Yes"
        estadd local instrument "LOO mean within SIC-2 x year"
        capture estadd scalar kp_F = r(F_kp)
        post `ivpost' ("dss_da_heese") ("`esg'") ("current") ///
            (r(N_used)) (r(F_kp)) (r(b_esg)) (r(se_esg)) (r(t_esg)) (r(p_esg))
    }
    else {
        post `ivpost' ("dss_da_heese") ("`esg'") ("current") ///
            (.) (.) (.) (.) (.) (.)
    }
}

capture noisily esttab ivda_vs_11 ivda_vs_4 ivda_vs_6 ///
    using "$OUTPUT\Master_v3_IV_HeeseDA.rtf", ///
    replace b(%9.4f) se(%9.4f) star(* 0.10 ** 0.05 *** 0.01) ///
    label compress nogaps ///
    mtitles("ES Composite" "Environmental" "Social") ///
    scalars("instrument Instrument" "kp_F KP rk Wald F" "N Observations") ///
    title("v3 IV: LOO ESG Instruments and Heese-Aligned Signed DA") ///
    addnotes("Instrument = leave-one-out SIC-2 × year peer average of ESG score.")

eststo clear
foreach esg in vs_11 vs_4 vs_6 {
    quietly run_loo_iv, esgvar(`esg') dvvar(rem_heese) ctrls("$ctrl")
    if r(ok) == 1 {
        eststo ivrem_`esg'
        estadd local fe_year "Yes"
        estadd local fe_firm "Yes"
        estadd local instrument "LOO mean within SIC-2 x year"
        capture estadd scalar kp_F = r(F_kp)
        post `ivpost' ("rem_heese") ("`esg'") ("current") ///
            (r(N_used)) (r(F_kp)) (r(b_esg)) (r(se_esg)) (r(t_esg)) (r(p_esg))
    }
    else {
        post `ivpost' ("rem_heese") ("`esg'") ("current") ///
            (.) (.) (.) (.) (.) (.)
    }
}

capture noisily esttab ivrem_vs_11 ivrem_vs_4 ivrem_vs_6 ///
    using "$OUTPUT\Master_v3_IV_REM.rtf", ///
    replace b(%9.4f) se(%9.4f) star(* 0.10 ** 0.05 *** 0.01) ///
    label compress nogaps ///
    mtitles("ES Composite" "Environmental" "Social") ///
    scalars("instrument Instrument" "kp_F KP rk Wald F" "N Observations") ///
    title("v3 IV: LOO ESG Instruments and Heese-Aligned REM") ///
    addnotes("Instrument = leave-one-out SIC-2 × year peer average of ESG score.")

postclose `ivpost'

preserve
use "$OUTPUT\Master_v3_IV_LOO_results.dta", clear
export delimited using "$OUTPUT\Master_v3_IV_LOO_results.csv", replace
restore

display as text ">>> IV block completed."
display as text ">>> Analysis v3 finished: $S_DATE $S_TIME"
display as text ">>> Tables under: $OUTPUT"
log close
