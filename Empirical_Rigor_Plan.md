# Empirical Rigor & UTD24 Methodology Plan

This document outlines the state-of-the-art econometric and identification strategies identified for aligning the "Moral Licensing in ESG and Earnings Management" study with UTD24 journal standards.

## 1. High-Standard Identification Strategies

| Methodology | Application in ESG-EM Research |
| :--- | :--- |
| **Two-Stage Least Squares (2SLS)** | Addresses endogeneity using industry-average or geographic-peer ESG scores as instruments. |
| **Staggered Difference-in-Differences (DiD)** | Leverages regulatory shocks (e.g., EU CSRD, ISSB) to compare treated vs. control firms. |
| **Oster (2019) Selection on Unobservables** | Tests the robustness of results against unobserved variables (e.g., managerial ethics). |
| **Propensity Score Matching (PSM)** | Creates comparable control groups based on financial characteristics (Size, ROA, Leverage). |
| **Textual Analysis (NLP)** | Categorizes ESG disclosures into "Progress" vs. "Commitment" framing. |

## 2. The "Moral Licensing" Identification Path

The core UTD24 requirement is the direct identification of the psychological mechanism.

### A. Framing Identification (NLP)
*   **Progress Dictionary:** "achieved," "attained," "completed," "milestone," "reached," "progress," "success."
*   **Commitment Dictionary:** "dedicated," "long-term," "priority," "values," "integral," "ongoing," "commitment," "mission."
*   **Test:** Interact `ESG Score` with `Progress-intensity`. Moral licensing (positive correlation with EM) should be strongest under *Progress Framing*.

### B. Moderated Mediation
*   **Logic:** `ESG` $\rightarrow$ `Moral Credit (Framing)` $\rightarrow$ `Earnings Management`.
*   **Moderator:** `Industry Culpability` (determines whether ESG is seen as a "commitment" or "progress").

## 3. Advanced Robustness Tests

1.  **Selection on Unobservables (Oster, 2019):** Prove that unobservables would need to be >1.0 times as important as observables to nullify the effect.
2.  **Alternative EM Proxies:** Test both **Accrual-based EM (AEM)** and **Real EM (REM)**.
3.  **Governance Boundary Conditions:** Test if high-quality governance (board independence, etc.) constraints the licensing effect.
4.  **Falsification (Placebo):** Run the model on "Social" (S) scores vs. "Environmental" (E) scores to validate the "substantive sacrifice" mechanism.

## 4. Implementation Checklist
- [ ] Refine "Progress/Commitment" word lists for NLP.
- [ ] Execute `psacalc` in Stata for Oster (2019) test.
- [ ] Identify a specific exogenous shock (e.g., California's SB 253/261 or EU NFRD) for DiD.
- [ ] Re-run models with Firm + Year + Industry-Year Fixed Effects.
