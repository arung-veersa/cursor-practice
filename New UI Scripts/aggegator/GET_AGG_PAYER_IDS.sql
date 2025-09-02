SELECT DISTINCT "Environment", "Aggregator Database Name"
FROM ANALYTICS_SANDBOX.BI.DIMUSER ORDER BY "Environment", "Aggregator Database Name"

CALL CONFLICTREPORT_SANDBOX.PUBLIC.GET_AGG_PAYER_IDS('AGGCLOSANDBOX');

CALL CONFLICTREPORT_SANDBOX.PUBLIC.GET_AGG_PAYER_IDS('AGGALPROD');


SELECT
	LISTAGG("Global Payer ID", ',') WITHIN GROUP (
	ORDER BY "payername")
FROM
	AGGCLOSANDBOX.PUBLIC."multipayer_payer";


create or replace procedure GET_AGG_PAYER_IDS(db_name string)
returns string
language python
runtime_version = 3.10
packages = ('snowflake-snowpark-python')
handler = 'run'
execute as caller
as
$$
def run(session, db_name: str) -> str:
    try:
        if db_name is None or str(db_name).strip() == '':
            return ''
        normalized_db = db_name if (db_name.startswith('"') and db_name.endswith('"')) else db_name.upper()
        fqn = f'{normalized_db}.PUBLIC."multipayer_payer"'
        rows = session.sql(f'''
            select listagg("Global Payer ID", ',')
            within group (order by "payername")
            from {fqn}
        ''').collect()
        if not rows:
            return ''
        val = rows[0][0]
        return '' if val is None else str(val)
    except Exception:
        return ''
$$;