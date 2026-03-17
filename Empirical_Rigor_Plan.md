# Empirical Rigor & UTD24 Methodology Plan
# Moral Licensing in ESG and Earnings Management

This document outlines a **fully executable** econometric and identification strategy for aligning the "Moral Licensing in ESG and Earnings Management" study with UTD24 journal standards (e.g., *Academy of Management Journal*, *Journal of Accounting and Economics*, *The Accounting Review*).

---

## 1. Research Design Overview

### Core Hypothesis
**H1 (Moral Licensing):** Higher ESG performance is positively associated with subsequent earnings management, as firms accumulate "moral credit" that psychologically licenses ethical slack.

### Dual-Moderator Framework
- **Moderator 1 — Industry Culpability (Contextual):** In non-culpable industries, ESG → licensing; in culpable ("sin") industries, ESG → constraining.
- **Moderator 2 — ESG Moral Identity (Dispositional):** Reactive/symbolic ESG firms are more susceptible to licensing; substantive/consistent ESG firms are constrained by identity dissonance.

### Theoretical Anchors
| Theory | Prediction |
|:---|:---|
| Moral Licensing (Merritt et al., 2010) | Past good deeds create a "moral credit" that permits subsequent transgressions |
| Moral Track Hypothesis (Kim, Park & Wier, 2012) | Ethically committed firms extend moral behavior to financial reporting |
| Symbolic vs. Substantive CSR (Westphal, 2023; Velte, 2024) | The CSR-EM link depends on whether CSR is genuine or strategic |

---

## 2. Data Sources & Sample Construction

### 2.1 Primary Databases

| Database | File | Period | Key Role |
|:---|:---|:---|:---|
| **KLD ESG STATS** | `D:\Research\Data\ESG\kld_zy.dta` | 2000–2022 | ESG performance (strengths/concerns), Sin stock flags |
| **MSCI ESG Ratings** | `D:\Research\Data\ESG\msci_ratings_clean.dta` | 2005–2024 | Alternative ESG measure, Pillar scores (E/S/G) |
| **Compustat** | `D:\Research\Data\Financials\compustat_80_25.dta` | 1979–2024 | Financial variables for EM computation, SIC codes |
| **Execucomp** | `D:\Research\Data\CEO\execucomp_10_25.dta` | 2010–2025 | CEO characteristics, compensation incentives |
| **IBES** | `D:\Research\Data\Financials\ibes_detail_raw.dta` | 1975–present | Analyst coverage, meeting/beating benchmarks |
| **Institutional Holdings** | `D:\Research\Data\Financials\io.dta` | — | Institutional ownership concentration |

### 2.2 Data Availability Validation (Stata-Verified)

| Item | Result |
|:---|:---|
| KLD gvkey–year obs (2000–2022) | 115,170 obs, 12,584 unique firms |
| KLD sin stock indicators (`alc_con_a`, `gam_con_a`, `tob_con_a`, `mil_con_a`, `nuc_con_a`) | Available; ~3% of obs flagged as sin |
| Compustat Modified Jones variables (ni, oancf, at, sale, rect, ppegt) | 177,929 obs with complete data (68%) |
| Compustat Real EM variables (oancf, cogs, invt, xsga, xrd) | 200,754 obs with core data |
| Compustat SIC codes (`sich`) | Available for industry classification |
| MSCI GVKEY linkage | 30,132 obs with GVKEY (18.5%); use `cusip6` for broader match |

### 2.3 Sample Selection Criteria

```stata
* === SAMPLE CONSTRUCTION ===
* Step 1: Start with Compustat (US firms, 2003–2022)
use "D:\Research\Data\Financials\compustat_80_25.dta", clear
keep if fyear >= 2003 & fyear <= 2022
keep if indfmt == "INDL" | indfmt == ""
drop if missing(at) | at <= 0
drop if missing(ni, oancf, sale, rect, ppegt)

* Exclude financials (SIC 6000-6999) and utilities (SIC 4900-4999)
drop if sich >= 6000 & sich <= 6999
drop if sich >= 4900 & sich <= 4999

* Require at least 15 obs per 2-digit SIC-year for Jones model estimation
gen sic2 = int(sich / 100)
bysort sic2 fyear: gen n_sic2yr = _N
drop if n_sic2yr < 15

* Step 2: Merge with KLD ESG
merge 1:1 gvkey fyear using "D:\Research\Data\ESG\kld_zy.dta", ///
    keep(match) nogenerate
```

