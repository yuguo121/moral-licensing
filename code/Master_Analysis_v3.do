

/****  ====================================================================
   MASTER ANALYSIS v3 — 6 DVs × 10 IVs (3 sources), OLS + IV-LOO
   Prerequisite: Master_Merge_v3.do → final_analysis_v3.dta
   Sample: keep if year > 2015 (fiscal years 2016 onward).

   DVs (Compustat / Heese):
     DA:  da_dss  da_ko  da_yu  da_ge  da_dechow
     REM: rem_heese only (Heese composite = AbPROD + AbDISX(−); no component DVs)

   IVs (ESG scores, original names):
     Refinitiv: vs_1 vs_4 vs_6 vs_11(=vs_4+vs_6)
     KLD:       emp_kld env_kld kld_es_total
     MSCI:      environmental_pillar_score social_pillar_score
                weighted_average_score

   Regressions:
     Part A — OLS (reghdfe): main + interaction with industry_type
     Part B — IV  (ivreghdfe): LOO SIC-2 × year peer-average instrument
   ====================================================================  ****/

version 19.0
clear all
set more off
capture log close _all

global ROOT      "c:\Users\HuGoL\OneDrive - HKUST (Guangzhou)\PhD\3_Research\Moral Licensing"
global PROJ_DATA "$ROOT\data\processed"
global OUTPUT    "$ROOT\output"

cd "$ROOT\code"
* Timestamped log avoids r(608) if a previous Stata session still holds analysis_v3.log
local _logts = strofreal(clock(c(current_date) + " " + c(current_time), "DMYhms"))
log using "$ROOT\code\analysis_v3_`_logts'.log", replace text

foreach pkg in reghdfe ivreghdfe winsor2 estout {
    capture which `pkg'
    if _rc {
        capture ssc install `pkg'
        if _rc display as text "  [WARN] Could not install `pkg' (SSC unreachable?)"
    }
}

capture confirm file "$PROJ_DATA\final_analysis_v3.dta"
if _rc {
    display as error "Missing final_analysis_v3.dta — run Master_Merge_v3.do first."
    exit 601
}

use "$PROJ_DATA\final_analysis_v3.dta", clear
xtset gvkey year

keep if year > 2015
quietly count
display as text "  [INFO] Sample: year > 2015  |  N = " r(N)

display as text _newline ">>> Analysis v3 started: $S_DATE $S_TIME"


/* ====================================================================
   VARIABLE LISTS
   ==================================================================== */

local dvlist da_dss da_ko da_yu da_ge da_dechow ///
             rem_heese

local iv_ref  vs_1 vs_4 vs_6 vs_11
local iv_kld  emp_kld env_kld kld_es_total
local iv_msci environmental_pillar_score social_pillar_score weighted_average_score

local ivall   `iv_ref' `iv_kld' `iv_msci'
local ivtags  ref1 ref4 ref6 ref11 kEmp kEnv kES mEnv mSoc mAvg


/* ====================================================================
   LABELS (source in brackets; variable names untouched)
   ==================================================================== */

capture label var da_dss          "DA: BS accrual, no dep [Compustat]"
capture label var da_ko           "DA: Jones incl. dep [Compustat]"
capture label var da_yu           "DA: NI − OANCF [Compustat]"
capture label var da_ge           "DA: IBC − OANCF [Compustat]"
capture label var da_dechow       "DA: IB − dCHE [Compustat]"
label var rem_heese               "REM aggregate [Compustat]"
capture label var ab_prod         "Abnormal production [Compustat]"
capture label var ab_disexp_neg   "Abnl disc. exp. ×(−1) [Compustat]"

capture label var vs_1            "ESG Overall [Refinitiv]"
capture label var vs_4            "Environmental [Refinitiv]"
capture label var vs_5            "Governance [Refinitiv]"
capture label var vs_6            "Social [Refinitiv]"
capture label var vs_11           "E+S Composite [Refinitiv]"

capture label var emp_kld         "Employee Net [KLD]"
capture label var env_kld         "Environmental Net [KLD]"
capture label var kld_es_total    "E+S Net [KLD]"

capture label var environmental_pillar_score "Environmental Pillar [MSCI]"
capture label var social_pillar_score        "Social Pillar [MSCI]"
capture label var weighted_average_score     "Overall Weighted [MSCI]"

label var industry_type  "Industry Culpability"
label var size           "Firm Size"
label var mb2            "Market-to-Book"
label var lev            "Leverage"
label var roa            "ROA"
label var growth_asset   "Asset Growth"
label var cash_holding   "Cash Holdings"
capture label var per_io     "Institutional Ownership"
capture label var big_4      "Big 4 Auditor"
capture label var firm_age   "Firm Age"
capture label var ceo_age    "CEO Age"
capture label var ceo_gender "CEO Gender"
capture label var duality    "CEO Duality"


