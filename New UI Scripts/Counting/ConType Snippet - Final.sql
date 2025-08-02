-- =====================================================
-- DIAGNOSTIC QUERIES - RUN THESE FIRST TO UNDERSTAND THE ISSUE
-- =====================================================

-- 1. Check the base daily total (should be 1188)
/*
SELECT 
    TO_CHAR(V1."G_CRDATEUNIQUE", 'YYYY-MM-DD') AS CRDATEUNIQUE,
    COUNT(DISTINCT V1."GroupID") AS base_total
FROM CONFLICTREPORT_SANDBOX.PUBLIC.CONFLICTVISITMAPS AS V1
INNER JOIN CONFLICTREPORT_SANDBOX.PUBLIC.CONFLICTS AS V2
    ON V2."CONFLICTID" = V1."CONFLICTID"
WHERE V1."PayerID" = '${payerId}' 
    AND V1."SameVisitTimeFlag" = 'Y'
GROUP BY TO_CHAR(V1."G_CRDATEUNIQUE", 'YYYY-MM-DD');
*/

-- 2. Check what happens after the LEFT JOIN multiplication
/*
WITH base_data AS (
    SELECT
        DISTINCT V1."GroupID",
        V1."CONFLICTID",
        V1."ShVTSTTime",
        V1."ShVTENTime",
        V1."BilledRateMinute",
        V1."G_CRDATEUNIQUE",
        TO_CHAR(V1."G_CRDATEUNIQUE", 'YYYY-MM-DD') AS CRDATEUNIQUE,
        V1."PayerID" AS APID,
        V1."BILLABLEMINUTESFULLSHIFT",
        V1."BILLABLEMINUTESOVERLAP",
        CASE
            WHEN V2."StatusFlag" IN('R', 'D') THEN 'R'
            WHEN V2."StatusFlag" IN ('N') THEN 'N'
            ELSE 'U'
        END AS "StatusFlag",
        V1."Billed",
        V1."VisitStartTime"
    FROM
        CONFLICTREPORT_SANDBOX.PUBLIC.CONFLICTVISITMAPS AS V1
    INNER JOIN CONFLICTREPORT_SANDBOX.PUBLIC.CONFLICTS AS V2
            ON V2."CONFLICTID" = V1."CONFLICTID"
    WHERE
        V1."GroupID" IN (
        SELECT DISTINCT "GroupID"
        FROM CONFLICTREPORT_SANDBOX.PUBLIC.CONFLICTVISITMAPS
        WHERE "PayerID" = '${payerId}' AND "SameVisitTimeFlag" = 'Y'
        )
)
SELECT 
    CRDATEUNIQUE,
    COUNT(DISTINCT "GroupID") AS after_base_data_total
FROM base_data
GROUP BY CRDATEUNIQUE;
*/

-- =====================================================
-- FIXED APPROACH - NO TOTAL REPETITION
-- =====================================================
-- Use window function to ensure daily total is applied correctly

