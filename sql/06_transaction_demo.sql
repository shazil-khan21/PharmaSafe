-- transaction demo: stored procedure dispenseitem handles dispensing atomically with full rollback on any failure
use pharmasafe;
drop procedure if exists dispenseitem;
delimiter //
create procedure dispenseitem(
    in p_item_id        int,
    in p_branch_id      int,
    in p_qty            int,
    in p_pharmacist     varchar(120)
)
begin
    declare v_alert         varchar(20);
    declare v_drug          int;
    declare v_stock         int;
    declare exit handler for sqlexception
    begin
        rollback;
        resignal;
    end;
    start transaction;
        -- re-check alert level set by trigger 1
        select alertlevel, drugid into v_alert, v_drug
        from prescriptionitem
        where itemid = p_item_id
        for update;
        if v_alert = 'contraindicated' then
            signal sqlstate '45000'
              set message_text = 'contraindicated - dispensing blocked';
        end if;
        -- confirm sufficient stock at the branch
        select quantityinstock into v_stock
        from inventory
        where branchid = p_branch_id and drugid = v_drug
        for update;
        if v_stock < p_qty then
            signal sqlstate '45000'
              set message_text = 'insufficient stock at this branch';
        end if;
        -- step a: insert dispensing log; trigger 3 will deduct stock automatically
        insert into dispensinglog (itemid, branchid, dispensedqty, pharmacistname)
        values (p_item_id, p_branch_id, p_qty, p_pharmacist);
        -- step b: mark the prescription item as dispensed
        update prescriptionitem
           set dispensed = true
         where itemid = p_item_id;
    commit;
end//
delimiter ;
-- test: call dispenseitem(10, 3, 30, 'pharmacist hina');  -- success
-- test: call dispenseitem(14, 2, 14, 'pharmacist omar');  -- blocked (contraindicated)
