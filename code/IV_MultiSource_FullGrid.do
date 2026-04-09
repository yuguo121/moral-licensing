version 17
clear all
set more off
capture log close

global ROOT      "c:\Users\HuGoL\OneDrive - HKUST (Guangzhou)\PhD\3_Research\Moral Lisensing"
global PROJ_DATA "$ROOT\data\processed"
global OUTPUT    "$ROOT\output"
global RAW_SUP   "c:\Users\HuGoL\OneDrive - HKUST (Guangzhou)\PhD\4_Data\original data\crsp_merged_final_zhangyue.dta"

cd "$ROOT\code"
log using "$ROOT\code\iv_multisource_fullgrid_log.log", replace

foreach pkg in ivreghdfe winsor2 {
    capture which `pkg'
    if _rc ssc install `pkg'
}

* Settings
global ctrl_core size mb2 lev roa growth_asset cash_holding big_4 noa mkt_share loss
global ctrl_full_raw size mb2 lev roa growth_asset cash_holding ///
                     per_io big_4 firm_age ceo_age ceo_gender ///
                     duality bod_independence bod_size
global ctrl_s2 size mb2 lev roa

use "$PROJ_DATA\final_analysis_v2.dta", clear
keep if fyear >= 2005

* Backfill CEO/board controls from raw merged dataset
capture confirm file "$RAW_SUP"
if !_rc {
    preserve
    use "$RAW_SUP", clear
    keep cusip_8 fyear ceo_age duality bod_independ bod_size
    duplicates drop cusip_8 fyear, force
    rename ceo_age ceo_age_sup
    rename duality duality_sup
    rename bod_independ bod_independ_sup
    rename bod_size bod_size_sup
    tempfile rawsup
    save `rawsup'
    restore
    merge 1:1 cusip_8 fyear using `rawsup', nogen keep(1 3)
    capture replace ceo_age = ceo_age_sup if missing(ceo_age) & !missing(ceo_age_sup)
    capture replace duality = duality_sup if missing(duality) & !missing(duality_sup)
    capture replace bod_independence = bod_independ_sup if missing(bod_independence) & !missing(bod_independ_sup)
    capture replace bod_size = bod_size_sup if missing(bod_size) & !missing(bod_size_sup)
    drop ceo_age_sup duality_sup bod_independ_sup bod_size_sup
}

* Build high-carbon flag (same SIC2 rule as prior scripts)
gen sic_2_num = real(sic_2)
gen byte high_carbon = 0
replace high_carbon = 1 if inrange(sic_2_num, 10, 14)
replace high_carbon = 1 if sic_2_num == 26
replace high_carbon = 1 if sic_2_num == 28
replace high_carbon = 1 if sic_2_num == 29
replace high_carbon = 1 if sic_2_num == 32
replace high_carbon = 1 if sic_2_num == 33
replace high_carbon = 1 if sic_2_num == 49

* Use vs_1 as total for asset4; fallback if missing
capture confirm variable vs_1
if _rc {
    capture confirm variable weighted_average_score
    if !_rc gen double vs_1 = weighted_average_score
}

* KLD requested constructs
capture drop kld_env_num1 kld_emp_num1
capture gen double kld_env_num1 = env_str_num1 - env_con_num1
capture gen double kld_emp_num1 = emp_str_num1 - emp_con_num1

* Winsorize existing vars used in grid
local wvars ko_da_sic ko_da_kothari rem_heese ///
            vs_1 vs_4 vs_6 ///
            environmental_pillar_score social_pillar_score weighted_average_score ///
            kld_env_num1 kld_emp_num1 kldnocg ///
            $ctrl_core $ctrl_full_raw $ctrl_s2
local wvars_exist
foreach v of local wvars {
    capture confirm variable `v'
    if !_rc local wvars_exist `wvars_exist' `v'
}
winsor2 `wvars_exist', cuts(0.5 99.5) replace

* Resolve full controls available after merge
local ctrl_full
foreach v in $ctrl_full_raw {
    capture confirm variable `v'
    if !_rc local ctrl_full "`ctrl_full' `v'"
}
display as text "Full controls used:`ctrl_full'"

tempfile base
save `base', replace

tempname mem
postfile `mem' str8 source str10 score str12 dv str10 setting str10 sample ///
    str10 run_status str20 year_window double N_used F_kp b_esg se_esg t_esg p_esg ///
    using "$OUTPUT\IV_MultiSource_FullGrid_results.dta", replace

