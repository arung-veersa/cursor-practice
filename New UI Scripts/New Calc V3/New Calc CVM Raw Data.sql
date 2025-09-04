-- Manual verification query built on reusable views

SET TARGET_PAYER_ID = '83828a9e-a1ad-4d29-bc4f-24be24db126f';  -- EverCare
-- SET TARGET_PAYER_ID = '042cb099-168b-4717-9bd0-936848b4fab1';  -- Able Homecare

-- verify raw data
SELECT *
FROM CONFLICTREPORT_SANDBOX.PUBLIC.V_PAYER_CONFLICTS_AGGREGATED_COMMON;
WHERE PROCESSING_PAYERID = $TARGET_PAYER_ID
ORDER BY
    "SSN",
    "GroupID",
    "CONFLICTID",
    "AppVisitID";