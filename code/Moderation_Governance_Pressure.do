/* ====================================================================
   MODERATION: GOVERNANCE & EARNINGS PRESSURE
   Interact environmental score (vs_4) with:
     - Governance: vs_gov, per_io, duality, bod_independence (if present)
     - Earnings pressure: under_duration, mb2 (market expectations)
   DVs: ko_da_sic, ko_da_kothari, rem_heese
   FE: firm + year; cluster gvkey
   ==================================================================== */

version 17
clear all
set more off
capture log close

global ROOT      "c:\Users\HuGoL\OneDrive - HKUST (Guangzhou)\PhD\3_Research\Moral Lisensing"
global PROJ_DATA "$ROOT\data"
global OUTPUT    "$ROOT\output"

cd "$ROOT\code"
log using "$ROOT\code\moderation_gov_pressure.log", replace

capture which reghdfe
if _rc ssc install reghdfe
capture which estout
if _rc ssc install estout
capture which winsor2
if _rc ssc install winsor2

use "$PROJ_DATA\final_analysis_v2.dta", clear
capture confirm variable year
if _rc gen year = fyear

* --- Moderators: winsorize tails ---
capture confirm variable vs_gov
if !_rc winsor2 vs_gov, cuts(0.5 99.5) replace

capture confirm variable per_io
if !_rc winsor2 per_io, cuts(0.5 99.5) replace

capture confirm variable bod_independence
if !_rc winsor2 bod_independence, cuts(0.5 99.5) replace

capture confirm variable under_duration
if !_rc {
    winsor2 under_duration, cuts(0.5 99.5) replace
    label var under_duration "Underperformance duration (winsor)"
}

winsor2 vs_4 ko_da_sic ko_da_kothari rem_heese mb2, cuts(0.5 99.5) replace

* Base controls: core + common extras; exclude moderator when it appears in interaction
global ctrl0 size lev roa growth_asset cash_holding big_4 noa mkt_share loss mb2
capture confirm variable per_io
if !_rc global ctrl0 $ctrl0 per_io
capture confirm variable firm_age
if !_rc global ctrl0 $ctrl0 firm_age

display as text _newline ">>> Base controls: $ctrl0"

* --- Part A: Governance moderation ---
display as text _newline "========== GOVERNANCE MODERATION =========="

eststo clear

