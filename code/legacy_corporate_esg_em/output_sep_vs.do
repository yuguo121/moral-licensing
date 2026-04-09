* =============================================================================
* 【早期版本】来源项目：Corporate ESG and EM
* 现位置：Moral Lisensing/code/legacy_corporate_esg_em/
* 说明：保留作历史对照；路径与变量名可能仍为旧项目设定，运行前请自行核对。
* 主线分析请使用：code/Master_Analysis.do 或 Master_Analysis_v2.do 等。
* 迁入日期：2026-04-01
* =============================================================================
/*
================================================================================
STATA DO FILE: Instrumental Variables Analysis for ESG Variables
================================================================================
Purpose: Generate industrial average instrumental variables for vs_* variables
         and run regressions using reghdfe and ivreghdfe
Author: [Your Name]
Date: [Current Date]
================================================================================
*/

// Set working directory with absolute path
cd "D:\OneDrive - HKUST (Guangzhou)\Data"

// Load the dataset
use final_sep, clear

// Define control variables global macro
global ctrl   size mb2 lev roa growth_asset cash_holding ///
              per_io big_4 firm_age ceo_age ceo_gender ///
              ceo_LogCompensation ceo_per_stock ceo_per_cash ///
              duality bod_independence bod_size

// Transform CEO age to log scale for better distribution
replace ceo_age = ln(ceo_age)

// Winsorize all control variables at 1st and 99th percentiles to reduce outlier impact
winsor2  size mb* roa lev growth_asset cash_holding per_* big_4 firm_age ceo_age ///
         ceo_gender ceo_LogCompensation ceo_per_stock ceo_per_cash duality ///
         bod_independence bod_size, cuts(1 99) replace


/*
================================================================================
SECTION 1: GENERATE INDUSTRIAL AVERAGE INSTRUMENTAL VARIABLES
================================================================================
This section creates instrumental variables using industry averages of lagged values
Method: For each firm, calculate the average of the variable across other firms
         in the same industry (sic_2) and year, excluding the firm itself
================================================================================
*/

// Define the list of variables to create instruments for
local var "vs_1 vs_4 vs_5 vs_6"

