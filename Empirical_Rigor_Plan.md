# Empirical Rigor & UTD24 Methodology Plan

This document outlines the state-of-the-art econometric and identification strategies identified for aligning the "Moral Licensing in ESG and Earnings Management" study with UTD24 journal standards (e.g., *Academy of Management Journal*, *Journal of Accounting and Economics*).

## 1. High-Standard Identification Strategies

| Methodology | Application in ESG-EM Research |
| :--- | :--- |
| **Two-Stage Least Squares (2SLS)** | Addresses endogeneity using industry-average ESG scores as excluded instruments (eliminating firm-level idiosyncratic error). |
| **Staggered Difference-in-Differences (DiD)** | Leverages regulatory shocks (e.g., EU NFRD, California SB 253) to establish causal direction. |
| **Oster (2019) Test** | Quantifies the potential impact of unobserved variables (e.g., managerial "hidden" ethics) on coefficient stability. |
| **Propensity Score Matching (PSM)** | Ensures treatment (High ESG) and control (Low ESG) groups are balanced on observable financial covariates. |

## 2. Theoretical Refinement: A Dual-Moderator Framework

To rigorously identify the "Moral Licensing" mechanism, we reconcile the contextual and dispositional boundaries of the effect.

### A. Moderator 1: Industry Culpability (Contextual Framing)
*   **Logic:** Determines the *socially constructed meaning* of ESG. 
    *   In **Non-Culpable Industries**, ESG is construed as **"Progress"** (discretionary moral credit $\rightarrow$ licensing).
    *   In **Culpable Industries**, ESG is construed as **"Commitment"** (necessary restorative effort $\rightarrow$ constraints licensing).

### B. Moderator 2: Moral Identity Centrality (Dispositional Authenticity)
*   **Construct:** Distinguishes between *Substantive* vs. *Symbolic* ESG engagement.
*   **Measurement (Early Adoption):** A dummy variable for firms that voluntarily adopted E/S policies or reporting **at least 3-5 years prior** to regional mandatory disclosure requirements.
*   **Theoretical Reconciliation:** While industry culpability sets the "external frame," **Early Adoption** reflects the firm's internal **Moral Path-Dependency**. 
    *   **Consistent Firms (Early Adopters):** ESG is central to their identity. The "Identity Dissonance" of committing EM outweighs any "Moral Licensing" benefit.
    *   **Reactive Firms (Late Adopters):** ESG is peripheral or strategic. They are more likely to view ESG as a "moral deposit" that justifies subsequent ethical lapses.

## 3. Advanced Robustness Tests

1.  **Oster (2019) Stability Analysis:** Ensuring the $\beta$ of ESG remains robust against selection on unobservables.
2.  **Alternative EM Proxies:** Moving beyond Jones-model residuals to **Real Earnings Management (REM)** (e.g., abnormal R&D cuts, overproduction).
3.  **Governance as a Boundary Condition:** Testing whether strong board monitoring (Dispositional Governance) attenuates the licensing effect.

## 4. Implementation Checklist
- [ ] **Construct Early Adoption Dummy:** Map firm-level ESG reporting start dates against jurisdictional regulatory timelines.
- [ ] **Instrument Validation:** Run Cragg-Donald Wald F-tests for the industry-average IV.
- [ ] **Mechanism Falsification:** Compare Environmental (high substantive sacrifice) vs. Governance (baseline compliance) effects.
- [ ] **Fixed Effects:** Ensure models include Firm + Year + Industry-Year Fixed Effects to capture time-varying industry shocks.
