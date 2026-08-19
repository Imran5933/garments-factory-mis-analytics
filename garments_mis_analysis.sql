SELECT * FROM "06_production_data" p LIMIT 10;

-- 1. Total Production Quantity by Factory and Line
CREATE OR REPLACE VIEW v_prod_qty_by_factory_line AS
SELECT P."Factory_ID", P."Line_ID", SUM(P."Actual_Qty") AS total_production_qty
FROM "06_production_data" P
GROUP BY P."Factory_ID", P."Line_ID"
ORDER BY total_production_qty DESC;

-- 2. Total Production Quantity by Factory, Line, and Date
CREATE OR REPLACE VIEW v_prod_qty_by_date AS
SELECT P."Production_Date", p."Factory_ID", P."Line_ID", SUM(P."Actual_Qty") AS total_production_qty
FROM "06_production_data" P
GROUP BY P."Production_Date", P."Factory_ID", P."Line_ID"
ORDER BY P."Production_Date";

-- 3. Production Lines Achieving Their Targets
CREATE OR REPLACE VIEW v_lines_achieving_targets AS
SELECT P."Factory_ID", P."Line_ID",
SUM(P."Target_Qty") AS total_target_qty,
SUM(P."Actual_Qty") AS total_actual_qty
FROM "06_production_data" P
GROUP BY P."Factory_ID", P."Line_ID"
HAVING SUM(p."Actual_Qty") >= SUM(p."Target_Qty")
ORDER BY total_actual_qty DESC;

-- 4. Production Achievement Percentage
CREATE OR REPLACE VIEW v_prod_achievement_percentage AS
SELECT p."Factory_ID", p."Line_ID",
SUM(p."Target_Qty") AS total_target_qty,
SUM(p."Actual_Qty") AS total_actual_qty,
ROUND(SUM(p."Actual_Qty") * 100.0 / NULLIF(SUM(p."Target_Qty"), 0), 2) AS achievement_percentage
FROM "06_production_data" p
GROUP BY p."Factory_ID", p."Line_ID"
ORDER BY achievement_percentage DESC;

-- 5. Underperforming Lines
CREATE OR REPLACE VIEW v_underperforming_lines AS
SELECT p."Factory_ID", p."Line_ID",
COUNT(*) AS total_days,
SUM(p."Target_Qty") AS total_target_qty,
SUM(p."Actual_Qty") AS total_actual_qty,
ROUND(SUM(p."Actual_Qty") * 100.0 / NULLIF(SUM(p."Target_Qty"), 0), 2) AS achievement_percentage
FROM "06_production_data" p
GROUP BY p."Factory_ID", p."Line_ID"
HAVING COUNT(*) FILTER (WHERE p."Actual_Qty" < p."Target_Qty") = COUNT(*)
ORDER BY achievement_percentage;

-- 6. Production Volume by Product/Style
CREATE OR REPLACE VIEW v_prod_volume_by_style AS
SELECT p."Style_ID",
SUM(p."Actual_Qty") AS total_production_qty
FROM "06_production_data" p
GROUP BY p."Style_ID"
ORDER BY total_production_qty DESC;

-- 7. Actual vs Planned Production Variance
CREATE OR REPLACE VIEW v_prod_actual_vs_plan_variance AS
SELECT p."Factory_ID", p."Line_ID",
SUM(p."Plan_Qty") AS planned_production_qty,
SUM(p."Actual_Qty") AS actual_production_qty,
SUM(p."Actual_Qty") - SUM(p."Plan_Qty") AS production_variance
FROM "06_production_data" p
GROUP BY p."Factory_ID", p."Line_ID"
ORDER BY production_variance DESC;

-- Where are the major productivity bottlenecks?
CREATE OR REPLACE VIEW v_productivity_bottlenecks AS
SELECT p."Factory_ID",p."Line_ID",
SUM(p."Plan_Qty") AS planned_qty,
SUM(p."Actual_Qty") AS actual_qty,
SUM(p."Plan_Qty") - SUM(p."Actual_Qty") AS production_shortfall
FROM "06_production_data" p
GROUP BY p."Factory_ID",p."Line_ID"
ORDER BY production_shortfall DESC;

-------------------------------------
SELECT * FROM "08_quality_data" q LIMIT 10;

--What is theoverall defect rate?
SELECT SUM("Defect_Qty") AS total_defect_qty,
SUM("Inspection_Qty") AS total_inspection_qty,
ROUND((SUM("Defect_Qty") * 100.0) / NULLIF(SUM("Inspection_Qty"), 0), 2) AS overall_defect_rate_pct
FROM "08_quality_data";

