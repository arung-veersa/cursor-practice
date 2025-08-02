WITH unique_groups AS (
  SELECT DISTINCT "GroupID"
  FROM CONFLICTVISITMAPS
  WHERE "PayerID" = '${payerId}'
    AND (
      "DistanceFlag" = 'Y' OR
      "SameSchTimeFlag" = 'Y' OR
      "SameVisitTimeFlag" = 'Y' OR
      "SchAndVisitTimeSameFlag" = 'Y' OR
      "SchOverAnotherSchTimeFlag" = 'Y' OR
      "VisitTimeOverAnotherVisitTimeFlag" = 'Y' OR
      "SchTimeOverVisitTimeFlag" = 'Y'
    )
),
base AS (
  SELECT
    DISTINCT V1."GroupID",
    V1."CONFLICTID",
    V1."ShVTSTTime",
    V1."ShVTENTime",
    V1."BilledRateMinute",
    TO_CHAR(V1."G_CRDATEUNIQUE", 'YYYY-MM-DD') AS CRDATEUNIQUE,
    V1."PayerID" AS APID
  FROM CONFLICTVISITMAPS AS V1
  INNER JOIN CONFLICTS AS V2 ON V2."CONFLICTID" = V1."CONFLICTID"
  WHERE V1."GroupID" IN (SELECT "GroupID" FROM unique_groups)
)
SELECT
  '${payerId}' AS PAYERID,
  a."CRDATEUNIQUE" AS "CRDATEUNIQUE",
  'Both' AS "ConflictType",
  '500' AS "ConflictTypeCode",
  COUNT(DISTINCT a."GroupID") AS "Total",
  SUM(
    CASE WHEN a.APID = '${payerId}'
    AND a."BilledRateMinute" > 0 THEN TIMESTAMPDIFF(
      MINUTE, a."ShVTSTTime", a."ShVTENTime"
    ) * a."BilledRateMinute" ELSE 0 END
  ) AS "ShiftPrice"
FROM base a
WHERE a."GroupID" IN (
  SELECT "GroupID" FROM CONFLICTVISITMAPS
  WHERE "PayerID" = '${payerId}'
    AND ("SameSchTimeFlag" = 'Y' OR
         "SameVisitTimeFlag" = 'Y' OR
         "SchAndVisitTimeSameFlag" = 'Y' OR
         "SchOverAnotherSchTimeFlag" = 'Y' OR
         "VisitTimeOverAnotherVisitTimeFlag" = 'Y' OR
         "SchTimeOverVisitTimeFlag" = 'Y') AND "DistanceFlag" = 'Y'
)
GROUP BY a.CRDATEUNIQUE
UNION ALL
SELECT
  '${payerId}' AS PAYERID,
  a."CRDATEUNIQUE" AS "CRDATEUNIQUE",
  'Time Distance Only' AS "ConflictType",
  '200' AS "ConflictTypeCode",
  COUNT(DISTINCT a."GroupID") AS "Total",
  SUM(
    CASE WHEN a.APID = '${payerId}'
    AND a."BilledRateMinute" > 0 THEN TIMESTAMPDIFF(
      MINUTE, a."ShVTSTTime", a."ShVTENTime"
    ) * a."BilledRateMinute" ELSE 0 END
  ) AS "ShiftPrice"
FROM base a
WHERE a."GroupID" IN (
  SELECT "GroupID" FROM CONFLICTVISITMAPS
  WHERE "PayerID" = '${payerId}'
    AND "DistanceFlag" = 'Y' AND "SameSchTimeFlag" = 'N' AND
         "SameVisitTimeFlag" = 'N' AND
         "SchAndVisitTimeSameFlag" = 'N' AND
         "SchOverAnotherSchTimeFlag" = 'N' AND
         "VisitTimeOverAnotherVisitTimeFlag" = 'N' AND
         "SchTimeOverVisitTimeFlag" = 'N'
)
GROUP BY a.CRDATEUNIQUE 
UNION ALL
SELECT
  '${payerId}' AS PAYERID,
  a."CRDATEUNIQUE" AS "CRDATEUNIQUE",
  'Time Overlap Only' AS "ConflictType",
  '300' AS "ConflictTypeCode",
  COUNT(DISTINCT a."GroupID") AS "Total",
  SUM(
    CASE WHEN a.APID = '${payerId}'
    AND a."BilledRateMinute" > 0 THEN TIMESTAMPDIFF(
      MINUTE, a."ShVTSTTime", a."ShVTENTime"
    ) * a."BilledRateMinute" ELSE 0 END
  ) AS "ShiftPrice"
FROM base a
WHERE a."GroupID" IN (
  SELECT "GroupID" FROM CONFLICTVISITMAPS
  WHERE "PayerID" = '${payerId}'
    AND ("SameSchTimeFlag" = 'Y' OR
         "SameVisitTimeFlag" = 'Y' OR
         "SchAndVisitTimeSameFlag" = 'Y' OR
         "SchOverAnotherSchTimeFlag" = 'Y' OR
         "VisitTimeOverAnotherVisitTimeFlag" = 'Y' OR
         "SchTimeOverVisitTimeFlag" = 'Y') AND "DistanceFlag" = 'N'
)
GROUP BY a.CRDATEUNIQUE;