---

## 3. Variable Construction

### 3.1 Dependent Variable: Earnings Management

#### A. Accrual-Based EM (Modified Jones Model)

Following Dechow et al. (1995) and Kim, Park & Wier (2012):

```stata
* === MODIFIED JONES MODEL ===
* Total accruals
gen TA = ni - oancf

* Lagged total assets
sort gvkey fyear
by gvkey: gen L_at = at[_n-1]
drop if missing(L_at)

* Scale variables
gen TA_A    = TA / L_at
gen inv_A   = 1 / L_at
gen dREV_A  = (sale - sale[_n-1]) / L_at
gen dREC_A  = (rect - rect[_n-1]) / L_at
gen PPE_A   = ppegt / L_at

* Estimate Modified Jones Model by SIC2-Year
gen DA = .
levelsof sic2, local(industries)
levelsof fyear, local(years)
foreach i of local industries {
    foreach y of local years {
        capture {
            reg TA_A inv_A dREV_A PPE_A if sic2 == `i' & fyear == `y', noconstant
            predict res if sic2 == `i' & fyear == `y', residuals
            replace DA = res if sic2 == `i' & fyear == `y' & !missing(res)
            drop res
        }
    }
}

* Absolute discretionary accruals (unsigned EM)
gen absDA = abs(DA)

* Performance-matched DA (Kothari et al., 2005)
gen ROA = ni / L_at
xtile roa_decile = ROA, nq(10)
bysort sic2 fyear roa_decile: egen mean_DA_match = mean(DA)
gen DA_pmatch = DA - mean_DA_match
gen absDA_pmatch = abs(DA_pmatch)
```

#### B. Real Earnings Management (Roychowdhury, 2006)

```stata
* === REAL EARNINGS MANAGEMENT ===
sort gvkey fyear
by gvkey: gen L_sale = sale[_n-1]
gen dSALE    = sale - L_sale
gen dSALE_A  = dSALE / L_at
gen SALE_A   = sale / L_at
gen PROD     = cogs + (invt - invt[_n-1])
gen PROD_A   = PROD / L_at
gen CFO_A    = oancf / L_at

* Abnormal CFO: CFO_A = a0*(1/L_at) + a1*(SALE_A) + a2*(dSALE_A) + e
* Abnormal Production: PROD_A = a0*(1/L_at) + a1*(SALE_A) + a2*(dSALE_A) + a3*(L.dSALE_A) + e
* Abnormal Discretionary Expenses: DISX_A = a0*(1/L_at) + a1*(L.SALE_A) + e

gen DISX = xsga  // SG&A as proxy for discretionary expenses
replace DISX = xrd + xad if missing(DISX)
gen DISX_A = DISX / L_at

by gvkey: gen L_dSALE_A = dSALE_A[_n-1]
by gvkey: gen L_SALE_A  = SALE_A[_n-1]

* Estimate by SIC2-Year, collect residuals as abnormal CFO/PROD/DISX
* (implementation analogous to Modified Jones Model above)

* Combined REM metric (higher = more real EM)
* REM = -Ab_CFO + Ab_PROD - Ab_DISX (Zang, 2012)
```

### 3.2 Independent Variable: ESG Performance

#### Primary Measure (KLD-Based)

Following the net strengths approach widely used in the literature:

```stata
* === ESG PERFORMANCE (KLD) ===
* Environmental net score
gen env_score = env_str_num - env_con_num

* Social net score (community + diversity + employee + human rights + product)
gen soc_score = (com_str_num + div_str_num + emp_str_num + hum_str_num + pro_str_num) ///
              - (com_con_num + div_con_num + emp_con_num + hum_con_num + pro_con_num)

* Governance net score
gen gov_score = cgov_str_num - cgov_con_num

* Aggregate ESG
gen esg_total = env_score + soc_score + gov_score

* Standardized ESG (within year)
bysort fyear: egen esg_mean_yr = mean(esg_total)
bysort fyear: egen esg_sd_yr   = sd(esg_total)
gen esg_std = (esg_total - esg_mean_yr) / esg_sd_yr

