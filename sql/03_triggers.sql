-- triggers: t0 dob validation, t1 interaction alert on prescription insert, t2 restock alert on inventory update, t3 stock deduction on dispense
use pharmasafe;
drop trigger if exists trg_patient_dob_check;
drop trigger if exists trg_pi_before_insert;
drop trigger if exists trg_inventory_after_update;
drop trigger if exists trg_dispensing_after_insert;
delimiter //
-- t0: blocks insertion of a patient with a future date of birth
create trigger trg_patient_dob_check
before insert on patient
for each row
begin
    if new.dob > current_date then
        signal sqlstate '45000'
        set message_text = 'date of birth cannot be in the future';
    end if;
end//
-- t1: detects drug interactions and sets alertlevel before inserting a prescription item
create trigger trg_pi_before_insert
before insert on prescriptionitem
for each row
begin
    declare v_patient   int;
    declare v_severity  varchar(20) default 'none';
    select patientid into v_patient
    from prescription
    where prescriptionid = new.prescriptionid;
    select coalesce(
               elt(max(field(i.severitylevel,
                             'minor','moderate','severe','contraindicated')),
                   'minor','moderate','severe','contraindicated'),
               'none')
    into v_severity
    from prescriptionitem pi
    join prescription p on p.prescriptionid = pi.prescriptionid
    join interaction  i on
         (i.drugid_a = new.drugid and i.drugid_b = pi.drugid)
      or (i.drugid_b = new.drugid and i.drugid_a = pi.drugid)
    where p.patientid = v_patient;
    set new.alertlevel = ifnull(v_severity, 'none');
    -- block dispensing if the combination is contraindicated
    if new.alertlevel = 'contraindicated' and new.dispensed = true then
        signal sqlstate '45000'
        set message_text = 'contraindicated drug combination - dispensing blocked';
    end if;
end//
-- t2: inserts a restock alert when inventory drops below reorder level
create trigger trg_inventory_after_update
after update on inventory
for each row
begin
    if new.quantityinstock < new.reorderlevel
       and old.quantityinstock >= old.reorderlevel then
        insert into restockalert (inventoryid, message)
        values (
            new.inventoryid,
            concat('stock fell below reorder level. current=',
                   new.quantityinstock,
                   ', reorder=', new.reorderlevel)
        );
    end if;
end//
-- t3: deducts dispensed quantity from inventory after a dispensing log row is inserted
create trigger trg_dispensing_after_insert
after insert on dispensinglog
for each row
begin
    declare v_drug int;
    select drugid into v_drug from prescriptionitem where itemid = new.itemid;
    update inventory
       set quantityinstock = quantityinstock - new.dispensedqty,
           lastupdated     = now()
     where branchid = new.branchid
       and drugid   = v_drug;
end//
delimiter ;
