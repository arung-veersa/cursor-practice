-- Step 1: TRUNCATE the table
TRUNCATE TABLE TEST_PY_DB_CON;

-- Step 2: Fetch payer IDs
SELECT 
  DISTINCT a.APID 
FROM 
  ANALYTICS.BI.DIMPAYER AS P 
  JOIN (
    SELECT 
      DISTINCT V1."GroupID", 
      V1."CONFLICTID", 
      V1."PayerID" AS APID 
    FROM 
      CONFLICTVISITMAPS AS V1 
      INNER JOIN CONFLICTS AS V2 ON V2."CONFLICTID" = V1."CONFLICTID" 
    WHERE 
      V1."GroupID" IN (
        SELECT 
          DISTINCT "GroupID" 
        FROM 
          CONFLICTVISITMAPS --WHERE
          --  ("SchOverAnotherSchTimeFlag" = 'Y'
          --     OR "VisitTimeOverAnotherVisitTimeFlag" = 'Y')
          )
  ) a 
  LEFT JOIN (
    SELECT 
      DISTINCT V1."GroupID", 
      V1."CONFLICTID" 
    FROM 
      CONFLICTVISITMAPS AS V1 
      INNER JOIN CONFLICTS AS V2 ON V2."CONFLICTID" = V1."CONFLICTID" 
    WHERE 
      V1."GroupID" IN (
        SELECT 
          DISTINCT "GroupID" 
        FROM 
          CONFLICTVISITMAPS --WHERE
          -- ("SchOverAnotherSchTimeFlag" = 'Y'
          --   OR "VisitTimeOverAnotherVisitTimeFlag" = 'Y')
          )
  ) b ON a.CONFLICTID <> b.CONFLICTID 
  AND a."GroupID" = b."GroupID" 
WHERE 
  P."Is Active" = TRUE 
  AND P."Is Demo" = FALSE 
  AND P."Payer Id" = a.APID;

-- Step 3: Loop through result set

---------------------------PAYER CON TYPE---------------------
INSERT INTO TEST_PY_DB_CON (
  PAYERID, CRDATEUNIQUE, CONTYPE, CONTYPES, 
  CO_TO, CO_SP, CO_OP, CO_FP
) 
SELECT 
  * 