/* ====================================================================
   CONTROLS — aligned with Master_Analysis.do
   ==================================================================== */

global ctrl size mb2 lev roa growth_asset cash_holding

foreach _v in per_io big_4 firm_age ceo_age ceo_gender duality {
    capture confirm variable `_v'
    if !_rc {
        quietly count if !missing(`_v')
        if r(N) > 5000 global ctrl $ctrl `_v'
    }
}

display as text "  [INFO] Controls: $ctrl"


/* ====================================================================
   FILTER IVs — keep those present with enough obs
   ==================================================================== */

local ivlist
local tags
local niv : word count `ivall'
forvalues i = 1/`niv' {
    local v : word `i' of `ivall'
    local t : word `i' of `ivtags'
    capture confirm variable `v'
    if !_rc {
        quietly count if !missing(`v')
        if r(N) > 100 {
            local ivlist `ivlist' `v'
            local tags   `tags'   `t'
        }
    }
}

display as text "  [INFO] IVs in model: `ivlist'"


/* ====================================================================
   WINSORIZE
   ==================================================================== */

local wvars
foreach v of local dvlist {
    capture confirm variable `v'
    if !_rc local wvars `wvars' `v'
}
foreach v of local ivlist {
    local wvars `wvars' `v'
}
foreach v in $ctrl {
    capture confirm variable `v'
    if !_rc local wvars `wvars' `v'
}
winsor2 `wvars', cuts(0.5 99.5) replace


/* ====================================================================
   PART A: OLS — reghdfe (main effects + interaction)
   ==================================================================== */
display as text _newline ">>> Part A: OLS (reghdfe) — 6 DVs × IVs..."

local niv : word count `ivlist'

foreach dv of local dvlist {
    capture confirm variable `dv'
    if _rc continue

    display as text _newline "  [OLS] DV = `dv'"

    * --- A1: Main effects ---
    eststo clear
    local mlist
    forvalues i = 1/`niv' {
        local iv  : word `i' of `ivlist'
        local tag : word `i' of `tags'
        capture noisily reghdfe `dv' `iv' i.industry_type $ctrl, ///
            absorb(gvkey year) cluster(gvkey)
        if !_rc {
            eststo m_`tag'
            estadd local fe "Firm, Year"
            local mlist `mlist' m_`tag'
        }
    }
    if "`mlist'" != "" {
        esttab `mlist' using "$OUTPUT\v3_OLS_main_`dv'.rtf", ///
            replace b(%9.4f) se(%9.4f) star(* 0.10 ** 0.05 *** 0.01) ///
            label compress nogaps ///
            scalars("fe FE" "N Observations" "r2_a Adj R²") ///
            title("OLS main effects — DV: `dv'") ///
            addnotes("Cluster: gvkey. FE: firm + year.")
    }

    * --- A2: Interaction with industry_type ---
    eststo clear
    local xlist
    forvalues i = 1/`niv' {
        local iv  : word `i' of `ivlist'
        local tag : word `i' of `tags'
        capture noisily reghdfe `dv' c.`iv'##i.industry_type $ctrl, ///
            absorb(gvkey year) cluster(gvkey)
        if !_rc {
            eststo x_`tag'
            estadd local fe "Firm, Year"
            local xlist `xlist' x_`tag'
        }
    }
    if "`xlist'" != "" {
        esttab `xlist' using "$OUTPUT\v3_OLS_int_`dv'.rtf", ///
            replace b(%9.4f) se(%9.4f) star(* 0.10 ** 0.05 *** 0.01) ///
            label compress nogaps ///
            scalars("fe FE" "N Observations" "r2_a Adj R²") ///
            title("OLS interaction (ESG × industry_type) — DV: `dv'") ///
            addnotes("Cluster: gvkey. FE: firm + year.")
    }
}

display as text ">>> Part A completed."


/* ====================================================================
   PART B: IV — LOO SIC-2 × year peer-average instrument
   Uses ivreghdfe if available; falls back to xtivreg (firm FE + i.year).
   ==================================================================== */
display as text _newline ">>> Part B: IV-LOO — 6 DVs × IVs..."

local iv_engine "xtivreg"
capture which ivreghdfe
if !_rc local iv_engine "ivreghdfe"
display as text "  [INFO] Preferred IV engine: `iv_engine'"
display as text "  [NOTE] ivreghdfe needs a current ivreg2 (ssc install ivreg2, replace)."
display as text "        If ivreghdfe fails (e.g. struct ms_vcvorthog undefined), fallback = xtivreg."