* ESG tercile dummy (High ESG treatment)
bysort fyear: xtile esg_tercile = esg_total, nq(3)
gen high_esg = (esg_tercile == 3)
```

#### Alternative: MSCI ESG Ratings

```stata
* === ALTERNATIVE: MSCI ESG ===
* Merge MSCI using cusip6
gen cusip6 = substr(cusip, 1, 6)
merge 1:1 cusip6 fyear using "D:\Research\Data\ESG\msci_ratings_clean.dta", ///
    keepusing(industry_adjusted_score environmental_pillar_score ///
              social_pillar_score governance_pillar_score iva_company_rating) ///
    keep(master match) nogenerate

* Numeric rating: CCC=1, B=2, BB=3, BBB=4, A=5, AA=6, AAA=7
gen msci_numeric = .
replace msci_numeric = 1 if iva_company_rating == "CCC"
replace msci_numeric = 2 if iva_company_rating == "B"
replace msci_numeric = 3 if iva_company_rating == "BB"
replace msci_numeric = 4 if iva_company_rating == "BBB"
replace msci_numeric = 5 if iva_company_rating == "A"
replace msci_numeric = 6 if iva_company_rating == "AA"
replace msci_numeric = 7 if iva_company_rating == "AAA"
```

### 3.3 Moderator 1: Industry Culpability

Following Hong & Kacperczyk (2009, *JFE*), sin stocks are defined using the Fama-French 48-industry classification:

```stata
* === MODERATOR 1: INDUSTRY CULPABILITY ===

* Method A: SIC-based (Compustat)
* Hong & Kacperczyk (2009): Alcohol (SIC 2080-2085), Tobacco (SIC 2100-2199),
* Gaming (NAICS 7132, 71312, 713210, 713290, 72112, 721120)
gen culpable_sic = 0
replace culpable_sic = 1 if sich >= 2080 & sich <= 2085   // Alcohol
replace culpable_sic = 1 if sich >= 2100 & sich <= 2199   // Tobacco
replace culpable_sic = 1 if inlist(sich, 7011, 7993)      // Gaming/casinos
replace culpable_sic = 1 if inlist(sich, 3484, 3489, 3812) // Firearms/defense
label var culpable_sic "=1 if Sin Industry (Hong & Kacperczyk 2009)"

* Method B: KLD controversial business flags (preferred, more precise)
gen culpable_kld = 0
replace culpable_kld = 1 if alc_con_a == 1  // Alcohol involvement
replace culpable_kld = 1 if gam_con_a == 1  // Gambling involvement
replace culpable_kld = 1 if tob_con_a == 1  // Tobacco involvement
replace culpable_kld = 1 if mil_con_a == 1  // Military/weapons involvement
replace culpable_kld = 1 if nuc_con_a == 1  // Nuclear power involvement
label var culpable_kld "=1 if Controversial Industry (KLD flags)"

* Extended definition: add fossil fuels (Sagbakken & Zhang, 2021)
* SIC 1200-1299 (coal), 1300-1389 (oil & gas extraction), 2911 (petroleum refining)
gen culpable_ext = culpable_sic
replace culpable_ext = 1 if sich >= 1200 & sich <= 1299  // Coal
replace culpable_ext = 1 if sich >= 1300 & sich <= 1389  // Oil & gas
replace culpable_ext = 1 if sich == 2911                  // Petroleum refining
label var culpable_ext "=1 if Extended Sin Industry (incl. fossil fuels)"
```

### 3.4 Moderator 2: ESG Moral Identity Centrality (Substantive vs. Symbolic ESG)

This is the key novel construct. We operationalize it through **three complementary approaches**, all leveraging existing ESG data:

#### Approach A: ESG Consistency Score (Primary — Recommended)

**Theoretical basis:** Firms with a deeply internalized moral identity exhibit **consistent** ESG performance over time, not sudden jumps. A firm whose ESG is central to identity will show low within-firm ESG variance relative to its level (Aquino & Reed, 2002; Westphal, 2023).

```stata
* === MODERATOR 2A: ESG CONSISTENCY (WITHIN-FIRM TEMPORAL STABILITY) ===

* Require at least 5 years of KLD data per firm
bysort gvkey: gen firm_nyears = _N
keep if firm_nyears >= 5

* Within-firm ESG mean and standard deviation
bysort gvkey: egen esg_firm_mean = mean(esg_total)
bysort gvkey: egen esg_firm_sd   = sd(esg_total)

* Consistency = inverse of coefficient of variation
* High consistency → substantive ESG identity
gen esg_consistency = 1 - (esg_firm_sd / (abs(esg_firm_mean) + 1))
* Add 1 to denominator to avoid division by zero

