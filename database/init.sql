drop table if exists Deliveries cascade;
drop table if exists PTWorkSchedules cascade;
drop table if exists FTWorkSchedules cascade;
drop table if exists WorkSchedules cascade;
drop table if exists PTRiders cascade;
drop table if exists FTRiders cascade;
drop table if exists Riders cascade;
drop table if exists FoodOrders cascade;
drop table if exists Orders cascade;
drop table if exists Food cascade;
drop table if exists RPromos cascade;
drop table if exists FDSPromos cascade;
drop table if exists FDSManagers cascade;
drop table if exists Promos cascade;
drop table if exists Restaurants cascade;
drop table if exists RestaurantStaff cascade;
drop table if exists Customers cascade;
drop table if exists Users cascade;

create table Users (
    uid         serial primary key,
    name        varchar(30) NOT NULL,
    username    varchar(20) NOT NULL,
    password    varchar(20) NOT NULL,
    contact     char(8)     NOT NULL,
    email       varchar(40),
    date_joined timestamp
);

create table Customers (
    uid         integer primary key references Users on delete cascade,
    address     varchar(60) NOT NULL,
    card_number char(16),
    cvc         char(3),
    default_payment integer,
    acc_points  integer
);

create table Restaurants (
    rid         serial primary key,
    name        varchar(30) NOT NULL,
    address     varchar(60) NOT NULL,
    min_amt_threshold integer
);

create table RestaurantStaff (
    uid         integer primary key references Users on delete cascade,
    rid         integer not null,
    foreign key (rid) references Restaurants on delete cascade
);

create table Promos (
    pid         serial primary key,
    start_date  date  NOT NULL,
    end_date    date  NOT NULL,
    promo_type  integer,
    discount    integer
);

create table FDSManagers (
    uid         integer primary key references Users on delete cascade
);

create table FDSPromos (
    pid         integer primary key references Promos on delete cascade,
    uid         integer references FDSManagers
);

create table RPromos (
    pid         integer primary key references Promos on delete cascade,
    uid         integer references RestaurantStaff
);

create table Food (
    fid         serial primary key,
    rid         integer not null,
    name        varchar(30) not null,
    category    varchar(30),
    price       decimal(38,2),
    food_limit  integer,
    foreign key (rid) references Restaurants on delete cascade
);

create table Orders (
    oid         serial primary key,
    uid         integer not null,
    pid         integer,
    order_time  timestamp,
    payment_type integer,
    used_points integer,
    review      varchar(150),
    foreign key (uid) references Customers on delete cascade,
    foreign key (pid) references Promos
);

create table FoodOrders (
    fid         integer not null,
    oid         integer references Orders on delete cascade,
    qty         integer,
    primary key (fid, oid),
    foreign key (fid) references Food on delete cascade
);

create table Riders (
    uid         integer primary key references Users on delete cascade
);

create table FTRiders (
    uid         integer primary key references Riders on delete cascade,
    monthly_base_salary integer
);

create table PTRiders (
    uid         integer primary key references Riders on delete cascade,
    weekly_base_salary integer
);

create table WorkSchedules (
    wid         serial primary key
);

create table FTWorkSchedules (
    wid         integer primary key references WorkSchedules on delete cascade,
    uid         integer not null,
    day_option  smallint not null
                check (day_option in (1,2,3,4,5,6,7)),
    D1          smallint not null,
    D2          smallint not null,
    D3          smallint not null, 
    D4          smallint not null,
    D5          smallint not null,
    date_created timestamp,
    foreign key (uid) references Users on delete cascade
);

create table PTWorkSchedules (
    wid         integer primary key references WorkSchedules on delete cascade,
    uid         integer not null,
    work_date   date,
    start_time  time,
    end_time    time,
    foreign key (uid) references Users on delete cascade
);

create table Deliveries (
    oid         integer primary key references Orders,
    uid         integer not null,
    rating      varchar(150),
    t1          timestamp,
    t2          timestamp,
    t3          timestamp,
    t4          timestamp,
    -- t1 = depart for restaurant
    -- t2 = arrive at restaurant
    -- t3 = depart for location
    -- t4 = arrive at location
    -- remember to indicate and explain in appendix or report
    foreign key (uid) references Riders
);

create or replace function NewCustomer(name varchar(30), username varchar(20), password varchar(20), contact char(8), email varchar(40),
                                        address varchar(60), card_number char(16), cvc char(3), default_payment int)
RETURNS void AS $$
with rows as (
    INSERT INTO Users(name, username, password, contact, email, date_joined)
    VALUES (name, username, password, contact, email, now()) RETURNING uid
),
content as (
    SELECT address AS address, card_number AS card_number, cvc AS cvc, default_payment AS default_payment
)
INSERT INTO Customers(uid, address, card_number, cvc, default_payment, acc_points)
    SELECT uid, address, card_number, cvc, default_payment, 0
    FROM rows, content;