// Loop through each variable to create industry average instruments
foreach v of local var {
    // Set panel data structure
    xtset gvkey year
    
    // Create year-specific mean for centering (optional step)
    sort year 
    by year: egen mean_`v' = mean(`v')
    gen c_`v' = `v' - mean_`v'
    
    // Create lagged values of the variable
    sort gvkey year
    by gvkey: gen l_`v' = l.`v'

    // Step 1: Mark non-missing observations for lagged variable
    gen nonmiss = !missing(l_`v')

    // Step 2: Calculate total and count of lagged variable per industry-year
    bysort sic_2 year: egen total_l_`v' = total(l_`v')
    bysort sic_2 year: egen count_l_`v' = count(l_`v')

    // Step 3: Compute industry average excluding the current firm
    // This is the key instrumental variable: average of other firms in same industry-year
    gen industry_avg_`v' = (total_l_`v' - l_`v') / (count_l_`v' - 1) if nonmiss & count_l_`v' > 1
    replace industry_avg_`v' = . if nonmiss & count_l_`v' == 1  // Not defined for single-firm industries

    // Cleanup temporary variables
    drop nonmiss total_l_`v' count_l_`v'
    
    // Test the instrument strength by running first-stage regression
    qui: xtreg `v' industry_avg_`v' $ctrl i.year, fe vce(robust)
    predict double `v'_hat, xb 
}

/*
================================================================================
SECTION 2: GENERATE CONTEMPORANEOUS INDUSTRY AVERAGE INSTRUMENTS
================================================================================
This section creates instruments using contemporaneous (not lagged) industry averages
This is an alternative approach to the lagged instruments above
================================================================================
*/

// Create contemporaneous industry average instruments
local var "vs_1 vs_4 vs_5 vs_6"
foreach v of local var {
    // Set panel data structure
    xtset gvkey year

    // Step 1: Mark non-missing observations for current variable
    gen nonmiss = !missing(`v')

    // Step 2: Calculate total and count of variable per industry-year
    bysort sic_2 year: egen total_`v' = total(`v')
    bysort sic_2 year: egen count_`v' = count(`v')

    // Step 3: Compute industry average excluding the current firm
    gen industry_avg_`v'1 = (total_`v' - `v') / (count_`v' - 1) if nonmiss & count_`v' > 1
    replace industry_avg_`v'1 = . if nonmiss & count_`v' == 1  // Not defined for single-firm industries

    // Cleanup temporary variables
    drop nonmiss total_`v' count_`v'
    
    // Test the instrument strength by running first-stage regression
    xtreg `v' industry_avg_`v'1 $ctrl i.year, fe vce(robust)
    predict double `v'_hat1, xb 
}


/*
================================================================================
SECTION 3: GENERATE STATE-LEVEL AVERAGE INSTRUMENTS
================================================================================
This section creates instruments using state-level averages instead of industry averages
This provides geographic variation as an alternative source of identification
================================================================================
*/

// Create state identifier for geographic grouping
encode state, gen(state_id)

// Create state-level average instruments
local var_region "vs_1 vs_4 vs_5 vs_6"

foreach v of local var_region {
    // Step 1: Mark non-missing observations for lagged variable
    gen nonmiss = !missing(l_`v')

    // Step 2: Calculate total and count of lagged variable per state-year
    bysort state_id year: egen total_`v' = total(l_`v')
    bysort state_id year: egen count_`v' = count(l_`v')

    // Step 3: Compute state average excluding the current firm
    gen state_avg_`v' = (total_`v' - l_`v') / (count_`v' - 1) if nonmiss & count_`v' > 1
    replace state_avg_`v' = . if nonmiss & count_`v' == 1  // Not defined for single-firm states

    // Cleanup temporary variables
    drop nonmiss total_`v' count_`v'
    
    // Test the instrument strength by running first-stage regression
    xtreg `v' state_avg_`v' $ctrl i.year, fe vce(robust)
    predict double `v'_hat_state, xb 
}


/*
================================================================================
SECTION 4: CREATE MODERATOR VARIABLES
================================================================================
This section creates variables that will be used as moderators in interaction terms
================================================================================
*/

// Create industry-year level control exposure variable
sort year sic_2
by year sic_2: egen contro_exposure = mean(vs_3)
bys year: egen contro_exposure_mean = mean(contro_exposure)
replace contro_exposure = contro_exposure - contro_exposure_mean

// Create industry-year level culpability measure
bys sic_2 year: egen culpability = total(vs_3)
bys year: egen culpability_mean = mean(culpability)
replace culpability = (culpability - culpability_mean) / culpability_mean

// Create centered SRI percentage variable
sum per_sri
gen per_sri_c = per_sri - r(mean)
/*
================================================================================
SECTION 5: MAIN REGRESSION ANALYSIS
================================================================================
This section runs the main regressions using both OLS (reghdfe) and IV (ivreghdfe)
for multiple dependent variables and independent variables.

Dependent variables: yu_da_ff, yu_da_sic, dss_da_ff, dss_da_sic, ge_da_ff, ge_da_sic, ko_da_ff, ko_da_sic
Independent variables: vs_1, vs_4, vs_5, vs_6

Models included:
- M2: OLS with main variable
- M5: OLS with both interactions (control exposure and SRI)
- M6: IV with main variable only
- M9: IV with both interactions
================================================================================
*/

// Set output directory with absolute path and create Test_1 subfolder
global out "D:\OneDrive - HKUST (Guangzhou)\Data\Test_1"
cap mkdir "$out"
// Verify directory creation
display "Output directory: $out"
display "Directory created successfully"

// Define dependent variables (prefixes and suffixes)
local prefixes "yu dss ge ko"
local suffixes "ff sic"

// Define independent variables to analyze
local x_vars "vs_1 vs_4 vs_5 vs_6"

// Loop through each dependent variable
foreach prefix of local prefixes {
    foreach suffix of local suffixes {
        local y_var "`prefix'_da_`suffix'"
        
        // Loop through each independent variable
        foreach v of local x_vars {
            // Clear previous estimates
            est clear
            
            // Model 2: OLS with main variable
            reghdfe `y_var' $ctrl `v', absorb(year gvkey) cluster(gvkey)
            est store m2
            
            // Model 5: OLS with both interactions
            reghdfe `y_var' $ctrl `v' c.`v'#c.contro_exposure c.`v'#c.per_sri, absorb(year gvkey) cluster(gvkey)
            est store m5
            
            // Model 6: IV with main variable only
            ivreghdfe `y_var' $ctrl (`v' = industry_avg_`v'), absorb(year gvkey) cluster(gvkey)
            estadd scalar waldF = e(widstat)
            estadd scalar sarganP = e(sarganp)
            est store m6
            
            // Model 9: IV with both interactions
            ivreghdfe `y_var' $ctrl (`v' c.`v'#c.contro_exposure c.`v'#c.per_sri = industry_avg_`v' c.industry_avg_`v'#c.contro_exposure c.industry_avg_`v'#c.per_sri), absorb(year gvkey) cluster(gvkey)
            estadd scalar waldF = e(widstat)
            estadd scalar sarganP = e(sarganp)
            est store m9


            /*
            ================================================================================
            OUTPUT RESULTS TO RTF AND LATEX FORMATS
            ================================================================================
            */
            
            // Create unique filename for each y-x combination
            local filename "`y_var'_on_`v'"
            
            // Output to RTF format with absolute paths
            esttab m2 m5 m6 m9 using "$out/`filename'.rtf", ///
                replace type star(* 0.10 ** 0.05 *** 0.01) ///
                stats(N r2_a waldF sarganP, fmt(%9.0f %9.3f %9.3f %9.3f) ///
                labels("Observations" "R-squared" "Weak ID F-stat" "Sargan P")) ///
                b(%9.3f) se(%9.3f) title("Table: `y_var' on `v'") ///
                mtitle("M2" "M5" "M6" "M9") ///
                nogap compress note("Standard errors clustered at firm level")
            
            // Output to LaTeX format with absolute paths
            esttab m2 m5 m6 m9 using "$out/`filename'.tex", ///
                replace type star(* 0.10 ** 0.05 *** 0.01) ///
                stats(N r2_a waldF sarganP, fmt(%9.0f %9.3f %9.3f %9.3f) ///
                labels("Observations" "R-squared" "Weak ID F-stat" "Sargan P")) ///
                b(%9.3f) se(%9.3f) title("Table: `y_var' on `v'") ///
                mtitle("M2" "M5" "M6" "M9") ///
                nogap compress note("Standard errors clustered at firm level")
        }
    }
}