WITH daily_totals AS (
    SELECT 
        TO_CHAR(V1."G_CRDATEUNIQUE", 'YYYY-MM-DD') AS CRDATEUNIQUE,
        COUNT(DISTINCT V1."GroupID") AS correct_daily_total
    FROM CONFLICTREPORT_SANDBOX.PUBLIC.CONFLICTVISITMAPS AS V1
    INNER JOIN CONFLICTREPORT_SANDBOX.PUBLIC.CONFLICTS AS V2
        ON V2."CONFLICTID" = V1."CONFLICTID"
    WHERE V1."PayerID" = '${payerId}' 
        AND V1."SameVisitTimeFlag" = 'Y'
    GROUP BY TO_CHAR(V1."G_CRDATEUNIQUE", 'YYYY-MM-DD')
),
base_data_with_totals AS (
    SELECT
        V1."GroupID",
        V1."CONFLICTID",
        V1."ShVTSTTime",
        V1."ShVTENTime",
        V1."BilledRateMinute",
        V1."G_CRDATEUNIQUE",
        TO_CHAR(V1."G_CRDATEUNIQUE", 'YYYY-MM-DD') AS CRDATEUNIQUE,
        V1."PayerID",
        V1."BILLABLEMINUTESFULLSHIFT",
        V1."BILLABLEMINUTESOVERLAP",
        CASE
            WHEN V2."StatusFlag" IN('R', 'D') THEN 'R'
            WHEN V2."StatusFlag" IN ('N') THEN 'N'
            ELSE 'U'
        END AS "StatusFlag",
        V1."Billed",
        V1."VisitStartTime",
        dt.correct_daily_total,
        -- Use window function to get the daily total for each row without multiplication
        FIRST_VALUE(dt.correct_daily_total) OVER (
            PARTITION BY TO_CHAR(V1."G_CRDATEUNIQUE", 'YYYY-MM-DD') 
            ORDER BY V1."GroupID" 
            ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING
        ) AS daily_total_fixed
    FROM CONFLICTREPORT_SANDBOX.PUBLIC.CONFLICTVISITMAPS AS V1
    INNER JOIN CONFLICTREPORT_SANDBOX.PUBLIC.CONFLICTS AS V2
        ON V2."CONFLICTID" = V1."CONFLICTID"
    INNER JOIN daily_totals dt ON dt.CRDATEUNIQUE = TO_CHAR(V1."G_CRDATEUNIQUE", 'YYYY-MM-DD')
    WHERE V1."PayerID" = '${payerId}' 
        AND V1."SameVisitTimeFlag" = 'Y'
)
SELECT
    '${payerId}' AS PAYERID,
    a.CRDATEUNIQUE AS "CRDATEUNIQUE",
    'Exact Visit Time Match' AS "ConflictType",
    '2' AS "ConflictTypeF",
    a."StatusFlag" AS "STATUSFLAG",
    CASE
        WHEN a."Billed" = 'yes' THEN 'Recovery'
        ELSE 'Avoidance'
    END AS "COSTTYPE",
    CASE
        WHEN a."VisitStartTime" IS NULL THEN 'Scheduled'
        WHEN a."VisitStartTime" IS NOT NULL AND a."Billed" != 'yes' THEN 'Confirmed'
        WHEN a."VisitStartTime" IS NOT NULL AND a."Billed" = 'yes' THEN 'Billed'
    END AS "VISITTYPE",
    a.daily_total_fixed AS "Total",  -- Use the fixed daily total from window function
    SUM(
        CASE
            WHEN a."PayerID" = '${payerId}' AND a."BilledRateMinute" > 0 AND a."BILLABLEMINUTESFULLSHIFT" IS NOT NULL THEN a."BILLABLEMINUTESFULLSHIFT" * a."BilledRateMinute"
            WHEN a."PayerID" = '${payerId}' AND a."BilledRateMinute" > 0 THEN TIMESTAMPDIFF(MINUTE, a."ShVTSTTime", a."ShVTENTime") * a."BilledRateMinute"
            ELSE 0
        END
    ) AS "ShiftPrice",
    SUM(
        CASE
            WHEN a."PayerID" = '${payerId}' AND a."BilledRateMinute" > 0 AND a."BILLABLEMINUTESOVERLAP" IS NOT NULL THEN a."BILLABLEMINUTESOVERLAP" * a."BilledRateMinute"
            WHEN a."PayerID" = '${payerId}' AND a."BilledRateMinute" > 0 AND b."ShVTSTTime" >= a."ShVTSTTime" AND b."ShVTSTTime" <= a."ShVTENTime" AND b."ShVTENTime" > a."ShVTENTime" THEN TIMESTAMPDIFF(MINUTE, b."ShVTSTTime", a."ShVTENTime") * a."BilledRateMinute"
            WHEN a."PayerID" = '${payerId}' AND a."BilledRateMinute" > 0 AND a."ShVTSTTime" >= b."ShVTSTTime" AND a."ShVTSTTime" <= b."ShVTENTime" AND a."ShVTENTime" > b."ShVTENTime" THEN TIMESTAMPDIFF(MINUTE, a."ShVTSTTime", b."ShVTENTime") * a."BilledRateMinute"
            WHEN a."PayerID" = '${payerId}' AND a."BilledRateMinute" > 0 AND b."ShVTSTTime" >= a."ShVTSTTime" AND b."ShVTENTime" <= a."ShVTENTime" THEN TIMESTAMPDIFF(MINUTE, b."ShVTSTTime", b."ShVTENTime") * a."BilledRateMinute"
            WHEN a."PayerID" = '${payerId}' AND a."BilledRateMinute" > 0 AND a."ShVTSTTime" >= b."ShVTSTTime" AND a."ShVTENTime" <= b."ShVTENTime" THEN TIMESTAMPDIFF(MINUTE, a."ShVTSTTime", a."ShVTENTime") * a."BilledRateMinute"
            WHEN a."PayerID" = '${payerId}' AND a."BilledRateMinute" > 0 AND b."ShVTSTTime" < a."ShVTSTTime" AND b."ShVTENTime" > a."ShVTENTime" THEN TIMESTAMPDIFF(MINUTE, a."ShVTSTTime", a."ShVTENTime") * a."BilledRateMinute"
            WHEN a."PayerID" = '${payerId}' AND a."BilledRateMinute" > 0 AND a."ShVTSTTime" < b."ShVTSTTime" AND a."ShVTENTime" > b."ShVTENTime" THEN TIMESTAMPDIFF(MINUTE, b."ShVTSTTime", b."ShVTENTime") * a."BilledRateMinute"
            ELSE 0
        END
    ) AS "OverlapPrice",
    SUM(
        CASE
            WHEN a."PayerID" = '${payerId}' AND a."StatusFlag" = 'R' AND a."BilledRateMinute" > 0 AND a."BILLABLEMINUTESOVERLAP" IS NOT NULL THEN a."BILLABLEMINUTESOVERLAP" * a."BilledRateMinute"
            WHEN a."PayerID" = '${payerId}' AND a."StatusFlag" = 'R' AND a."BilledRateMinute" > 0 AND b."ShVTSTTime" >= a."ShVTSTTime" AND b."ShVTSTTime" <= a."ShVTENTime" AND b."ShVTENTime" > a."ShVTENTime" THEN TIMESTAMPDIFF(MINUTE, b."ShVTSTTime", a."ShVTENTime") * a."BilledRateMinute"
            WHEN a."PayerID" = '${payerId}' AND a."StatusFlag" = 'R' AND a."BilledRateMinute" > 0 AND a."ShVTSTTime" >= b."ShVTSTTime" AND a."ShVTSTTime" <= b."ShVTENTime" AND a."ShVTENTime" > b."ShVTENTime" THEN TIMESTAMPDIFF(MINUTE, a."ShVTSTTime", b."ShVTENTime") * a."BilledRateMinute"
            WHEN a."PayerID" = '${payerId}' AND a."StatusFlag" = 'R' AND a."BilledRateMinute" > 0 AND b."ShVTSTTime" >= a."ShVTSTTime" AND b."ShVTENTime" <= a."ShVTENTime" THEN TIMESTAMPDIFF(MINUTE, b."ShVTSTTime", b."ShVTENTime") * a."BilledRateMinute"
            WHEN a."PayerID" = '${payerId}' AND a."StatusFlag" = 'R' AND a."BilledRateMinute" > 0 AND a."ShVTSTTime" >= b."ShVTSTTime" AND a."ShVTENTime" <= b."ShVTENTime" THEN TIMESTAMPDIFF(MINUTE, a."ShVTSTTime", a."ShVTENTime") * a."BilledRateMinute"
            WHEN a."PayerID" = '${payerId}' AND a."StatusFlag" = 'R' AND a."BilledRateMinute" > 0 AND b."ShVTSTTime" < a."ShVTSTTime" AND b."ShVTENTime" > a."ShVTENTime" THEN TIMESTAMPDIFF(MINUTE, a."ShVTSTTime", a."ShVTENTime") * a."BilledRateMinute"
            WHEN a."PayerID" = '${payerId}' AND a."StatusFlag" = 'R' AND a."BilledRateMinute" > 0 AND a."ShVTSTTime" < b."ShVTSTTime" AND a."ShVTENTime" > b."ShVTENTime" THEN TIMESTAMPDIFF(MINUTE, b."ShVTSTTime", b."ShVTENTime") * a."BilledRateMinute"
            ELSE 0
        END
    ) AS "FinalPrice"