--l Which lines products have the highest defect rates?
CREATE OR REPLACE VIEW v_line_style_defect_rates AS
SELECT q."Line_ID",
SUM(q."Defect_Qty") AS total_defect_qty,
SUM(q."Inspection_Qty") AS total_inspection_qty,
ROUND((SUM(q."Defect_Qty") * 100.0) / NULLIF(SUM(q."Inspection_Qty"), 0), 2) AS defect_rate_pct
FROM "08_quality_data" q
GROUP BY q."Line_ID"
ORDER BY defect_rate_pct DESC;

--What are the most common defect types?
SELECT q."Defect_Type",
SUM(q."Defect_Qty") AS total_defect_qty,
COUNT(*) AS total_occurrences
FROM "08_quality_data" q
GROUP BY q."Defect_Type"
ORDER BY total_defect_qty DESC;

--Which production lines repeatedly generate quality problems?
CREATE OR REPLACE VIEW v_repeated_quality_problems AS
SELECT q."Line_ID",
COUNT(*) AS total_inspections,
SUM(q."Defect_Qty") AS total_defect_qty,
SUM(q."Inspection_Qty") AS total_inspection_qty,
ROUND((SUM(q."Defect_Qty") * 100.0) / NULLIF(SUM(q."Inspection_Qty"), 0), 2) AS defect_rate_pct
FROM "08_quality_data" q
GROUP BY q."Line_ID"
HAVING (SUM(q."Defect_Qty") * 100.0) / NULLIF(SUM(q."Inspection_Qty"), 0) > 5.0 -- ৫% এর বেশি ডিফেক্ট রেট থাকা লাইন
ORDER BY defect_rate_pct DESC;

--What percentage of production is rejected?
SELECT SUM(q."Defect_Qty") AS total_rejected_qty,
SUM(q."Inspection_Qty") AS total_inspection_qty,
ROUND((SUM(q."Defect_Qty") * 100.0) / NULLIF(SUM(q."Inspection_Qty"), 0), 2) AS rejected_percentage
FROM "08_quality_data" q;

--Is there a relationship between production volume and quality issues?
SELECT q."Line_ID",
SUM(q."Inspection_Qty") AS total_volume,
SUM(q."Defect_Qty") AS total_defects,
SUM(q."Reject_Qty") AS total_rejects,
ROUND((SUM(q."Defect_Qty") * 100.0) / NULLIF(SUM(q."Inspection_Qty"), 0), 2) AS defect_rate_pct
FROM "08_quality_data" q
GROUP BY q."Line_ID"
ORDER BY total_volume DESC;

------------------------------------------
SELECT * FROM "05_order_master" o LIMIT 10;

--How many orders are currently open?
SELECT "Order_Status",
COUNT(*) AS total_orders
FROM "05_order_master"
GROUP BY "Order_Status";

--What is the order quantity versus produced quantity?
SELECT o."Order_ID",o."Style_ID",o."Order_Qty",
COALESCE(SUM(p."Actual_Qty"), 0) AS total_produced_qty,(COALESCE(SUM(p."Actual_Qty"), 0) - o."Order_Qty") AS variance_qty
FROM "05_order_master" o
LEFT JOIN "06_production_data" p 
ON o."Order_ID" = p."Order_ID"
GROUP BY o."Order_ID", o."Style_ID", o."Order_Qty"
ORDER BY o."Order_ID";

--Which orders are at risk of delay?
CREATE OR REPLACE VIEW v_orders_at_risk_of_delay AS
SELECT 
o."Order_ID",
o."Style_ID",
o."Order_Qty",
COALESCE(SUM(p."Actual_Qty"), 0) AS total_produced_qty,(o."Order_Qty" - COALESCE(SUM(p."Actual_Qty"), 0)) AS remaining_qty,
o."Shipment_Date",
o."Order_Status"
FROM "05_order_master" o
LEFT JOIN "06_production_data" p 
ON o."Order_ID" = p."Order_ID"
GROUP BY 
o."Order_ID", 
o."Style_ID", 
o."Order_Qty", 
o."Shipment_Date", 
o."Order_Status"
HAVING o."Order_Status" = 'Delayed'
OR (o."Order_Status" IN ('In Production', 'Partially Shipped')
AND COALESCE(SUM(p."Actual_Qty"), 0) < o."Order_Qty");