/*
================================================================================
SECTION 6: SUMMARY STATISTICS AND DIAGNOSTICS
================================================================================
This section provides summary statistics and diagnostic tests
================================================================================
*/

// Display and save summary statistics for all dependent variables
local all_y_vars "yu_da_ff yu_da_sic dss_da_ff dss_da_sic ge_da_ff ge_da_sic ko_da_ff ko_da_sic"
sum `all_y_vars' vs_1 vs_4 vs_5 vs_6 $ctrl, detail

// Save summary statistics to file
quietly {
    log using "$out/summary_statistics.log", replace
    sum `all_y_vars' vs_1 vs_4 vs_5 vs_6 $ctrl, detail
    log close
}

// Display and save correlation matrix for main variables
corr `all_y_vars' vs_1 vs_4 vs_5 vs_6
// Save correlation matrix to file
quietly {
    log using "$out/correlation_matrix.log", replace
    corr `all_y_vars' vs_1 vs_4 vs_5 vs_6
    log close
}

// Test for weak instruments (first-stage F-statistics) and save results
quietly {
    log using "$out/weak_instrument_tests.log", replace
    foreach v of local x_vars {
        qui: xtreg `v' industry_avg_`v' $ctrl i.year, fe vce(robust)
        test industry_avg_`v'
        display "Weak instrument test for `v': F-stat = " r(F) ", p-value = " r(p)
    }
    log close
}

// Display weak instrument tests to console
foreach v of local x_vars {
    qui: xtreg `v' industry_avg_`v' $ctrl i.year, fe vce(robust)
    test industry_avg_`v'
    display "Weak instrument test for `v': F-stat = " r(F) ", p-value = " r(p)
}

// Display final message with absolute paths
display "Analysis complete. Results saved to Test_1 folder:"
display "Individual regression results: $out/[y_var]_on_[x_var].rtf/.tex"
display "Summary statistics: $out/summary_statistics.log"
display "Correlation matrix: $out/correlation_matrix.log"
display "Weak instrument tests: $out/weak_instrument_tests.log"
display ""
display "Total combinations analyzed: 32 (8 dependent variables × 4 independent variables)"
display "Models per combination: M2, M5, M6, M9"
