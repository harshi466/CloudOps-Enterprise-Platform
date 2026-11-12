"""Simple linear-trend forecast used when the serverless predictor is not configured."""


def forecast_next(monthly_totals):
    n = len(monthly_totals)
    if n == 0:
        return 0.0
    if n == 1:
        return round(float(monthly_totals[0]), 2)
    mx, my = (n - 1) / 2, sum(monthly_totals) / n
    denom = sum((x - mx) ** 2 for x in range(n))
    slope = sum((x - mx) * (y - my) for x, y in zip(range(n), monthly_totals)) / denom
    return round(max(0.0, my + slope * (n - mx)), 2)