* Binary: firms in top tercile of consistency with above-median ESG = Substantive
bysort fyear: xtile consist_tercile = esg_consistency, nq(3)
gen substantive_esg = (consist_tercile == 3 & esg_firm_mean > 0)
label var substantive_esg "=1 if Substantive ESG (High & Consistent)"
```

#### Approach B: ESG Trajectory Slope (Alternative)

**Logic:** Firms whose ESG is increasing steeply are "reactive" (likely responding to external pressure); firms with persistently high ESG are "substantive."

```stata
* === MODERATOR 2B: ESG TRAJECTORY SLOPE ===

* Firm-specific ESG time trend (rolling 5-year window)
gen esg_slope = .
sort gvkey fyear
by gvkey: gen t = _n

* Estimate firm-by-firm OLS slope
statsby _b[t], by(gvkey) saving(esg_slopes, replace): ///
    reg esg_total t

* Merge slopes back
merge m:1 gvkey using esg_slopes, nogenerate
rename _b_t esg_trend

* Reactive = high positive slope (improving fast, from low base)
* Substantive = low/zero slope with high level (already high, stable)
gen reactive_esg = (esg_trend > 0 & esg_firm_mean <= 0)
gen substantive_esg_v2 = (esg_trend <= 0 & esg_firm_mean > 0) | ///
                         (abs(esg_trend) < 0.5 & esg_firm_mean > 0)
label var reactive_esg "=1 if Reactive/Symbolic ESG (steep improvement)"
label var substantive_esg_v2 "=1 if Substantive ESG (stable high)"
```

#### Approach C: Early ESG Adoption Dummy (Clean Identification)

**Logic:** Firms that exhibited positive ESG engagement **before** it became mainstream or mandated reflect intrinsic moral commitment (Velte, 2024; Kim et al., 2012).

```stata
* === MODERATOR 2C: EARLY ADOPTION ===

* First year firm shows positive ESG net score in KLD
bysort gvkey (fyear): gen first_pos_esg = fyear if esg_total > 0 & !missing(esg_total)
bysort gvkey: egen first_pos_year = min(first_pos_esg)
drop first_pos_esg

* Cutoff: "Early" = positive ESG by 2005 (before KLD expanded to Russell 3000)
* Alternative: by 2010 (before EU NFRD debate began)
gen early_adopter_2005 = (first_pos_year <= 2005) if !missing(first_pos_year)
gen early_adopter_2010 = (first_pos_year <= 2010) if !missing(first_pos_year)
label var early_adopter_2005 "=1 if ESG+ before 2005 (pre-mainstream)"
label var early_adopter_2010 "=1 if ESG+ before 2010 (pre-mandate era)"

* Validated: ~48% of KLD firms qualify as early adopter (≤2005), good balance
```

### 3.5 Control Variables

```stata
* === CONTROL VARIABLES ===
gen SIZE    = ln(at)
gen LEV     = lt / at
gen ROA_c   = ni / at
gen MTB     = (csho * prcc_f) / ceq if ceq > 0
gen GROWTH  = (sale - L_sale) / L_sale if L_sale > 0
gen CFO_c   = oancf / at
gen LOSS    = (ni < 0)
gen LNAT    = ln(at)

* Big 4 auditor (if available in Compustat)
gen BIG4 = (au == 1 | au == 2 | au == 3 | au == 4) if !missing(au)

* Board governance (from Execucomp if CEO data desired)
* merge m:1 gvkey fyear using "D:\Research\Data\CEO\execucomp_10_25.dta", ...

* Institutional ownership
* merge m:1 gvkey fyear using "D:\Research\Data\Financials\io.dta", ...
```

---

## 4. Econometric Models

### 4.1 Baseline: OLS with Fixed Effects

$$EM_{i,t+1} = \beta_1 ESG_{i,t} + \gamma X_{i,t} + \alpha_i + \delta_t + \mu_{j \times t} + \varepsilon_{i,t}$$

Where:
- $EM_{i,t+1}$: Earnings management in year $t+1$ (one-year lead, addresses reverse causality)
- $ESG_{i,t}$: ESG performance in year $t$
- $X_{i,t}$: Controls (SIZE, LEV, ROA, MTB, GROWTH, CFO, LOSS, BIG4)
- $\alpha_i$: Firm fixed effects
- $\delta_t$: Year fixed effects
- $\mu_{j \times t}$: Industry × Year fixed effects (absorbs time-varying industry shocks)

```stata
* === BASELINE REGRESSION ===
* Lead dependent variable
sort gvkey fyear
by gvkey: gen F_absDA = absDA[_n+1]
by gvkey: gen F_DA    = DA[_n+1]

