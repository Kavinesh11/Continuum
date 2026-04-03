# Feature: continuum-ml-pipelines, Property 4: Actuarial Formula Lower Bound, Property 5: Zone Loss Ratio Escalation Monotonicity

"""
Property-based tests for the actuarial premium calculation.

Validates: Requirements 2.3, 2.4
"""

from decimal import Decimal

import pytest
from hypothesis import given, settings
from hypothesis import strategies as st

from services.risk_profiler.premium import compute_final_premium

# ---------------------------------------------------------------------------
# Shared strategies
# ---------------------------------------------------------------------------

# risk_score ∈ [0.0, 1.0]
risk_score_st = st.floats(min_value=0.0, max_value=1.0, allow_nan=False, allow_infinity=False)

# zone_loss_ratio ∈ [0.0, 2.0]
zone_loss_ratio_st = st.floats(min_value=0.0, max_value=2.0, allow_nan=False, allow_infinity=False)

# Monetary loads: non-negative Decimals up to 10 000 INR
def decimal_load_st():
    return st.floats(min_value=0.0, max_value=10_000.0, allow_nan=False, allow_infinity=False).map(
        lambda v: Decimal(str(round(v, 2)))
    )

# coverage_cap: positive Decimal up to 100 000 INR
coverage_cap_st = st.floats(min_value=1.0, max_value=100_000.0, allow_nan=False, allow_infinity=False).map(
    lambda v: Decimal(str(round(v, 2)))
)

# affordability_anchor: non-negative Decimal up to 10 000 INR
affordability_anchor_st = st.floats(min_value=0.0, max_value=10_000.0, allow_nan=False, allow_infinity=False).map(
    lambda v: Decimal(str(round(v, 2)))
)


# ---------------------------------------------------------------------------
# Property 4: Actuarial Formula Lower Bound
# Validates: Requirements 2.3
# ---------------------------------------------------------------------------

@settings(max_examples=100)
@given(
    risk_score=risk_score_st,
    zone_loss_ratio=zone_loss_ratio_st,
    coverage_cap=coverage_cap_st,
    affordability_anchor=affordability_anchor_st,
    expense_load=decimal_load_st(),
    fraud_load=decimal_load_st(),
    reinsurance_load=decimal_load_st(),
    risk_margin=decimal_load_st(),
)
def test_property4_final_premium_gte_affordability_anchor(
    risk_score,
    zone_loss_ratio,
    coverage_cap,
    affordability_anchor,
    expense_load,
    fraud_load,
    reinsurance_load,
    risk_margin,
):
    """**Validates: Requirements 2.3**

    Property 4: Actuarial Formula Lower Bound —
    FinalPremium >= AffordabilityAnchor for all valid inputs.
    """
    final_premium = compute_final_premium(
        risk_score=risk_score,
        zone_loss_ratio=zone_loss_ratio,
        coverage_cap=coverage_cap,
        affordability_anchor=affordability_anchor,
        expense_load=expense_load,
        fraud_load=fraud_load,
        reinsurance_load=reinsurance_load,
        risk_margin=risk_margin,
    )

    assert final_premium >= affordability_anchor, (
        f"FinalPremium {final_premium} < AffordabilityAnchor {affordability_anchor} "
        f"(risk_score={risk_score}, zone_loss_ratio={zone_loss_ratio})"
    )


# ---------------------------------------------------------------------------
# Property 5: Zone Loss Ratio Escalation Monotonicity
# Validates: Requirements 2.4
# ---------------------------------------------------------------------------

# zone_loss_ratio strictly above the 0.80 escalation threshold
above_threshold_st = st.floats(
    min_value=0.801, max_value=2.0, allow_nan=False, allow_infinity=False
)

# zone_loss_ratio at or below the 0.80 threshold
at_or_below_threshold_st = st.floats(
    min_value=0.0, max_value=0.80, allow_nan=False, allow_infinity=False
)

# risk_margin >= 2.0 ensures TechnicalPremium is large enough that the escalation
# difference (multiplier >= 1.0025) survives 2-decimal rounding.
# Minimum: 2.0 × 0.0025 = 0.005, which rounds to 0.01 — a visible difference.
positive_risk_margin_st = st.floats(
    min_value=2.0, max_value=10_000.0, allow_nan=False, allow_infinity=False
).map(lambda v: Decimal(str(round(v, 2))))


@settings(max_examples=100)
@given(
    risk_score=risk_score_st,
    coverage_cap=coverage_cap_st,
    expense_load=decimal_load_st(),
    fraud_load=decimal_load_st(),
    reinsurance_load=decimal_load_st(),
    risk_margin=positive_risk_margin_st,
    high_loss_ratio=above_threshold_st,
    low_loss_ratio=at_or_below_threshold_st,
)
def test_property5_escalated_premium_gt_non_escalated(
    risk_score,
    coverage_cap,
    expense_load,
    fraud_load,
    reinsurance_load,
    risk_margin,
    high_loss_ratio,
    low_loss_ratio,
):
    """**Validates: Requirements 2.4**

    Property 5: Zone Loss Ratio Escalation Monotonicity —
    A zone_loss_ratio above 0.80 must produce a strictly higher TechnicalPremium
    than zone_loss_ratio at or below 0.80 for the same inputs.

    We use affordability_anchor=0 so the floor never masks the escalation effect,
    and require risk_margin > 0 so TechnicalPremium is always positive (escalation
    of zero would trivially equal zero regardless of multiplier).
    """
    zero_anchor = Decimal("0")

    premium_escalated = compute_final_premium(
        risk_score=risk_score,
        zone_loss_ratio=high_loss_ratio,
        coverage_cap=coverage_cap,
        affordability_anchor=zero_anchor,
        expense_load=expense_load,
        fraud_load=fraud_load,
        reinsurance_load=reinsurance_load,
        risk_margin=risk_margin,
    )

    premium_non_escalated = compute_final_premium(
        risk_score=risk_score,
        zone_loss_ratio=low_loss_ratio,
        coverage_cap=coverage_cap,
        affordability_anchor=zero_anchor,
        expense_load=expense_load,
        fraud_load=fraud_load,
        reinsurance_load=reinsurance_load,
        risk_margin=risk_margin,
    )

    assert premium_escalated > premium_non_escalated, (
        f"Escalated premium {premium_escalated} should be strictly greater than "
        f"non-escalated {premium_non_escalated} "
        f"(risk_score={risk_score}, high_loss_ratio={high_loss_ratio}, low_loss_ratio={low_loss_ratio}, "
        f"risk_margin={risk_margin})"
    )
