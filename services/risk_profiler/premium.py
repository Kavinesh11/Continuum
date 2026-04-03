"""
Actuarial premium calculation for Continuum ML Pipelines.

Implements the final premium formula with zone loss ratio escalation.
"""

from decimal import Decimal, ROUND_HALF_UP

# Module-level constants
ESCALATION_THRESHOLD = Decimal("0.80")
ESCALATION_SLOPE = Decimal("2.5")


def compute_final_premium(
    risk_score: float,
    zone_loss_ratio: float,
    coverage_cap: Decimal,
    affordability_anchor: Decimal,
    expense_load: Decimal,
    fraud_load: Decimal,
    reinsurance_load: Decimal,
    risk_margin: Decimal,
) -> Decimal:
    """Compute the final weekly premium for a worker.

    Applies the actuarial formula:
        ExpectedLoss      = risk_score × coverage_cap × zone_loss_ratio
        TechnicalPremium  = ExpectedLoss + expense_load + fraud_load
                            + reinsurance_load + risk_margin
        If zone_loss_ratio > ESCALATION_THRESHOLD:
            EscalationMultiplier = 1 + (zone_loss_ratio - 0.80) × 2.5
            TechnicalPremium    *= EscalationMultiplier
        FinalPremium = max(affordability_anchor, TechnicalPremium)

    Args:
        risk_score:          Worker risk score in [0.0, 1.0].
        zone_loss_ratio:     4-week rolling loss ratio for the zone (e.g. 0.85 = 85%).
        coverage_cap:        Maximum insured amount in INR.
        affordability_anchor: Minimum floor premium in INR.
        expense_load:        Fixed expense load in INR.
        fraud_load:          Fixed fraud load in INR.
        reinsurance_load:    Fixed reinsurance load in INR.
        risk_margin:         Fixed risk margin in INR.

    Returns:
        FinalPremium rounded to 2 decimal places (ROUND_HALF_UP).
    """
    rs = Decimal(str(risk_score))
    zlr = Decimal(str(zone_loss_ratio))

    expected_loss = rs * coverage_cap * zlr

    technical_premium = (
        expected_loss
        + expense_load
        + fraud_load
        + reinsurance_load
        + risk_margin
    )

    if zlr > ESCALATION_THRESHOLD:
        escalation_multiplier = Decimal("1") + (zlr - ESCALATION_THRESHOLD) * ESCALATION_SLOPE
        technical_premium *= escalation_multiplier

    final_premium = max(affordability_anchor, technical_premium)

    return final_premium.quantize(Decimal("0.01"), rounding=ROUND_HALF_UP)
