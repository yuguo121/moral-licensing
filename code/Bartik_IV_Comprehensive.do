/* ====================================================================
   COMPREHENSIVE BARTIK IV ANALYSIS
   Project: Corporate ESG Engagement and Earnings Management
   Date: 2026-03-24

   Design:
     - Three ESG databases: Asset4 (vs_4), KLD (env_kld, kldnocg), MSCI (ias)
     - Two DA models: Modified Jones (ko_da_sic), Kothari (ko_da_kothari)
     - All DVs use SIGNED DA (Heese 2023 TAR)
     - REM (Heese composite) as complement (no reversal)
     - IV: Leave-one-out industry-year ESG mean
     - Robustness: control for L.DA
   ==================================================================== */

version 17
clear all
set more off
set matsize 10000
capture log close

global ROOT      "c:\Users\HuGoL\OneDrive - HKUST (Guangzhou)\PhD\3_Research\Moral Lisensing"
global RAW_DATA  "D:\Research\Data"
global PROJ_DATA "$ROOT\data"
global OUTPUT    "$ROOT\output"

cd "$ROOT\code"
log using "$ROOT\code\bartik_iv_log.log", replace

foreach pkg in reghdfe estout winsor2 {
    capture which `pkg'
    if _rc {
        ssc install `pkg'
    }
}

display as text _newline ">>> Bartik IV Comprehensive: $S_DATE $S_TIME"

/* ====================================================================
   PART 1: LOAD DATA & CONSTRUCT VARIABLES
   ==================================================================== */
display as text _newline ">>> Part 1: Data Loading"

use "$PROJ_DATA\final_analysis_v2.dta", clear

global ctrl_core size mb2 lev roa growth_asset cash_holding big_4 noa mkt_share loss

* --- Merge MSCI industry_adjusted_score ---
preserve
use "$RAW_DATA\ESG\msci_ratings_clean.dta", clear
gen cusip_8 = substr(issuer_cusip, 1, 8) if strlen(issuer_cusip) >= 8
keep if cusip_8 != ""
duplicates drop cusip_8 year, force
keep cusip_8 year industry_adjusted_score
rename year fyear
rename industry_adjusted_score ias
tempfile msci_ias
save `msci_ias'
restore

capture drop ias
merge 1:1 cusip_8 fyear using `msci_ias', keep(1 3) nogen

* --- Ensure KLD variables ---
capture confirm variable env_kld
if _rc {
    capture gen env_kld = env_str_num1 - env_con_num1
}
capture confirm variable kldnocg
if _rc {
    capture gen kldnocg = env_str_num1 - env_con_num1 + com_str_num1 - com_con_num1 + hum_str_num1 - hum_con_num1 + emp_str_num1 - emp_con_num1 + div_str_num1 - div_con_num1 + pro_str_num1 - pro_con_num1
}

* --- Lagged DA for reversal control ---
sort gvkey fyear
by gvkey: gen L_ko_da_sic = ko_da_sic[_n-1] if fyear[_n-1] == fyear - 1
by gvkey: gen L_ko_da_kothari = ko_da_kothari[_n-1] if fyear[_n-1] == fyear - 1

* --- Winsorize ---
winsor2 vs_4 env_kld kldnocg ias, cuts(0.5 99.5) replace

* --- Labels ---
label var ko_da_sic     "DA (Modified Jones)"
label var ko_da_kothari "DA (Kothari)"
capture label var rem_heese    "REM (Heese)"
capture label var ias          "MSCI IAS"
capture label var env_kld      "KLD Env Net"
capture label var kldnocg      "KLD Total (no Gov)"
label var L_ko_da_sic     "L.DA (MJ)"
label var L_ko_da_kothari "L.DA (Kothari)"

