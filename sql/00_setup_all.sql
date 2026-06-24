-- setup: run this file to bootstrap the entire pharmasafe database
source 01_schema.sql;
source 02_seed_data.sql;
source 03_triggers.sql;
source 04_views.sql;
source 05_queries.sql;
source 06_transaction_demo.sql;
-- sanity check: verify row counts across all main tables
select 'setup complete. counts:' as status;
select 'drug' as tbl, count(*) as rowcnt from drug
union all select 'patient', count(*) from patient
union all select 'doctor', count(*) from doctor
union all select 'prescription', count(*) from prescription
union all select 'prescriptionitem', count(*) from prescriptionitem
union all select 'inventory', count(*) from inventory
union all select 'interaction', count(*) from interaction
union all select 'dispensinglog', count(*) from dispensinglog;