--What is the order completion percentage?
SELECT 
o."Order_ID",
o."Style_ID",
o."Order_Qty",
COALESCE(SUM(p."Actual_Qty"), 0) AS total_produced_qty,
ROUND((COALESCE(SUM(p."Actual_Qty"), 0) * 100.0) / NULLIF(o."Order_Qty", 0), 2) AS completion_percentage
FROM "05_order_master" o
LEFT JOIN "06_production_data" p 
ON o."Order_ID" = p."Order_ID"
GROUP BY o."Order_ID", o."Style_ID", o."Order_Qty"
ORDER BY completion_percentage DESC;
-----------------------------------------------------
SELECT * FROM "09_inventory_item_master" i LIMIT 10;
SELECT * FROM "10_inventory_transaction" it LIMIT 10;

--What is the current inventory quantity and value?
SELECT i."Item_ID",i."Item_Name",
SUM(t."Quantity") AS current_stock_qty,
ROUND(SUM(t."Quantity" * t."Unit_Cost_USD")::numeric, 2) AS total_stock_value
FROM "09_inventory_item_master" i
JOIN "10_inventory_transaction" t ON i."Item_ID" = t."Item_ID"
WHERE t."Transaction_Status" = 'Posted'
GROUP BY i."Item_ID", i."Item_Name";

--Which materials are overstocked?
SELECT i."Item_ID",i."Item_Name",i."Maximum_Stock",
SUM(t."Quantity") AS current_stock_qty
FROM "09_inventory_item_master" i
JOIN "10_inventory_transaction" t ON i."Item_ID" = t."Item_ID"
WHERE t."Transaction_Status" = 'Posted'
GROUP BY i."Item_ID", i."Item_Name", i."Maximum_Stock"
HAVING SUM(t."Quantity") > i."Maximum_Stock";

--Which materials are below required levels?
SELECT i."Item_ID",i."Item_Name",i."Minimum_Stock",
SUM(t."Quantity") AS current_stock_qty
FROM "09_inventory_item_master" i
JOIN "10_inventory_transaction" t ON i."Item_ID" = t."Item_ID"
WHERE t."Transaction_Status" = 'Posted'
GROUP BY i."Item_ID", i."Item_Name", i."Minimum_Stock"
HAVING SUM(t."Quantity") < i."Minimum_Stock";

--Which materials have high consumption rates?
SELECT i."Item_ID",i."Item_Name",
ABS(SUM(t."Quantity")) AS total_consumed_qty
FROM "09_inventory_item_master" i
JOIN "10_inventory_transaction" t ON i."Item_ID" = t."Item_ID"
WHERE t."Transaction_Status" = 'Posted'
AND t."Transaction_Type" = 'Issue'
GROUP BY i."Item_ID", i."Item_Name"
ORDER BY total_consumed_qty DESC;

--Are there slow-moving or obsolete inventory items?
SELECT i."Item_ID",i."Item_Name",
MAX(t."Transaction_Date") AS last_transaction_date
FROM "09_inventory_item_master" i
LEFT JOIN "10_inventory_transaction" t ON i."Item_ID" = t."Item_ID"
GROUP BY i."Item_ID", i."Item_Name"
HAVING MAX(t."Transaction_Date") < CURRENT_DATE - INTERVAL '90 days'
OR MAX(t."Transaction_Date") IS NULL;

--Which materials require urgent purchasing?
SELECT i."Item_ID",i."Item_Name",."Minimum_Stock",
COALESCE(SUM(t."Quantity"), 0) AS current_stock_qty,
(i."Minimum_Stock" - COALESCE(SUM(t."Quantity"), 0)) AS required_reorder_qty,
i."Supplier_ID"
FROM "09_inventory_item_master" i
LEFT JOIN "10_inventory_transaction" t 
ON i."Item_ID" = t."Item_ID" AND t."Transaction_Status" = 'Posted'
WHERE i."Active_Status" = 'Active'
GROUP BY i."Item_ID", i."Item_Name", i."Minimum_Stock", i."Supplier_ID"
HAVING COALESCE(SUM(t."Quantity"), 0) <= i."Minimum_Stock"
ORDER BY current_stock_qty ASC;

---------------------------
SELECT * FROM "15_supplier_master" s LIMIT 10;
---------------------------
SELECT * FROM "16_purchase_data" pu LIMIT 10;

--Which suppliers provide the highest purchase volume?
SELECT s."Supplier_ID",s."Supplier_Name",
SUM(pu."Order_Qty") AS total_order_qty,
ROUND(SUM(pu."Order_Qty" * pu."Unit_Cost_USD")::numeric, 2) AS total_purchase_value_usd
FROM "15_supplier_master" s
JOIN "16_purchase_data" pu ON s."Supplier_ID" = pu."Supplier_ID"
GROUP BY s."Supplier_ID", s."Supplier_Name"
ORDER BY total_purchase_value_usd DESC;

