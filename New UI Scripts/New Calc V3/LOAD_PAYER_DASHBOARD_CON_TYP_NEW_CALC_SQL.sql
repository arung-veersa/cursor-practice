-- Load aggregated payer dashboard data using reusable views

-- Clear existing data
TRUNCATE TABLE CONFLICTREPORT_SANDBOX.PUBLIC.PAYER_DASHBOARD_CON_TYP_NEW_CALC_V2;

-- Insert aggregated data for all active/non-demo payers via view
INSERT INTO CONFLICTREPORT_SANDBOX.PUBLIC.PAYER_DASHBOARD_CON_TYP_NEW_CALC_V2 (
    PAYERID, CRDATEUNIQUE, CONTYPE, CONTYPEDESC, STATUSFLAG, COSTTYPE, VISITTYPE,
    CO_TO, CO_SP, CO_OP, CO_FP
)
SELECT 
    "PayerId" AS PAYERID,
    CAST("CRDATEUNIQUE" AS DATE) AS CRDATEUNIQUE,
    CONTYPE,
    CASE 
        WHEN CONTYPE = 'only_to' THEN 'Time Overlap Only'
        WHEN CONTYPE = 'only_td' THEN 'Time Distance Only'
        WHEN CONTYPE = 'only_is' THEN 'In Service Only'
        WHEN CONTYPE = 'both_to_td' THEN 'Time Overlap and Time Distance'
        WHEN CONTYPE = 'both_to_is' THEN 'Time Overlap and In Service'
        WHEN CONTYPE = 'both_td_is' THEN 'Time Distance and In Service'
        WHEN CONTYPE = 'all_to_td_is' THEN 'All Three (Time Overlap, Time Distance, and In Service)'
        ELSE NULL
    END AS CONTYPEDESC,
    "StatusFlag" AS STATUSFLAG,
    COSTTYPE,
    VISITTYPE,
    COUNT(*) AS CO_TO,
    SUM(FULL_SHIFT_AMOUNT) AS CO_SP,
    SUM(OVERLAP_AMOUNT) AS CO_OP,
    SUM(CASE WHEN "StatusFlag" IN ('R', 'D') THEN OVERLAP_AMOUNT ELSE 0 END) AS CO_FP
FROM CONFLICTREPORT_SANDBOX.PUBLIC.V_PAYER_CONFLICTS_AGGREGATED_COMMON
WHERE RN = 1
GROUP BY 
    PROCESSING_PAYERID,
    CAST("CRDATEUNIQUE" AS DATE),
    CONTYPE,
    "StatusFlag",
    COSTTYPE,
    VISITTYPE;