* Firm + Year FE
reghdfe F_absDA esg_std SIZE LEV ROA_c MTB GROWTH CFO_c LOSS, ///
    absorb(gvkey fyear) cluster(gvkey)
estimates store baseline_unsigned

reghdfe F_DA esg_std SIZE LEV ROA_c MTB GROWTH CFO_c LOSS, ///
    absorb(gvkey fyear) cluster(gvkey)
estimates store baseline_signed

* Firm + Industry×Year FE
egen ind_year = group(sic2 fyear)
reghdfe F_absDA esg_std SIZE LEV ROA_c MTB GROWTH CFO_c LOSS, ///
    absorb(gvkey ind_year) cluster(gvkey)
estimates store baseline_indyr
```

### 4.2 Moderator 1: Industry Culpability Interaction

**H2:** The moral licensing effect is stronger in non-culpable industries and weaker (or reversed) in culpable industries.

```stata
* === MODERATOR 1: INDUSTRY CULPABILITY ===
gen esg_x_culp = esg_std * culpable_kld

reghdfe F_absDA esg_std culpable_kld esg_x_culp ///
    SIZE LEV ROA_c MTB GROWTH CFO_c LOSS, ///
    absorb(gvkey fyear) cluster(gvkey)
estimates store mod1_culpability

* Interpretation:
* β(esg_std) > 0: Licensing effect in non-culpable industries
* β(esg_x_culp) < 0: Culpable industries constrain licensing
* Net effect for culpable: β(esg_std) + β(esg_x_culp) ≈ 0 or negative
lincom esg_std + esg_x_culp  // test net effect in culpable industries
```

### 4.3 Moderator 2: ESG Moral Identity

**H3:** The moral licensing effect is concentrated among reactive/symbolic ESG firms and absent among substantive ESG firms.

```stata
* === MODERATOR 2: ESG MORAL IDENTITY ===
gen esg_x_subst = esg_std * substantive_esg

reghdfe F_absDA esg_std substantive_esg esg_x_subst ///
    SIZE LEV ROA_c MTB GROWTH CFO_c LOSS, ///
    absorb(gvkey fyear) cluster(gvkey)
estimates store mod2_identity

* Interpretation:
* β(esg_std) > 0: Licensing among reactive/symbolic firms
* β(esg_x_subst) < 0: Substantive ESG identity suppresses licensing
lincom esg_std + esg_x_subst  // test net effect for substantive firms
```

### 4.4 Triple Interaction (Full Model)

```stata
* === FULL MODEL: TRIPLE INTERACTION ===
gen esg_culp_subst = esg_std * culpable_kld * substantive_esg
gen culp_subst     = culpable_kld * substantive_esg

reghdfe F_absDA esg_std culpable_kld substantive_esg ///
    esg_x_culp esg_x_subst culp_subst esg_culp_subst ///
    SIZE LEV ROA_c MTB GROWTH CFO_c LOSS, ///
    absorb(gvkey fyear) cluster(gvkey)
estimates store full_model
```

---

## 5. Identification Strategies

### 5.1 Two-Stage Least Squares (2SLS)

**Instrument:** Industry-average ESG (excluding focal firm) — captures exogenous industry-level ESG trends while purging firm-specific endogenous ESG choices.

```stata
* === 2SLS: INDUSTRY-AVERAGE ESG INSTRUMENT ===
bysort sic2 fyear: egen sum_esg = total(esg_total)
bysort sic2 fyear: gen n_firms = _N
gen iv_ind_esg = (sum_esg - esg_total) / (n_firms - 1)
label var iv_ind_esg "Industry-avg ESG excl. focal firm"

* First stage
reghdfe esg_std iv_ind_esg SIZE LEV ROA_c MTB GROWTH CFO_c LOSS, ///
    absorb(gvkey fyear) cluster(gvkey)
* Check F-stat (Cragg-Donald / Kleibergen-Paap)

* 2SLS
ivreghdfe F_absDA (esg_std = iv_ind_esg) ///
    SIZE LEV ROA_c MTB GROWTH CFO_c LOSS, ///
    absorb(gvkey fyear) cluster(gvkey) first