$$ language sql;

create or replace function NewRestaurantStaff(name varchar(30), username varchar(20), password varchar(20), contact char(8), email varchar(40),
                                        rid int)
RETURNS void AS $$
with rows as (
    INSERT INTO Users(name, username, password, contact, email, date_joined)
    VALUES (name, username, password, contact, email, now()) RETURNING uid
),
content as (SELECT rid AS rid)
INSERT INTO RestaurantStaff(uid, rid)
    SELECT uid, rid
    FROM rows, content;
$$ language sql;

create or replace function NewFDSManager(name varchar(30), username varchar(20), password varchar(20), contact char(8), email varchar(40))
RETURNS void AS $$
with rows as (
    INSERT INTO Users(name, username, password, contact, email, date_joined)
    VALUES (name, username, password, contact, email, now()) RETURNING uid
)
INSERT INTO FDSManagers(uid)
    SELECT uid FROM rows;
$$ language sql;

create or replace function NewFTRider(name varchar(30), username varchar(20), password varchar(20), contact char(8), email varchar(40),
                                        monthly_base_salary int, day_option smallint, D1 smallint, D2 smallint, D3 smallint, D4 smallint,
                                        D5 smallint)
RETURNS void AS $$
with rows as (
    INSERT INTO Users(name, username, password, contact, email, date_joined)
    VALUES (name, username, password, contact, email, now()) RETURNING uid
)
INSERT INTO Riders(uid)
    SELECT uid FROM rows;
with rows as (
    INSERT INTO Users(name, username, password, contact, email, date_joined)
    VALUES (name, username, password, contact, email, now()) RETURNING uid
),
ridercontent as (SELECT monthly_base_salary AS monthly_base_salary)
INSERT INTO FTRiders(uid, monthly_base_salary)
    SELECT uid, monthly_base_salary FROM rows, ridercontent;
with rows as (
    INSERT INTO Users(name, username, password, contact, email, date_joined)
    VALUES (name, username, password, contact, email, now()) RETURNING uid
),
ws as (
    INSERT INTO WorkSchedules(wid) VALUES(DEFAULT) RETURNING wid
),
wscontent as (SELECT day_option AS day_option, D1 AS D1, D2 AS D2, D3 AS D3, D4 AS D4, D5 AS D5, now() as date_created)
INSERT INTO FTWorkSchedules(wid, uid, day_option, D1, D2, D3, D4, D5, date_created)
    SELECT wid, uid, day_option, D1, D2, D3, D4, D5, date_created
    FROM ws, rows, wscontent;
$$ language sql;

create or replace function NewPTRider(name varchar(30), username varchar(20), password varchar(20), contact char(8), email varchar(40),
                                        weekly_base_salary int)
RETURNS void AS $$
with rows as (
    INSERT INTO Users(name, username, password, contact, email, date_joined)
    VALUES (name, username, password, contact, email, now()) RETURNING uid
),
ridercontent as (SELECT weekly_base_salary AS weekly_base_salary)
INSERT INTO PTRiders(uid, weekly_base_salary)
    SELECT uid, weekly_base_salary FROM rows, ridercontent;
$$ language sql;

create or replace function NewFDSPromo(uid int, start_date date, end_date date, promo_type int, discount int)
RETURNS void AS $$
with rows as (
    INSERT INTO Promos(start_date, end_date, promo_type, discount)
    VALUES (start_date, end_date, promo_type, discount) RETURNING pid
),
content as (SELECT uid AS uid)
INSERT INTO FDSPromos(pid, uid)
    SELECT pid, uid FROM rows, content;
$$ language sql;

create or replace function NewRPromo(uid int, start_date date, end_date date, promo_type int, discount int)
RETURNS void AS $$
with rows as (
    INSERT INTO Promos(start_date, end_date, promo_type, discount)
    VALUES (start_date, end_date, promo_type, discount) RETURNING pid
),
content as (SELECT uid AS uid)
INSERT INTO RPromos(pid, uid)
    SELECT pid, uid FROM rows, content;
$$ language sql;

create or replace function NewOrder(uid int, pid int, payment_type int, used_points int, foods hstore)
RETURNS void AS $$
with rows as (
	INSERT INTO Orders(uid, pid, order_time, payment_type, used_points)
    VALUES (uid, pid, now(), payment_type, used_points) RETURNING oid
)
INSERT INTO FoodOrders(fid, oid, qty)
	SELECT key::int, oid, value::int FROM rows, each(foods);
$$ language sql;

-- insert into Users (name, username, password, contact, email, date_joined)
-- values ("Bob", "bobbytables", "poppytables", 91234567, "bobbytables@gmail.com", now())

-- insert into Customers (address, card_number, cvc, default_payment, acc_points)
-- values ("TAMPINES ROAD", 6372817462739572, 233, 0, 0)