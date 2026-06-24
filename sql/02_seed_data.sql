-- seed: inserts reference data for categories, drugs, ingredients, doctors, patients, branches, inventory, interactions, prescriptions, and dispensing logs
use pharmasafe;
-- categories
insert into category (categoryname, description) values
('antibiotic',        'treats bacterial infections'),
('analgesic',         'pain relief medications'),
('antihypertensive',  'lowers blood pressure'),
('anticoagulant',     'prevents blood clot formation'),
('antidiabetic',      'manages blood glucose levels'),
('antidepressant',    'treats mood disorders'),
('antacid',           'reduces stomach acid'),
('statin',            'lowers cholesterol'),
('nsaid',             'non-steroidal anti-inflammatory'),
('benzodiazepine',    'sedative / anxiolytic class');
-- drugs
insert into drug (genericname, brandname, categoryid, dosageform, strength, approvalstatus, unitprice) values
('warfarin',      'coumadin',   4, 'tablet',  '5mg',   'approved', 25.00),
('aspirin',       'disprin',    9, 'tablet',  '300mg', 'approved',  3.50),
('ibuprofen',     'brufen',     9, 'tablet',  '400mg', 'approved',  4.00),
('amoxicillin',   'amoxil',     1, 'capsule', '500mg', 'approved', 12.00),
('metformin',     'glucophage', 5, 'tablet',  '500mg', 'approved',  8.50),
('lisinopril',    'zestril',    3, 'tablet',  '10mg',  'approved', 14.00),
('simvastatin',   'zocor',      8, 'tablet',  '20mg',  'approved', 18.00),
('clarithromycin','klaricid',   1, 'tablet',  '500mg', 'approved', 30.00),
('diazepam',      'valium',    10, 'tablet',  '5mg',   'approved', 11.00),
('fluoxetine',    'prozac',     6, 'capsule', '20mg',  'approved', 22.00),
('omeprazole',    'losec',      7, 'capsule', '20mg',  'approved',  9.00),
('paracetamol',   'panadol',    2, 'tablet',  '500mg', 'approved',  2.00);
-- active ingredients
insert into ingredient (ingredientname, molecularweight) values
('warfarin sodium',      330.31),
('acetylsalicylic acid', 180.16),
('ibuprofen',            206.28),
('amoxicillin trihydrate',419.45),
('metformin hcl',        165.62),
('lisinopril dihydrate', 441.52),
('simvastatin',          418.57),
('clarithromycin',       747.95),
('diazepam',             284.74),
('fluoxetine hcl',       345.79),
('omeprazole',           345.42),
('paracetamol',          151.16);
-- drug-ingredient bridge
insert into drugingredient (drugid, ingredientid, amountmg) values
(1, 1, 5),    (2, 2, 300),  (3, 3, 400),  (4, 4, 500),
(5, 5, 500),  (6, 6, 10),   (7, 7, 20),   (8, 8, 500),
(9, 9, 5),    (10,10,20),   (11,11,20),   (12,12,500);
-- doctors
insert into doctor (fullname, specialization, licenseno, phone) values
('dr. asad mahmood',  'cardiology',      'pmc-1001-a', '0300-1111111'),
('dr. sara khan',     'general practice','pmc-1002-b', '0300-2222222'),
('dr. hassan raza',   'endocrinology',   'pmc-1003-c', '0300-3333333'),
('dr. ayesha tariq',  'psychiatry',      'pmc-1004-d', '0300-4444444'),
('dr. bilal ahmed',   'gastroenterology','pmc-1005-e', '0300-5555555');
-- patients
insert into patient (fullname, dob, gender, phone, allergies) values
('ahmed khan',   '1965-04-12','male',  '0301-1010101','penicillin'),
('fatima bibi',  '1972-09-23','female','0301-2020202',null),
('usman tariq',  '1980-01-30','male',  '0301-3030303','sulfa drugs'),
('hira sheikh',  '1990-07-18','female','0301-4040404',null),
('imran yousaf', '1955-12-05','male',  '0301-5050505','aspirin'),
('sana malik',   '1988-03-22','female','0301-6060606',null),
('bilal hussain','1975-11-09','male',  '0301-7070707',null),
('zara iqbal',   '1995-06-14','female','0301-8080808','latex');
-- pharmacy branches
insert into pharmacybranch (branchname, city, address, phone) values
('pharmasafe blue area', 'islamabad',  'plot 22, blue area',       '051-1111000'),
('pharmasafe f-7',       'islamabad',  'jinnah super market, f-7', '051-2222000'),
('pharmasafe saddar',    'rawalpindi', 'bank road, saddar',        '051-3333000');
-- inventory per branch
insert into inventory (branchid, drugid, quantityinstock, reorderlevel) values
(1, 1, 120, 30),  (1, 2, 400, 60),  (1, 3, 350, 50),  (1, 4, 200, 40),
(1, 5, 280, 50),  (1, 6, 90,  25),  (1, 7, 75,  20),  (1, 8, 60,  20),
(1, 9, 110, 30),  (1, 10,140, 30),  (1, 11,260, 40),  (1, 12,500, 80),
(2, 1, 80,  30),  (2, 2, 300, 60),  (2, 3, 220, 50),  (2, 4, 150, 40),
(2, 5, 180, 50),  (2, 6, 60,  25),  (2, 7, 45,  20),  (2, 8, 40,  20),
(2, 9, 70,  30),  (2, 10,95,  30),  (2, 11,200, 40),  (2, 12,420, 80),
(3, 1, 25,  30),  (3, 2, 150, 60),  (3, 3, 18,  50),  (3, 4, 100, 40),
(3, 5, 130, 50),  (3, 6, 22,  25),  (3, 7, 30,  20),  (3, 8, 35,  20),
(3, 9, 50,  30),  (3, 10,60,  30),  (3, 11,180, 40),  (3, 12,300, 80);
-- clinically documented drug interaction pairs
insert into interaction
(drugid_a, drugid_b, severitylevel, mechanismdescription, clinicaleffect, managementrecommendation) values
(1, 2, 'severe',         'both drugs increase bleeding risk via different pathways',
                         'major haemorrhage; gi bleeding',
                         'avoid combination; if essential, monitor inr closely'),