capture program drop run_one_iv
program define run_one_iv, rclass
    syntax, ESGVAR(name) DVVAR(name) CTRLS(string)
    tempvar sm cn iv_loo
    quietly bysort sic_2 fyear: egen double `sm' = total(`esgvar')
    quietly bysort sic_2 fyear: egen `cn' = count(`esgvar')
    quietly gen double `iv_loo' = (`sm' - `esgvar') / (`cn' - 1) if `cn' > 1 & !missing(`esgvar')
    quietly drop `sm' `cn'

    capture noisily ivreghdfe `dvvar' (`esgvar' = `iv_loo') `ctrls', absorb(gvkey fyear) cluster(gvkey)
    if _rc {
        return scalar ok = 0
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
    if missing(return(b_esg)) | missing(return(se_esg)) | return(se_esg)==0 {
        return scalar t_esg = .
        return scalar p_esg = .
    }
    else {
        return scalar t_esg = return(b_esg) / return(se_esg)
        return scalar p_esg = 2*ttail(e(df_r), abs(return(t_esg)))
    }
end

local dvs ko_da_sic ko_da_kothari rem_heese
foreach smp in full highcarbon {
    use `base', clear
    if "`smp'" == "highcarbon" keep if high_carbon == 1
    quietly summarize fyear
    local yw = string(r(min), "%9.0g") + "-" + string(r(max), "%9.0g")

    foreach stg in core full s2 {
        local ctrls ""
        if "`stg'" == "core" local ctrls "$ctrl_core"
        if "`stg'" == "full" local ctrls "`ctrl_full'"
        if "`stg'" == "s2"   local ctrls "$ctrl_s2"

        foreach dv of local dvs {
            * asset4
            foreach pair in "E vs_4" "S vs_6" "Total vs_1" {
                gettoken sc ev : pair
                capture noisily run_one_iv, esgvar(`ev') dvvar(`dv') ctrls("`ctrls'")
                if _rc | r(ok)!=1 post `mem' ("asset4") ("`sc'") ("`dv'") ("`stg'") ("`smp'") ("fail") ("`yw'") (.) (.) (.) (.) (.) (.)
                else post `mem' ("asset4") ("`sc'") ("`dv'") ("`stg'") ("`smp'") ("ok") ("`yw'") (r(N_used)) (r(F_kp)) (r(b_esg)) (r(se_esg)) (r(t_esg)) (r(p_esg))
            }

            * msci
            foreach pair in "E environmental_pillar_score" "S social_pillar_score" "Total weighted_average_score" {
                gettoken sc ev : pair
                capture noisily run_one_iv, esgvar(`ev') dvvar(`dv') ctrls("`ctrls'")
                if _rc | r(ok)!=1 post `mem' ("msci") ("`sc'") ("`dv'") ("`stg'") ("`smp'") ("fail") ("`yw'") (.) (.) (.) (.) (.) (.)
                else post `mem' ("msci") ("`sc'") ("`dv'") ("`stg'") ("`smp'") ("ok") ("`yw'") (r(N_used)) (r(F_kp)) (r(b_esg)) (r(se_esg)) (r(t_esg)) (r(p_esg))
            }

            * kld (Total uses kldnocg as requested)
            foreach pair in "E kld_env_num1" "S kld_emp_num1" "Total kldnocg" {
                gettoken sc ev : pair
                capture noisily run_one_iv, esgvar(`ev') dvvar(`dv') ctrls("`ctrls'")
                if _rc | r(ok)!=1 post `mem' ("kld") ("`sc'") ("`dv'") ("`stg'") ("`smp'") ("fail") ("`yw'") (.) (.) (.) (.) (.) (.)
                else post `mem' ("kld") ("`sc'") ("`dv'") ("`stg'") ("`smp'") ("ok") ("`yw'") (r(N_used)) (r(F_kp)) (r(b_esg)) (r(se_esg)) (r(t_esg)) (r(p_esg))
            }
        }
    }
}

postclose `mem'

use "$OUTPUT\IV_MultiSource_FullGrid_results.dta", clear
sort sample setting source dv score
format N_used %12.0gc
format F_kp b_esg se_esg t_esg p_esg %12.4f
export delimited using "$OUTPUT\IV_MultiSource_FullGrid_results.csv", replace
list, sepby(sample setting source dv) noobs abbreviate(24)

log close
