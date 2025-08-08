-- CONFLICTREPORT_SANDBOX.PUBLIC.CONFLICTS definition

create or replace TABLE CONFLICTREPORT_SANDBOX.PUBLIC.CONFLICTS cluster by (CONFLICTID, "FlagForReview", "StatusFlag")(
	CONFLICTID NUMBER(38,0) NOT NULL autoincrement start 1 increment 1 noorder,
	RECORDEDDATETIME TIMESTAMP_NTZ(9) DEFAULT CURRENT_TIMESTAMP(),
	"StatusFlag" VARCHAR(5) DEFAULT 'U',
	"NoResponseFlag" VARCHAR(10),
	"NoResponseReasonID" NUMBER(38,0),
	"NoResponseTitle" VARCHAR(500),
	"NoResponseNotes" VARCHAR(500),
	"ResolveDate" TIMESTAMP_NTZ(9),
	"CreatedDate" TIMESTAMP_NTZ(9),
	"ResolvedBy" VARCHAR(200),
	"NoResponseDate" TIMESTAMP_NTZ(9),
	"FlagForReview" VARCHAR(5),
	"FlagForReviewDate" TIMESTAMP_NTZ(9),
	"UpdatedRFlag" VARCHAR(5),
	primary key (CONFLICTID)
);