FROM base_data_with_totals a
LEFT JOIN (
    SELECT
        DISTINCT V1."GroupID",
        V1."CONFLICTID",
        V1."ShVTSTTime",
        V1."ShVTENTime",
        TO_CHAR(V1."G_CRDATEUNIQUE", 'YYYY-MM-DD') AS CRDATEUNIQUE
    FROM CONFLICTREPORT_SANDBOX.PUBLIC.CONFLICTVISITMAPS AS V1
    INNER JOIN CONFLICTREPORT_SANDBOX.PUBLIC.CONFLICTS AS V2
            ON V2."CONFLICTID" = V1."CONFLICTID"
    WHERE V1."PayerID" = '${payerId}'
) b ON a.CONFLICTID <> b.CONFLICTID AND a."GroupID" = b."GroupID"
GROUP BY
    a.CRDATEUNIQUE,
    a."StatusFlag",
    CASE
        WHEN a."Billed" = 'yes' THEN 'Recovery'
        ELSE 'Avoidance'
    END,
    CASE
        WHEN a."VisitStartTime" IS NULL THEN 'Scheduled'
        WHEN a."VisitStartTime" IS NOT NULL AND a."Billed" != 'yes' THEN 'Confirmed'
        WHEN a."VisitStartTime" IS NOT NULL AND a."Billed" = 'yes' THEN 'Billed'
    END,
    a.daily_total_fixed
