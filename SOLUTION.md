# Solution Steps

1. Implement v_plan_revenue as a SQL-only view in candidate_solution.sql (do not rely on v_plan_revenue_draft).

2. Define the month filter explicitly: invoices.billing_month = DATE '2025-03-01' and invoices.status = 'paid' (this excludes void and other months).

3. Compute gross revenue in a first CTE aggregated at plan grain: SUM(invoices.charged_amount) grouped by subscriptions.plan_id. This ensures each invoice’s charged_amount is counted exactly once.

4. Compute adjustments in a second CTE aggregated at the same plan grain: SUM(payment_adjustments.amount), joining payment_adjustments -> invoices (to apply month/status filters) -> subscriptions (to get plan_id). Do not join invoice_line_items.

5. Combine gross + adjustments in the final SELECT, coalescing NULL adjustments to 0, and ROUND to 2 decimals for stable reconciliation.

6. Optionally add supporting indexes (IF NOT EXISTS) on invoices(billing_month,status), invoices(subscription_id), and payment_adjustments(invoice_id) to keep the query fast at scale.

7. Run the provided tests/validation.sql to confirm: (1) one row per plan, (2) total net_revenue matches 412,900.00, (3) per-plan totals match expected values, and (4) the output is deterministic.