* A1: MSCI governance pillar (vs_gov)
capture confirm variable vs_gov
if !_rc {
    foreach dv in ko_da_sic ko_da_kothari rem_heese {
        capture confirm variable `dv'
        if !_rc {
            reghdfe `dv' c.vs_4 c.vs_gov c.vs_4#c.vs_gov $ctrl0, absorb(year gvkey) cluster(gvkey)
            eststo g_`dv'_vsgov
            estadd local fe "Firm+Year"
            estadd local mod "vs_gov"
        }
    }
    esttab g_ko_da_sic_vsgov g_ko_da_kothari_vsgov g_rem_heese_vsgov ///
        using "$OUTPUT\Moderation_Governance_vs_gov.rtf", replace ///
        b(%9.4f) se(%9.4f) star(* 0.10 ** 0.05 *** 0.01) ///
        label compress nogaps mtitles("DA_MJ" "DA_Ko" "REM") ///
        title("Moderation: Environmental score x MSCI Governance (vs_gov)") ///
        addnotes("Interaction: c.vs_4#c.vs_gov. Controls include mb2." "Firm+Year FE, cluster gvkey.")
}

* A2: Institutional ownership
capture confirm variable per_io
if !_rc {
    local ctrl1 "size lev roa growth_asset cash_holding big_4 noa mkt_share loss mb2"
    capture confirm variable firm_age
    if !_rc local ctrl1 `ctrl1' firm_age
    eststo clear
    foreach dv in ko_da_sic ko_da_kothari rem_heese {
        capture confirm variable `dv'
        if !_rc {
            reghdfe `dv' c.vs_4 c.per_io c.vs_4#c.per_io `ctrl1', absorb(year gvkey) cluster(gvkey)
            eststo g_`dv'_pio
            estadd local fe "Firm+Year"
            estadd local mod "per_io"
        }
    }
    esttab g_ko_da_sic_pio g_ko_da_kothari_pio g_rem_heese_pio ///
        using "$OUTPUT\Moderation_Governance_per_io.rtf", replace ///
        b(%9.4f) se(%9.4f) star(* 0.10 ** 0.05 *** 0.01) ///
        label compress nogaps mtitles("DA_MJ" "DA_Ko" "REM") ///
        title("Moderation: Environmental score x Institutional ownership") ///
        addnotes("per_io excluded from rhs except as moderator+interaction." "Firm+Year FE, cluster gvkey.")
}

* A3: CEO duality (binary)
capture confirm variable duality
if !_rc {
    eststo clear
    local ctrl1 "size lev roa growth_asset cash_holding big_4 noa mkt_share loss mb2"
    capture confirm variable per_io
    if !_rc local ctrl1 `ctrl1' per_io
    capture confirm variable firm_age
    if !_rc local ctrl1 `ctrl1' firm_age
    foreach dv in ko_da_sic ko_da_kothari rem_heese {
        capture confirm variable `dv'
        if !_rc {
            reghdfe `dv' c.vs_4 i.duality c.vs_4#i.duality `ctrl1', absorb(year gvkey) cluster(gvkey)
            eststo g_`dv'_dual
            estadd local fe "Firm+Year"
            estadd local mod "duality"
        }
    }
    esttab g_ko_da_sic_dual g_ko_da_kothari_dual g_rem_heese_dual ///
        using "$OUTPUT\Moderation_Governance_duality.rtf", replace ///
        b(%9.4f) se(%9.4f) star(* 0.10 ** 0.05 *** 0.01) ///
        label compress nogaps mtitles("DA_MJ" "DA_Ko" "REM") ///
        title("Moderation: Environmental score x CEO duality") ///
        addnotes("duality not in baseline controls here." "Firm+Year FE, cluster gvkey.")
}

* A4: Board independence (if in dataset)
capture confirm variable bod_independence
if !_rc {
    eststo clear
    foreach dv in ko_da_sic ko_da_kothari rem_heese {
        capture confirm variable `dv'
        if !_rc {
            reghdfe `dv' c.vs_4 c.bod_independence c.vs_4#c.bod_independence $ctrl0, absorb(year gvkey) cluster(gvkey)
            eststo g_`dv'_bod
            estadd local fe "Firm+Year"
            estadd local mod "bod_indep"
        }
    }
    esttab g_ko_da_sic_bod g_ko_da_kothari_bod g_rem_heese_bod ///
        using "$OUTPUT\Moderation_Governance_bod_indep.rtf", replace ///
        b(%9.4f) se(%9.4f) star(* 0.10 ** 0.05 *** 0.01) ///
        label compress nogaps mtitles("DA_MJ" "DA_Ko" "REM") ///
        title("Moderation: Environmental score x Board independence") ///
        addnotes("If bod_independence missing in your build, this file is skipped at runtime." "Firm+Year FE, cluster gvkey.")
}

* --- Part B: Earnings pressure moderation ---
display as text _newline "========== EARNINGS PRESSURE MODERATION =========="

* B1: Consecutive underperformance (industry-adj ROA < 0 streak)
capture confirm variable under_duration
if !_rc {
    eststo clear
    foreach dv in ko_da_sic ko_da_kothari rem_heese {
        capture confirm variable `dv'
        if !_rc {
            reghdfe `dv' c.vs_4 c.under_duration c.vs_4#c.under_duration $ctrl0, absorb(year gvkey) cluster(gvkey)
            eststo p_`dv'_udur
            estadd local fe "Firm+Year"
            estadd local mod "under_dur"
        }
    }
    esttab p_ko_da_sic_udur p_ko_da_kothari_udur p_rem_heese_udur ///
        using "$OUTPUT\Moderation_Pressure_under_duration.rtf", replace ///
        b(%9.4f) se(%9.4f) star(* 0.10 ** 0.05 *** 0.01) ///
        label compress nogaps mtitles("DA_MJ" "DA_Ko" "REM") ///
        title("Moderation: Environmental score x Underperformance duration") ///
        addnotes("under_duration from Master_Analysis_v2 (adj ROA<0 streak)." "Firm+Year FE, cluster gvkey.")
}

* B2: Market-to-book as expectations / valuation pressure (c.vs_4#c.mb2 — mb2 also in ctrl)
*    Interpretation: slope of vs_4 on DA varies with growth/valuation
eststo clear
local ctrl2 "size lev roa growth_asset cash_holding big_4 noa mkt_share loss"
capture confirm variable per_io
if !_rc local ctrl2 `ctrl2' per_io
capture confirm variable firm_age
if !_rc local ctrl2 `ctrl2' firm_age
foreach dv in ko_da_sic ko_da_kothari rem_heese {
    capture confirm variable `dv'
    if !_rc {
        reghdfe `dv' c.vs_4 c.mb2 c.vs_4#c.mb2 `ctrl2', absorb(year gvkey) cluster(gvkey)
        eststo p_`dv'_mb2
        estadd local fe "Firm+Year"
        estadd local mod "mb2"
    }
}
esttab p_ko_da_sic_mb2 p_ko_da_kothari_mb2 p_rem_heese_mb2 ///
    using "$OUTPUT\Moderation_Pressure_mb2.rtf", replace ///
    b(%9.4f) se(%9.4f) star(* 0.10 ** 0.05 *** 0.01) ///
    label compress nogaps mtitles("DA_MJ" "DA_Ko" "REM") ///
    title("Moderation: Environmental score x Market-to-book (mb2)") ///
    addnotes("mb2 in controls + interaction; captures heterogeneity by valuation/growth." "Firm+Year FE, cluster gvkey.")

* --- Part C: compact summary (vs_gov + under_duration + mb2 on DA MJ only) ---
eststo clear
capture confirm variable vs_gov
if !_rc {
    reghdfe ko_da_sic c.vs_4 c.vs_gov c.vs_4#c.vs_gov $ctrl0, absorb(year gvkey) cluster(gvkey)
    eststo sum1
    estadd local fe "FY"
    estadd local spec "x vs_gov"
}
capture confirm variable under_duration
if !_rc {
    reghdfe ko_da_sic c.vs_4 c.under_duration c.vs_4#c.under_duration $ctrl0, absorb(year gvkey) cluster(gvkey)
    eststo sum2
    estadd local fe "FY"
    estadd local spec "x under_dur"
}
reghdfe ko_da_sic c.vs_4 c.mb2 c.vs_4#c.mb2 `ctrl2', absorb(year gvkey) cluster(gvkey)
eststo sum3
estadd local fe "FY"
estadd local spec "x mb2"

esttab sum1 sum2 sum3 using "$OUTPUT\Moderation_Summary_DA_MJ.rtf", replace ///
    b(%9.4f) se(%9.4f) star(* 0.10 ** 0.05 *** 0.01) ///
    label compress nogaps mtitles("xGov" "xUnderDur" "xMB") ///
    title("Summary: ESG x Moderator on DA (Modified Jones)") ///
    scalars("fe FE" "spec Moderator")

display as text _newline ">>> Done. RTF tables in $OUTPUT"
log close
