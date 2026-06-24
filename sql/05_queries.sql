-- queries: six analytical queries covering joins, subqueries, group by rollup, and prescribing pattern analysis
use pharmasafe;
-- q1: full prescription print with severity flag for each line item
select
    pr.prescriptionid,
    pat.fullname              as patient,
    doc.fullname              as doctor,
    pr.prescribedon,
    d.genericname,
    d.brandname,
    pi.quantity,
    pi.durationdays,
    pi.alertlevel             as severity,
    case pi.alertlevel
        when 'contraindicated' then '[x] blocked'
        when 'severe'          then '!!  high'
        when 'moderate'        then '!   med'
        when 'minor'           then '.   low'
        else                        'ok'
    end                        as flag
from prescription      pr
join patient           pat on pat.patientid = pr.patientid
join doctor            doc on doc.doctorid  = pr.doctorid
join prescriptionitem  pi  on pi.prescriptionid = pr.prescriptionid
join drug              d   on d.drugid = pi.drugid
order by pr.prescriptionid, pi.itemid;
-- q2: ranks dangerous drug combos by how often they were co-prescribed
select
    a.genericname  as druga,
    b.genericname  as drugb,
    i.severitylevel,
    count(*)       as coprescribedtimes
from interaction i
join drug a on a.drugid = i.drugid_a
join drug b on b.drugid = i.drugid_b
join prescriptionitem pi_a on pi_a.drugid = i.drugid_a
join prescriptionitem pi_b on pi_b.drugid = i.drugid_b
                          and pi_b.prescriptionid = pi_a.prescriptionid
where i.severitylevel in ('severe','contraindicated')
group by a.genericname, b.genericname, i.severitylevel
order by coprescribedtimes desc, i.severitylevel desc;
-- q3: lists patients currently on two or more drugs with a severe or contraindicated interaction
select distinct
    p.patientid,
    p.fullname,
    p.phone
from patient p
where exists (
    select 1
    from prescriptionitem pi1
    join prescription pr1 on pr1.prescriptionid = pi1.prescriptionid
    join prescriptionitem pi2 on pi2.prescriptionid = pi1.prescriptionid
                              and pi2.drugid <> pi1.drugid
    join interaction i on
         (i.drugid_a = pi1.drugid and i.drugid_b = pi2.drugid)
      or (i.drugid_b = pi1.drugid and i.drugid_a = pi2.drugid)
    where pr1.patientid = p.patientid
      and i.severitylevel in ('severe','contraindicated')
);
-- q4: dispensing frequency report grouped by branch and drug with rollup totals
select
    coalesce(b.branchname, 'grand total') as branch,
    coalesce(d.genericname, 'all drugs')  as drug,
    sum(dl.dispensedqty)                  as totaldispensed
from dispensinglog    dl
join pharmacybranch   b  on b.branchid = dl.branchid
join prescriptionitem pi on pi.itemid  = dl.itemid
join drug             d  on d.drugid   = pi.drugid
group by b.branchname, d.genericname with rollup;
-- q5: inventory reorder report listing all drugs below reorder level ordered by urgency
select
    b.branchname,
    b.city,
    d.genericname,
    d.brandname,
    inv.quantityinstock,
    inv.reorderlevel,
    (inv.reorderlevel - inv.quantityinstock) as deficitunits
from inventory inv
join pharmacybranch b on b.branchid = inv.branchid
join drug           d on d.drugid   = inv.drugid
where inv.quantityinstock < inv.reorderlevel
order by b.branchname, deficitunits desc;
-- q6: doctor prescribing patterns showing unique drugs, total items, and high-severity percentage
select
    doc.fullname                                    as doctor,
    doc.specialization,
    count(distinct pi.drugid)                       as uniquedrugs,
    count(pi.itemid)                                as totallineitems,
    sum(case when pi.alertlevel in ('severe','contraindicated')
             then 1 else 0 end)                     as highseverityitems,
    round(100.0 *
          sum(case when pi.alertlevel in ('severe','contraindicated')
                   then 1 else 0 end) / count(pi.itemid),
          2)                                        as highseveritypct
from doctor doc
join prescription pr on pr.doctorid = doc.doctorid
join prescriptionitem pi on pi.prescriptionid = pr.prescriptionid
group by doc.doctorid, doc.fullname, doc.specialization
order by highseveritypct desc;