* --- Coverage diagnostics ---
display as text _newline "  --- ESG Coverage ---"
foreach v in vs_4 env_kld kldnocg ias {
    quietly count if !missing(`v')
    display as text "  `v': " r(N) " obs"
}
display ""
foreach v in ko_da_sic ko_da_kothari rem_heese {
    quietly count if !missing(`v')
    display as text "  `v': " r(N) " obs"
}

xtset gvkey fyear


/* ====================================================================
   PART 2: BARTIK IV — ASSET4 (vs_4)
   ==================================================================== */
display as text _newline "=========================================="
display as text ">>> Part 2: Bartik IV — Asset4 (vs_4)"
display as text "=========================================="

* --- Construct IV ---
capture drop iv_a4
bysort sic_2 fyear: egen double _sm = total(vs_4)
bysort sic_2 fyear: egen _cn = count(vs_4)
gen double iv_a4 = (_sm - vs_4) / (_cn - 1) if _cn > 1 & !missing(vs_4)
drop _sm _cn
label var iv_a4 "Bartik IV: vs_4"

* --- Panel A: Baseline ---
eststo clear

* First stage
reghdfe vs_4 iv_a4 $ctrl_core, absorb(gvkey fyear) cluster(gvkey)
eststo a4_1st
estadd local fe_firm "Yes"
estadd local fe_year "Yes"
test iv_a4
estadd scalar F_first = r(F)

* 2SLS: DA (Modified Jones)
capture drop _hat
reghdfe vs_4 iv_a4 $ctrl_core, absorb(gvkey fyear) cluster(gvkey) resid
predict double _hat, xb
reghdfe ko_da_sic _hat $ctrl_core, absorb(gvkey fyear) cluster(gvkey)
eststo a4_da_mj
estadd local fe_firm "Yes"
estadd local fe_year "Yes"
drop _hat

* 2SLS: DA (Kothari)
capture drop _hat
reghdfe vs_4 iv_a4 $ctrl_core, absorb(gvkey fyear) cluster(gvkey) resid
predict double _hat, xb
reghdfe ko_da_kothari _hat $ctrl_core, absorb(gvkey fyear) cluster(gvkey)
eststo a4_da_ko
estadd local fe_firm "Yes"
estadd local fe_year "Yes"
drop _hat

* 2SLS: REM
capture drop _hat
reghdfe vs_4 iv_a4 $ctrl_core, absorb(gvkey fyear) cluster(gvkey) resid
predict double _hat, xb
reghdfe rem_heese _hat $ctrl_core, absorb(gvkey fyear) cluster(gvkey)
eststo a4_rem
estadd local fe_firm "Yes"
estadd local fe_year "Yes"
drop _hat

esttab a4_1st a4_da_mj a4_da_ko a4_rem using "$OUTPUT\BartikIV_Asset4.rtf", replace b(%9.4f) se(%9.4f) star(* 0.10 ** 0.05 *** 0.01) label compress nogaps mtitles("1st Stage" "DA(MJ)" "DA(Kothari)" "REM") scalars("fe_firm Firm FE" "fe_year Year FE" "F_first 1st-Stage F" "N Observations" "r2_a Adj. R-sq") title("Bartik IV: Asset4 Environmental Score (vs_4)") addnotes("IV: Leave-one-out industry-year mean of vs_4." "DV: Signed DA (Heese 2023). Firm+Year FE. SE clustered at firm.")

* --- Panel B: With L.DA ---
eststo clear

reghdfe vs_4 iv_a4 $ctrl_core L_ko_da_sic, absorb(gvkey fyear) cluster(gvkey)
eststo a4L_1st
estadd local fe_firm "Yes"
estadd local fe_year "Yes"
test iv_a4
estadd scalar F_first = r(F)

capture drop _hat
reghdfe vs_4 iv_a4 $ctrl_core L_ko_da_sic, absorb(gvkey fyear) cluster(gvkey) resid
predict double _hat, xb
reghdfe ko_da_sic _hat $ctrl_core L_ko_da_sic, absorb(gvkey fyear) cluster(gvkey)
eststo a4L_da_mj
estadd local fe_firm "Yes"
estadd local fe_year "Yes"
drop _hat

capture drop _hat
reghdfe vs_4 iv_a4 $ctrl_core L_ko_da_kothari, absorb(gvkey fyear) cluster(gvkey) resid
predict double _hat, xb
reghdfe ko_da_kothari _hat $ctrl_core L_ko_da_kothari, absorb(gvkey fyear) cluster(gvkey)
eststo a4L_da_ko
estadd local fe_firm "Yes"
estadd local fe_year "Yes"
drop _hat

capture drop _hat
reghdfe vs_4 iv_a4 $ctrl_core L_ko_da_sic, absorb(gvkey fyear) cluster(gvkey) resid
predict double _hat, xb
reghdfe rem_heese _hat $ctrl_core L_ko_da_sic, absorb(gvkey fyear) cluster(gvkey)
eststo a4L_rem
estadd local fe_firm "Yes"
estadd local fe_year "Yes"
drop _hat

esttab a4L_1st a4L_da_mj a4L_da_ko a4L_rem using "$OUTPUT\BartikIV_Asset4_LagDA.rtf", replace b(%9.4f) se(%9.4f) star(* 0.10 ** 0.05 *** 0.01) label compress nogaps mtitles("1st Stage" "DA(MJ)" "DA(Kothari)" "REM") scalars("fe_firm Firm FE" "fe_year Year FE" "F_first 1st-Stage F" "N Observations" "r2_a Adj. R-sq") title("Bartik IV: Asset4 (vs_4) — with Lagged DA control") addnotes("Controls include L.DA to absorb accrual reversal." "IV: Leave-one-out industry-year mean vs_4.")

display as text ">>> Asset4 Bartik IV completed."


/* ====================================================================
   PART 3: BARTIK IV — KLD Environmental (env_kld)
   ==================================================================== */
display as text _newline "=========================================="
display as text ">>> Part 3A: Bartik IV — KLD Env"
display as text "=========================================="

capture drop iv_kld_e
bysort sic_2 fyear: egen double _sm = total(env_kld)
bysort sic_2 fyear: egen _cn = count(env_kld)
gen double iv_kld_e = (_sm - env_kld) / (_cn - 1) if _cn > 1 & !missing(env_kld)
drop _sm _cn
label var iv_kld_e "Bartik IV: env_kld"

eststo clear

reghdfe env_kld iv_kld_e $ctrl_core, absorb(gvkey fyear) cluster(gvkey)
eststo ke_1st
estadd local fe_firm "Yes"
estadd local fe_year "Yes"
test iv_kld_e
estadd scalar F_first = r(F)

capture drop _hat
reghdfe env_kld iv_kld_e $ctrl_core, absorb(gvkey fyear) cluster(gvkey) resid
predict double _hat, xb
reghdfe ko_da_sic _hat $ctrl_core, absorb(gvkey fyear) cluster(gvkey)
eststo ke_da_mj
estadd local fe_firm "Yes"
estadd local fe_year "Yes"
drop _hat

capture drop _hat
reghdfe env_kld iv_kld_e $ctrl_core, absorb(gvkey fyear) cluster(gvkey) resid
predict double _hat, xb
reghdfe ko_da_kothari _hat $ctrl_core, absorb(gvkey fyear) cluster(gvkey)
eststo ke_da_ko
estadd local fe_firm "Yes"
estadd local fe_year "Yes"
drop _hat

capture drop _hat
reghdfe env_kld iv_kld_e $ctrl_core, absorb(gvkey fyear) cluster(gvkey) resid
predict double _hat, xb
reghdfe rem_heese _hat $ctrl_core, absorb(gvkey fyear) cluster(gvkey)
eststo ke_rem
estadd local fe_firm "Yes"
estadd local fe_year "Yes"
drop _hat

esttab ke_1st ke_da_mj ke_da_ko ke_rem using "$OUTPUT\BartikIV_KLD_Env.rtf", replace b(%9.4f) se(%9.4f) star(* 0.10 ** 0.05 *** 0.01) label compress nogaps mtitles("1st Stage" "DA(MJ)" "DA(Kothari)" "REM") scalars("fe_firm Firm FE" "fe_year Year FE" "F_first 1st-Stage F" "N Observations" "r2_a Adj. R-sq") title("Bartik IV: KLD Environmental Net (env_kld)") addnotes("IV: Leave-one-out industry-year mean of KLD env net." "KLD env_kld = env_str - env_con." "DV: Signed DA. Firm+Year FE. SE clustered at firm.")

* With L.DA
eststo clear

reghdfe env_kld iv_kld_e $ctrl_core L_ko_da_sic, absorb(gvkey fyear) cluster(gvkey)
eststo keL_1st
estadd local fe_firm "Yes"
estadd local fe_year "Yes"
test iv_kld_e
estadd scalar F_first = r(F)

capture drop _hat
reghdfe env_kld iv_kld_e $ctrl_core L_ko_da_sic, absorb(gvkey fyear) cluster(gvkey) resid
predict double _hat, xb
reghdfe ko_da_sic _hat $ctrl_core L_ko_da_sic, absorb(gvkey fyear) cluster(gvkey)
eststo keL_da_mj
estadd local fe_firm "Yes"
estadd local fe_year "Yes"
drop _hat

capture drop _hat
reghdfe env_kld iv_kld_e $ctrl_core L_ko_da_kothari, absorb(gvkey fyear) cluster(gvkey) resid
predict double _hat, xb
reghdfe ko_da_kothari _hat $ctrl_core L_ko_da_kothari, absorb(gvkey fyear) cluster(gvkey)
eststo keL_da_ko
estadd local fe_firm "Yes"
estadd local fe_year "Yes"
drop _hat

capture drop _hat
reghdfe env_kld iv_kld_e $ctrl_core L_ko_da_sic, absorb(gvkey fyear) cluster(gvkey) resid
predict double _hat, xb
reghdfe rem_heese _hat $ctrl_core L_ko_da_sic, absorb(gvkey fyear) cluster(gvkey)
eststo keL_rem
estadd local fe_firm "Yes"
estadd local fe_year "Yes"
drop _hat

esttab keL_1st keL_da_mj keL_da_ko keL_rem using "$OUTPUT\BartikIV_KLD_Env_LagDA.rtf", replace b(%9.4f) se(%9.4f) star(* 0.10 ** 0.05 *** 0.01) label compress nogaps mtitles("1st Stage" "DA(MJ)" "DA(Kothari)" "REM") scalars("fe_firm Firm FE" "fe_year Year FE" "F_first 1st-Stage F" "N Observations" "r2_a Adj. R-sq") title("Bartik IV: KLD Env — with Lagged DA") addnotes("Controls include L.DA to absorb accrual reversal.")

display as text ">>> KLD Env completed."

* --- 3B: KLD Total (excl. Governance) ---
display as text _newline "=========================================="
display as text ">>> Part 3B: Bartik IV — KLD Total (no Gov)"
display as text "=========================================="

capture drop iv_kld_t
bysort sic_2 fyear: egen double _sm = total(kldnocg)
bysort sic_2 fyear: egen _cn = count(kldnocg)
gen double iv_kld_t = (_sm - kldnocg) / (_cn - 1) if _cn > 1 & !missing(kldnocg)
drop _sm _cn
label var iv_kld_t "Bartik IV: kldnocg"

eststo clear

reghdfe kldnocg iv_kld_t $ctrl_core, absorb(gvkey fyear) cluster(gvkey)
eststo kt_1st
estadd local fe_firm "Yes"
estadd local fe_year "Yes"
test iv_kld_t
estadd scalar F_first = r(F)

capture drop _hat
reghdfe kldnocg iv_kld_t $ctrl_core, absorb(gvkey fyear) cluster(gvkey) resid
predict double _hat, xb
reghdfe ko_da_sic _hat $ctrl_core, absorb(gvkey fyear) cluster(gvkey)
eststo kt_da_mj
estadd local fe_firm "Yes"
estadd local fe_year "Yes"
drop _hat

capture drop _hat
reghdfe kldnocg iv_kld_t $ctrl_core, absorb(gvkey fyear) cluster(gvkey) resid
predict double _hat, xb
reghdfe ko_da_kothari _hat $ctrl_core, absorb(gvkey fyear) cluster(gvkey)
eststo kt_da_ko
estadd local fe_firm "Yes"
estadd local fe_year "Yes"
drop _hat

capture drop _hat
reghdfe kldnocg iv_kld_t $ctrl_core, absorb(gvkey fyear) cluster(gvkey) resid
predict double _hat, xb
reghdfe rem_heese _hat $ctrl_core, absorb(gvkey fyear) cluster(gvkey)
eststo kt_rem
estadd local fe_firm "Yes"
estadd local fe_year "Yes"
drop _hat

esttab kt_1st kt_da_mj kt_da_ko kt_rem using "$OUTPUT\BartikIV_KLD_Total.rtf", replace b(%9.4f) se(%9.4f) star(* 0.10 ** 0.05 *** 0.01) label compress nogaps mtitles("1st Stage" "DA(MJ)" "DA(Kothari)" "REM") scalars("fe_firm Firm FE" "fe_year Year FE" "F_first 1st-Stage F" "N Observations" "r2_a Adj. R-sq") title("Bartik IV: KLD Total excl. Governance (kldnocg)") addnotes("IV: Leave-one-out industry-year mean kldnocg." "kldnocg = env+com+hum+emp+div+pro net scores." "DV: Signed DA. Firm+Year FE. SE clustered at firm.")

display as text ">>> KLD Total completed."


/* ====================================================================
   PART 4: BARTIK IV — MSCI (industry_adjusted_score)
   ==================================================================== */
display as text _newline "=========================================="
display as text ">>> Part 4: Bartik IV — MSCI"
display as text "=========================================="

capture drop iv_msci
bysort sic_2 fyear: egen double _sm = total(ias)
bysort sic_2 fyear: egen _cn = count(ias)
gen double iv_msci = (_sm - ias) / (_cn - 1) if _cn > 1 & !missing(ias)
drop _sm _cn
label var iv_msci "Bartik IV: MSCI IAS"

eststo clear

reghdfe ias iv_msci $ctrl_core, absorb(gvkey fyear) cluster(gvkey)
eststo ms_1st
estadd local fe_firm "Yes"
estadd local fe_year "Yes"
test iv_msci
estadd scalar F_first = r(F)

capture drop _hat
reghdfe ias iv_msci $ctrl_core, absorb(gvkey fyear) cluster(gvkey) resid
predict double _hat, xb
reghdfe ko_da_sic _hat $ctrl_core, absorb(gvkey fyear) cluster(gvkey)
eststo ms_da_mj
estadd local fe_firm "Yes"
estadd local fe_year "Yes"
drop _hat

capture drop _hat
reghdfe ias iv_msci $ctrl_core, absorb(gvkey fyear) cluster(gvkey) resid
predict double _hat, xb
reghdfe ko_da_kothari _hat $ctrl_core, absorb(gvkey fyear) cluster(gvkey)
eststo ms_da_ko
estadd local fe_firm "Yes"
estadd local fe_year "Yes"
drop _hat

capture drop _hat
reghdfe ias iv_msci $ctrl_core, absorb(gvkey fyear) cluster(gvkey) resid
predict double _hat, xb
reghdfe rem_heese _hat $ctrl_core, absorb(gvkey fyear) cluster(gvkey)
eststo ms_rem
estadd local fe_firm "Yes"
estadd local fe_year "Yes"
drop _hat

esttab ms_1st ms_da_mj ms_da_ko ms_rem using "$OUTPUT\BartikIV_MSCI.rtf", replace b(%9.4f) se(%9.4f) star(* 0.10 ** 0.05 *** 0.01) label compress nogaps mtitles("1st Stage" "DA(MJ)" "DA(Kothari)" "REM") scalars("fe_firm Firm FE" "fe_year Year FE" "F_first 1st-Stage F" "N Observations" "r2_a Adj. R-sq") title("Bartik IV: MSCI Industry-Adjusted Score") addnotes("IV: Leave-one-out industry-year mean MSCI IAS." "DV: Signed DA. Firm+Year FE. SE clustered at firm.")

* With L.DA
eststo clear

reghdfe ias iv_msci $ctrl_core L_ko_da_sic, absorb(gvkey fyear) cluster(gvkey)
eststo msL_1st
estadd local fe_firm "Yes"
estadd local fe_year "Yes"
test iv_msci
estadd scalar F_first = r(F)

capture drop _hat
reghdfe ias iv_msci $ctrl_core L_ko_da_sic, absorb(gvkey fyear) cluster(gvkey) resid
predict double _hat, xb
reghdfe ko_da_sic _hat $ctrl_core L_ko_da_sic, absorb(gvkey fyear) cluster(gvkey)
eststo msL_da_mj
estadd local fe_firm "Yes"
estadd local fe_year "Yes"
drop _hat

capture drop _hat
reghdfe ias iv_msci $ctrl_core L_ko_da_kothari, absorb(gvkey fyear) cluster(gvkey) resid
predict double _hat, xb
reghdfe ko_da_kothari _hat $ctrl_core L_ko_da_kothari, absorb(gvkey fyear) cluster(gvkey)
eststo msL_da_ko
estadd local fe_firm "Yes"
estadd local fe_year "Yes"
drop _hat

capture drop _hat
reghdfe ias iv_msci $ctrl_core L_ko_da_sic, absorb(gvkey fyear) cluster(gvkey) resid
predict double _hat, xb
reghdfe rem_heese _hat $ctrl_core L_ko_da_sic, absorb(gvkey fyear) cluster(gvkey)
eststo msL_rem
estadd local fe_firm "Yes"
estadd local fe_year "Yes"
drop _hat

esttab msL_1st msL_da_mj msL_da_ko msL_rem using "$OUTPUT\BartikIV_MSCI_LagDA.rtf", replace b(%9.4f) se(%9.4f) star(* 0.10 ** 0.05 *** 0.01) label compress nogaps mtitles("1st Stage" "DA(MJ)" "DA(Kothari)" "REM") scalars("fe_firm Firm FE" "fe_year Year FE" "F_first 1st-Stage F" "N Observations" "r2_a Adj. R-sq") title("Bartik IV: MSCI — with Lagged DA") addnotes("Controls include L.DA to absorb accrual reversal.")

display as text ">>> MSCI Bartik IV completed."


/* ====================================================================
   PART 5: CROSS-DATABASE COMPARISON (one table)
   ==================================================================== */
display as text _newline "=========================================="
display as text ">>> Part 5: Cross-Database Comparison"
display as text "=========================================="

eststo clear

* Asset4
reghdfe vs_4 iv_a4 $ctrl_core, absorb(gvkey fyear) cluster(gvkey)
eststo xdb_a4_1st
estadd local fe "Firm+Year"
test iv_a4
estadd scalar F_first = r(F)

capture drop _hat
reghdfe vs_4 iv_a4 $ctrl_core, absorb(gvkey fyear) cluster(gvkey) resid
predict double _hat, xb
reghdfe ko_da_sic _hat $ctrl_core, absorb(gvkey fyear) cluster(gvkey)
eststo xdb_a4_da
estadd local fe "Firm+Year"
estadd local esg_db "Asset4"
drop _hat

* KLD
reghdfe env_kld iv_kld_e $ctrl_core, absorb(gvkey fyear) cluster(gvkey)
eststo xdb_kld_1st
estadd local fe "Firm+Year"
test iv_kld_e
estadd scalar F_first = r(F)

capture drop _hat
reghdfe env_kld iv_kld_e $ctrl_core, absorb(gvkey fyear) cluster(gvkey) resid
predict double _hat, xb
reghdfe ko_da_sic _hat $ctrl_core, absorb(gvkey fyear) cluster(gvkey)
eststo xdb_kld_da
estadd local fe "Firm+Year"
estadd local esg_db "KLD"
drop _hat

* MSCI
reghdfe ias iv_msci $ctrl_core, absorb(gvkey fyear) cluster(gvkey)
eststo xdb_msci_1st
estadd local fe "Firm+Year"
test iv_msci
estadd scalar F_first = r(F)

capture drop _hat
reghdfe ias iv_msci $ctrl_core, absorb(gvkey fyear) cluster(gvkey) resid
predict double _hat, xb
reghdfe ko_da_sic _hat $ctrl_core, absorb(gvkey fyear) cluster(gvkey)
eststo xdb_msci_da
estadd local fe "Firm+Year"
estadd local esg_db "MSCI"
drop _hat

esttab xdb_a4_1st xdb_a4_da xdb_kld_1st xdb_kld_da xdb_msci_1st xdb_msci_da using "$OUTPUT\BartikIV_CrossDB.rtf", replace b(%9.4f) se(%9.4f) star(* 0.10 ** 0.05 *** 0.01) label compress nogaps mtitles("A4:1st" "A4:DA" "KLD:1st" "KLD:DA" "MSCI:1st" "MSCI:DA") scalars("fe FE" "F_first 1st-Stage F" "esg_db ESG Database" "N Observations" "r2_a Adj. R-sq") title("Cross-Database Bartik IV: Signed DA (Modified Jones)") addnotes("Asset4=MSCI Pillar; KLD=Env net; MSCI=Industry-adjusted score." "All: Firm+Year FE, SE clustered at firm." "DV: Signed DA following Heese et al. (2023, TAR).")


/* ====================================================================
   PART 6: DIAGNOSTICS
   ==================================================================== */
display as text _newline "=========================================="
display as text ">>> Part 6: Diagnostics"
display as text "=========================================="

display as text "  --- Sample by ESG x DV ---"
foreach esg in vs_4 env_kld kldnocg ias {
    foreach dv in ko_da_sic ko_da_kothari rem_heese {
        quietly count if !missing(`esg') & !missing(`dv')
        display as text "  `esg' x `dv': " r(N)
    }
    display ""
}

display as text "  --- Year range by ESG ---"
foreach esg in vs_4 env_kld kldnocg ias {
    quietly summarize fyear if !missing(`esg')
    display as text "  `esg': " r(min) " - " r(max) " (N=" r(N) ")"
}

display as text _newline ">>> All done: $S_DATE $S_TIME"
display as text ">>> Output:"
display as text "    BartikIV_Asset4.rtf"
display as text "    BartikIV_Asset4_LagDA.rtf"
display as text "    BartikIV_KLD_Env.rtf"
display as text "    BartikIV_KLD_Env_LagDA.rtf"
display as text "    BartikIV_KLD_Total.rtf"
display as text "    BartikIV_MSCI.rtf"
display as text "    BartikIV_MSCI_LagDA.rtf"
display as text "    BartikIV_CrossDB.rtf"

log close