(1, 3, 'severe',         'nsaid displaces warfarin from plasma proteins; inhibits platelets',
                         'increased anticoagulant effect; bleeding',
                         'avoid; prefer paracetamol for analgesia'),
(1, 8, 'severe',         'clarithromycin is a cyp3a4 inhibitor, raises warfarin levels',
                         'elevated inr; bleeding risk',
                         'avoid combination or reduce warfarin dose under monitoring'),
(2, 3, 'moderate',       'both nsaids/antiplatelet - additive gi irritation',
                         'increased risk of gastric ulcer / bleeding',
                         'use lowest effective dose; add ppi if both required'),
(7, 8, 'contraindicated','clarithromycin strongly inhibits cyp3a4 metabolism of simvastatin',
                         'severe rhabdomyolysis risk',
                         'absolute contraindication - never co-prescribe'),
(9, 10,'severe',         'additive cns depression; serotonergic effects',
                         'profound sedation, respiratory depression',
                         'avoid; if both required, monitor in supervised setting'),
(6, 5, 'moderate',       'both lower blood pressure / glucose, additive hypotension',
                         'symptomatic hypotension; dizziness',
                         'monitor bp regularly during titration'),
(11,1, 'moderate',       'omeprazole inhibits warfarin metabolism (cyp2c19)',
                         'mildly elevated inr',
                         'monitor inr when starting/stopping omeprazole'),
(3, 6, 'moderate',       'nsaid reduces antihypertensive effect of ace inhibitors',
                         'reduced bp control; possible kidney injury',
                         'monitor bp and renal function; consider paracetamol'),
(12,1, 'minor',          'high dose paracetamol may modestly elevate inr',
                         'slight inr elevation at >2g/day chronic use',
                         'monitor inr with prolonged paracetamol use'),
(4, 1, 'minor',          'antibiotic alters gut flora producing vitamin k',
                         'possible mild inr rise',
                         'monitor inr if course exceeds 7 days');
-- sample prescriptions for query demos
insert into prescription (patientid, doctorid, branchid, prescribedon, notes) values
(1, 1, 1, '2026-04-01 10:00:00', 'post-mi follow-up'),
(2, 2, 1, '2026-04-02 11:15:00', 'routine check'),
(3, 3, 2, '2026-04-03 09:30:00', 'diabetes management'),
(4, 4, 2, '2026-04-04 14:00:00', 'anxiety / depression'),
(5, 1, 3, '2026-04-05 16:20:00', 'hypertension'),
(6, 2, 1, '2026-04-06 10:45:00', 'pain management'),
(7, 5, 3, '2026-04-07 12:00:00', 'gerd'),
(8, 2, 2, '2026-04-08 13:30:00', 'infection');
-- prescription line items; alertlevel pre-filled for bootstrap (trigger sets it on live inserts)
insert into prescriptionitem
(prescriptionid, drugid, quantity, durationdays, dispensed, alertlevel) values
(1, 1,  30, 30, true,  'none'),
(1, 12, 20, 10, true,  'minor'),
(2, 4,  21,  7, true,  'none'),
(2, 12, 10,  5, true,  'none'),
(3, 5,  60, 30, true,  'none'),
(3, 6,  30, 30, true,  'moderate'),
(4, 10, 30, 30, true,  'none'),
(4, 9,  14, 14, false, 'severe'),
(5, 6,  30, 30, true,  'none'),
(5, 3,  20, 10, false, 'moderate'),
(6, 2,  30, 15, true,  'none'),
(6, 3,  30, 15, false, 'moderate'),
(7, 11, 28, 28, true,  'none'),
(8, 8,  14,  7, false, 'contraindicated'),
(8, 7,  30, 30, false, 'contraindicated');
-- dispensing log entries for analytics demos
insert into dispensinglog (itemid, branchid, dispensedqty, pharmacistname) values
(1,  1, 30, 'pharmacist ali'),
(2,  1, 20, 'pharmacist ali'),
(3,  1, 21, 'pharmacist sana'),
(4,  1, 10, 'pharmacist sana'),
(5,  2, 60, 'pharmacist omar'),
(6,  2, 30, 'pharmacist omar'),
(7,  2, 30, 'pharmacist sana'),
(9,  3, 30, 'pharmacist hina'),
(11, 1, 30, 'pharmacist ali'),
(13, 3, 28, 'pharmacist hina');