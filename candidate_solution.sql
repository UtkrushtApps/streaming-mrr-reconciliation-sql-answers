-- =====================================================================
-- CANDIDATE SOLUTION FILE (SQL ONLY)
-- =====================================================================
-- Deliver a corrected, deterministic per-plan revenue report for the
-- reporting month 2025-03 that reconciles to the finance control total
-- of 412,900.00 and performs well at scale.
--
-- Graded object MUST be a view named v_plan_revenue with columns:
--   plan_id, plan_name, net_revenue (one row per plan for the month)
-- =====================================================================

/*
ASSUMPTIONS (explicit rules)
1) Recognized (reported) gross revenue for month 2025-03 is the sum of
   invoices.charged_amount for invoices where:
     - invoices.billing_month = DATE '2025-03-01'
     - invoices.status = 'paid'

2) Net revenue includes all recorded payment_adjustments.amount for those
   same paid invoices (including negative refunds / proration credits).
   - We do NOT filter by adjustment_type because the reconciliation/control
     total expects all adjustment rows to be netted.

3) Fan-out prevention / accounting correctness:
   - Each invoice's charged_amount must be counted exactly once.
   - Therefore we aggregate gross revenue at plan level from invoices first,
     and aggregate adjustments at plan level from payment_adjustments second,
     then combine the two aggregates.

4) Exclusions:
   - VOID invoices are excluded (status != 'paid').
   - Invoices from other billing months are excluded.

5) Determinism:
   - All operations are set-based aggregation over fixed filters.
     Numeric arithmetic is exact in Postgres; we additionally ROUND to 2
     decimals to stabilize presentation.
*/

-- Optional performance aids (safe to run repeatedly).
-- The view itself is set-based and avoids invoice_line_items join fan-out.
CREATE INDEX IF NOT EXISTS idx_invoices_billing_month_status
  ON invoices (billing_month, status);

CREATE INDEX IF NOT EXISTS idx_invoices_subscription_id
  ON invoices (subscription_id);

CREATE INDEX IF NOT EXISTS idx_payment_adjustments_invoice_id
  ON payment_adjustments (invoice_id);

-- Create the corrected deterministic per-plan reconciliation view.
CREATE OR REPLACE VIEW v_plan_revenue AS
WITH
  gross AS (
    SELECT
      s.plan_id,
      SUM(i.charged_amount) AS gross_amount
    FROM invoices i
    JOIN subscriptions s
      ON s.subscription_id = i.subscription_id
    WHERE i.billing_month = DATE '2025-03-01'
      AND i.status = 'paid'
    GROUP BY s.plan_id
  ),
  adj AS (
    SELECT
      s.plan_id,
      SUM(pa.amount) AS adjustments_amount
    FROM payment_adjustments pa
    JOIN invoices i
      ON i.invoice_id = pa.invoice_id
    JOIN subscriptions s
      ON s.subscription_id = i.subscription_id
    WHERE i.billing_month = DATE '2025-03-01'
      AND i.status = 'paid'
    GROUP BY s.plan_id
  )
SELECT
  p.plan_id,
  p.plan_name,
  ROUND(g.gross_amount + COALESCE(a.adjustments_amount, 0), 2) AS net_revenue
FROM gross g
JOIN plans p
  ON p.plan_id = g.plan_id
LEFT JOIN adj a
  ON a.plan_id = g.plan_id;
