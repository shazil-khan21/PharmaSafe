-- views: v1 lists active patient medications, v2 summarises severe and contraindicated drug pairs
use pharmasafe;
drop view if exists activepatientmedications;
drop view if exists severdrugpairs;
-- v1: shows each patient's current medications from prescriptions in the last 90 days
create view activepatientmedications as
select
    p.patientid,
    p.fullname            as patientname,
    p.dob,
    d.drugid,
    d.genericname,
    d.brandname,
    pi.quantity,
    pi.durationdays,
    pi.dispensed,
    pi.alertlevel,
    pr.prescribedon,
    doc.fullname          as doctorname
from patient p
join prescription      pr  on pr.patientid      = p.patientid
join prescriptionitem  pi  on pi.prescriptionid = pr.prescriptionid
join drug              d   on d.drugid          = pi.drugid
join doctor            doc on doc.doctorid      = pr.doctorid
where pr.prescribedon >= (current_date - interval 90 day);
-- v2: lists all drug pairs flagged as severe or contraindicated with clinical details
create view severedrugpairs as
select
    i.interactionid,
    a.genericname    as druga,
    b.genericname    as drugb,
    i.severitylevel,
    i.clinicaleffect,
    i.managementrecommendation
from interaction i
join drug a on a.drugid = i.drugid_a
join drug b on b.drugid = i.drugid_b
where i.severitylevel in ('severe','contraindicated');
