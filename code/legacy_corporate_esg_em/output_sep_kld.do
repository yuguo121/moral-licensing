* =============================================================================
* 【早期版本】来源项目：Corporate ESG and EM
* 现位置：Moral Lisensing/code/legacy_corporate_esg_em/
* 说明：保留作历史对照；路径与变量名可能仍为旧项目设定，运行前请自行核对。
* 主线分析请使用：code/Master_Analysis.do 或 Master_Analysis_v2.do 等。
* 迁入日期：2026-04-01
* =============================================================================
/*
================================================================================
STATA DO FILE: Instrumental Variables Analysis for KLD Variables
================================================================================
Purpose: Generate industrial average instrumental variables for KLD variables
         and run regressions using reghdfe and ivreghdfe
Author: [Your Name]
Date: [Current Date]
================================================================================
*/

// Set working directory with absolute path
cd "C:\Users\Yuguo\OneDrive - HKUST (Guangzhou)\Data"

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

// Define the list of KLD variables to create instruments for
local var "env emp com div hum pro cgov"

// Loop through each KLD variable to create industry average instruments
foreach v of local var {
	// Set panel data structure
	xtset gvkey year

    gen `v' = `v'_str_num1

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

// Create kld7 (sum of all 7 KLD variables)
gen kld7 = env + emp + com + div + hum + pro + cgov

// Create kld5 (sum of first 5 KLD variables, excluding pro and cgov)
gen kld5 = env + emp + com + div + hum

// Create lagged values for kld5 and kld7
sort gvkey year
by gvkey: gen l_kld5 = l.kld5
by gvkey: gen l_kld7 = l.kld7

// Create industry average instruments for kld5 and kld7
foreach v in kld5 kld7 {
    // Step 1: Mark non-missing observations for lagged variable
    gen nonmiss = !missing(l_`v')

    // Step 2: Calculate total and count of lagged variable per industry-year
    bysort sic_2 year: egen total_l_`v' = total(l_`v')
    bysort sic_2 year: egen count_l_`v' = count(l_`v')

    // Step 3: Compute industry average excluding the current firm
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
SECTION 2: GENERATE STATE-LEVEL AVERAGE INSTRUMENTS
================================================================================
This section creates instruments using state-level averages instead of industry averages
This provides geographic variation as an alternative source of identification
================================================================================
*/

// Create state identifier for geographic grouping
    encode state, gen(state_id)

// Create state-level average instruments
local var_region "env emp com div hum pro cgov kld5 kld7"

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
SECTION 3: CREATE MODERATOR VARIABLES
================================================================================
This section creates variables that will be used as moderators in interaction terms
Variables used: industry_type, under_duration, per_sri
================================================================================
*/

// Create industry_type variable (assuming it exists in the dataset)
// Create under_duration variable (assuming it exists in the dataset)
// Ensure per_sri variable exists and is properly formatted

// Create centered versions for better interpretation (optional)
sum industry_type
gen industry_type_c = industry_type - r(mean)

sum under_duration  
gen under_duration_c = under_duration - r(mean)

sum per_sri
gen per_sri_c = per_sri - r(mean)

// Define the list of KLD variables (including composite variables)
local kld_vars "env emp com div hum pro cgov kld5 kld7"

// Create interaction terms for each KLD variable with each moderator
foreach v of local kld_vars {
    // Create interaction with industry_type (shortened to it)
    gen `v'_it = `v' * industry_type
    
    // Create interaction with under_duration (shortened to ud)
    gen `v'_ud = `v' * under_duration
    
    // Create interaction with per_sri (shortened to ps)
    gen `v'_ps = `v' * per_sri
    
    // Create triple interaction terms (optional)
    gen `v'_it_ud = `v' * industry_type * under_duration
    gen `v'_it_ps = `v' * industry_type * per_sri
    gen `v'_ud_ps = `v' * under_duration * per_sri
}

// Create interaction terms for instruments as well
foreach v of local kld_vars {
    gen industry_avg_`v'_it = industry_avg_`v' * industry_type
    gen industry_avg_`v'_ud = industry_avg_`v' * under_duration
    gen industry_avg_`v'_ps = industry_avg_`v' * per_sri
}

/*
================================================================================
SECTION 4: MAIN REGRESSION ANALYSIS
================================================================================
This section runs the main regressions using both OLS (reghdfe) and IV (ivreghdfe)
for multiple dependent variables and independent variables.

Dependent variables: yu_da_ff, yu_da_sic, dss_da_ff, dss_da_sic
Independent variables: env, emp, com, div, hum, pro, cgov

Models included:
- M1: OLS with main variable
- M2: OLS with interactions (industry type, under duration, and SRI)
- M3: IV with main variable only
- M4: IV with interactions (industry type, under duration, and SRI)
- M5: Dynamic panel (xtabond2) with lagged dependent variable and interactions (industry type, under duration, and SRI)
- M6: Dynamic panel (xtabond2) with lagged dependent variable (main variable only)
================================================================================
*/


// Set output directory with absolute path and create test_2 subfolder
global out "C:\Users\Yuguo\OneDrive - HKUST (Guangzhou)\Data\test_2"
cap mkdir "$out"
// Verify directory creation
display "Output directory: $out"
display "Directory created successfully"
// Define dependent variables (prefixes and suffixes)
local prefixes "yu dss"
local suffixes "ff sic"

// Define independent variables to analyze
local x_vars "env emp com div hum pro cgov"

// Loop through each dependent variable
foreach prefix of local prefixes {
    foreach suffix of local suffixes {
        local y_var "`prefix'_da_`suffix'"
        
        // Loop through each independent variable
        foreach v of local x_vars {
             display "Running regressions for `y_var' on `v'"
            
            // Clear any existing stored estimates
            est clear
            
            // Model 1: reghdfe with interaction terms
            reghdfe `y_var' `v' `v'_it `v'_ud `v'_ps $ctrl, ///
                absorb(gvkey year) vce(cluster gvkey)
            estadd scalar r2_a_1 = e(r2_a)
            estadd scalar r2_within_1 = e(r2_within)
            estadd scalar r2_a_within_1 = e(r2_a_within)
            estadd scalar N_1 = e(N)
            estadd scalar N_g_1 = e(N_g)
            est store m1
            
            // Model 2: reghdfe without interaction terms
            reghdfe `y_var' `v' $ctrl, ///
                absorb(gvkey year) vce(cluster gvkey)
            estadd scalar r2_a_2 = e(r2_a)
            estadd scalar r2_within_2 = e(r2_within)
            estadd scalar r2_a_within_2 = e(r2_a_within)
            estadd scalar N_2 = e(N)
            estadd scalar N_g_2 = e(N_g)
            est store m2
            
            // Model 3: ivreghdfe with interaction terms
            ivreghdfe `y_var' (`v' `v'_it `v'_ud `v'_ps = ///
                industry_avg_`v' industry_avg_`v'_it industry_avg_`v'_ud industry_avg_`v'_ps) ///
                $ctrl, absorb(gvkey year) cluster(gvkey)
            estadd scalar r2_a_3 = e(r2_a)
            estadd scalar r2_within_3 = e(r2_within)
            estadd scalar r2_a_within_3 = e(r2_a_within)
            estadd scalar N_3 = e(N)
            estadd scalar N_g_3 = e(N_g)
            est store m3
            
            // Model 4: ivreghdfe without interaction terms
            ivreghdfe `y_var' (`v' = industry_avg_`v') $ctrl, ///
                absorb(gvkey year) cluster(gvkey)
            estadd scalar r2_a_4 = e(r2_a)
            estadd scalar r2_within_4 = e(r2_within)
            estadd scalar r2_a_within_4 = e(r2_a_within)
            estadd scalar N_4 = e(N)
            estadd scalar N_g_4 = e(N_g)
            est store m4
            

            /*
            ================================================================================
            OUTPUT RESULTS TO RTF AND LATEX FORMATS
            ================================================================================
            */
            
            // Create unique filename for each y-x combination
            local filename "`y_var'_on_`v'"
            
            // Output to RTF format with absolute paths
            esttab m1 m2 m3 m4 using "$out/`filename'.rtf", ///
                replace type star(* 0.10 ** 0.05 *** 0.01) ///
                stats(N r2_a waldF sarganP, fmt(%9.0f %9.3f %9.3f %9.3f) ///
                labels("Observations" "R-squared" "Weak ID F-stat" "Sargan P")) ///
                b(%9.3f) se(%9.3f) title("Table: `y_var' on `v'") ///
                mtitle("M1" "M2" "M3" "M4") ///
                nogap compress note("Standard errors clustered at firm level")
            
            // Output to LaTeX format with absolute paths
            esttab m1 m2 m3 m4 using "$out/`filename'.tex", ///
                replace type star(* 0.10 ** 0.05 *** 0.01) ///
                stats(N r2_a waldF sarganP, fmt(%9.0f %9.3f %9.3f %9.3f) ///
                labels("Observations" "R-squared" "Weak ID F-stat" "Sargan P")) ///
                b(%9.3f) se(%9.3f) title("Table: `y_var' on `v'") ///
                mtitle("M1" "M2" "M3" "M4") ///
                nogap compress note("Standard errors clustered at firm level")
        }
    }
}

/*
================================================================================
SECTION 5: SUMMARY STATISTICS AND DIAGNOSTICS
================================================================================
This section provides summary statistics and diagnostic tests
================================================================================
*/

// Display and save summary statistics for all dependent variables
local all_y_vars "yu_da_ff yu_da_sic dss_da_ff dss_da_sic"
sum `all_y_vars' env emp com div hum pro cgov $ctrl, detail

// Save summary statistics to file
quietly {
    log using "$out/summary_statistics.log", replace
    sum `all_y_vars' env emp com div hum pro cgov $ctrl, detail
    log close
}

// Display and save correlation matrix for main variables
corr `all_y_vars' env emp com div hum pro cgov
// Save correlation matrix to file
quietly {
    log using "$out/correlation_matrix.log", replace
    corr `all_y_vars' env emp com div hum pro cgov
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
display "Analysis complete. Results saved to test_2 folder:"
display "Individual regression results: $out/[y_var]_on_[x_var].rtf/.tex"
display "Summary statistics: $out/summary_statistics.log"
display "Correlation matrix: $out/correlation_matrix.log"
display "Weak instrument tests: $out/weak_instrument_tests.log"
display ""
display "Total combinations analyzed: 14 (4 dependent variables × 7 independent variables)"
display "Models per combination: M1, M2, M3, M4 (M5, M6 skipped due to xtabond2 syntax issues)"
display ""
display "Analysis completed successfully!"
display "All results saved to test_2 folder."

// Exit Stata to stop MCP execution
exit, clear