* esttab: do not use drop(*.year) — year is absorbed under ivreghdfe (no *.year in e(b)) → r(111).
local keeplist_iv `ivlist'
foreach v in $ctrl {
    local keeplist_iv `keeplist_iv' `v'
}

capture program drop run_loo_iv
program define run_loo_iv, rclass
    syntax, ESGVAR(name) DVVAR(name) CTRLS(string) ENGINE(string)

    tempvar sm cn iv_loo
    quietly bysort sic_2 year: egen double `sm' = total(`esgvar')
    quietly bysort sic_2 year: egen long   `cn' = count(`esgvar')
    quietly gen double `iv_loo' = (`sm' - `esgvar') / (`cn' - 1) ///
        if `cn' > 1 & !missing(`esgvar')

    * Try ivreghdfe when selected; on failure fall back to xtivreg (broken ivreg2 / load errors).
    if "`engine'" == "ivreghdfe" {
        capture quietly ivreghdfe `dvvar' (`esgvar' = `iv_loo') `ctrls', ///
            absorb(gvkey year) cluster(gvkey)
        if !_rc {
            return local engine_used "ivreghdfe"
            return scalar ok     = 1
            return scalar N_used = e(N)
            capture return scalar F_1st = e(widstat)
            if _rc return scalar F_1st = .
            return scalar b_esg  = _b[`esgvar']
            return scalar se_esg = _se[`esgvar']
            exit
        }
    }

    capture quietly xtivreg `dvvar' (`esgvar' = `iv_loo') `ctrls' i.year, ///
        fe vce(cluster gvkey)
    if _rc {
        return local engine_used ""
        return scalar ok = 0
        return scalar N_used = .
        return scalar F_1st  = .
        return scalar b_esg  = .
        return scalar se_esg = .
        exit
    }
    return local engine_used "xtivreg"
    return scalar ok     = 1
    return scalar N_used = e(N)
    return scalar F_1st  = e(F_f)
    return scalar b_esg  = _b[`esgvar']
    return scalar se_esg = _se[`esgvar']
end

tempname ivpost
postfile `ivpost' str24 dv str32 iv str12 source ///
    double(N F_1st b se) ///
    using "$OUTPUT\v3_IV_LOO_summary.dta", replace

foreach dv of local dvlist {
    capture confirm variable `dv'
    if _rc continue

    display as text _newline "  [IV] DV = `dv'"
    eststo clear
    local ivmodels

    forvalues i = 1/`niv' {
        local iv  : word `i' of `ivlist'
        local tag : word `i' of `tags'

        local src "?"
        foreach _r of local iv_ref {
            if "`iv'" == "`_r'" local src "Refinitiv"
        }
        foreach _k of local iv_kld {
            if "`iv'" == "`_k'" local src "KLD"
        }
        foreach _m of local iv_msci {
            if "`iv'" == "`_m'" local src "MSCI"
        }

        quietly run_loo_iv, esgvar(`iv') dvvar(`dv') ctrls("$ctrl") engine("`iv_engine'")
        if r(ok) == 1 {
            eststo iv_`tag'
            estadd local fe "Firm, Year"
            estadd local instrument "LOO SIC-2×year"
            capture estadd local iv_cmd "`r(engine_used)'"
            capture estadd scalar F_1st = r(F_1st)
            local ivmodels `ivmodels' iv_`tag'
            post `ivpost' ("`dv'") ("`iv'") ("`src'") ///
                (r(N_used)) (r(F_1st)) (r(b_esg)) (r(se_esg))
        }
        else {
            post `ivpost' ("`dv'") ("`iv'") ("`src'") (.) (.) (.) (.)
        }
    }

    if "`ivmodels'" != "" {
        esttab `ivmodels' using "$OUTPUT\v3_IV_`dv'.rtf", ///
            replace b(%9.4f) se(%9.4f) star(* 0.10 ** 0.05 *** 0.01) ///
            label compress nogaps keep(`keeplist_iv') ///
            scalars("fe FE" "instrument Instrument" "F_1st First-stage F" "N Observations") ///
            title("IV-LOO — DV: `dv'") ///
            addnotes("Instrument = LOO SIC-2 × year peer average. Cluster: gvkey.")
    }
}

postclose `ivpost'

preserve
use "$OUTPUT\v3_IV_LOO_summary.dta", clear
list, sepby(dv) abbreviate(32)
export delimited using "$OUTPUT\v3_IV_LOO_summary.csv", replace
restore


display as text _newline ">>> Analysis v3 finished: $S_DATE $S_TIME"
display as text ">>> Output: $OUTPUT\v3_OLS_*.rtf, v3_IV_*.rtf, v3_IV_LOO_summary.csv"
log close