FROM 
  (
    SELECT 
      '${payerId}' AS PAYERID, 
      a."CRDATEUNIQUE" AS "CRDATEUNIQUE", 
      'Exact Schedule Time Match' AS "ConflictType", 
      '1' AS "ConflictTypeF", 
      COUNT(DISTINCT a."GroupID") AS "Total", 
      SUM(
        CASE WHEN a.APID = '${payerId}' 
        AND a."BilledRateMinute" > 0 THEN TIMESTAMPDIFF(
          MINUTE, a."ShVTSTTime", a."ShVTENTime"
        ) * a."BilledRateMinute" ELSE 0 END
      ) AS "ShiftPrice", 
      SUM(
        CASE WHEN a.APID = '${payerId}' 
        AND a."BilledRateMinute" > 0 
        AND b."ShVTSTTime" >= a."ShVTSTTime" 
        AND b."ShVTSTTime" <= a."ShVTENTime" 
        AND b."ShVTENTime" > a."ShVTENTime" THEN TIMESTAMPDIFF(
          MINUTE, b."ShVTSTTime", a."ShVTENTime"
        ) * a."BilledRateMinute" WHEN a.APID = '${payerId}' 
        AND a."BilledRateMinute" > 0 
        AND a."ShVTSTTime" >= b."ShVTSTTime" 
        AND a."ShVTSTTime" <= b."ShVTENTime" 
        AND a."ShVTENTime" > b."ShVTENTime" THEN TIMESTAMPDIFF(
          MINUTE, a."ShVTSTTime", b."ShVTENTime"
        ) * a."BilledRateMinute" WHEN a.APID = '${payerId}' 
        AND a."BilledRateMinute" > 0 
        AND b."ShVTSTTime" >= a."ShVTSTTime" 
        AND b."ShVTENTime" <= a."ShVTENTime" THEN TIMESTAMPDIFF(
          MINUTE, b."ShVTSTTime", b."ShVTENTime"
        ) * a."BilledRateMinute" WHEN a.APID = '${payerId}' 
        AND a."BilledRateMinute" > 0 
        AND a."ShVTSTTime" >= b."ShVTSTTime" 
        AND a."ShVTENTime" <= b."ShVTENTime" THEN TIMESTAMPDIFF(
          MINUTE, a."ShVTSTTime", a."ShVTENTime"
        ) * a."BilledRateMinute" WHEN a.APID = '${payerId}' 
        AND a."BilledRateMinute" > 0 
        AND b."ShVTSTTime" < a."ShVTSTTime" 
        AND b."ShVTENTime" > a."ShVTENTime" THEN TIMESTAMPDIFF(
          MINUTE, a."ShVTSTTime", a."ShVTENTime"
        ) * a."BilledRateMinute" WHEN a.APID = '${payerId}' 
        AND a."BilledRateMinute" > 0 
        AND a."ShVTSTTime" < b."ShVTSTTime" 
        AND a."ShVTENTime" > b."ShVTENTime" THEN TIMESTAMPDIFF(
          MINUTE, b."ShVTSTTime", b."ShVTENTime"
        ) * a."BilledRateMinute" ELSE 0 END
      ) AS "OverlapPrice", 
      SUM(
        CASE WHEN a.APID = '${payerId}' 
        AND a."StatusFlag" = 'R' 
        AND a."BilledRateMinute" > 0 
        AND b."ShVTSTTime" >= a."ShVTSTTime" 
        AND b."ShVTSTTime" <= a."ShVTENTime" 
        AND b."ShVTENTime" > a."ShVTENTime" THEN TIMESTAMPDIFF(
          MINUTE, b."ShVTSTTime", a."ShVTENTime"
        ) * a."BilledRateMinute" WHEN a.APID = '${payerId}' 
        AND a."StatusFlag" = 'R' 
        AND a."BilledRateMinute" > 0 
        AND a."ShVTSTTime" >= b."ShVTSTTime" 
        AND a."ShVTSTTime" <= b."ShVTENTime" 
        AND a."ShVTENTime" > b."ShVTENTime" THEN TIMESTAMPDIFF(
          MINUTE, a."ShVTSTTime", b."ShVTENTime"
        ) * a."BilledRateMinute" WHEN a.APID = '${payerId}' 
        AND a."StatusFlag" = 'R' 
        AND a."BilledRateMinute" > 0 
        AND b."ShVTSTTime" >= a."ShVTSTTime" 
        AND b."ShVTENTime" <= a."ShVTENTime" THEN TIMESTAMPDIFF(
          MINUTE, b."ShVTSTTime", b."ShVTENTime"
        ) * a."BilledRateMinute" WHEN a.APID = '${payerId}' 
        AND a."StatusFlag" = 'R' 
        AND a."BilledRateMinute" > 0 
        AND a."ShVTSTTime" >= b."ShVTSTTime" 
        AND a."ShVTENTime" <= b."ShVTENTime" THEN TIMESTAMPDIFF(
          MINUTE, a."ShVTSTTime", a."ShVTENTime"
        ) * a."BilledRateMinute" WHEN a.APID = '${payerId}' 
        AND a."StatusFlag" = 'R' 
        AND a."BilledRateMinute" > 0 
        AND b."ShVTSTTime" < a."ShVTSTTime" 
        AND b."ShVTENTime" > a."ShVTENTime" THEN TIMESTAMPDIFF(
          MINUTE, a."ShVTSTTime", a."ShVTENTime"
        ) * a."BilledRateMinute" WHEN a.APID = '${payerId}' 
        AND a."StatusFlag" = 'R' 
        AND a."BilledRateMinute" > 0 
        AND a."ShVTSTTime" < b."ShVTSTTime" 
        AND a."ShVTENTime" > b."ShVTENTime" THEN TIMESTAMPDIFF(
          MINUTE, b."ShVTSTTime", b."ShVTENTime"
        ) * a."BilledRateMinute" ELSE 0 END
      ) AS "FinalPrice" 
    FROM 
      (
        SELECT 
          DISTINCT V1."GroupID", 
          V1."CONFLICTID", 
          V1."ShVTSTTime", 
          V1."ShVTENTime", 
          V1."BilledRateMinute", 
          V1."G_CRDATEUNIQUE", 
          TO_CHAR(
            V1."G_CRDATEUNIQUE", 'YYYY-MM-DD'
          ) AS CRDATEUNIQUE, 
          V1."PayerID" AS APID, 
          CASE WHEN V2."StatusFlag" IN('R', 'D') THEN 'R' WHEN V2."StatusFlag" IN ('N') THEN 'N' ELSE 'U' END AS "StatusFlag" 
        FROM 
          CONFLICTVISITMAPS AS V1 
          INNER JOIN CONFLICTS AS V2 ON V2."CONFLICTID" = V1."CONFLICTID" 
        WHERE 
          V1."GroupID" IN (
            SELECT 
              DISTINCT "GroupID" 
            FROM 
              CONFLICTVISITMAPS 
            WHERE 
              "PayerID" = '${payerId}' 
              AND "SameSchTimeFlag" = 'Y'
          )
      ) a 
      LEFT JOIN (
        SELECT 
          DISTINCT V1."GroupID", 
          V1."CONFLICTID", 
          V1."ShVTSTTime", 
          V1."ShVTENTime", 
          TO_CHAR(
            V1."G_CRDATEUNIQUE", 'YYYY-MM-DD'
          ) AS CRDATEUNIQUE, 
        FROM 
          CONFLICTVISITMAPS AS V1 
          INNER JOIN CONFLICTS AS V2 ON V2."CONFLICTID" = V1."CONFLICTID" 
        WHERE 
          V1."GroupID" IN (
            SELECT 
              DISTINCT "GroupID" 
            FROM 
              CONFLICTVISITMAPS 
            WHERE 
              "PayerID" = '${payerId}'
          )
      ) b ON a.CONFLICTID <> b.CONFLICTID 
      AND a."GroupID" = b."GroupID" 
    GROUP BY 
      a.CRDATEUNIQUE 
    UNION ALL 
    SELECT 
      '${payerId}' AS PAYERID, 
      a."CRDATEUNIQUE" AS "CRDATEUNIQUE", 
      'Exact Visit Time Match' AS "ConflictType", 
      '2' AS "ConflictTypeF", 
      COUNT(DISTINCT a."GroupID") AS "Total", 
      SUM(
        CASE WHEN a.APID = '${payerId}' 
        AND a."BilledRateMinute" > 0 THEN TIMESTAMPDIFF(
          MINUTE, a."ShVTSTTime", a."ShVTENTime"
        ) * a."BilledRateMinute" ELSE 0 END
      ) AS "ShiftPrice", 
      SUM(
        CASE WHEN a.APID = '${payerId}' 
        AND a."BilledRateMinute" > 0 
        AND b."ShVTSTTime" >= a."ShVTSTTime" 
        AND b."ShVTSTTime" <= a."ShVTENTime" 
        AND b."ShVTENTime" > a."ShVTENTime" THEN TIMESTAMPDIFF(
          MINUTE, b."ShVTSTTime", a."ShVTENTime"
        ) * a."BilledRateMinute" WHEN a.APID = '${payerId}' 
        AND a."BilledRateMinute" > 0 
        AND a."ShVTSTTime" >= b."ShVTSTTime" 
        AND a."ShVTSTTime" <= b."ShVTENTime" 
        AND a."ShVTENTime" > b."ShVTENTime" THEN TIMESTAMPDIFF(
          MINUTE, a."ShVTSTTime", b."ShVTENTime"
        ) * a."BilledRateMinute" WHEN a.APID = '${payerId}' 
        AND a."BilledRateMinute" > 0 
        AND b."ShVTSTTime" >= a."ShVTSTTime" 
        AND b."ShVTENTime" <= a."ShVTENTime" THEN TIMESTAMPDIFF(
          MINUTE, b."ShVTSTTime", b."ShVTENTime"
        ) * a."BilledRateMinute" WHEN a.APID = '${payerId}' 
        AND a."BilledRateMinute" > 0 
        AND a."ShVTSTTime" >= b."ShVTSTTime" 
        AND a."ShVTENTime" <= b."ShVTENTime" THEN TIMESTAMPDIFF(
          MINUTE, a."ShVTSTTime", a."ShVTENTime"
        ) * a."BilledRateMinute" WHEN a.APID = '${payerId}' 
        AND a."BilledRateMinute" > 0 
        AND b."ShVTSTTime" < a."ShVTSTTime" 
        AND b."ShVTENTime" > a."ShVTENTime" THEN TIMESTAMPDIFF(
          MINUTE, a."ShVTSTTime", a."ShVTENTime"
        ) * a."BilledRateMinute" WHEN a.APID = '${payerId}' 
        AND a."BilledRateMinute" > 0 
        AND a."ShVTSTTime" < b."ShVTSTTime" 
        AND a."ShVTENTime" > b."ShVTENTime" THEN TIMESTAMPDIFF(
          MINUTE, b."ShVTSTTime", b."ShVTENTime"
        ) * a."BilledRateMinute" ELSE 0 END
      ) AS "OverlapPrice", 
      SUM(
        CASE WHEN a.APID = '${payerId}' 
        AND a."StatusFlag" = 'R' 
        AND a."BilledRateMinute" > 0 
        AND b."ShVTSTTime" >= a."ShVTSTTime" 
        AND b."ShVTSTTime" <= a."ShVTENTime" 
        AND b."ShVTENTime" > a."ShVTENTime" THEN TIMESTAMPDIFF(
          MINUTE, b."ShVTSTTime", a."ShVTENTime"
        ) * a."BilledRateMinute" WHEN a.APID = '${payerId}' 
        AND a."StatusFlag" = 'R' 
        AND a."BilledRateMinute" > 0 
        AND a."ShVTSTTime" >= b."ShVTSTTime" 
        AND a."ShVTSTTime" <= b."ShVTENTime" 
        AND a."ShVTENTime" > b."ShVTENTime" THEN TIMESTAMPDIFF(
          MINUTE, a."ShVTSTTime", b."ShVTENTime"
        ) * a."BilledRateMinute" WHEN a.APID = '${payerId}' 
        AND a."StatusFlag" = 'R' 
        AND a."BilledRateMinute" > 0 
        AND b."ShVTSTTime" >= a."ShVTSTTime" 
        AND b."ShVTENTime" <= a."ShVTENTime" THEN TIMESTAMPDIFF(
          MINUTE, b."ShVTSTTime", b."ShVTENTime"
        ) * a."BilledRateMinute" WHEN a.APID = '${payerId}' 
        AND a."StatusFlag" = 'R' 
        AND a."BilledRateMinute" > 0 
        AND a."ShVTSTTime" >= b."ShVTSTTime" 
        AND a."ShVTENTime" <= b."ShVTENTime" THEN TIMESTAMPDIFF(
          MINUTE, a."ShVTSTTime", a."ShVTENTime"
        ) * a."BilledRateMinute" WHEN a.APID = '${payerId}' 
        AND a."StatusFlag" = 'R' 
        AND a."BilledRateMinute" > 0 
        AND b."ShVTSTTime" < a."ShVTSTTime" 
        AND b."ShVTENTime" > a."ShVTENTime" THEN TIMESTAMPDIFF(
          MINUTE, a."ShVTSTTime", a."ShVTENTime"
        ) * a."BilledRateMinute" WHEN a.APID = '${payerId}' 
        AND a."StatusFlag" = 'R' 
        AND a."BilledRateMinute" > 0 
        AND a."ShVTSTTime" < b."ShVTSTTime" 
        AND a."ShVTENTime" > b."ShVTENTime" THEN TIMESTAMPDIFF(
          MINUTE, b."ShVTSTTime", b."ShVTENTime"
        ) * a."BilledRateMinute" ELSE 0 END
      ) AS "FinalPrice" 
    FROM 
      (
        SELECT 
          DISTINCT V1."GroupID", 
          V1."CONFLICTID", 
          V1."ShVTSTTime", 
          V1."ShVTENTime", 
          V1."BilledRateMinute", 
          V1."G_CRDATEUNIQUE", 
          TO_CHAR(
            V1."G_CRDATEUNIQUE", 'YYYY-MM-DD'
          ) AS CRDATEUNIQUE, 
          V1."PayerID" AS APID, 
          CASE WHEN V2."StatusFlag" IN('R', 'D') THEN 'R' WHEN V2."StatusFlag" IN ('N') THEN 'N' ELSE 'U' END AS "StatusFlag" 
        FROM 
          CONFLICTVISITMAPS AS V1 
          INNER JOIN CONFLICTS AS V2 ON V2."CONFLICTID" = V1."CONFLICTID" 
        WHERE 
          V1."GroupID" IN (
            SELECT 
              DISTINCT "GroupID" 
            FROM 
              CONFLICTVISITMAPS 
            WHERE 
              "PayerID" = '${payerId}' 
              AND "SameVisitTimeFlag" = 'Y'
          )
      ) a 
      LEFT JOIN (
        SELECT 
          DISTINCT V1."GroupID", 
          V1."CONFLICTID", 
          V1."ShVTSTTime", 
          V1."ShVTENTime", 
          TO_CHAR(
            V1."G_CRDATEUNIQUE", 'YYYY-MM-DD'
          ) AS CRDATEUNIQUE, 
        FROM 
          CONFLICTVISITMAPS AS V1 
          INNER JOIN CONFLICTS AS V2 ON V2."CONFLICTID" = V1."CONFLICTID" 
        WHERE 
          V1."GroupID" IN (
            SELECT 
              DISTINCT "GroupID" 
            FROM 
              CONFLICTVISITMAPS 
            WHERE 
              "PayerID" = '${payerId}'
          )
      ) b ON a.CONFLICTID <> b.CONFLICTID 
      AND a."GroupID" = b."GroupID" 
    GROUP BY 
      a.CRDATEUNIQUE 
    UNION ALL 
    SELECT 
      '${payerId}' AS PAYERID, 
      a."CRDATEUNIQUE" AS "CRDATEUNIQUE", 
      'Exact Schedule and Visit Time Match' AS "ConflictType", 
      '3' AS "ConflictTypeF", 
      COUNT(DISTINCT a."GroupID") AS "Total", 
      SUM(
        CASE WHEN a.APID = '${payerId}' 
        AND a."BilledRateMinute" > 0 THEN TIMESTAMPDIFF(
          MINUTE, a."ShVTSTTime", a."ShVTENTime"
        ) * a."BilledRateMinute" ELSE 0 END
      ) AS "ShiftPrice", 
      SUM(
        CASE WHEN a.APID = '${payerId}' 
        AND a."BilledRateMinute" > 0 
        AND b."ShVTSTTime" >= a."ShVTSTTime" 
        AND b."ShVTSTTime" <= a."ShVTENTime" 
        AND b."ShVTENTime" > a."ShVTENTime" THEN TIMESTAMPDIFF(
          MINUTE, b."ShVTSTTime", a."ShVTENTime"
        ) * a."BilledRateMinute" WHEN a.APID = '${payerId}' 
        AND a."BilledRateMinute" > 0 
        AND a."ShVTSTTime" >= b."ShVTSTTime" 
        AND a."ShVTSTTime" <= b."ShVTENTime" 
        AND a."ShVTENTime" > b."ShVTENTime" THEN TIMESTAMPDIFF(
          MINUTE, a."ShVTSTTime", b."ShVTENTime"
        ) * a."BilledRateMinute" WHEN a.APID = '${payerId}' 
        AND a."BilledRateMinute" > 0 
        AND b."ShVTSTTime" >= a."ShVTSTTime" 
        AND b."ShVTENTime" <= a."ShVTENTime" THEN TIMESTAMPDIFF(
          MINUTE, b."ShVTSTTime", b."ShVTENTime"
        ) * a."BilledRateMinute" WHEN a.APID = '${payerId}' 
        AND a."BilledRateMinute" > 0 
        AND a."ShVTSTTime" >= b."ShVTSTTime" 
        AND a."ShVTENTime" <= b."ShVTENTime" THEN TIMESTAMPDIFF(
          MINUTE, a."ShVTSTTime", a."ShVTENTime"
        ) * a."BilledRateMinute" WHEN a.APID = '${payerId}' 
        AND a."BilledRateMinute" > 0 
        AND b."ShVTSTTime" < a."ShVTSTTime" 
        AND b."ShVTENTime" > a."ShVTENTime" THEN TIMESTAMPDIFF(
          MINUTE, a."ShVTSTTime", a."ShVTENTime"
        ) * a."BilledRateMinute" WHEN a.APID = '${payerId}' 
        AND a."BilledRateMinute" > 0 
        AND a."ShVTSTTime" < b."ShVTSTTime" 
        AND a."ShVTENTime" > b."ShVTENTime" THEN TIMESTAMPDIFF(
          MINUTE, b."ShVTSTTime", b."ShVTENTime"
        ) * a."BilledRateMinute" ELSE 0 END
      ) AS "OverlapPrice", 
      SUM(
        CASE WHEN a.APID = '${payerId}' 
        AND a."StatusFlag" = 'R' 
        AND a."BilledRateMinute" > 0 
        AND b."ShVTSTTime" >= a."ShVTSTTime" 
        AND b."ShVTSTTime" <= a."ShVTENTime" 
        AND b."ShVTENTime" > a."ShVTENTime" THEN TIMESTAMPDIFF(
          MINUTE, b."ShVTSTTime", a."ShVTENTime"
        ) * a."BilledRateMinute" WHEN a.APID = '${payerId}' 
        AND a."StatusFlag" = 'R' 
        AND a."BilledRateMinute" > 0 
        AND a."ShVTSTTime" >= b."ShVTSTTime" 
        AND a."ShVTSTTime" <= b."ShVTENTime" 
        AND a."ShVTENTime" > b."ShVTENTime" THEN TIMESTAMPDIFF(
          MINUTE, a."ShVTSTTime", b."ShVTENTime"
        ) * a."BilledRateMinute" WHEN a.APID = '${payerId}' 
        AND a."StatusFlag" = 'R' 
        AND a."BilledRateMinute" > 0 
        AND b."ShVTSTTime" >= a."ShVTSTTime" 
        AND b."ShVTENTime" <= a."ShVTENTime" THEN TIMESTAMPDIFF(
          MINUTE, b."ShVTSTTime", b."ShVTENTime"
        ) * a."BilledRateMinute" WHEN a.APID = '${payerId}' 
        AND a."StatusFlag" = 'R' 
        AND a."BilledRateMinute" > 0 
        AND a."ShVTSTTime" >= b."ShVTSTTime" 
        AND a."ShVTENTime" <= b."ShVTENTime" THEN TIMESTAMPDIFF(
          MINUTE, a."ShVTSTTime", a."ShVTENTime"
        ) * a."BilledRateMinute" WHEN a.APID = '${payerId}' 
        AND a."StatusFlag" = 'R' 
        AND a."BilledRateMinute" > 0 
        AND b."ShVTSTTime" < a."ShVTSTTime" 
        AND b."ShVTENTime" > a."ShVTENTime" THEN TIMESTAMPDIFF(
          MINUTE, a."ShVTSTTime", a."ShVTENTime"
        ) * a."BilledRateMinute" WHEN a.APID = '${payerId}' 
        AND a."StatusFlag" = 'R' 
        AND a."BilledRateMinute" > 0 
        AND a."ShVTSTTime" < b."ShVTSTTime" 
        AND a."ShVTENTime" > b."ShVTENTime" THEN TIMESTAMPDIFF(
          MINUTE, b."ShVTSTTime", b."ShVTENTime"
        ) * a."BilledRateMinute" ELSE 0 END
      ) AS "FinalPrice" 
    FROM 
      (
        SELECT 
          DISTINCT V1."GroupID", 
          V1."CONFLICTID", 
          V1."ShVTSTTime", 
          V1."ShVTENTime", 
          V1."BilledRateMinute", 
          V1."G_CRDATEUNIQUE", 
          TO_CHAR(
            V1."G_CRDATEUNIQUE", 'YYYY-MM-DD'
          ) AS CRDATEUNIQUE, 
          V1."PayerID" AS APID, 
          CASE WHEN V2."StatusFlag" IN('R', 'D') THEN 'R' WHEN V2."StatusFlag" IN ('N') THEN 'N' ELSE 'U' END AS "StatusFlag" 
        FROM 
          CONFLICTVISITMAPS AS V1 
          INNER JOIN CONFLICTS AS V2 ON V2."CONFLICTID" = V1."CONFLICTID" 
        WHERE 
          V1."GroupID" IN (
            SELECT 
              DISTINCT "GroupID" 
            FROM 
              CONFLICTVISITMAPS 
            WHERE 
              "PayerID" = '${payerId}' 
              AND "SchAndVisitTimeSameFlag" = 'Y'
          )
      ) a 
      LEFT JOIN (
        SELECT 
          DISTINCT V1."GroupID", 
          V1."CONFLICTID", 
          V1."ShVTSTTime", 
          V1."ShVTENTime", 
          TO_CHAR(
            V1."G_CRDATEUNIQUE", 'YYYY-MM-DD'
          ) AS CRDATEUNIQUE, 
        FROM 
          CONFLICTVISITMAPS AS V1 
          INNER JOIN CONFLICTS AS V2 ON V2."CONFLICTID" = V1."CONFLICTID" 
        WHERE 
          V1."GroupID" IN (
            SELECT 
              DISTINCT "GroupID" 
            FROM 
              CONFLICTVISITMAPS 
            WHERE 
              "PayerID" = '${payerId}'
          )
      ) b ON a.CONFLICTID <> b.CONFLICTID 
      AND a."GroupID" = b."GroupID" 
    GROUP BY 
      a.CRDATEUNIQUE 
    UNION ALL 
    SELECT 
      '${payerId}' AS PAYERID, 
      a."CRDATEUNIQUE" AS "CRDATEUNIQUE", 
      'Schedule time overlap' AS "ConflictType", 
      '4' AS "ConflictTypeF", 
      COUNT(DISTINCT a."GroupID") AS "Total", 
      SUM(
        CASE WHEN a.APID = '${payerId}' 
        AND a."BilledRateMinute" > 0 THEN TIMESTAMPDIFF(
          MINUTE, a."ShVTSTTime", a."ShVTENTime"
        ) * a."BilledRateMinute" ELSE 0 END
      ) AS "ShiftPrice", 
      SUM(
        CASE WHEN a.APID = '${payerId}' 
        AND a."BilledRateMinute" > 0 
        AND b."ShVTSTTime" >= a."ShVTSTTime" 
        AND b."ShVTSTTime" <= a."ShVTENTime" 
        AND b."ShVTENTime" > a."ShVTENTime" THEN TIMESTAMPDIFF(
          MINUTE, b."ShVTSTTime", a."ShVTENTime"
        ) * a."BilledRateMinute" WHEN a.APID = '${payerId}' 
        AND a."BilledRateMinute" > 0 
        AND a."ShVTSTTime" >= b."ShVTSTTime" 
        AND a."ShVTSTTime" <= b."ShVTENTime" 
        AND a."ShVTENTime" > b."ShVTENTime" THEN TIMESTAMPDIFF(
          MINUTE, a."ShVTSTTime", b."ShVTENTime"
        ) * a."BilledRateMinute" WHEN a.APID = '${payerId}' 
        AND a."BilledRateMinute" > 0 
        AND b."ShVTSTTime" >= a."ShVTSTTime" 
        AND b."ShVTENTime" <= a."ShVTENTime" THEN TIMESTAMPDIFF(
          MINUTE, b."ShVTSTTime", b."ShVTENTime"
        ) * a."BilledRateMinute" WHEN a.APID = '${payerId}' 
        AND a."BilledRateMinute" > 0 
        AND a."ShVTSTTime" >= b."ShVTSTTime" 
        AND a."ShVTENTime" <= b."ShVTENTime" THEN TIMESTAMPDIFF(
          MINUTE, a."ShVTSTTime", a."ShVTENTime"
        ) * a."BilledRateMinute" WHEN a.APID = '${payerId}' 
        AND a."BilledRateMinute" > 0 
        AND b."ShVTSTTime" < a."ShVTSTTime" 
        AND b."ShVTENTime" > a."ShVTENTime" THEN TIMESTAMPDIFF(
          MINUTE, a."ShVTSTTime", a."ShVTENTime"
        ) * a."BilledRateMinute" WHEN a.APID = '${payerId}' 
        AND a."BilledRateMinute" > 0 
        AND a."ShVTSTTime" < b."ShVTSTTime" 
        AND a."ShVTENTime" > b."ShVTENTime" THEN TIMESTAMPDIFF(
          MINUTE, b."ShVTSTTime", b."ShVTENTime"
        ) * a."BilledRateMinute" ELSE 0 END
      ) AS "OverlapPrice", 
      SUM(
        CASE WHEN a.APID = '${payerId}' 
        AND a."StatusFlag" = 'R' 
        AND a."BilledRateMinute" > 0 
        AND b."ShVTSTTime" >= a."ShVTSTTime" 
        AND b."ShVTSTTime" <= a."ShVTENTime" 
        AND b."ShVTENTime" > a."ShVTENTime" THEN TIMESTAMPDIFF(
          MINUTE, b."ShVTSTTime", a."ShVTENTime"
        ) * a."BilledRateMinute" WHEN a.APID = '${payerId}' 
        AND a."StatusFlag" = 'R' 
        AND a."BilledRateMinute" > 0 
        AND a."ShVTSTTime" >= b."ShVTSTTime" 
        AND a."ShVTSTTime" <= b."ShVTENTime" 
        AND a."ShVTENTime" > b."ShVTENTime" THEN TIMESTAMPDIFF(
          MINUTE, a."ShVTSTTime", b."ShVTENTime"
        ) * a."BilledRateMinute" WHEN a.APID = '${payerId}' 
        AND a."StatusFlag" = 'R' 
        AND a."BilledRateMinute" > 0 
        AND b."ShVTSTTime" >= a."ShVTSTTime" 
        AND b."ShVTENTime" <= a."ShVTENTime" THEN TIMESTAMPDIFF(
          MINUTE, b."ShVTSTTime", b."ShVTENTime"
        ) * a."BilledRateMinute" WHEN a.APID = '${payerId}' 
        AND a."StatusFlag" = 'R' 
        AND a."BilledRateMinute" > 0 
        AND a."ShVTSTTime" >= b."ShVTSTTime" 
        AND a."ShVTENTime" <= b."ShVTENTime" THEN TIMESTAMPDIFF(
          MINUTE, a."ShVTSTTime", a."ShVTENTime"
        ) * a."BilledRateMinute" WHEN a.APID = '${payerId}' 
        AND a."StatusFlag" = 'R' 
        AND a."BilledRateMinute" > 0 
        AND b."ShVTSTTime" < a."ShVTSTTime" 
        AND b."ShVTENTime" > a."ShVTENTime" THEN TIMESTAMPDIFF(
          MINUTE, a."ShVTSTTime", a."ShVTENTime"
        ) * a."BilledRateMinute" WHEN a.APID = '${payerId}' 
        AND a."StatusFlag" = 'R' 
        AND a."BilledRateMinute" > 0 
        AND a."ShVTSTTime" < b."ShVTSTTime" 
        AND a."ShVTENTime" > b."ShVTENTime" THEN TIMESTAMPDIFF(
          MINUTE, b."ShVTSTTime", b."ShVTENTime"
        ) * a."BilledRateMinute" ELSE 0 END
      ) AS "FinalPrice" 
    FROM 
      (
        SELECT 
          DISTINCT V1."GroupID", 
          V1."CONFLICTID", 
          V1."ShVTSTTime", 
          V1."ShVTENTime", 
          V1."BilledRateMinute", 
          V1."G_CRDATEUNIQUE", 
          TO_CHAR(
            V1."G_CRDATEUNIQUE", 'YYYY-MM-DD'
          ) AS CRDATEUNIQUE, 
          V1."PayerID" AS APID, 
          CASE WHEN V2."StatusFlag" IN('R', 'D') THEN 'R' WHEN V2."StatusFlag" IN ('N') THEN 'N' ELSE 'U' END AS "StatusFlag" 
        FROM 
          CONFLICTVISITMAPS AS V1 
          INNER JOIN CONFLICTS AS V2 ON V2."CONFLICTID" = V1."CONFLICTID" 
        WHERE 
          V1."GroupID" IN (
            SELECT 
              DISTINCT "GroupID" 
            FROM 
              CONFLICTVISITMAPS 
            WHERE 
              "PayerID" = '${payerId}' 
              AND "SchOverAnotherSchTimeFlag" = 'Y'
          )
      ) a 
      LEFT JOIN (
        SELECT 
          DISTINCT V1."GroupID", 
          V1."CONFLICTID", 
          V1."ShVTSTTime", 
          V1."ShVTENTime", 
          TO_CHAR(
            V1."G_CRDATEUNIQUE", 'YYYY-MM-DD'
          ) AS CRDATEUNIQUE, 
        FROM 
          CONFLICTVISITMAPS AS V1 
          INNER JOIN CONFLICTS AS V2 ON V2."CONFLICTID" = V1."CONFLICTID" 
        WHERE 
          V1."GroupID" IN (
            SELECT 
              DISTINCT "GroupID" 
            FROM 
              CONFLICTVISITMAPS 
            WHERE 
              "PayerID" = '${payerId}'
          )
      ) b ON a.CONFLICTID <> b.CONFLICTID 
      AND a."GroupID" = b."GroupID" 
    GROUP BY 
      a.CRDATEUNIQUE 
    UNION ALL 
    SELECT 
      '${payerId}' AS PAYERID, 
      a."CRDATEUNIQUE" AS "CRDATEUNIQUE", 
      'Visit Time Overlap' AS "ConflictType", 
      '5' AS "ConflictTypeF", 
      COUNT(DISTINCT a."GroupID") AS "Total", 
      SUM(
        CASE WHEN a.APID = '${payerId}' 
        AND a."BilledRateMinute" > 0 THEN TIMESTAMPDIFF(
          MINUTE, a."ShVTSTTime", a."ShVTENTime"
        ) * a."BilledRateMinute" ELSE 0 END
      ) AS "ShiftPrice", 
      SUM(
        CASE WHEN a.APID = '${payerId}' 
        AND a."BilledRateMinute" > 0 
        AND b."ShVTSTTime" >= a."ShVTSTTime" 
        AND b."ShVTSTTime" <= a."ShVTENTime" 
        AND b."ShVTENTime" > a."ShVTENTime" THEN TIMESTAMPDIFF(
          MINUTE, b."ShVTSTTime", a."ShVTENTime"
        ) * a."BilledRateMinute" WHEN a.APID = '${payerId}' 
        AND a."BilledRateMinute" > 0 
        AND a."ShVTSTTime" >= b."ShVTSTTime" 
        AND a."ShVTSTTime" <= b."ShVTENTime" 
        AND a."ShVTENTime" > b."ShVTENTime" THEN TIMESTAMPDIFF(
          MINUTE, a."ShVTSTTime", b."ShVTENTime"
        ) * a."BilledRateMinute" WHEN a.APID = '${payerId}' 
        AND a."BilledRateMinute" > 0 
        AND b."ShVTSTTime" >= a."ShVTSTTime" 
        AND b."ShVTENTime" <= a."ShVTENTime" THEN TIMESTAMPDIFF(
          MINUTE, b."ShVTSTTime", b."ShVTENTime"
        ) * a."BilledRateMinute" WHEN a.APID = '${payerId}' 
        AND a."BilledRateMinute" > 0 
        AND a."ShVTSTTime" >= b."ShVTSTTime" 
        AND a."ShVTENTime" <= b."ShVTENTime" THEN TIMESTAMPDIFF(
          MINUTE, a."ShVTSTTime", a."ShVTENTime"
        ) * a."BilledRateMinute" WHEN a.APID = '${payerId}' 
        AND a."BilledRateMinute" > 0 
        AND b."ShVTSTTime" < a."ShVTSTTime" 
        AND b."ShVTENTime" > a."ShVTENTime" THEN TIMESTAMPDIFF(
          MINUTE, a."ShVTSTTime", a."ShVTENTime"
        ) * a."BilledRateMinute" WHEN a.APID = '${payerId}' 
        AND a."BilledRateMinute" > 0 
        AND a."ShVTSTTime" < b."ShVTSTTime" 
        AND a."ShVTENTime" > b."ShVTENTime" THEN TIMESTAMPDIFF(
          MINUTE, b."ShVTSTTime", b."ShVTENTime"
        ) * a."BilledRateMinute" ELSE 0 END
      ) AS "OverlapPrice", 
      SUM(
        CASE WHEN a.APID = '${payerId}' 
        AND a."StatusFlag" = 'R' 
        AND a."BilledRateMinute" > 0 
        AND b."ShVTSTTime" >= a."ShVTSTTime" 
        AND b."ShVTSTTime" <= a."ShVTENTime" 
        AND b."ShVTENTime" > a."ShVTENTime" THEN TIMESTAMPDIFF(
          MINUTE, b."ShVTSTTime", a."ShVTENTime"
        ) * a."BilledRateMinute" WHEN a.APID = '${payerId}' 
        AND a."StatusFlag" = 'R' 
        AND a."BilledRateMinute" > 0 
        AND a."ShVTSTTime" >= b."ShVTSTTime" 
        AND a."ShVTSTTime" <= b."ShVTENTime" 
        AND a."ShVTENTime" > b."ShVTENTime" THEN TIMESTAMPDIFF(
          MINUTE, a."ShVTSTTime", b."ShVTENTime"
        ) * a."BilledRateMinute" WHEN a.APID = '${payerId}' 
        AND a."StatusFlag" = 'R' 
        AND a."BilledRateMinute" > 0 
        AND b."ShVTSTTime" >= a."ShVTSTTime" 
        AND b."ShVTENTime" <= a."ShVTENTime" THEN TIMESTAMPDIFF(
          MINUTE, b."ShVTSTTime", b."ShVTENTime"
        ) * a."BilledRateMinute" WHEN a.APID = '${payerId}' 
        AND a."StatusFlag" = 'R' 
        AND a."BilledRateMinute" > 0 
        AND a."ShVTSTTime" >= b."ShVTSTTime" 
        AND a."ShVTENTime" <= b."ShVTENTime" THEN TIMESTAMPDIFF(
          MINUTE, a."ShVTSTTime", a."ShVTENTime"
        ) * a."BilledRateMinute" WHEN a.APID = '${payerId}' 
        AND a."StatusFlag" = 'R' 
        AND a."BilledRateMinute" > 0 
        AND b."ShVTSTTime" < a."ShVTSTTime" 
        AND b."ShVTENTime" > a."ShVTENTime" THEN TIMESTAMPDIFF(
          MINUTE, a."ShVTSTTime", a."ShVTENTime"
        ) * a."BilledRateMinute" WHEN a.APID = '${payerId}' 
        AND a."StatusFlag" = 'R' 
        AND a."BilledRateMinute" > 0 
        AND a."ShVTSTTime" < b."ShVTSTTime" 
        AND a."ShVTENTime" > b."ShVTENTime" THEN TIMESTAMPDIFF(
          MINUTE, b."ShVTSTTime", b."ShVTENTime"
        ) * a."BilledRateMinute" ELSE 0 END
      ) AS "FinalPrice" 
    FROM 
      (
        SELECT 
          DISTINCT V1."GroupID", 
          V1."CONFLICTID", 
          V1."ShVTSTTime", 
          V1."ShVTENTime", 
          V1."BilledRateMinute", 
          V1."G_CRDATEUNIQUE", 
          TO_CHAR(
            V1."G_CRDATEUNIQUE", 'YYYY-MM-DD'
          ) AS CRDATEUNIQUE, 
          V1."PayerID" AS APID, 
          CASE WHEN V2."StatusFlag" IN('R', 'D') THEN 'R' WHEN V2."StatusFlag" IN ('N') THEN 'N' ELSE 'U' END AS "StatusFlag" 
        FROM 
          CONFLICTVISITMAPS AS V1 
          INNER JOIN CONFLICTS AS V2 ON V2."CONFLICTID" = V1."CONFLICTID" 
        WHERE 
          V1."GroupID" IN (
            SELECT 
              DISTINCT "GroupID" 
            FROM 
              CONFLICTVISITMAPS 
            WHERE 
              "PayerID" = '${payerId}' 
              AND "VisitTimeOverAnotherVisitTimeFlag" = 'Y'
          )
      ) a 
      LEFT JOIN (
        SELECT 
          DISTINCT V1."GroupID", 
          V1."CONFLICTID", 
          V1."ShVTSTTime", 
          V1."ShVTENTime", 
          TO_CHAR(
            V1."G_CRDATEUNIQUE", 'YYYY-MM-DD'
          ) AS CRDATEUNIQUE, 
        FROM 
          CONFLICTVISITMAPS AS V1 
          INNER JOIN CONFLICTS AS V2 ON V2."CONFLICTID" = V1."CONFLICTID" 
        WHERE 
          V1."GroupID" IN (
            SELECT 
              DISTINCT "GroupID" 
            FROM 
              CONFLICTVISITMAPS 
            WHERE 
              "PayerID" = '${payerId}'
          )
      ) b ON a.CONFLICTID <> b.CONFLICTID 
      AND a."GroupID" = b."GroupID" 
    GROUP BY 
      a.CRDATEUNIQUE 
    UNION ALL 
    SELECT 
      '${payerId}' AS PAYERID, 
      a."CRDATEUNIQUE" AS "CRDATEUNIQUE", 
      'Schedule and Visit time overlap' AS "ConflictType", 
      '6' AS "ConflictTypeF", 
      COUNT(DISTINCT a."GroupID") AS "Total", 
      SUM(
        CASE WHEN a.APID = '${payerId}' 
        AND a."BilledRateMinute" > 0 THEN TIMESTAMPDIFF(
          MINUTE, a."ShVTSTTime", a."ShVTENTime"
        ) * a."BilledRateMinute" ELSE 0 END
      ) AS "ShiftPrice", 
      SUM(
        CASE WHEN a.APID = '${payerId}' 
        AND a."BilledRateMinute" > 0 
        AND b."ShVTSTTime" >= a."ShVTSTTime" 
        AND b."ShVTSTTime" <= a."ShVTENTime" 
        AND b."ShVTENTime" > a."ShVTENTime" THEN TIMESTAMPDIFF(
          MINUTE, b."ShVTSTTime", a."ShVTENTime"
        ) * a."BilledRateMinute" WHEN a.APID = '${payerId}' 
        AND a."BilledRateMinute" > 0 
        AND a."ShVTSTTime" >= b."ShVTSTTime" 
        AND a."ShVTSTTime" <= b."ShVTENTime" 
        AND a."ShVTENTime" > b."ShVTENTime" THEN TIMESTAMPDIFF(
          MINUTE, a."ShVTSTTime", b."ShVTENTime"
        ) * a."BilledRateMinute" WHEN a.APID = '${payerId}' 
        AND a."BilledRateMinute" > 0 
        AND b."ShVTSTTime" >= a."ShVTSTTime" 
        AND b."ShVTENTime" <= a."ShVTENTime" THEN TIMESTAMPDIFF(
          MINUTE, b."ShVTSTTime", b."ShVTENTime"
        ) * a."BilledRateMinute" WHEN a.APID = '${payerId}' 
        AND a."BilledRateMinute" > 0 
        AND a."ShVTSTTime" >= b."ShVTSTTime" 
        AND a."ShVTENTime" <= b."ShVTENTime" THEN TIMESTAMPDIFF(
          MINUTE, a."ShVTSTTime", a."ShVTENTime"
        ) * a."BilledRateMinute" WHEN a.APID = '${payerId}' 
        AND a."BilledRateMinute" > 0 
        AND b."ShVTSTTime" < a."ShVTSTTime" 
        AND b."ShVTENTime" > a."ShVTENTime" THEN TIMESTAMPDIFF(
          MINUTE, a."ShVTSTTime", a."ShVTENTime"
        ) * a."BilledRateMinute" WHEN a.APID = '${payerId}' 
        AND a."BilledRateMinute" > 0 
        AND a."ShVTSTTime" < b."ShVTSTTime" 
        AND a."ShVTENTime" > b."ShVTENTime" THEN TIMESTAMPDIFF(
          MINUTE, b."ShVTSTTime", b."ShVTENTime"
        ) * a."BilledRateMinute" ELSE 0 END
      ) AS "OverlapPrice", 
      SUM(
        CASE WHEN a.APID = '${payerId}' 
        AND a."StatusFlag" = 'R' 
        AND a."BilledRateMinute" > 0 
        AND b."ShVTSTTime" >= a."ShVTSTTime" 
        AND b."ShVTSTTime" <= a."ShVTENTime" 
        AND b."ShVTENTime" > a."ShVTENTime" THEN TIMESTAMPDIFF(
          MINUTE, b."ShVTSTTime", a."ShVTENTime"
        ) * a."BilledRateMinute" WHEN a.APID = '${payerId}' 
        AND a."StatusFlag" = 'R' 
        AND a."BilledRateMinute" > 0 
        AND a."ShVTSTTime" >= b."ShVTSTTime" 
        AND a."ShVTSTTime" <= b."ShVTENTime" 
        AND a."ShVTENTime" > b."ShVTENTime" THEN TIMESTAMPDIFF(
          MINUTE, a."ShVTSTTime", b."ShVTENTime"
        ) * a."BilledRateMinute" WHEN a.APID = '${payerId}' 
        AND a."StatusFlag" = 'R' 
        AND a."BilledRateMinute" > 0 
        AND b."ShVTSTTime" >= a."ShVTSTTime" 
        AND b."ShVTENTime" <= a."ShVTENTime" THEN TIMESTAMPDIFF(
          MINUTE, b."ShVTSTTime", b."ShVTENTime"
        ) * a."BilledRateMinute" WHEN a.APID = '${payerId}' 
        AND a."StatusFlag" = 'R' 
        AND a."BilledRateMinute" > 0 
        AND a."ShVTSTTime" >= b."ShVTSTTime" 
        AND a."ShVTENTime" <= b."ShVTENTime" THEN TIMESTAMPDIFF(
          MINUTE, a."ShVTSTTime", a."ShVTENTime"
        ) * a."BilledRateMinute" WHEN a.APID = '${payerId}' 
        AND a."StatusFlag" = 'R' 
        AND a."BilledRateMinute" > 0 
        AND b."ShVTSTTime" < a."ShVTSTTime" 
        AND b."ShVTENTime" > a."ShVTENTime" THEN TIMESTAMPDIFF(
          MINUTE, a."ShVTSTTime", a."ShVTENTime"
        ) * a."BilledRateMinute" WHEN a.APID = '${payerId}' 
        AND a."StatusFlag" = 'R' 
        AND a."BilledRateMinute" > 0 
        AND a."ShVTSTTime" < b."ShVTSTTime" 
        AND a."ShVTENTime" > b."ShVTENTime" THEN TIMESTAMPDIFF(
          MINUTE, b."ShVTSTTime", b."ShVTENTime"
        ) * a."BilledRateMinute" ELSE 0 END
      ) AS "FinalPrice" 
    FROM 
      (
        SELECT 
          DISTINCT V1."GroupID", 
          V1."CONFLICTID", 
          V1."ShVTSTTime", 
          V1."ShVTENTime", 
          V1."BilledRateMinute", 
          V1."G_CRDATEUNIQUE", 
          TO_CHAR(
            V1."G_CRDATEUNIQUE", 'YYYY-MM-DD'
          ) AS CRDATEUNIQUE, 
          V1."PayerID" AS APID, 
          CASE WHEN V2."StatusFlag" IN('R', 'D') THEN 'R' WHEN V2."StatusFlag" IN ('N') THEN 'N' ELSE 'U' END AS "StatusFlag" 
        FROM 
          CONFLICTVISITMAPS AS V1 
          INNER JOIN CONFLICTS AS V2 ON V2."CONFLICTID" = V1."CONFLICTID" 
        WHERE 
          V1."GroupID" IN (
            SELECT 
              DISTINCT "GroupID" 
            FROM 
              CONFLICTVISITMAPS 
            WHERE 
              "PayerID" = '${payerId}' 
              AND "SchTimeOverVisitTimeFlag" = 'Y'
          )
      ) a 
      LEFT JOIN (
        SELECT 
          DISTINCT V1."GroupID", 
          V1."CONFLICTID", 
          V1."ShVTSTTime", 
          V1."ShVTENTime", 
          TO_CHAR(
            V1."G_CRDATEUNIQUE", 'YYYY-MM-DD'
          ) AS CRDATEUNIQUE, 
        FROM 
          CONFLICTVISITMAPS AS V1 
          INNER JOIN CONFLICTS AS V2 ON V2."CONFLICTID" = V1."CONFLICTID" 
        WHERE 
          V1."GroupID" IN (
            SELECT 
              DISTINCT "GroupID" 
            FROM 
              CONFLICTVISITMAPS 
            WHERE 
              "PayerID" = '${payerId}'
          )
      ) b ON a.CONFLICTID <> b.CONFLICTID 
      AND a."GroupID" = b."GroupID" 
    GROUP BY 
      a.CRDATEUNIQUE 
    UNION ALL 
    SELECT 
      '${payerId}' AS PAYERID, 
      a."CRDATEUNIQUE" AS "CRDATEUNIQUE", 
      'Time- Distance' AS "ConflictType", 
      '7' AS "ConflictTypeF", 
      COUNT(DISTINCT a."GroupID") AS "Total", 
      SUM(
        CASE WHEN a.APID = '${payerId}' 
        AND a."BilledRateMinute" > 0 THEN TIMESTAMPDIFF(
          MINUTE, a."ShVTSTTime", a."ShVTENTime"
        ) * a."BilledRateMinute" ELSE 0 END
      ) AS "ShiftPrice", 
      SUM(
        CASE WHEN a.APID = '${payerId}' 
        AND a."BilledRateMinute" > 0 
        AND b."ShVTSTTime" >= a."ShVTSTTime" 
        AND b."ShVTSTTime" <= a."ShVTENTime" 
        AND b."ShVTENTime" > a."ShVTENTime" THEN TIMESTAMPDIFF(
          MINUTE, b."ShVTSTTime", a."ShVTENTime"
        ) * a."BilledRateMinute" WHEN a.APID = '${payerId}' 
        AND a."BilledRateMinute" > 0 
        AND a."ShVTSTTime" >= b."ShVTSTTime" 
        AND a."ShVTSTTime" <= b."ShVTENTime" 
        AND a."ShVTENTime" > b."ShVTENTime" THEN TIMESTAMPDIFF(
          MINUTE, a."ShVTSTTime", b."ShVTENTime"
        ) * a."BilledRateMinute" WHEN a.APID = '${payerId}' 
        AND a."BilledRateMinute" > 0 
        AND b."ShVTSTTime" >= a."ShVTSTTime" 
        AND b."ShVTENTime" <= a."ShVTENTime" THEN TIMESTAMPDIFF(
          MINUTE, b."ShVTSTTime", b."ShVTENTime"
        ) * a."BilledRateMinute" WHEN a.APID = '${payerId}' 
        AND a."BilledRateMinute" > 0 
        AND a."ShVTSTTime" >= b."ShVTSTTime" 
        AND a."ShVTENTime" <= b."ShVTENTime" THEN TIMESTAMPDIFF(
          MINUTE, a."ShVTSTTime", a."ShVTENTime"
        ) * a."BilledRateMinute" WHEN a.APID = '${payerId}' 
        AND a."BilledRateMinute" > 0 
        AND b."ShVTSTTime" < a."ShVTSTTime" 
        AND b."ShVTENTime" > a."ShVTENTime" THEN TIMESTAMPDIFF(
          MINUTE, a."ShVTSTTime", a."ShVTENTime"
        ) * a."BilledRateMinute" WHEN a.APID = '${payerId}' 
        AND a."BilledRateMinute" > 0 
        AND a."ShVTSTTime" < b."ShVTSTTime" 
        AND a."ShVTENTime" > b."ShVTENTime" THEN TIMESTAMPDIFF(
          MINUTE, b."ShVTSTTime", b."ShVTENTime"
        ) * a."BilledRateMinute" ELSE 0 END
      ) AS "OverlapPrice", 
      SUM(
        CASE WHEN a.APID = '${payerId}' 
        AND a."StatusFlag" = 'R' 
        AND a."BilledRateMinute" > 0 
        AND b."ShVTSTTime" >= a."ShVTSTTime" 
        AND b."ShVTSTTime" <= a."ShVTENTime" 
        AND b."ShVTENTime" > a."ShVTENTime" THEN TIMESTAMPDIFF(
          MINUTE, b."ShVTSTTime", a."ShVTENTime"
        ) * a."BilledRateMinute" WHEN a.APID = '${payerId}' 
        AND a."StatusFlag" = 'R' 
        AND a."BilledRateMinute" > 0 
        AND a."ShVTSTTime" >= b."ShVTSTTime" 
        AND a."ShVTSTTime" <= b."ShVTENTime" 
        AND a."ShVTENTime" > b."ShVTENTime" THEN TIMESTAMPDIFF(
          MINUTE, a."ShVTSTTime", b."ShVTENTime"
        ) * a."BilledRateMinute" WHEN a.APID = '${payerId}' 
        AND a."StatusFlag" = 'R' 
        AND a."BilledRateMinute" > 0 
        AND b."ShVTSTTime" >= a."ShVTSTTime" 
        AND b."ShVTENTime" <= a."ShVTENTime" THEN TIMESTAMPDIFF(
          MINUTE, b."ShVTSTTime", b."ShVTENTime"
        ) * a."BilledRateMinute" WHEN a.APID = '${payerId}' 
        AND a."StatusFlag" = 'R' 
        AND a."BilledRateMinute" > 0 
        AND a."ShVTSTTime" >= b."ShVTSTTime" 
        AND a."ShVTENTime" <= b."ShVTENTime" THEN TIMESTAMPDIFF(
          MINUTE, a."ShVTSTTime", a."ShVTENTime"
        ) * a."BilledRateMinute" WHEN a.APID = '${payerId}' 
        AND a."StatusFlag" = 'R' 
        AND a."BilledRateMinute" > 0 
        AND b."ShVTSTTime" < a."ShVTSTTime" 
        AND b."ShVTENTime" > a."ShVTENTime" THEN TIMESTAMPDIFF(
          MINUTE, a."ShVTSTTime", a."ShVTENTime"
        ) * a."BilledRateMinute" WHEN a.APID = '${payerId}' 
        AND a."StatusFlag" = 'R' 
        AND a."BilledRateMinute" > 0 
        AND a."ShVTSTTime" < b."ShVTSTTime" 
        AND a."ShVTENTime" > b."ShVTENTime" THEN TIMESTAMPDIFF(
          MINUTE, b."ShVTSTTime", b."ShVTENTime"
        ) * a."BilledRateMinute" ELSE 0 END
      ) AS "FinalPrice" 
    FROM 
      (
        SELECT 
          DISTINCT V1."GroupID", 
          V1."CONFLICTID", 
          V1."ShVTSTTime", 
          V1."ShVTENTime", 
          V1."BilledRateMinute", 
          V1."G_CRDATEUNIQUE", 
          TO_CHAR(
            V1."G_CRDATEUNIQUE", 'YYYY-MM-DD'
          ) AS CRDATEUNIQUE, 
          V1."PayerID" AS APID, 
          CASE WHEN V2."StatusFlag" IN('R', 'D') THEN 'R' WHEN V2."StatusFlag" IN ('N') THEN 'N' ELSE 'U' END AS "StatusFlag" 
        FROM 
          CONFLICTVISITMAPS AS V1 
          INNER JOIN CONFLICTS AS V2 ON V2."CONFLICTID" = V1."CONFLICTID" 
        WHERE 
          V1."GroupID" IN (
            SELECT 
              DISTINCT "GroupID" 
            FROM 
              CONFLICTVISITMAPS 
            WHERE 
              "PayerID" = '${payerId}' 
              AND "DistanceFlag" = 'Y'
          )
      ) a 
      LEFT JOIN (
        SELECT 
          DISTINCT V1."GroupID", 
          V1."CONFLICTID", 
          V1."ShVTSTTime", 
          V1."ShVTENTime", 
          TO_CHAR(
            V1."G_CRDATEUNIQUE", 'YYYY-MM-DD'
          ) AS CRDATEUNIQUE, 
        FROM 
          CONFLICTVISITMAPS AS V1 
          INNER JOIN CONFLICTS AS V2 ON V2."CONFLICTID" = V1."CONFLICTID" 
        WHERE 
          V1."GroupID" IN (
            SELECT 
              DISTINCT "GroupID" 
            FROM 
              CONFLICTVISITMAPS 
            WHERE 
              "PayerID" = '${payerId}'
          )
      ) b ON a.CONFLICTID <> b.CONFLICTID 
      AND a."GroupID" = b."GroupID" 
    GROUP BY 
      a.CRDATEUNIQUE 
    UNION ALL 
    SELECT 
      '${payerId}' AS PAYERID, 
      a."CRDATEUNIQUE" AS "CRDATEUNIQUE", 
      'In-Service' AS "ConflictType", 
      '8' AS "ConflictTypeF", 
      COUNT(DISTINCT a."GroupID") AS "Total", 
      SUM(
        CASE WHEN a.APID = '${payerId}' 
        AND a."BilledRateMinute" > 0 THEN TIMESTAMPDIFF(
          MINUTE, a."ShVTSTTime", a."ShVTENTime"
        ) * a."BilledRateMinute" ELSE 0 END
      ) AS "ShiftPrice", 
      SUM(
        CASE WHEN a.APID = '${payerId}' 
        AND a."BilledRateMinute" > 0 
        AND b."ShVTSTTime" >= a."ShVTSTTime" 
        AND b."ShVTSTTime" <= a."ShVTENTime" 
        AND b."ShVTENTime" > a."ShVTENTime" THEN TIMESTAMPDIFF(
          MINUTE, b."ShVTSTTime", a."ShVTENTime"
        ) * a."BilledRateMinute" WHEN a.APID = '${payerId}' 
        AND a."BilledRateMinute" > 0 
        AND a."ShVTSTTime" >= b."ShVTSTTime" 
        AND a."ShVTSTTime" <= b."ShVTENTime" 
        AND a."ShVTENTime" > b."ShVTENTime" THEN TIMESTAMPDIFF(
          MINUTE, a."ShVTSTTime", b."ShVTENTime"
        ) * a."BilledRateMinute" WHEN a.APID = '${payerId}' 
        AND a."BilledRateMinute" > 0 
        AND b."ShVTSTTime" >= a."ShVTSTTime" 
        AND b."ShVTENTime" <= a."ShVTENTime" THEN TIMESTAMPDIFF(
          MINUTE, b."ShVTSTTime", b."ShVTENTime"
        ) * a."BilledRateMinute" WHEN a.APID = '${payerId}' 
        AND a."BilledRateMinute" > 0 
        AND a."ShVTSTTime" >= b."ShVTSTTime" 
        AND a."ShVTENTime" <= b."ShVTENTime" THEN TIMESTAMPDIFF(
          MINUTE, a."ShVTSTTime", a."ShVTENTime"
        ) * a."BilledRateMinute" WHEN a.APID = '${payerId}' 
        AND a."BilledRateMinute" > 0 
        AND b."ShVTSTTime" < a."ShVTSTTime" 
        AND b."ShVTENTime" > a."ShVTENTime" THEN TIMESTAMPDIFF(
          MINUTE, a."ShVTSTTime", a."ShVTENTime"
        ) * a."BilledRateMinute" WHEN a.APID = '${payerId}' 
        AND a."BilledRateMinute" > 0 
        AND a."ShVTSTTime" < b."ShVTSTTime" 
        AND a."ShVTENTime" > b."ShVTENTime" THEN TIMESTAMPDIFF(
          MINUTE, b."ShVTSTTime", b."ShVTENTime"
        ) * a."BilledRateMinute" ELSE 0 END
      ) AS "OverlapPrice", 
      SUM(
        CASE WHEN a.APID = '${payerId}' 
        AND a."StatusFlag" = 'R' 
        AND a."BilledRateMinute" > 0 
        AND b."ShVTSTTime" >= a."ShVTSTTime" 
        AND b."ShVTSTTime" <= a."ShVTENTime" 
        AND b."ShVTENTime" > a."ShVTENTime" THEN TIMESTAMPDIFF(
          MINUTE, b."ShVTSTTime", a."ShVTENTime"
        ) * a."BilledRateMinute" WHEN a.APID = '${payerId}' 
        AND a."StatusFlag" = 'R' 
        AND a."BilledRateMinute" > 0 
        AND a."ShVTSTTime" >= b."ShVTSTTime" 
        AND a."ShVTSTTime" <= b."ShVTENTime" 
        AND a."ShVTENTime" > b."ShVTENTime" THEN TIMESTAMPDIFF(
          MINUTE, a."ShVTSTTime", b."ShVTENTime"
        ) * a."BilledRateMinute" WHEN a.APID = '${payerId}' 
        AND a."StatusFlag" = 'R' 
        AND a."BilledRateMinute" > 0 
        AND b."ShVTSTTime" >= a."ShVTSTTime" 
        AND b."ShVTENTime" <= a."ShVTENTime" THEN TIMESTAMPDIFF(
          MINUTE, b."ShVTSTTime", b."ShVTENTime"
        ) * a."BilledRateMinute" WHEN a.APID = '${payerId}' 
        AND a."StatusFlag" = 'R' 
        AND a."BilledRateMinute" > 0 
        AND a."ShVTSTTime" >= b."ShVTSTTime" 
        AND a."ShVTENTime" <= b."ShVTENTime" THEN TIMESTAMPDIFF(
          MINUTE, a."ShVTSTTime", a."ShVTENTime"
        ) * a."BilledRateMinute" WHEN a.APID = '${payerId}' 
        AND a."StatusFlag" = 'R' 
        AND a."BilledRateMinute" > 0 
        AND b."ShVTSTTime" < a."ShVTSTTime" 
        AND b."ShVTENTime" > a."ShVTENTime" THEN TIMESTAMPDIFF(
          MINUTE, a."ShVTSTTime", a."ShVTENTime"
        ) * a."BilledRateMinute" WHEN a.APID = '${payerId}' 
        AND a."StatusFlag" = 'R' 
        AND a."BilledRateMinute" > 0 
        AND a."ShVTSTTime" < b."ShVTSTTime" 
        AND a."ShVTENTime" > b."ShVTENTime" THEN TIMESTAMPDIFF(
          MINUTE, b."ShVTSTTime", b."ShVTENTime"
        ) * a."BilledRateMinute" ELSE 0 END
      ) AS "FinalPrice" 
    FROM 
      (
        SELECT 
          DISTINCT V1."GroupID", 
          V1."CONFLICTID", 
          V1."ShVTSTTime", 
          V1."ShVTENTime", 
          V1."BilledRateMinute", 
          V1."G_CRDATEUNIQUE", 
          TO_CHAR(
            V1."G_CRDATEUNIQUE", 'YYYY-MM-DD'
          ) AS CRDATEUNIQUE, 
          V1."PayerID" AS APID, 
          CASE WHEN V2."StatusFlag" IN('R', 'D') THEN 'R' WHEN V2."StatusFlag" IN ('N') THEN 'N' ELSE 'U' END AS "StatusFlag" 
        FROM 
          CONFLICTVISITMAPS AS V1 
          INNER JOIN CONFLICTS AS V2 ON V2."CONFLICTID" = V1."CONFLICTID" 
        WHERE 
          V1."GroupID" IN (
            SELECT 
              DISTINCT "GroupID" 
            FROM 
              CONFLICTVISITMAPS 
            WHERE 
              "PayerID" = '${payerId}' 
              AND "InServiceFlag" = 'Y'
          )
      ) a 
      LEFT JOIN (
        SELECT 
          DISTINCT V1."GroupID", 
          V1."CONFLICTID", 
          V1."ShVTSTTime", 
          V1."ShVTENTime", 
          TO_CHAR(
            V1."G_CRDATEUNIQUE", 'YYYY-MM-DD'
          ) AS CRDATEUNIQUE, 
        FROM 
          CONFLICTVISITMAPS AS V1 
          INNER JOIN CONFLICTS AS V2 ON V2."CONFLICTID" = V1."CONFLICTID" 
        WHERE 
          V1."GroupID" IN (
            SELECT 
              DISTINCT "GroupID" 
            FROM 
              CONFLICTVISITMAPS 
            WHERE 
              "PayerID" = '${payerId}'
          )
      ) b ON a.CONFLICTID <> b.CONFLICTID 
      AND a."GroupID" = b."GroupID" 
    GROUP BY 
      a.CRDATEUNIQUE 
    UNION ALL 
    SELECT 
      '${payerId}' AS PAYERID, 
      a."CRDATEUNIQUE" AS "CRDATEUNIQUE", 
      'PTO' AS "ConflictType", 
      '9' AS "ConflictTypeF", 
      COUNT(DISTINCT a."GroupID") AS "Total", 
      SUM(
        CASE WHEN a.APID = '${payerId}' 
        AND a."BilledRateMinute" > 0 THEN TIMESTAMPDIFF(
          MINUTE, a."ShVTSTTime", a."ShVTENTime"
        ) * a."BilledRateMinute" ELSE 0 END
      ) AS "ShiftPrice", 
      SUM(
        CASE WHEN a.APID = '${payerId}' 
        AND a."BilledRateMinute" > 0 
        AND b."ShVTSTTime" >= a."ShVTSTTime" 
        AND b."ShVTSTTime" <= a."ShVTENTime" 
        AND b."ShVTENTime" > a."ShVTENTime" THEN TIMESTAMPDIFF(
          MINUTE, b."ShVTSTTime", a."ShVTENTime"
        ) * a."BilledRateMinute" WHEN a.APID = '${payerId}' 
        AND a."BilledRateMinute" > 0 
        AND a."ShVTSTTime" >= b."ShVTSTTime" 
        AND a."ShVTSTTime" <= b."ShVTENTime" 
        AND a."ShVTENTime" > b."ShVTENTime" THEN TIMESTAMPDIFF(
          MINUTE, a."ShVTSTTime", b."ShVTENTime"
        ) * a."BilledRateMinute" WHEN a.APID = '${payerId}' 
        AND a."BilledRateMinute" > 0 
        AND b."ShVTSTTime" >= a."ShVTSTTime" 
        AND b."ShVTENTime" <= a."ShVTENTime" THEN TIMESTAMPDIFF(
          MINUTE, b."ShVTSTTime", b."ShVTENTime"
        ) * a."BilledRateMinute" WHEN a.APID = '${payerId}' 
        AND a."BilledRateMinute" > 0 
        AND a."ShVTSTTime" >= b."ShVTSTTime" 
        AND a."ShVTENTime" <= b."ShVTENTime" THEN TIMESTAMPDIFF(
          MINUTE, a."ShVTSTTime", a."ShVTENTime"
        ) * a."BilledRateMinute" WHEN a.APID = '${payerId}' 
        AND a."BilledRateMinute" > 0 
        AND b."ShVTSTTime" < a."ShVTSTTime" 
        AND b."ShVTENTime" > a."ShVTENTime" THEN TIMESTAMPDIFF(
          MINUTE, a."ShVTSTTime", a."ShVTENTime"
        ) * a."BilledRateMinute" WHEN a.APID = '${payerId}' 
        AND a."BilledRateMinute" > 0 
        AND a."ShVTSTTime" < b."ShVTSTTime" 
        AND a."ShVTENTime" > b."ShVTENTime" THEN TIMESTAMPDIFF(
          MINUTE, b."ShVTSTTime", b."ShVTENTime"
        ) * a."BilledRateMinute" ELSE 0 END
      ) AS "OverlapPrice", 
      SUM(
        CASE WHEN a.APID = '${payerId}' 
        AND a."StatusFlag" = 'R' 
        AND a."BilledRateMinute" > 0 
        AND b."ShVTSTTime" >= a."ShVTSTTime" 
        AND b."ShVTSTTime" <= a."ShVTENTime" 
        AND b."ShVTENTime" > a."ShVTENTime" THEN TIMESTAMPDIFF(
          MINUTE, b."ShVTSTTime", a."ShVTENTime"
        ) * a."BilledRateMinute" WHEN a.APID = '${payerId}' 
        AND a."StatusFlag" = 'R' 
        AND a."BilledRateMinute" > 0 
        AND a."ShVTSTTime" >= b."ShVTSTTime" 
        AND a."ShVTSTTime" <= b."ShVTENTime" 
        AND a."ShVTENTime" > b."ShVTENTime" THEN TIMESTAMPDIFF(
          MINUTE, a."ShVTSTTime", b."ShVTENTime"
        ) * a."BilledRateMinute" WHEN a.APID = '${payerId}' 
        AND a."StatusFlag" = 'R' 
        AND a."BilledRateMinute" > 0 
        AND b."ShVTSTTime" >= a."ShVTSTTime" 
        AND b."ShVTENTime" <= a."ShVTENTime" THEN TIMESTAMPDIFF(
          MINUTE, b."ShVTSTTime", b."ShVTENTime"
        ) * a."BilledRateMinute" WHEN a.APID = '${payerId}' 
        AND a."StatusFlag" = 'R' 
        AND a."BilledRateMinute" > 0 
        AND a."ShVTSTTime" >= b."ShVTSTTime" 
        AND a."ShVTENTime" <= b."ShVTENTime" THEN TIMESTAMPDIFF(
          MINUTE, a."ShVTSTTime", a."ShVTENTime"
        ) * a."BilledRateMinute" WHEN a.APID = '${payerId}' 
        AND a."StatusFlag" = 'R' 
        AND a."BilledRateMinute" > 0 
        AND b."ShVTSTTime" < a."ShVTSTTime" 
        AND b."ShVTENTime" > a."ShVTENTime" THEN TIMESTAMPDIFF(
          MINUTE, a."ShVTSTTime", a."ShVTENTime"
        ) * a."BilledRateMinute" WHEN a.APID = '${payerId}' 
        AND a."StatusFlag" = 'R' 
        AND a."BilledRateMinute" > 0 
        AND a."ShVTSTTime" < b."ShVTSTTime" 
        AND a."ShVTENTime" > b."ShVTENTime" THEN TIMESTAMPDIFF(
          MINUTE, b."ShVTSTTime", b."ShVTENTime"
        ) * a."BilledRateMinute" ELSE 0 END
      ) AS "FinalPrice" 
    FROM 
      (
        SELECT 
          DISTINCT V1."GroupID", 
          V1."CONFLICTID", 
          V1."ShVTSTTime", 
          V1."ShVTENTime", 
          V1."BilledRateMinute", 
          V1."G_CRDATEUNIQUE", 
          TO_CHAR(
            V1."G_CRDATEUNIQUE", 'YYYY-MM-DD'
          ) AS CRDATEUNIQUE, 
          V1."PayerID" AS APID, 
          CASE WHEN V2."StatusFlag" IN('R', 'D') THEN 'R' WHEN V2."StatusFlag" IN ('N') THEN 'N' ELSE 'U' END AS "StatusFlag" 
        FROM 
          CONFLICTVISITMAPS AS V1 
          INNER JOIN CONFLICTS AS V2 ON V2."CONFLICTID" = V1."CONFLICTID" 
        WHERE 
          V1."GroupID" IN (
            SELECT 
              DISTINCT "GroupID" 
            FROM 
              CONFLICTVISITMAPS 
            WHERE 
              "PayerID" = '${payerId}' 
              AND "PTOFlag" = 'Y'
          )
      ) a 
      LEFT JOIN (
        SELECT 
          DISTINCT V1."GroupID", 
          V1."CONFLICTID", 
          V1."ShVTSTTime", 
          V1."ShVTENTime", 
          TO_CHAR(
            V1."G_CRDATEUNIQUE", 'YYYY-MM-DD'
          ) AS CRDATEUNIQUE, 
        FROM 
          CONFLICTVISITMAPS AS V1 
          INNER JOIN CONFLICTS AS V2 ON V2."CONFLICTID" = V1."CONFLICTID" 
        WHERE 
          V1."GroupID" IN (
            SELECT 
              DISTINCT "GroupID" 
            FROM 
              CONFLICTVISITMAPS 
            WHERE 
              "PayerID" = '${payerId}'
          )
      ) b ON a.CONFLICTID <> b.CONFLICTID 
      AND a."GroupID" = b."GroupID" 
    GROUP BY 
      a.CRDATEUNIQUE
  );
---------------------------END PAYER CON TYPE---------------------