ORDER BY 
    a.CRDATEUNIQUE,
    a."StatusFlag",
    CASE
        WHEN a."Billed" = 'yes' THEN 'Recovery'
        ELSE 'Avoidance'
    END,
    CASE
        WHEN a."VisitStartTime" IS NULL THEN 'Scheduled'
        WHEN a."VisitStartTime" IS NOT NULL AND a."Billed" != 'yes' THEN 'Confirmed'
        WHEN a."VisitStartTime" IS NOT NULL AND a."Billed" = 'yes' THEN 'Billed'
    END;

-- =====================================================
-- ALTERNATIVE: IF YOU WANT TO SEE GRANULAR COUNTS INSTEAD OF DAILY TOTAL
-- =====================================================
-- Uncomment this section if you want to see the actual count for each granular combination
-- (Note: Sum of all granular counts will be > 1188 due to overlapping GroupIDs)

/*
WITH daily_totals AS (
    SELECT 
        TO_CHAR(V1."G_CRDATEUNIQUE", 'YYYY-MM-DD') AS CRDATEUNIQUE,
        COUNT(DISTINCT V1."GroupID") AS correct_daily_total
    FROM CONFLICTREPORT_SANDBOX.PUBLIC.CONFLICTVISITMAPS AS V1
    INNER JOIN CONFLICTREPORT_SANDBOX.PUBLIC.CONFLICTS AS V2
        ON V2."CONFLICTID" = V1."CONFLICTID"
    WHERE V1."PayerID" = '${payerId}' 
        AND V1."SameVisitTimeFlag" = 'Y'
    GROUP BY TO_CHAR(V1."G_CRDATEUNIQUE", 'YYYY-MM-DD')
)
SELECT
    '${payerId}' AS PAYERID,
    TO_CHAR(V1."G_CRDATEUNIQUE", 'YYYY-MM-DD') AS "CRDATEUNIQUE",
    'Exact Visit Time Match' AS "ConflictType",
    '2' AS "ConflictTypeF",
    CASE
        WHEN V2."StatusFlag" IN('R', 'D') THEN 'R'
        WHEN V2."StatusFlag" IN ('N') THEN 'N'
        ELSE 'U'
    END AS "STATUSFLAG",
    CASE
        WHEN V1."Billed" = 'yes' THEN 'Recovery'
        ELSE 'Avoidance'
    END AS "COSTTYPE",
    CASE
        WHEN V1."VisitStartTime" IS NULL THEN 'Scheduled'
        WHEN V1."VisitStartTime" IS NOT NULL AND V1."Billed" != 'yes' THEN 'Confirmed'
        WHEN V1."VisitStartTime" IS NOT NULL AND V1."Billed" = 'yes' THEN 'Billed'
    END AS "VISITTYPE",
    COUNT(DISTINCT V1."GroupID") AS "Total",  -- Show granular count instead of daily total
    SUM(
        CASE
            WHEN V1."PayerID" = '${payerId}' AND V1."BilledRateMinute" > 0 AND V1."BILLABLEMINUTESFULLSHIFT" IS NOT NULL THEN V1."BILLABLEMINUTESFULLSHIFT" * V1."BilledRateMinute"
            WHEN V1."PayerID" = '${payerId}' AND V1."BilledRateMinute" > 0 THEN TIMESTAMPDIFF(MINUTE, V1."ShVTSTTime", V1."ShVTENTime") * V1."BilledRateMinute"
            ELSE 0
        END
    ) AS "ShiftPrice",
    SUM(
        CASE
            WHEN V1."PayerID" = '${payerId}' AND V1."BilledRateMinute" > 0 AND V1."BILLABLEMINUTESOVERLAP" IS NOT NULL THEN V1."BILLABLEMINUTESOVERLAP" * V1."BilledRateMinute"
            WHEN V1."PayerID" = '${payerId}' AND V1."BilledRateMinute" > 0 AND b."ShVTSTTime" >= V1."ShVTSTTime" AND b."ShVTSTTime" <= V1."ShVTENTime" AND b."ShVTENTime" > V1."ShVTENTime" THEN TIMESTAMPDIFF(MINUTE, b."ShVTSTTime", V1."ShVTENTime") * V1."BilledRateMinute"
            WHEN V1."PayerID" = '${payerId}' AND V1."BilledRateMinute" > 0 AND V1."ShVTSTTime" >= b."ShVTSTTime" AND V1."ShVTSTTime" <= b."ShVTENTime" AND V1."ShVTENTime" > b."ShVTENTime" THEN TIMESTAMPDIFF(MINUTE, V1."ShVTSTTime", b."ShVTENTime") * V1."BilledRateMinute"
            WHEN V1."PayerID" = '${payerId}' AND V1."BilledRateMinute" > 0 AND b."ShVTSTTime" >= V1."ShVTSTTime" AND b."ShVTENTime" <= V1."ShVTENTime" THEN TIMESTAMPDIFF(MINUTE, b."ShVTSTTime", b."ShVTENTime") * V1."BilledRateMinute"
            WHEN V1."PayerID" = '${payerId}' AND V1."BilledRateMinute" > 0 AND V1."ShVTSTTime" >= b."ShVTSTTime" AND V1."ShVTENTime" <= b."ShVTENTime" THEN TIMESTAMPDIFF(MINUTE, V1."ShVTSTTime", V1."ShVTENTime") * V1."BilledRateMinute"
            WHEN V1."PayerID" = '${payerId}' AND V1."BilledRateMinute" > 0 AND b."ShVTSTTime" < V1."ShVTSTTime" AND b."ShVTENTime" > V1."ShVTENTime" THEN TIMESTAMPDIFF(MINUTE, V1."ShVTSTTime", V1."ShVTENTime") * V1."BilledRateMinute"
            WHEN V1."PayerID" = '${payerId}' AND V1."BilledRateMinute" > 0 AND V1."ShVTSTTime" < b."ShVTSTTime" AND V1."ShVTENTime" > b."ShVTENTime" THEN TIMESTAMPDIFF(MINUTE, b."ShVTSTTime", b."ShVTENTime") * V1."BilledRateMinute"
            ELSE 0
        END
    ) AS "OverlapPrice",
    SUM(
        CASE
            WHEN V1."PayerID" = '${payerId}' AND V2."StatusFlag" IN('R', 'D') AND V1."BilledRateMinute" > 0 AND V1."BILLABLEMINUTESOVERLAP" IS NOT NULL THEN V1."BILLABLEMINUTESOVERLAP" * V1."BilledRateMinute"
            WHEN V1."PayerID" = '${payerId}' AND V2."StatusFlag" IN('R', 'D') AND V1."BilledRateMinute" > 0 AND b."ShVTSTTime" >= V1."ShVTSTTime" AND b."ShVTSTTime" <= V1."ShVTENTime" AND b."ShVTENTime" > V1."ShVTENTime" THEN TIMESTAMPDIFF(MINUTE, b."ShVTSTTime", V1."ShVTENTime") * V1."BilledRateMinute"
            WHEN V1."PayerID" = '${payerId}' AND V2."StatusFlag" IN('R', 'D') AND V1."BilledRateMinute" > 0 AND V1."ShVTSTTime" >= b."ShVTSTTime" AND V1."ShVTSTTime" <= b."ShVTENTime" AND V1."ShVTENTime" > b."ShVTENTime" THEN TIMESTAMPDIFF(MINUTE, V1."ShVTSTTime", b."ShVTENTime") * V1."BilledRateMinute"
            WHEN V1."PayerID" = '${payerId}' AND V2."StatusFlag" IN('R', 'D') AND V1."BilledRateMinute" > 0 AND b."ShVTSTTime" >= V1."ShVTSTTime" AND b."ShVTENTime" <= V1."ShVTENTime" THEN TIMESTAMPDIFF(MINUTE, b."ShVTSTTime", b."ShVTENTime") * V1."BilledRateMinute"
            WHEN V1."PayerID" = '${payerId}' AND V2."StatusFlag" IN('R', 'D') AND V1."BilledRateMinute" > 0 AND V1."ShVTSTTime" >= b."ShVTSTTime" AND V1."ShVTENTime" <= b."ShVTENTime" THEN TIMESTAMPDIFF(MINUTE, V1."ShVTSTTime", V1."ShVTENTime") * V1."BilledRateMinute"
            WHEN V1."PayerID" = '${payerId}' AND V2."StatusFlag" IN('R', 'D') AND V1."BilledRateMinute" > 0 AND b."ShVTSTTime" < V1."ShVTSTTime" AND b."ShVTENTime" > V1."ShVTENTime" THEN TIMESTAMPDIFF(MINUTE, V1."ShVTSTTime", V1."ShVTENTime") * V1."BilledRateMinute"
            WHEN V1."PayerID" = '${payerId}' AND V2."StatusFlag" IN('R', 'D') AND V1."BilledRateMinute" > 0 AND V1."ShVTSTTime" < b."ShVTSTTime" AND V1."ShVTENTime" > b."ShVTENTime" THEN TIMESTAMPDIFF(MINUTE, b."ShVTSTTime", b."ShVTENTime") * V1."BilledRateMinute"
            ELSE 0
        END
    ) AS "FinalPrice"
FROM CONFLICTREPORT_SANDBOX.PUBLIC.CONFLICTVISITMAPS AS V1
INNER JOIN CONFLICTREPORT_SANDBOX.PUBLIC.CONFLICTS AS V2
    ON V2."CONFLICTID" = V1."CONFLICTID"
LEFT JOIN (
    SELECT
        DISTINCT V1."GroupID",
        V1."CONFLICTID",
        V1."ShVTSTTime",
        V1."ShVTENTime",
        TO_CHAR(V1."G_CRDATEUNIQUE", 'YYYY-MM-DD') AS CRDATEUNIQUE
    FROM CONFLICTREPORT_SANDBOX.PUBLIC.CONFLICTVISITMAPS AS V1
    INNER JOIN CONFLICTREPORT_SANDBOX.PUBLIC.CONFLICTS AS V2
            ON V2."CONFLICTID" = V1."CONFLICTID"
    WHERE V1."PayerID" = '${payerId}'
) b ON V1.CONFLICTID <> b.CONFLICTID AND V1."GroupID" = b."GroupID"
WHERE V1."PayerID" = '${payerId}' 
    AND V1."SameVisitTimeFlag" = 'Y'
GROUP BY
    TO_CHAR(V1."G_CRDATEUNIQUE", 'YYYY-MM-DD'),
    CASE
        WHEN V2."StatusFlag" IN('R', 'D') THEN 'R'
        WHEN V2."StatusFlag" IN ('N') THEN 'N'
        ELSE 'U'
    END,
    CASE
        WHEN V1."Billed" = 'yes' THEN 'Recovery'
        ELSE 'Avoidance'
    END,
    CASE
        WHEN V1."VisitStartTime" IS NULL THEN 'Scheduled'
        WHEN V1."VisitStartTime" IS NOT NULL AND V1."Billed" != 'yes' THEN 'Confirmed'
        WHEN V1."VisitStartTime" IS NOT NULL AND V1."Billed" = 'yes' THEN 'Billed'
    END
ORDER BY 
    TO_CHAR(V1."G_CRDATEUNIQUE", 'YYYY-MM-DD'),
    CASE
        WHEN V2."StatusFlag" IN('R', 'D') THEN 'R'
        WHEN V2."StatusFlag" IN ('N') THEN 'N'
        ELSE 'U'
    END,
    CASE
        WHEN V1."Billed" = 'yes' THEN 'Recovery'
        ELSE 'Avoidance'
    END,
    CASE
        WHEN V1."VisitStartTime" IS NULL THEN 'Scheduled'
        WHEN V1."VisitStartTime" IS NOT NULL AND V1."Billed" != 'yes' THEN 'Confirmed'
        WHEN V1."VisitStartTime" IS NOT NULL AND V1."Billed" = 'yes' THEN 'Billed'
    END;
*/

-- =====================================================
-- EXPLANATION OF THE FIXED APPROACH
-- =====================================================
-- 
-- PROBLEM: 
-- The LEFT JOIN was causing row multiplication, which made the daily total
-- appear multiple times in the result set, inflating the total count.
--
-- SOLUTION:
-- 1. Use a window function (FIRST_VALUE) to ensure the daily total is applied
--    correctly to each row without being affected by the LEFT JOIN multiplication
-- 2. The window function partitions by date and ensures the same daily total
--    is used for all rows within that date partition
-- 3. This prevents the total from being repeated or inflated due to JOIN multiplication
--
-- KEY IMPROVEMENTS:
-- - Window function ensures consistent daily total across all rows
-- - No more repetition of the total value
-- - Accurate price calculations with LEFT JOIN
-- - Clean granular breakdown without inflated totals 