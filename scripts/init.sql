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
    name        varchar(30),
    username    varchar(20),
    password    varchar(20),
    contact     char(8),
    email       varchar(40),
    date_joined timestamp
);

create table Customers (
    uid         serial primary key references Users on delete cascade,
    address     varchar(60),
    card_number char(16),
    cvc         char(3),
    default_payment integer,
    acc_points  integer
);

create table Restaurants (
    rid         serial primary key,
    name        varchar(30),
    address     varchar(60),
    min_amt_threshold integer
);

create table RestaurantStaff (
    uid         serial primary key references Users on delete cascade,
    rid         serial not null,
    foreign key (rid) references Restaurants on delete cascade
);

create table Promos (
    pid         serial primary key,
    start_date  date,
    end_date    date,
    promo_type  integer,
    discount    integer
);

create table FDSManagers (
    uid         serial primary key references Users on delete cascade
);

create table FDSPromos (
    pid         serial primary key references Promos on delete cascade,
    uid         serial references FDSManagers
);

create table RPromos (
    pid         serial primary key references Promos on delete cascade,
    uid         serial references RestaurantStaff
);

create table Food (
    fid         serial primary key,
    rid         serial not null,
    name        varchar(30),
    category    varchar(30),
    price       decimal(38,2),
    food_limit  integer,
    foreign key (rid) references Restaurants on delete cascade
);

create table Orders (
    oid         serial primary key,
    uid         serial not null,
    pid         serial references Promos,
    order_time  timestamp,
    payment_type integer,
    used_points integer,
    review      varchar(150),
    foreign key (uid) references Customers on delete cascade
);

create table FoodOrders (
    fid         serial not null,
    oid         serial references Orders on delete cascade,
    qty         integer,
    primary key (fid, oid),
    foreign key (fid) references Food on delete cascade
);

create table Riders (
    uid         serial primary key references Users on delete cascade
);

create table FTRiders (
    uid         serial primary key references Riders on delete cascade,
    monthly_base_salary integer
);

create table PTRiders (
    uid         serial primary key references Riders on delete cascade,
    weekly_base_salary integer
);

create table WorkSchedules (
    wid         serial primary key
);

create table FTWorkSchedules (
    wid         serial primary key references WorkSchedules on delete cascade,
    uid         serial not null,
    day_option  integer,
    D1          integer,
    D2          integer,
    D3          integer,
    D4          integer,
    D5          integer,
    date_created timestamp,
    foreign key (uid) references Users on delete cascade
);

create table PTWorkSchedules (
    wid         serial primary key references WorkSchedules on delete cascade,
    uid         serial not null,
    work_date   date,
    start_time  time,
    end_time    time,
    foreign key (uid) references Users on delete cascade
);

create table Deliveries (
    oid         serial primary key references Orders,
    uid         serial not null,
    rating      varchar(150),
    depart_for_restaurant timestamp,
    arrive_at_restaurant timestamp,
    depart_for_location timestamp,
    arrive_at_location timestamp,
    foreign key (uid) references Riders
);

-- insert into Users (name, username, password, contact, email, date_joined)
-- values ("Bob", "bobbytables", "poppytables", 91234567, "bobbytables@gmail.com", now())

-- insert into Customers (address, card_number, cvc, default_payment, acc_points)
-- values ("TAMPINES ROAD", 6372817462739572, 233, 0, 0)