--What is the purchase quantity versus received quantity?
SELECT 
pu."PO_Number",
s."Supplier_Name",
pu."Order_Qty",
pu."Received_Qty",(pu."Order_Qty" - pu."Received_Qty") AS pending_qty
FROM "16_purchase_data" pu
JOIN "15_supplier_master" s ON pu."Supplier_ID" = s."Supplier_ID"
ORDER BY pu."PO_Number";

--Which suppliers have delayed deliveries?
SELECT s."Supplier_ID",s."Supplier_Name",
COUNT(pu."Purchase_ID") AS total_delayed_orders
FROM "16_purchase_data" pu
JOIN "15_supplier_master" s ON pu."Supplier_ID" = s."Supplier_ID"
WHERE pu."Purchase_Status" LIKE '%Late%' 
OR pu."Received_Date" > pu."Expected_Date"
GROUP BY s."Supplier_ID", s."Supplier_Name"
ORDER BY total_delayed_orders DESC;

--Which suppliers have the highest rejection/quality issues?
SELECT 
s."Supplier_ID",
s."Supplier_Name",
SUM(pu."Order_Qty") AS total_ordered_qty,
SUM(pu."Received_Qty") AS total_received_qty,
SUM(pu."Order_Qty" - pu."Received_Qty") AS total_short_or_rejected_qty,
    ROUND(((SUM(pu."Order_Qty" - pu."Received_Qty")) * 100.0) / NULLIF(SUM(pu."Order_Qty"), 0), 2) AS defect_or_shortage_rate_pct
FROM "16_purchase_data" pu
JOIN "15_supplier_master" s ON pu."Supplier_ID" = s."Supplier_ID"
GROUP BY s."Supplier_ID", s."Supplier_Name"
HAVING SUM(pu."Order_Qty" - pu."Received_Qty") > 0
ORDER BY defect_or_shortage_rate_pct DESC;

--What is the supplier fulfillment rate?
SELECT 
s."Supplier_ID",
s."Supplier_Name",
COUNT(pu."Purchase_ID") AS total_orders,
ROUND((SUM(pu."Received_Qty") * 100.0) / NULLIF(SUM(pu."Order_Qty"), 0), 2) AS fulfillment_rate_pct
FROM "16_purchase_data" pu
JOIN "15_supplier_master" s ON pu."Supplier_ID" = s."Supplier_ID"
GROUP BY s."Supplier_ID", s."Supplier_Name"
ORDER BY fulfillment_rate_pct DESC;

--Which suppliers should management monitor closely?
SELECT 
s."Supplier_ID",
s."Supplier_Name",
s."Supplier_Status",
s."Lead_Time_Days",
ROUND((SUM(pu."Received_Qty") * 100.0) / NULLIF(SUM(pu."Order_Qty"), 0), 2) AS fulfillment_rate_pct,
COUNT(CASE WHEN pu."Purchase_Status" LIKE '%Late%' OR pu."Received_Date" > pu."Expected_Date" THEN 1 END) AS delayed_orders_count
FROM "15_supplier_master" s
JOIN "16_purchase_data" pu ON s."Supplier_ID" = pu."Supplier_ID"
GROUP BY s."Supplier_ID", s."Supplier_Name", s."Supplier_Status", s."Lead_Time_Days"
HAVING 
ROUND((SUM(pu."Received_Qty") * 100.0) / NULLIF(SUM(pu."Order_Qty"), 0), 2) < 95.0
OR COUNT(CASE WHEN pu."Purchase_Status" LIKE '%Late%' OR pu."Received_Date" > pu."Expected_Date" THEN 1 END) > 0
ORDER BY delayed_orders_count DESC, fulfillment_rate_pct ASC;

---------------------------
SELECT * FROM "12_employee_master" e LIMIT 10;
--------------------------
SELECT * FROM "01_factory_master" f LIMIT 10;
---------------------------
SELECT * FROM "13_attendance_data" a LIMIT 10;
--What is the total headcount?
SELECT 
    COUNT(e."Employee_ID") AS total_headcount
FROM "12_employee_master" e;

--What percentage of employees are active, resigned, or terminated?
SELECT 
    e."Employment_Status",
    COUNT(e."Employee_ID") AS total_employees,
  ROUND((COUNT(e."Employee_ID") * 100.0) / SUM(COUNT(e."Employee_ID")) OVER (), 2) AS percentage
