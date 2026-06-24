-- schema: 12 entities in 3nf/bcnf with referential integrity, check/unique constraints, innodb for acid support
drop database if exists pharmasafe;
create database pharmasafe
    character set utf8mb4
    collate utf8mb4_unicode_ci;
use pharmasafe;
-- drug therapeutic categories
create table category (
    categoryid      int auto_increment primary key,
    categoryname    varchar(80)  not null unique,
    description     varchar(255),
    createdat       datetime     not null default current_timestamp
) engine=innodb;
-- master catalog of all drugs
create table drug (
    drugid          int auto_increment primary key,
    genericname     varchar(120) not null,
    brandname       varchar(120),
    categoryid      int          not null,
    dosageform      enum('tablet','capsule','syrup','injection','cream','drops','inhaler') not null,
    strength        varchar(40)  not null,
    approvalstatus  enum('approved','pending','withdrawn') not null default 'approved',
    unitprice       decimal(10,2) not null,
    constraint fk_drug_category
        foreign key (categoryid) references category(categoryid)
        on delete restrict on update cascade,
    constraint chk_drug_price check (unitprice >= 0),
    constraint uq_drug_generic_strength unique (genericname, strength, dosageform)
) engine=innodb;
create index idx_drug_generic on drug(genericname);
create index idx_drug_brand on drug(brandname);
-- active ingredients contained within drugs
create table ingredient (
    ingredientid    int auto_increment primary key,
    ingredientname  varchar(120) not null unique,
    molecularweight decimal(8,2),
    constraint chk_ingredient_mw check (molecularweight is null or molecularweight > 0)
) engine=innodb;
-- m:n bridge resolving drug-to-ingredient relationship
create table drugingredient (
    drugid          int not null,
    ingredientid    int not null,
    amountmg        decimal(10,3) not null,
    primary key (drugid, ingredientid),
    constraint fk_di_drug
        foreign key (drugid) references drug(drugid)
        on delete cascade on update cascade,
    constraint fk_di_ing
        foreign key (ingredientid) references ingredient(ingredientid)
        on delete cascade on update cascade,
    constraint chk_di_amount check (amountmg > 0)
) engine=innodb;
-- self-referencing m:n on drug storing known dangerous pairings
create table interaction (
    interactionid            int auto_increment primary key,
    drugid_a                 int not null,
    drugid_b                 int not null,
    severitylevel            enum('minor','moderate','severe','contraindicated') not null,
    mechanismdescription     varchar(500),
    clinicaleffect           varchar(500),
    managementrecommendation varchar(500),
    constraint fk_int_a foreign key (drugid_a) references drug(drugid)
        on delete cascade on update cascade,
    constraint fk_int_b foreign key (drugid_b) references drug(drugid)
        on delete cascade on update cascade,
    constraint uq_int_pair unique (drugid_a, drugid_b),
    constraint chk_int_distinct check (drugid_a <> drugid_b)
) engine=innodb;
create index idx_int_severity on interaction(severitylevel);
-- prescribing doctors
create table doctor (
    doctorid        int auto_increment primary key,
    fullname        varchar(120) not null,
    specialization  varchar(80)  not null,
    licenseno       varchar(40)  not null unique,
    phone           varchar(20)
) engine=innodb;
-- registered patients
create table patient (
    patientid       int auto_increment primary key,
    fullname        varchar(120) not null,
    dob             date         not null,
    gender          enum('male','female','other') not null,
    phone           varchar(20),
    allergies       varchar(255)
) engine=innodb;
-- dob <= current_date enforced by trigger trg_patient_dob_check (mysql 8 disallows current_date in check constraints)
-- pharmacy branch locations
create table pharmacybranch (
    branchid        int auto_increment primary key,
    branchname      varchar(80)  not null unique,
    city            varchar(60)  not null,
    address         varchar(200) not null,
    phone           varchar(20)
) engine=innodb;
-- prescription header linking patient, doctor, and branch
create table prescription (
    prescriptionid  int auto_increment primary key,
    patientid       int not null,
    doctorid        int not null,
    branchid        int not null,
    prescribedon    datetime not null default current_timestamp,
    notes           varchar(500),
    constraint fk_pres_patient foreign key (patientid) references patient(patientid)
        on delete cascade on update cascade,
    constraint fk_pres_doctor  foreign key (doctorid)  references doctor(doctorid)
        on delete restrict on update cascade,
    constraint fk_pres_branch  foreign key (branchid)  references pharmacybranch(branchid)
        on delete restrict on update cascade
) engine=innodb;
create index idx_pres_patient on prescription(patientid);
create index idx_pres_date on prescription(prescribedon);
-- each line item is one drug on a prescription; trigger fills alertlevel
create table prescriptionitem (
    itemid          int auto_increment primary key,
    prescriptionid  int not null,
    drugid          int not null,
    quantity        int not null,
    durationdays    int not null,
    dispensed       boolean not null default false,
    alertlevel      enum('none','minor','moderate','severe','contraindicated') not null default 'none',
    constraint fk_pi_pres foreign key (prescriptionid) references prescription(prescriptionid)
        on delete cascade on update cascade,
    constraint fk_pi_drug foreign key (drugid) references drug(drugid)
        on delete restrict on update cascade,
    constraint chk_pi_qty check (quantity > 0),
    constraint chk_pi_duration check (durationdays > 0)
) engine=innodb;
create index idx_pi_drug on prescriptionitem(drugid);
-- per-branch stock counts
create table inventory (
    inventoryid     int auto_increment primary key,
    branchid        int not null,
    drugid          int not null,
    quantityinstock int not null,
    reorderlevel    int not null,
    lastupdated     datetime not null default current_timestamp,
    constraint fk_inv_branch foreign key (branchid) references pharmacybranch(branchid)
        on delete cascade on update cascade,
    constraint fk_inv_drug   foreign key (drugid)   references drug(drugid)
        on delete cascade on update cascade,
    constraint uq_inv_branch_drug unique (branchid, drugid),
    constraint chk_inv_stock check (quantityinstock >= 0),
    constraint chk_inv_reorder check (reorderlevel >= 0)
) engine=innodb;
-- audit log for every dispense action
create table dispensinglog (
    logid           int auto_increment primary key,
    itemid          int not null,
    branchid        int not null,
    dispensedqty    int not null,
    dispensedon     datetime not null default current_timestamp,
    pharmacistname  varchar(120) not null,
    constraint fk_log_item   foreign key (itemid)   references prescriptionitem(itemid)
        on delete cascade on update cascade,
    constraint fk_log_branch foreign key (branchid) references pharmacybranch(branchid)
        on delete restrict on update cascade,
    constraint chk_log_qty   check (dispensedqty > 0)
) engine=innodb;
create index idx_log_branch_date on dispensinglog(branchid, dispensedon);
-- side-effect sink populated by the restock trigger on inventory
create table restockalert (
    alertid         int auto_increment primary key,
    inventoryid     int not null,
    alertedat       datetime not null default current_timestamp,
    message         varchar(255) not null,
    resolved        boolean not null default false,
    constraint fk_ra_inv foreign key (inventoryid) references inventory(inventoryid)
        on delete cascade on update cascade
) engine=innodb;