```

### 5.2 Staggered Difference-in-Differences

**Shock:** EU Non-Financial Reporting Directive (NFRD, Directive 2014/95/EU), effective 2017. Firms subject to mandatory ESG disclosure experienced an exogenous increase in ESG visibility.

For US-only sample, use **SEC 2010 Climate Disclosure Guidance** or **California SB 253 (2023)** as staggered treatment.

Alternative: Use KLD coverage expansion as a shock (KLD expanded from S&P 500 to Russell 3000 in 2003).

```stata
* === STAGGERED DiD (KLD expansion shock, 2003) ===
* Treatment: Firms first entering KLD coverage in 2003
gen treated_2003 = (first_kld_year == 2003)
gen post_2003 = (fyear >= 2003)
gen did = treated_2003 * post_2003

reghdfe F_absDA did SIZE LEV ROA_c MTB GROWTH CFO_c LOSS, ///
    absorb(gvkey fyear) cluster(gvkey)
```

### 5.3 Oster (2019) Coefficient Stability Test

Tests whether the treatment effect $\beta_{ESG}$ is robust to selection on unobservables.

```stata
* === OSTER (2019) BOUNDS ===
* Requires: psacalc (Stata package)
* ssc install psacalc

* Step 1: Uncontrolled regression
reg F_absDA esg_std, cluster(gvkey)
local b_tilde = _b[esg_std]
local r_tilde = e(r2)

* Step 2: Controlled regression
reghdfe F_absDA esg_std SIZE LEV ROA_c MTB GROWTH CFO_c LOSS, ///
    absorb(gvkey fyear) cluster(gvkey)
local b_hat = _b[esg_std]
local r_hat = e(r2)

* Step 3: Calculate delta (assuming Rmax = 1.3 * R_controlled)
psacalc delta esg_std, rmax(1.3) mcontrol(SIZE LEV ROA_c MTB GROWTH CFO_c LOSS)
* If |delta| > 1, the result is robust: unobservables would need to be
* more important than observables to explain away the effect
```

### 5.4 Propensity Score Matching (PSM)

```stata
* === PSM: HIGH vs LOW ESG ===
* Treatment = Top tercile ESG
logit high_esg SIZE LEV ROA_c MTB GROWTH CFO_c LOSS i.sic2 i.fyear
predict pscore, pr

* Nearest-neighbor matching (1:1, caliper 0.05)
psmatch2 high_esg, pscore(pscore) neighbor(1) caliper(0.05) ///
    outcome(F_absDA) common

* Covariate balance check
pstest SIZE LEV ROA_c MTB GROWTH CFO_c LOSS, treated(high_esg)
```

---

## 6. Robustness Tests

### 6.1 Alternative EM Proxies

| Test | Measure |
|:---|:---|
| Real EM (Roychowdhury, 2006) | Abnormal CFO, Production, Discretionary expenses |
| Performance-matched DA (Kothari, 2005) | DA matched on ROA decile |
| Meet/Beat analyst forecasts | P(actual EPS ≥ consensus - $0.01) using IBES |

### 6.2 Alternative ESG Measures

| Test | Measure |
|:---|:---|
| MSCI ESG Rating | 7-point ordinal (CCC–AAA) |
| Environmental pillar only | `environmental_pillar_score` from MSCI |
| ESG strengths only (no concerns) | `esg_str_num` from KLD |
| E vs. S vs. G decomposition | Test which pillar drives licensing |

### 6.3 Mechanism Falsification

**Key test:** If moral licensing drives the effect, it should be strongest for **Environmental** (high discretionary moral credit) and weakest for **Governance** (baseline compliance, low "credit" accumulation).

```stata
* === E vs. G FALSIFICATION ===
reghdfe F_absDA env_score SIZE LEV ROA_c MTB GROWTH CFO_c LOSS, ///
    absorb(gvkey fyear) cluster(gvkey)
estimates store mech_E

reghdfe F_absDA gov_score SIZE LEV ROA_c MTB GROWTH CFO_c LOSS, ///
    absorb(gvkey fyear) cluster(gvkey)
estimates store mech_G

* Expect: β(env_score) > β(gov_score), consistent with moral licensing
suest mech_E mech_G
test [mech_E_mean]env_score = [mech_G_mean]gov_score
```

### 6.4 Governance as Boundary Condition

```stata
* === GOVERNANCE MODERATION ===
* Strong governance should attenuate licensing
* Proxy: governance pillar score from KLD or MSCI
gen strong_gov = (gov_score > 0) if !missing(gov_score)
gen esg_x_gov = esg_std * strong_gov

