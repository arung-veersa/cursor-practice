SELECT
	'${payerId}' AS PAYERID,
	a."CRDATEUNIQUE" AS "CRDATEUNIQUE",
	'Exact Visit Time Match' AS "ConflictType",
	'2' AS "ConflictTypeF",
	a."StatusFlag" AS "STATUSFLAG",
	CASE
		WHEN a."Billed" = 'yes' THEN 'Recovery'
		ELSE 'Avoidance'
	END AS "COSTTYPE",
	CASE
		WHEN a."VisitStartTime" IS NULL THEN 'Scheduled'
		WHEN a."VisitStartTime" IS NOT NULL
		AND a."Billed" != 'yes' THEN 'Confirmed'
		WHEN a."VisitStartTime" IS NOT NULL
		AND a."Billed" = 'yes' THEN 'Billed'
	END AS "VISITTYPE",
	COUNT(DISTINCT a."GroupID") AS "Total",
	SUM(
        CASE
            WHEN a.APID = '${payerId}' AND a."BilledRateMinute" > 0 AND a."BILLABLEMINUTESFULLSHIFT" IS NOT NULL THEN a."BILLABLEMINUTESFULLSHIFT" * a."BilledRateMinute"
            WHEN a.APID = '${payerId}' AND a."BilledRateMinute" > 0 THEN TIMESTAMPDIFF(MINUTE, a."ShVTSTTime", a."ShVTENTime") * a."BilledRateMinute"
            ELSE 0
        END
    ) AS "ShiftPrice",
	SUM(
        CASE
            WHEN a.APID = '${payerId}' AND a."BilledRateMinute" > 0 AND a."BILLABLEMINUTESOVERLAP" IS NOT NULL THEN a."BILLABLEMINUTESOVERLAP" * a."BilledRateMinute"
            WHEN a.APID = '${payerId}' AND a."BilledRateMinute" > 0 AND b."ShVTSTTime" >= a."ShVTSTTime" AND b."ShVTSTTime" <= a."ShVTENTime" AND b."ShVTENTime" > a."ShVTENTime" THEN TIMESTAMPDIFF(MINUTE, b."ShVTSTTime", a."ShVTENTime") * a."BilledRateMinute"
            WHEN a.APID = '${payerId}' AND a."BilledRateMinute" > 0 AND a."ShVTSTTime" >= b."ShVTSTTime" AND a."ShVTSTTime" <= b."ShVTENTime" AND a."ShVTENTime" > b."ShVTENTime" THEN TIMESTAMPDIFF(MINUTE, a."ShVTSTTime", b."ShVTENTime") * a."BilledRateMinute"
            WHEN a.APID = '${payerId}' AND a."BilledRateMinute" > 0 AND b."ShVTSTTime" >= a."ShVTSTTime" AND b."ShVTENTime" <= a."ShVTENTime" THEN TIMESTAMPDIFF(MINUTE, b."ShVTSTTime", b."ShVTENTime") * a."BilledRateMinute"
            WHEN a.APID = '${payerId}' AND a."BilledRateMinute" > 0 AND a."ShVTSTTime" >= b."ShVTSTTime" AND a."ShVTENTime" <= b."ShVTENTime" THEN TIMESTAMPDIFF(MINUTE, a."ShVTSTTime", a."ShVTENTime") * a."BilledRateMinute"
            WHEN a.APID = '${payerId}' AND a."BilledRateMinute" > 0 AND b."ShVTSTTime" < a."ShVTSTTime" AND b."ShVTENTime" > a."ShVTENTime" THEN TIMESTAMPDIFF(MINUTE, a."ShVTSTTime", a."ShVTENTime") * a."BilledRateMinute"
            WHEN a.APID = '${payerId}' AND a."BilledRateMinute" > 0 AND a."ShVTSTTime" < b."ShVTSTTime" AND a."ShVTENTime" > b."ShVTENTime" THEN TIMESTAMPDIFF(MINUTE, b."ShVTSTTime", b."ShVTENTime") * a."BilledRateMinute"
            ELSE 0
        END
    ) AS "OverlapPrice",
	SUM(
        CASE
            WHEN a.APID = '${payerId}' AND a."StatusFlag" = 'R' AND a."BilledRateMinute" > 0 AND a."BILLABLEMINUTESOVERLAP" IS NOT NULL THEN a."BILLABLEMINUTESOVERLAP" * a."BilledRateMinute"
            WHEN a.APID = '${payerId}' AND a."StatusFlag" = 'R' AND a."BilledRateMinute" > 0 AND b."ShVTSTTime" >= a."ShVTSTTime" AND b."ShVTSTTime" <= a."ShVTENTime" AND b."ShVTENTime" > a."ShVTENTime" THEN TIMESTAMPDIFF(MINUTE, b."ShVTSTTime", a."ShVTENTime") * a."BilledRateMinute"
            WHEN a.APID = '${payerId}' AND a."StatusFlag" = 'R' AND a."BilledRateMinute" > 0 AND a."ShVTSTTime" >= b."ShVTSTTime" AND a."ShVTSTTime" <= b."ShVTENTime" AND a."ShVTENTime" > b."ShVTENTime" THEN TIMESTAMPDIFF(MINUTE, a."ShVTSTTime", b."ShVTENTime") * a."BilledRateMinute"
            WHEN a.APID = '${payerId}' AND a."StatusFlag" = 'R' AND a."BilledRateMinute" > 0 AND b."ShVTSTTime" >= a."ShVTSTTime" AND b."ShVTENTime" <= a."ShVTENTime" THEN TIMESTAMPDIFF(MINUTE, b."ShVTSTTime", b."ShVTENTime") * a."BilledRateMinute"
            WHEN a.APID = '${payerId}' AND a."StatusFlag" = 'R' AND a."BilledRateMinute" > 0 AND a."ShVTSTTime" >= b."ShVTSTTime" AND a."ShVTENTime" <= b."ShVTENTime" THEN TIMESTAMPDIFF(MINUTE, a."ShVTSTTime", a."ShVTENTime") * a."BilledRateMinute"
            WHEN a.APID = '${payerId}' AND a."StatusFlag" = 'R' AND a."BilledRateMinute" > 0 AND b."ShVTSTTime" < a."ShVTSTTime" AND b."ShVTENTime" > a."ShVTENTime" THEN TIMESTAMPDIFF(MINUTE, a."ShVTSTTime", a."ShVTENTime") * a."BilledRateMinute"
            WHEN a.APID = '${payerId}' AND a."StatusFlag" = 'R' AND a."BilledRateMinute" > 0 AND a."ShVTSTTime" < b."ShVTSTTime" AND a."ShVTENTime" > b."ShVTENTime" THEN TIMESTAMPDIFF(MINUTE, b."ShVTSTTime", b."ShVTENTime") * a."BilledRateMinute"
            ELSE 0
        END
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
            ON
		V2."CONFLICTID" = V1."CONFLICTID"
	WHERE
		V1."GroupID" IN (
		SELECT
			DISTINCT "GroupID"
		FROM
			CONFLICTREPORT_SANDBOX.PUBLIC.CONFLICTVISITMAPS
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
		TO_CHAR(V1."G_CRDATEUNIQUE", 'YYYY-MM-DD') AS CRDATEUNIQUE
	FROM
		CONFLICTREPORT_SANDBOX.PUBLIC.CONFLICTVISITMAPS AS V1
	INNER JOIN CONFLICTREPORT_SANDBOX.PUBLIC.CONFLICTS AS V2
            ON
		V2."CONFLICTID" = V1."CONFLICTID"
	WHERE
		V1."GroupID" IN (
		SELECT
			DISTINCT "GroupID"
		FROM
			CONFLICTREPORT_SANDBOX.PUBLIC.CONFLICTVISITMAPS
		WHERE
			"PayerID" = '${payerId}'
			AND "SameVisitTimeFlag" = 'Y'
        )
) b
    ON
	a.CONFLICTID <> b.CONFLICTID
	AND a."GroupID" = b."GroupID"
GROUP BY
	a.CRDATEUNIQUE,
	a."StatusFlag",
	CASE
		WHEN a."Billed" = 'yes' THEN 'Recovery'
		ELSE 'Avoidance'
	END,
	CASE
		WHEN a."VisitStartTime" IS NULL THEN 'Scheduled'
		WHEN a."VisitStartTime" IS NOT NULL
		AND a."Billed" != 'yes' THEN 'Confirmed'
		WHEN a."VisitStartTime" IS NOT NULL
		AND a."Billed" = 'yes' THEN 'Billed'
	END