FROM "12_employee_master" e
GROUP BY e."Employment_Status"
ORDER BY total_employees DESC;

--Which departments have the highest headcount?
SELECT e."Department",COUNT(e."Employee_ID") AS headcount
FROM "12_employee_master" e
WHERE e."Employment_Status" = 'Active'
GROUP BY e."Department"
ORDER BY headcount DESC;


--Which factories have workforce shortages?
SELECT f."Factory_Name",
f."Production_Line_Count",
COUNT(e."Employee_ID") AS current_active_headcount,
ROUND(COUNT(e."Employee_ID") * 1.0 / f."Production_Line_Count", 2) AS avg_workers_per_line,
((f."Production_Line_Count" * 50) - COUNT(e."Employee_ID")) AS workforce_shortage
FROM "01_factory_master" f
LEFT JOIN "12_employee_master" e 
    ON f."Factory_ID" = e."Factory_ID" AND e."Employment_Status" = 'Active'
GROUP BY f."Factory_ID", f."Factory_Name", f."Production_Line_Count"
ORDER BY workforce_shortage DESC;

--Which factory is performing better overall?
SELECT p."Factory_ID",
ROUND((SUM(p."Actual_Qty") * 100.0) / NULLIF(SUM(p."Target_Qty"), 0), 2) AS target_achievement_pct,
ROUND((SUM(p."Reject_Qty") * 100.0) / NULLIF(SUM(p."Actual_Qty"), 0), 2) AS defect_rate_pct,
ROUND((SUM(p."Alter_Qty") * 100.0) / NULLIF(SUM(p."Actual_Qty"), 0), 2) AS alter_rate_pct
FROM "06_production_data" p
GROUP BY p."Factory_ID"
ORDER BY target_achievement_pct DESC, defect_rate_pct ASC;

--Which production lines are consistently underperforming?
SELECT 
ROUND((SUM(p."Actual_Qty") * 100.0) / NULLIF(SUM(p."Target_Qty"), 0), 2) AS achievement_pct
FROM "06_production_data" p
GROUP BY p."Factory_ID", p."Line_ID"
HAVING ((SUM(p."Actual_Qty") * 100.0) / NULLIF(SUM(p."Target_Qty"), 0)) < 85.0
ORDER BY achievement_pct ASC;

--Which factory has the highest efficiency?
SELECT 
ROUND((SUM(p."Actual_Qty") * 100.0) / NULLIF(SUM(p."Target_Qty"), 0), 2) AS efficiency_pct
FROM "06_production_data" p
GROUP BY p."Factory_ID"
ORDER BY efficiency_pct DESC
LIMIT 1;

--Which factory has the highest defect rate?
SELECT p."Factory_ID",
SUM(p."Actual_Qty") AS total_produced,
SUM(p."Reject_Qty") AS total_rejected,
ROUND((SUM(p."Reject_Qty") * 100.0) / NULLIF(SUM(p."Actual_Qty"), 0), 2) AS defect_rate_pct
FROM "06_production_data" p
GROUP BY p."Factory_ID"
ORDER BY defect_rate_pct DESC
LIMIT 1;

--Which factory has the best production target achievement?
SELECT 
p."Factory_ID",
SUM(p."Target_Qty") AS total_target,
SUM(p."Actual_Qty") AS total_actual,
ROUND((SUM(p."Actual_Qty") * 100.0) / NULLIF(SUM(p."Target_Qty"), 0), 2) AS target_achievement_pct
FROM "06_production_data" p
GROUP BY p."Factory_ID"
ORDER BY target_achievement_pct DESC
LIMIT 1;

--What are the major operational differences between factories?
SELECT 
p."Factory_ID",
SUM(p."Actual_Qty") AS total_produced_qty,
ROUND(AVG(p."Manpower")::numeric, 0) AS avg_manpower_per_run,
ROUND(AVG(p."Working_Hours")::numeric, 1) AS avg_working_hours,
ROUND(SUM(p."Overtime_Hours")::numeric, 1) AS total_overtime_hours,
ROUND((SUM(p."Reject_Qty") * 100.0) / NULLIF(SUM(p."Actual_Qty"), 0), 2) AS defect_rate_pct,
ROUND((SUM(p."Alter_Qty") * 100.0) / NULLIF(SUM(p."Actual_Qty"), 0), 2) AS alter_rate_pct
FROM "06_production_data" p
GROUP BY p."Factory_ID"
ORDER BY p."Factory_ID";