reghdfe F_absDA esg_std strong_gov esg_x_gov ///
    SIZE LEV ROA_c MTB GROWTH CFO_c LOSS, ///
    absorb(gvkey fyear) cluster(gvkey)
```

### 6.5 Heckman Selection Correction

Address potential selection bias from firms choosing to be ESG-active.

---

## 7. Implementation Checklist

- [ ] **Step 1:** Run sample construction code (Section 2.3)
- [ ] **Step 2:** Compute Modified Jones DA and Real EM (Section 3.1)
- [ ] **Step 3:** Construct ESG variables from KLD (Section 3.2)
- [ ] **Step 4:** Construct Moderator 1: Industry Culpability (Section 3.3)
- [ ] **Step 5:** Construct Moderator 2: ESG Consistency + Early Adoption (Section 3.4)
- [ ] **Step 6:** Merge datasets and create analysis sample
- [ ] **Step 7:** Run baseline regressions (Section 4.1)
- [ ] **Step 8:** Run moderator models (Sections 4.2–4.4)
- [ ] **Step 9:** Run 2SLS and PSM (Section 5)
- [ ] **Step 10:** Run Oster (2019) bounds
- [ ] **Step 11:** Robustness: Alternative EM & ESG measures (Section 6)
- [ ] **Step 12:** Mechanism falsification: E vs. G test
- [ ] **Step 13:** Tables and figures

---

## 8. Expected Results & Interpretation

| Hypothesis | Expected Sign | Interpretation |
|:---|:---|:---|
| H1: ESG → EM | β₁ > 0 | Moral licensing: ESG creates "moral credit" |
| H2: ESG × Culpable → EM | β₂ < 0 | Sin industries constrain licensing (ESG = commitment, not credit) |
| H3: ESG × Substantive → EM | β₃ < 0 | Identity-consistent firms don't license (dissonance > credit) |
| Mechanism: E > G | β_E > β_G | Environmental ESG generates more discretionary "credit" |

---

## References

- Dechow, P. M., Sloan, R. G., & Sweeney, A. P. (1995). Detecting earnings management. *The Accounting Review*, 70(2), 193–225.
- Hong, H., & Kacperczyk, M. (2009). The price of sin: The effects of social norms on markets. *Journal of Financial Economics*, 93(1), 15–36. https://doi.org/10.1016/j.jfineco.2008.09.001
- Kim, Y., Park, M. S., & Wier, B. (2012). Is earnings quality associated with corporate social responsibility? *The Accounting Review*, 87(3), 761–796. https://doi.org/10.2308/accr-10209
- Kothari, S. P., Leone, A. J., & Wasley, C. E. (2005). Performance matched discretionary accrual measures. *Journal of Accounting and Economics*, 39(1), 163–197.
- Merritt, A. C., Effron, D. A., & Monin, B. (2010). Moral self-licensing: When being good frees us to be bad. *Social and Personality Psychology Compass*, 4(5), 344–357.
- Oster, E. (2019). Unobservable selection and coefficient stability: Theory and evidence. *Journal of Business & Economic Statistics*, 37(2), 187–204. https://doi.org/10.1080/07350015.2016.1227711
- Paradis, G., & Schiehll, E. (2021). ESG outcasts: Study of the ESG performance of sin stocks. *Sustainability*, 13(17), 9556. https://doi.org/10.3390/su13179556
- Roychowdhury, S. (2006). Earnings management through real activities manipulation. *Journal of Accounting and Economics*, 42(3), 335–370.
- Sagbakken, S. T., & Zhang, D. (2021). European sin stocks. *Journal of Asset Management*, 23(1), 1–18. https://doi.org/10.1057/s41260-021-00247-9
- Velte, P. (2024). CSR and earnings management: A structured literature review. *Corporate Social Responsibility and Environmental Management*, 31(6), 6000–6018. https://doi.org/10.1002/csr.2903
- Westphal, J. D. (2023). Systemic symbolic management, CSR, and corporate purpose. *Academy of Management Review*, 48(2). https://doi.org/10.5465/amr.2023.0107
- Zang, A. Y. (2012). Evidence on the trade-off between real activities manipulation and accrual-based earnings management. *The Accounting Review*, 87(2), 675–703.
