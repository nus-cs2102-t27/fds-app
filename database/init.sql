create extension if not exists hstore;

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
    min_amt_threshold integer NOT NULL,
    delivery_fee integer NOT NULL
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
    discount_type integer,
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
    isRemoved   boolean,
    foreign key (rid) references Restaurants on delete cascade
);

create table Orders (
    oid         serial primary key,
    uid         integer not null,
    location    varchar(60) not null,
    pid         integer,
    order_time  timestamp,
    payment_type integer,
    used_points integer,
    review      varchar(150),
    discount    varchar(50),
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
    uid         integer primary key references Users on delete cascade,
    monthly_base_salary integer
);

create table PTRiders (
    uid         integer primary key references Users on delete cascade,
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
    start_time  timestamp,
    end_time    timestamp,
    date_created timestamp,
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
    collected   boolean,
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
    VALUES ($1, $2, $3, $4, $5, now()) RETURNING uid
)
INSERT INTO Customers(uid, address, card_number, cvc, default_payment, acc_points)
    SELECT uid, $6, $7, $8, $9, 0
    FROM rows;
$$ language sql;

create or replace function NewRestaurantStaff(name varchar(30), username varchar(20), password varchar(20), contact char(8), email varchar(40),
                                        rid int)
RETURNS void AS $$
with rows as (
    INSERT INTO Users(name, username, password, contact, email, date_joined)
    VALUES ($1, $2, $3, $4, $5, now()) RETURNING uid
)
INSERT INTO RestaurantStaff(uid, rid)
    SELECT uid, $6
    FROM rows;
$$ language sql;

create or replace function NewFDSManager(name varchar(30), username varchar(20), password varchar(20), contact char(8), email varchar(40))
RETURNS void AS $$
with rows as (
    INSERT INTO Users(name, username, password, contact, email, date_joined)
    VALUES ($1, $2, $3, $4, $5, now()) RETURNING uid
)
INSERT INTO FDSManagers(uid)
    SELECT uid FROM rows;
$$ language sql;

create or replace function NewFTRider(name varchar(30), username varchar(20), password varchar(20), contact char(8), email varchar(40),
                                        monthly_base_salary int, day_option smallint, D1 smallint, D2 smallint, D3 smallint, D4 smallint,
                                        D5 smallint)
RETURNS void AS $$
DECLARE
    userId int;
    workId int;
BEGIN
    INSERT INTO Users(name, username, password, contact, email, date_joined)
    VALUES ($1, $2, $3, $4, $5, now()) RETURNING uid INTO userId;
    INSERT INTO Riders(uid) VALUES (userId);
    INSERT INTO FTRiders(uid, monthly_base_salary) VALUES (userId, $6);
    INSERT INTO WorkSchedules(wid) VALUES(DEFAULT) RETURNING wid INTO workId;
    INSERT INTO FTWorkSchedules(wid, uid, day_option, D1, D2, D3, D4, D5, date_created)
    VALUES (workId, userId, $7, $8, $9, $10, $11, $12, now());
END;
$$ language plpgsql;

create or replace function NewPTRider(name varchar(30), username varchar(20), password varchar(20), contact char(8), email varchar(40),
                                        weekly_base_salary int)
RETURNS void AS $$
with rows as (
    INSERT INTO Users(name, username, password, contact, email, date_joined)
    VALUES ($1, $2, $3, $4, $5, now()) RETURNING uid
),
content as (
    INSERT INTO Riders(uid)
        SELECT uid FROM rows RETURNING uid
)
INSERT INTO PTRiders(uid, weekly_base_salary)
    SELECT uid, $6 FROM content;
$$ language sql;

create or replace function NewFDSPromo(uid int, start_date date, end_date date, promo_type int, discount int)
RETURNS void AS $$
with rows as (
    INSERT INTO Promos(start_date, end_date, promo_type, discount_type, discount)
    VALUES ($2, $3, 0, $4, $5) RETURNING pid
)
INSERT INTO FDSPromos(pid, uid)
    SELECT pid, $1 FROM rows;
$$ language sql;

create or replace function NewRPromo(uid int, start_date date, end_date date, promo_type int, discount int)
RETURNS void AS $$
with rows as (
    INSERT INTO Promos(start_date, end_date, promo_type, discount_type, discount)
    VALUES ($2, $3, 1, $4, $5) RETURNING pid
)
INSERT INTO RPromos(pid, uid)
    SELECT pid, $1 FROM rows;
$$ language sql;

create or replace function NewPTWorkSchedule(uid int, start_time timestamp, end_time timestamp)
RETURNS void AS $$
with rows as (
    INSERT INTO WorkSchedules(wid) VALUES(DEFAULT) RETURNING wid
)
INSERT INTO PTWorkSchedules(wid, uid, start_time, end_time, date_created)
    SELECT wid, $1, $2, $3, now() FROM rows;
$$ language sql;

create or replace function RemoveFood(fid int)
RETURNS void AS $$
UPDATE Food
SET isRemoved = True
WHERE fid = $1;
$$ language sql;

-- For this function, use 'SELECT * FROM GetFood(xxx);'
-- Not doing so will result in the returned table becoming a tuple
create or replace function GetFood(rid int)
RETURNS TABLE(fid int, rid int, name varchar(30), category varchar(30), price decimal(38,2),
food_limit int, isRemoved boolean, food_left bigint) AS $$
with orders_today as (
    SELECT fid, sum(qty) as total_qty
    FROM FoodOrders NATURAL JOIN Orders
    WHERE order_time::DATE = now()::DATE
    GROUP BY fid
)
SELECT f.fid, rid, name, category, price, food_limit, isRemoved,
    COALESCE(food_limit - total_qty, food_limit) AS food_left
FROM orders_today o RIGHT OUTER JOIN Food f
ON o.fid = f.fid
WHERE rid = $1 AND isRemoved = False;
$$ language sql;

create or replace function Price(oid int)
RETURNS numeric AS $$
SELECT sum(fo.qty*f.price)
FROM FoodOrders fo NATURAL JOIN Food f
WHERE fo.oid = $1
$$ language sql;

create or replace function AccPoints(oid int)
RETURNS numeric AS $$
    SELECT ROUND(Price($1), 0);
$$ language sql;

create or replace function getCustomerByOrder(oid int)
RETURNS int AS $$
SELECT uid FROM Orders WHERE oid = $1
$$ language sql;

create or replace function AddPointsByOrder(oid int)
RETURNS void AS $$
DECLARE
    customer int;
    points int;
    current_points int;
BEGIN
    SELECT getCustomerByOrder($1), AccPoints($1) INTO customer, points;
    SELECT acc_points INTO current_points FROM Customers WHERE uid = customer;
    UPDATE Customers
    SET acc_points = current_points + points
    WHERE uid = customer;
END
$$ language plpgsql;

create or replace function UsedPoints(oid int)
RETURNS int AS $$
    SELECT used_points FROM Orders WHERE oid = $1
$$ language sql;

create or replace function DeletePointsByOrder(oid int)
RETURNS void AS $$
DECLARE
    customer int;
    points int;
    current_points int;
BEGIN
    SELECT getCustomerByOrder($1), UsedPoints($1) INTO customer, points;
    SELECT acc_points INTO current_points FROM Customers WHERE uid = customer;
    UPDATE Customers
    SET acc_points = current_points - points
    WHERE uid = customer;
END
$$ language plpgsql;

create or replace function ModifyPointsByOrder(oid int)
RETURNS void AS $$
    SELECT AddPointsByOrder($1);
    SELECT DeletePointsByOrder($1);
$$ language sql;

create or replace function NewOrder(uid int, location varchar(60), pid int, payment_type int, used_points int, discount varchar(50), foods hstore)
RETURNS void AS $$
with rows as (
    INSERT INTO Orders(uid, location, pid, order_time, payment_type, used_points, discount)
    VALUES ($1, $2, $3, now(), $4, $5, $6) RETURNING oid
),
content as (
    INSERT INTO FoodOrders(fid, oid, qty)
        SELECT key::int, oid, value::int FROM rows, each($7) RETURNING oid
)
SELECT ModifyPointsByOrder((SELECT oid FROM content ORDER BY oid DESC LIMIT 1));
$$ language sql;

create or replace function LastFiveLocations(uid int)
RETURNS TABLE(location varchar(60)) AS $$
SELECT location
FROM Orders
WHERE uid = $1
GROUP BY location
ORDER BY max(oid) DESC
LIMIT 5;
$$ language sql;

create or replace function check_ws_hour_constraint()
RETURNS trigger AS $$
DECLARE
	c int;
BEGIN
	SELECT COUNT(*) INTO c
	FROM PTWorkSchedules
	WHERE wid = NEW.wid AND (
		(EXTRACT(minute from start_time) <> 0) OR (EXTRACT(second from start_time) <> 0) OR
	    (EXTRACT(minute from end_time) <> 0) OR (EXTRACT(second from end_time) <> 0));
	IF c > 0 THEN
        RAISE EXCEPTION 'Hour interval does not start/end on the hour';
    END IF;
    RETURN NULL;
END;
$$ language plpgsql;

drop trigger if exists ws_hour_trigger on PTWorkSchedules cascade;
create constraint trigger ws_hour_trigger
    after insert on PTWorkSchedules
    deferrable initially immediate
    for each row execute procedure check_ws_hour_constraint();

create or replace function check_duration_constraint()
RETURNS trigger AS $$
DECLARE
    duration int;
BEGIN
    SELECT DATE_PART('hours', end_time - start_time) INTO duration
    FROM PTWorkSchedules
    WHERE wid = NEW.wid;
    IF duration > 4 THEN
        RAISE EXCEPTION 'Duration of work schedule exceeds 4 hours';
    END IF;
    IF duration < 1 THEN
        RAISE EXCEPTION 'Duration of work schedule must be at least 1 hour';
    END IF;
    RETURN NULL;
END;
$$ language plpgsql;

drop trigger if exists duration_trigger on PTWorkSchedules cascade;
create constraint trigger duration_trigger
    after insert on PTWorkSchedules
    deferrable initially immediate
    for each row execute procedure check_duration_constraint();

create or replace function check_no_overlap_constraint()
RETURNS trigger AS $$
DECLARE
	c int;
BEGIN
	SELECT COUNT(*) INTO c FROM PTWorkSchedules
	WHERE wid <> NEW.wid AND uid = new.uid AND (
		((start_time > NEW.start_time - '1 hour'::interval) AND (start_time < NEW.end_time + '1 hour'::interval)) OR
		((end_time > NEW.start_time - '1 hour'::interval) AND (end_time < NEW.end_time + '1 hour'::interval)));
	IF c > 0 THEN
		RAISE EXCEPTION 'Work schedule clashes with other schedules or insufficient break';
	END IF;
	RETURN NULL;
END;
$$ language plpgsql;

drop trigger if exists overlap_trigger on PTWorkSchedules cascade;
create constraint trigger overlap_trigger
    after insert on PTWorkSchedules
    deferrable initially immediate
    for each row execute procedure check_no_overlap_constraint();

create or replace function check_schedule_in_advance_constraint()
RETURNS trigger AS $$
DECLARE
    c int;
BEGIN
    SELECT COUNT(*) INTO c FROM PTWorkSchedules
    WHERE wid = NEW.wid AND (
        start_time < (now() + '1 week'::interval)
    );
    IF c > 0 THEN
        RAISE EXCEPTION 'Work schedule needs to be created at least 1 week in advance';
    END IF;
    RETURN NULL;
END;
$$ language plpgsql;

drop trigger if exists schedule_in_advance_trigger on PTWorkSchedules cascade;
create constraint trigger schedule_in_advance_trigger
    after insert on PTWorkSchedules
    deferrable initially immediate
    for each row execute procedure check_schedule_in_advance_constraint();

create or replace function check_min_amount_constraint()
RETURNS trigger AS $$
DECLARE
    min_amount int;
    amount int;
BEGIN
    SELECT r.min_amt_threshold, fo.qty*f.price INTO min_amount, amount
    FROM FoodOrders fo NATURAL JOIN Food f INNER JOIN Restaurants r
    ON f.rid = r.rid
    WHERE fo.oid = NEW.oid;
    IF amount < min_amount THEN
        RAISE EXCEPTION 'Amount is below minimum amount threshold';
    END IF;
    RETURN NULL;
END;
$$ language plpgsql;

drop trigger if exists min_amt_trigger on Orders cascade;
create constraint trigger min_amt_trigger
    after insert on Orders
    deferrable initially immediate
    for each row execute procedure check_min_amount_constraint();

create or replace function check_same_restaurant_constraint()
RETURNS trigger AS $$
DECLARE
    restaurant int;
    orderId int;
    c int;
BEGIN
    SELECT f.rid, fo.oid INTO restaurant, orderId
    FROM FoodOrders fo NATURAL JOIN Food f
    WHERE fo.oid = NEW.oid
    LIMIT 1;
	SELECT COUNT(*) INTO c
	FROM FoodOrders fo NATURAL JOIN Food f
	WHERE fo.oid = orderId AND f.rid <> restaurant;
	IF c > 0 THEN
		RAISE EXCEPTION 'Food not ordered from same restaurant';
	END IF;
	RETURN NULL;
END;
$$ language plpgsql;

drop trigger if exists same_restaurant_trigger on Orders cascade;
create constraint trigger same_restaurant_trigger
    after insert on Orders
    deferrable initially immediate
    for each row execute procedure check_same_restaurant_constraint();

-- create or replace trigger

-- insert into Users (name, username, password, contact, email, date_joined)
-- values ("Bob", "bobbytables", "poppytables", 91234567, "bobbytables@gmail.com", now())

-- insert into Customers (address, card_number, cvc, default_payment, acc_points)
-- values ("TAMPINES ROAD", 6372817462739572, 233, 0, 0)

-- -- Customers
select NewCustomer('Joya Saunter','jsaunter0','password','95492674','jsaunter0@cbsnews.com','3 Ronald Regan Street','2151899168688168','338','1');
select NewCustomer('Marcus Splevings','msplevings1','rTMwwI','90094778','msplevings1@ask.com','0511 Shopko Parkway','9177743529610093','641','0');
select NewCustomer('Fraze Mont','fmont2','gB3LdsBY2o','98563720','fmont2@whitehouse.gov','05 Russell Avenue','9682891473181828','455','0');
select NewCustomer('Miguela Vasichev','mvasichev3','zM5qAXVukHx','96507786','mvasichev3@loc.gov','97550 Kipling Avenue','8087102548227046','157','0');
select NewCustomer('Marjory Kynston','mkynston4','0zvxr9','92132150','mkynston4@oracle.com','04809 5th Road','6292707104585243','852','0');
select NewCustomer('Vladamir Fideler','vfideler5','SPxcJl4cVI','94110435','vfideler5@dot.gov','9600 Old Shore Place','8327391810849015','787','1');
select NewCustomer('Quinta Flowerdew','qflowerdew6','b4fDlrJfc','94156203','qflowerdew6@walmart.com','4153 Carpenter Terrace','7469199714100427','088','1');
select NewCustomer('Farah Masham','fmasham7','FEU9sBuohW','98398691','fmasham7@aol.com','643 Waywood Road','4107564092073593','326','1');
select NewCustomer('Beniamino Heningam','bheningam8','B7xBBKdYFH','94126780','bheningam8@wsj.com','6 Longview Parkway','6161569325575907','666','0');
select NewCustomer('Baxie Lacky','blacky9','9aqrjsm','94125588','blacky9@photobucket.com','8096 Hoepker Circle','9314358942971052','503','0');
select NewCustomer('Leona Pibsworth','lpibswortha','sdeDDkLhBW','92510014','lpibswortha@accuweather.com','6526 Sheridan Point','6072849949103842','827','1');
select NewCustomer('Amandy Kennelly','akennellyb','fwDixkhdD','90312390','akennellyb@virginia.edu','4 Oriole Place','3679558778215172','987','0');
select NewCustomer('Tilly Kobierzycki','tkobierzyckic','jiErDvTAMb3','99021511','tkobierzyckic@usatoday.com','9 Carey Trail','3318473165845082','369','0');
select NewCustomer('Lamar Balsom','lbalsomd','51HMrQSsOXNb','91477732','lbalsomd@acquirethisname.com','57 Waywood Drive','9401945229862538','413','1');
select NewCustomer('Kalinda Titchener','ktitchenere','elmbn7LNO','93911611','ktitchenere@nbcnews.com','03079 Katie Terrace','7063715368435983','021','0');
select NewCustomer('Fayre Cockshutt','fcockshuttf','KaZAgrRFQgHv','96538683','fcockshuttf@g.co','92 Spenser Alley','4214692794485430','709','0');
select NewCustomer('Katheryn Mulhill','kmulhillg','wLsdSYt','99652439','kmulhillg@topsy.com','09882 Parkside Place','7351720686637056','513','0');
select NewCustomer('Burt Hackelton','bhackeltonh','a3uJ5K4CbT','90417791','bhackeltonh@blogtalkradio.com','181 Bowman Street','4821337298699190','549','1');
select NewCustomer('Tanney Toppas','ttoppasi','PSQNi42mZ','97461279','ttoppasi@samsung.com','3317 Wayridge Crossing','4379579282185977','891','0');
select NewCustomer('Cal Beamiss','cbeamissj','M7ckhM7','90845020','cbeamissj@epa.gov','3 Kennedy Circle','6498923514776589','032','1');
select NewCustomer('Carlos Vyse','cvysek','XJdriSTZ','98966604','cvysek@dailymotion.com','7 Melvin Junction','1383664682671272','649','1');
select NewCustomer('Brannon Malin','bmalinl','OpkE69kxkP5','94137851','bmalinl@fc2.com','4 Blackbird Way','4703438115520028','436','0');
select NewCustomer('Marlin Gallihaulk','mgallihaulkm','ZDKq5L0lYA','94324170','mgallihaulkm@google.ca','9401 Hagan Lane','4927261255994050','071','1');
select NewCustomer('Anastassia Duckfield','aduckfieldn','VhFz1ApUPvxg','95057478','aduckfieldn@cisco.com','0 Petterle Point','0199624225643240','615','0');
select NewCustomer('Ted Prior','tprioro','rKOSh14a','93267446','tprioro@twitter.com','36 Service Plaza','5988381060019713','607','0');
select NewCustomer('Bibbie Platt','bplattp','idh60S2Z','94092491','bplattp@adobe.com','4034 Knutson Point','1030489891962603','667','0');
select NewCustomer('Mufi Pearmine','mpearmineq','4SRZkl0it58','91104764','mpearmineq@livejournal.com','05 Heffernan Hill','3523346830889284','574','1');
select NewCustomer('Ashby Ewebank','aewebankr','0MZa6t5mY','95108252','aewebankr@clickbank.net','51 Vermont Circle','6211904947278420','962','0');
select NewCustomer('Bethany Rizzardini','brizzardinis','NO1ZjP','93475752','brizzardinis@tiny.cc','3 Talisman Circle','8371730935209461','521','0');
select NewCustomer('Jefferey Davidde','jdaviddet','Qke78t','97293891','jdaviddet@japanpost.jp','3580 Butternut Road','8638970035226396','514','1');
select NewCustomer('Gerhard Elijah','gelijahu','UsOkMuxJ','93536938','gelijahu@webeden.co.uk','4400 Dahle Street','8035401145046331','331','0');
select NewCustomer('Taryn Deware','tdewarev','ZIei85','98960207','tdewarev@scientificamerican.com','29827 Fuller Trail','5443533351146344','194','1');
select NewCustomer('Carlyle Danielczyk','cdanielczykw','ZrE7AHW76','93761750','cdanielczykw@howstuffworks.com','64992 Emmet Drive','6963573790761708','619','1');
select NewCustomer('Godfrey Aveyard','gaveyardx','V5WMVRGM5R','90201759','gaveyardx@de.vu','63 Cottonwood Park','9957904232996820','102','1');
select NewCustomer('Lenka Danton','ldantony','svpIcvbhAkD','98699414','ldantony@reddit.com','89323 Dakota Drive','8973586960504296','522','1');
select NewCustomer('Minor Quinnelly','mquinnellyz','swC1K7bpM','91677937','mquinnellyz@stanford.edu','349 Montana Point','6588515599033175','557','0');
select NewCustomer('Denver Dagleas','ddagleas10','NrJwLupHcUf','94580581','ddagleas10@t-online.de','72552 Utah Center','7618804944706144','956','0');
select NewCustomer('Roxanne Wardhaw','rwardhaw11','T3RH8rZAPh','91395987','rwardhaw11@cloudflare.com','24624 Bartelt Point','6955272421025339','575','1');
select NewCustomer('Tanitansy Lyvon','tlyvon12','vhZ0nJQR0kE','92296417','tlyvon12@hubpages.com','677 Holy Cross Way','1979526753312014','288','1');
select NewCustomer('Robbyn Boards','rboards13','gYd4Qmm3','96810164','rboards13@soundcloud.com','0664 Delladonna Avenue','3022049418006174','347','1');
select NewCustomer('Armin Palphramand','apalphramand14','1y6qNqfFo','95883803','apalphramand14@sohu.com','5885 Menomonie Point','6252805603998471','024','0');
select NewCustomer('Sharl Hammett','shammett15','iIaOvM','94782673','shammett15@examiner.com','27 Lake View Drive','8792853004033925','200','1');
select NewCustomer('Malinda Artus','martus16','SMxZS8savXsQ','90856649','martus16@ca.gov','94796 Esker Plaza','7187042787619959','840','0');
select NewCustomer('Gussi Jira','gjira17','9KMUaEB1CI2k','90757944','gjira17@miibeian.gov.cn','13287 Gateway Center','9043125725561103','125','0');
select NewCustomer('Guenevere Bohan','gbohan18','fmIXP4sBRAr','90224971','gbohan18@chron.com','1 Westport Point','6878898732587315','637','0');
select NewCustomer('Nolana Hynes','nhynes19','liGLXCt','97758110','nhynes19@bloglovin.com','3 Basil Trail','4406435731143812','857','0');
select NewCustomer('Coleman Elsmere','celsmere1a','VNoW17JKjY','92507011','celsmere1a@ucsd.edu','34363 Anderson Lane','3298789131028737','064','1');
select NewCustomer('Packston Jenking','pjenking1b','fhabAKYL7uW','95967678','pjenking1b@soup.io','492 Scott Plaza','4420323833014267','800','0');
select NewCustomer('Rikki Vashchenko','rvashchenko1c','fGTlRANSj7wq','92623361','rvashchenko1c@globo.com','22317 Pine View Avenue','1839905701846461','618','1');
select NewCustomer('Odelinda Roe','oroe1d','LXma6f','96686606','oroe1d@google.fr','61084 Autumn Leaf Plaza','4328826903828949','619','1');
select NewCustomer('Nata Dinis','ndinis1e','o1sRzcAGj','93513221','ndinis1e@liveinternet.ru','2 Pennsylvania Way','2988036465996491','360','1');
select NewCustomer('Wade Twycross','wtwycross1f','BsoWP5Zo5uD','97677534','wtwycross1f@microsoft.com','811 Golf Course Crossing','6877855816153660','745','0');
select NewCustomer('Hillard Crankshaw','hcrankshaw1g','jSnyi709lD','97926312','hcrankshaw1g@de.vu','0875 Debs Terrace','2957802093722157','538','1');
select NewCustomer('Carri Clair','cclair1h','sGhYIdHho7','99717227','cclair1h@weibo.com','4 Saint Paul Drive','3096324784673956','232','0');
select NewCustomer('Bowie Chitson','bchitson1i','f8J5JMe26Le','93601278','bchitson1i@free.fr','5222 Homewood Point','3262713417542757','495','0');
select NewCustomer('Hallie Elcom','helcom1j','wo7bQx','90992269','helcom1j@illinois.edu','2 Green Place','3556216760396522','229','0');
select NewCustomer('Boniface Blackwood','bblackwood1k','kqKluDKdQMq','91081691','bblackwood1k@vk.com','424 Northview Court','1416256245799568','796','0');
select NewCustomer('Roby Gare','rgare1l','bqv4tI','94928948','rgare1l@comsenz.com','0 Monument Parkway','0992471331654445','160','0');
select NewCustomer('Britt Toffolo','btoffolo1m','BZGlfOX2T2','92156234','btoffolo1m@indiegogo.com','5783 Brentwood Point','3908971189400890','162','0');
select NewCustomer('Lynnell Ingerith','lingerith1n','soiLqdL','95382777','lingerith1n@mysql.com','36 Superior Place','0988901191747250','924','0');
select NewCustomer('Bud Sexstone','bsexstone1o','ZriaotPdR','96023235','bsexstone1o@studiopress.com','207 Amoth Crossing','9050850245087199','430','1');
select NewCustomer('Foss Reynalds','freynalds1p','E2oUkMRs','97681994','freynalds1p@google.pl','81 Fair Oaks Park','2227776626937105','100','0');
select NewCustomer('Regan Clancey','rclancey1q','hhU7JV','90448559','rclancey1q@goo.gl','06314 Buhler Place','9640154579734300','475','0');
select NewCustomer('Hurley Ballance','hballance1r','gKbgGKX','94006587','hballance1r@list-manage.com','542 Northridge Center','4628071440769316','132','0');
select NewCustomer('Wallis Duddin','wduddin1s','csE9lnK7w5','99595039','wduddin1s@qq.com','6 Veith Point','8996286199361099','885','1');
select NewCustomer('Giordano Candish','gcandish1t','FCcZjj4','99868121','gcandish1t@dailymail.co.uk','7 Glendale Parkway','2444805694701387','791','1');
select NewCustomer('Moria Pfertner','mpfertner1u','nC7dFLaVvZqJ','92446149','mpfertner1u@printfriendly.com','6155 Atwood Point','6917691234491986','011','1');
select NewCustomer('Bernadine Seniour','bseniour1v','mhPu2KJ','99442556','bseniour1v@hc360.com','3700 Hazelcrest Trail','7215764157592731','874','0');
select NewCustomer('Emilia Just','ejust1w','TRrGXxXArqtk','98052660','ejust1w@cornell.edu','32 Tennyson Court','4551641655237894','944','1');
select NewCustomer('Arlene Tucker','atucker1x','54g45O','93115643','atucker1x@canalblog.com','9819 Lunder Junction','4512671325751929','247','1');
select NewCustomer('Lovell Templeman','ltempleman1y','VgkIqY3TrFS','93722299','ltempleman1y@mlb.com','5540 Blaine Circle','2368312840219136','774','0');
select NewCustomer('Cleo Cominotti','ccominotti1z','5KdapU','93833126','ccominotti1z@reuters.com','7889 Bluejay Crossing','5013336057192020','505','1');
select NewCustomer('Kitty Yurov','kyurov20','FQjbp4S','95664990','kyurov20@xinhuanet.com','860 Shelley Road','1019867825095400','690','0');
select NewCustomer('Laurence Siward','lsiward21','zrW1USrS','90280411','lsiward21@toplist.cz','8 Elmside Place','7902755228489094','298','0');
select NewCustomer('Giffy Van den Oord','gvan22','FkjJbk3','90617100','gvan22@examiner.com','4 Fulton Alley','6858806656513930','085','0');
select NewCustomer('Starlin Gwyer','sgwyer23','gPCkzU','91968400','sgwyer23@ebay.com','51949 Ryan Pass','8326146773037496','167','1');
select NewCustomer('Immanuel Bucknell','ibucknell24','BMygby1hBFP','95344724','ibucknell24@sfgate.com','3642 Grasskamp Trail','5370865302660177','210','0');
select NewCustomer('Brett Jeves','bjeves25','WEfz7tN','92645056','bjeves25@businessweek.com','974 Maple Circle','3602728795424237','839','1');
select NewCustomer('Cyndia Cuchey','ccuchey26','IE7ND4H','94190258','ccuchey26@fema.gov','455 Ilene Terrace','1938761443192279','708','1');
select NewCustomer('Jennilee Robillart','jrobillart27','lgNYbQTRnkTp','98067587','jrobillart27@spotify.com','98826 Bunting Parkway','5985016468944625','880','0');
select NewCustomer('Duncan Towersey','dtowersey28','8VqVXL1LB4IP','98544331','dtowersey28@multiply.com','4752 Dorton Park','4614968460244176','228','0');
select NewCustomer('Rutger Calcut','rcalcut29','bUwCOGG3e','91569422','rcalcut29@va.gov','73803 Declaration Drive','2183383688736200','556','0');
select NewCustomer('Dannie MacTrustam','dmactrustam2a','6BCa2XwYCfC','92574723','dmactrustam2a@census.gov','1 Oriole Avenue','7470145426914643','219','1');
select NewCustomer('Reinold Deboick','rdeboick2b','M2SqfhCw1dj','91142207','rdeboick2b@hostgator.com','571 Bartillon Parkway','0142697750734000','196','1');
select NewCustomer('Lenette Nowakowski','lnowakowski2c','kS8QsZYK4aR','92960657','lnowakowski2c@pcworld.com','885 Sunnyside Trail','9651374126048473','868','0');
select NewCustomer('Skye Koene','skoene2d','3ygxy0zpM6','99529749','skoene2d@usnews.com','80471 Karstens Lane','1423163356020274','901','1');
select NewCustomer('Rayner Crosse','rcrosse2e','hU10IM0R','94506637','rcrosse2e@printfriendly.com','05 Maywood Park','8807716289372917','229','1');
select NewCustomer('Marketa Tolefree','mtolefree2f','PS11WWnUqi','96371612','mtolefree2f@un.org','20 Upham Point','7828448993715771','623','0');
select NewCustomer('Sioux McNeilley','smcneilley2g','4y3bETi','90828387','smcneilley2g@canalblog.com','95 Melby Parkway','0404512713878661','051','1');
select NewCustomer('Carolee Shelmerdine','cshelmerdine2h','p5vEgFW38','95932841','cshelmerdine2h@berkeley.edu','637 David Point','9993097489823262','249','1');
select NewCustomer('Leonore Brightwell','lbrightwell2i','cWa6AOKyhHH','98506029','lbrightwell2i@myspace.com','638 Coleman Place','2663287157082806','455','0');
select NewCustomer('Dolly Wieprecht','dwieprecht2j','F4dg6dE','91580351','dwieprecht2j@businesswire.com','8 Linden Junction','8976476855583532','025','0');
select NewCustomer('Kirk Beese','kbeese2k','45BKCDvQf','92289573','kbeese2k@quantcast.com','24875 Novick Park','7752896871482282','770','0');
select NewCustomer('Hillie Penticost','hpenticost2l','Kp6DsJU1Rru3','96773902','hpenticost2l@cnet.com','86597 Dunning Plaza','1813690784820681','124','0');
select NewCustomer('Gerrilee Densumbe','gdensumbe2m','sYLXkTY','95171585','gdensumbe2m@bbc.co.uk','95667 Hanover Plaza','9477678092982793','970','1');
select NewCustomer('Ettie Readett','ereadett2n','f56D3fn51Nge','94461512','ereadett2n@bravesites.com','5 Farragut Way','6845986022817912','775','1');
select NewCustomer('Nicholle Flanagan','nflanagan2o','RCdZon2VTN','95614347','nflanagan2o@tripadvisor.com','253 Northland Point','6673147983909358','416','0');
select NewCustomer('Fae Gerge','fgerge2p','10nJgnvf6','93817640','fgerge2p@vk.com','6 Doe Crossing Terrace','5231011359327916','130','1');
select NewCustomer('Wilden Padbery','wpadbery2q','JIPhumNzmsl','95241479','wpadbery2q@state.tx.us','25995 Algoma Alley','0303430952324991','240','1');
select NewCustomer('Regan Craw','rcraw2r','jtGMqkLU','99806441','rcraw2r@nbcnews.com','831 3rd Plaza','7099803781783165','549','0');
select NewCustomer('Mel Shall','mshall2s','9yFQVuOWI0Y','90652579','mshall2s@wikimedia.org','135 Lighthouse Bay Parkway','6369285632066879','887','1');
select NewCustomer('Beverlie MacConnal','bmacconnal2t','95ZSQJYk3GAM','92174310','bmacconnal2t@usda.gov','2 Myrtle Lane','1926742967669823','168','1');
select NewCustomer('Richard Slimon','rslimon2u','IxA7gZ5','98098754','rslimon2u@ehow.com','52122 Talisman Avenue','7325336578718830','411','0');
select NewCustomer('Anneliese Blase','ablase2v','Bi588HZu','93731269','ablase2v@usa.gov','18 Springview Park','2329296445133505','847','1');
select NewCustomer('Eirena Perritt','eperritt2w','qE5s2a','91417169','eperritt2w@eventbrite.com','6644 Redwing Pass','2696945662701080','482','1');
select NewCustomer('Bradly Herion','bherion2x','odOrIl','93516307','bherion2x@histats.com','1411 Beilfuss Road','6447061656344456','549','0');
select NewCustomer('Antonella Paylor','apaylor2y','W429qxx','95125724','apaylor2y@tiny.cc','6 Hintze Drive','1920678926369349','366','0');
select NewCustomer('Abby Amery','aamery2z','Prbtj48','93663999','aamery2z@goo.gl','48 Artisan Circle','0059827375669360','413','1');
select NewCustomer('Thomas Spratling','tspratling30','a0AO5dA','91277853','tspratling30@digg.com','8 Park Meadow Street','3910249884645014','222','1');
select NewCustomer('Ashlin O''Leahy','aoleahy31','5Fn3niP','98649106','aoleahy31@toplist.cz','570 Monica Drive','5308533776436040','309','0');
select NewCustomer('Gabie Abella','gabella32','Fuzg19Ped','93371851','gabella32@cloudflare.com','67 Lakewood Way','0043515634862778','316','0');
select NewCustomer('Silvia Crux','scrux33','wsoCOO2D3aX','97512201','scrux33@google.com.au','427 Birchwood Hill','5363325166525214','300','0');
select NewCustomer('Oby Isack','oisack34','rRZirANDXJVc','97487427','oisack34@multiply.com','60955 Summer Ridge Circle','4354761194879137','303','0');
select NewCustomer('Rayner Weafer','rweafer35','GhqvQxr','96014732','rweafer35@webeden.co.uk','349 Erie Drive','5448739422410527','838','0');
select NewCustomer('Rainer Dowd','rdowd36','fXVVpGyO','92907104','rdowd36@privacy.gov.au','67 Pankratz Hill','2372601848032367','300','1');
select NewCustomer('Aleda Klemensiewicz','aklemensiewicz37','bkZ4KoitHK','90863799','aklemensiewicz37@shinystat.com','6 Utah Place','6498971849850870','143','1');
select NewCustomer('Misha Poundsford','mpoundsford38','6ng7a1','96003932','mpoundsford38@wired.com','46 Stoughton Plaza','5827680678180786','010','1');
select NewCustomer('Catharine Crips','ccrips39','RilLPc2ddB','95377558','ccrips39@sun.com','0 Summit Terrace','0166036086912828','632','1');
select NewCustomer('Lin Hedin','lhedin3a','GZiQKyS','91981745','lhedin3a@aboutads.info','1543 Farmco Road','9553431175947788','463','1');
select NewCustomer('Koo Mutch','kmutch3b','i4yQgXHi','90342278','kmutch3b@gravatar.com','087 Monica Way','7035232638345460','349','1');
select NewCustomer('Becka Litel','blitel3c','ic2d4nCl','97339506','blitel3c@cnn.com','7349 Havey Avenue','6501292884401150','981','0');
select NewCustomer('Burke Jammet','bjammet3d','4DcrOkJDQ','91374275','bjammet3d@technorati.com','53821 Lunder Point','8677831958739356','269','0');
select NewCustomer('Loren Molden','lmolden3e','ZLrtzKCiA','94149985','lmolden3e@gizmodo.com','798 Menomonie Parkway','1995561746956117','459','0');
select NewCustomer('Kaitlyn Gunney','kgunney3f','tRIH1RjU','94490152','kgunney3f@acquirethisname.com','8321 Debra Avenue','2838723347282661','910','1');
select NewCustomer('Norry Langhor','nlanghor3g','3KQ0u0MF','95507081','nlanghor3g@businesswire.com','4008 Roxbury Hill','7385721187066676','844','1');
select NewCustomer('Fay Archbald','farchbald3h','YXUdkql9boq','97373043','farchbald3h@mlb.com','078 John Wall Way','8684832896641688','264','0');
select NewCustomer('Lurleen Lyford','llyford3i','L7o30svLe','95043211','llyford3i@smugmug.com','45734 Maryland Trail','4719812530025391','406','1');
select NewCustomer('Patrick Sommerly','psommerly3j','2anrVpA','95855661','psommerly3j@ask.com','75800 Chive Drive','9314193649082497','399','1');
select NewCustomer('Carolyn Skym','cskym3k','wsARP8ideCZa','94180301','cskym3k@gov.uk','2953 Pankratz Junction','6336592705384848','456','0');
select NewCustomer('Alan Rosekilly','arosekilly3l','vwLwWYVJBUF','90923140','arosekilly3l@java.com','881 Ilene Parkway','1189358468664981','866','1');
select NewCustomer('Nikolaos Featherby','nfeatherby3m','PXAr2D0e','93841274','nfeatherby3m@tuttocitta.it','33 Clyde Gallagher Plaza','1463794804824697','794','1');
select NewCustomer('Mead Stapells','mstapells3n','M1Y8Cd4UMtw','93093581','mstapells3n@tinypic.com','27635 Waubesa Alley','7286116768626839','601','0');
select NewCustomer('Allyson Titley','atitley3o','A1Z3cb','91243389','atitley3o@miibeian.gov.cn','25 Helena Park','6636053897167929','166','1');
select NewCustomer('Felizio Nix','fnix3p','QLBHvC','97229138','fnix3p@vkontakte.ru','950 Buell Road','7933221239114639','944','0');
select NewCustomer('Adaline Sara','asara3q','FwM9OjTOh7R','93026037','asara3q@phpbb.com','953 Sheridan Terrace','9943127328243187','138','0');
select NewCustomer('Luigi Jovicevic','ljovicevic3r','WLwsT1mRG5','92039769','ljovicevic3r@google.it','2 Monument Pass','5359275488584230','142','0');
select NewCustomer('Mei Carvilla','mcarvilla3s','UcBIc4uJaU','96016161','mcarvilla3s@paypal.com','15 Hanson Trail','4077675859062447','825','1');
select NewCustomer('Karyn Rosenbarg','krosenbarg3t','ECqmCuTmeC','98311203','krosenbarg3t@nasa.gov','2 Kingsford Road','0628331072193540','974','0');
select NewCustomer('Lorne Kinforth','lkinforth3u','ThRIwQkKHu','93755374','lkinforth3u@delicious.com','50 Buhler Drive','6490543790251454','284','1');
select NewCustomer('Magdaia Davydenko','mdavydenko3v','67BatKWxi','95496110','mdavydenko3v@umn.edu','07 Troy Point','3562249779042406','750','1');
select NewCustomer('Fletch Karleman','fkarleman3w','Ny10FtZRdf','91966701','fkarleman3w@ft.com','898 Sachtjen Street','0921684183991027','044','1');
select NewCustomer('Flory Giovannetti','fgiovannetti3x','J23vSEieMY','92343714','fgiovannetti3x@soup.io','7362 American Ash Circle','6601047525016262','344','1');
select NewCustomer('Ethelin Nazer','enazer3y','zLCnJN6','96744714','enazer3y@state.tx.us','23 Coolidge Crossing','0987266423180135','095','1');
select NewCustomer('Odie Shanahan','oshanahan3z','3lxTouUYSL5','96582766','oshanahan3z@salon.com','58484 Bunting Terrace','0309282413528130','996','0');
select NewCustomer('Danny Nowill','dnowill40','01pHTnQVOdD','91781642','dnowill40@epa.gov','292 Declaration Crossing','7510420145562890','765','0');
select NewCustomer('Madison Jenton','mjenton41','lzubtAgZ','96920320','mjenton41@ca.gov','2934 Pleasure Circle','2767191471888769','888','1');
select NewCustomer('Kerrin Cherry','kcherry42','jWZU3eWiNq9','92064958','kcherry42@mayoclinic.com','4 Tennessee Alley','5703500603828875','434','0');
select NewCustomer('Caitlin Venus','cvenus43','eh6SdxPDDX2','97629473','cvenus43@un.org','89358 Beilfuss Road','9814805205593198','503','0');
select NewCustomer('Alina Farbrother','afarbrother44','kzrCuB37xjy','99972766','afarbrother44@census.gov','73560 American Ash Court','5401019654725889','688','0');
select NewCustomer('Tudor Tiffney','ttiffney45','AQ1mgYNXfs1','91068629','ttiffney45@walmart.com','68 Brown Terrace','2259075765515983','117','1');
select NewCustomer('Sophia Bentall','sbentall46','9OKGT5uPf5e','94155645','sbentall46@hubpages.com','40881 4th Avenue','0849144352827762','168','1');
select NewCustomer('Darrin Aleswell','daleswell47','kc6g3A','92472704','daleswell47@usnews.com','56191 Burning Wood Pass','1333106208999850','122','0');
select NewCustomer('Ninnetta Simioli','nsimioli48','J47jcLyCIfe','99630728','nsimioli48@wordpress.com','8184 Washington Lane','7871317115995567','160','0');
select NewCustomer('Laura Sarfass','lsarfass49','tkI9MF','97309392','lsarfass49@barnesandnoble.com','3 Elka Crossing','9584267160619662','343','1');
select NewCustomer('Say Attarge','sattarge4a','eDcn0bbb','92559599','sattarge4a@wix.com','9 Heffernan Pass','4578061200540753','215','1');
select NewCustomer('Prinz Osband','posband4b','bfRQru','92884299','posband4b@sciencedirect.com','72 Summit Place','9453829210393682','821','0');
select NewCustomer('Marwin Kohrding','mkohrding4c','MhE2IKC','96169057','mkohrding4c@mlb.com','84379 Brown Plaza','8906492146180625','553','1');
select NewCustomer('Walker McAughtry','wmcaughtry4d','8mK2fx3','90884074','wmcaughtry4d@woothemes.com','751 Dorton Park','8245510850233093','602','0');
select NewCustomer('Kris Danilchik','kdanilchik4e','ubD93UYG91Y','98717357','kdanilchik4e@nps.gov','9753 Hooker Street','6996736700628117','832','1');
select NewCustomer('Stinky Gepheart','sgepheart4f','vE90guWf','91582941','sgepheart4f@shutterfly.com','52590 Sunbrook Parkway','6510205166011520','636','1');
select NewCustomer('Heall Ruzicka','hruzicka4g','2VT7gAd','98955190','hruzicka4g@zimbio.com','61759 Oriole Terrace','7397246953664010','563','0');
select NewCustomer('Golda Yitzhakov','gyitzhakov4h','7PJ849lPS','98631001','gyitzhakov4h@yandex.ru','04 Evergreen Center','1501131223997699','568','0');
select NewCustomer('Conrado Doorly','cdoorly4i','ZKEJ11vM','91265519','cdoorly4i@bloglovin.com','6150 Elka Place','0536759973803136','926','1');
select NewCustomer('Grantham Godly','ggodly4j','7IkeuEkL0yf','95084287','ggodly4j@mediafire.com','94 Esch Center','5950424550399206','596','1');
select NewCustomer('Marion Harcase','mharcase4k','efpVjP','96022953','mharcase4k@naver.com','20266 Cascade Way','8934560097604688','470','0');
select NewCustomer('Granny Matussevich','gmatussevich4l','kL1eVtog7j','98707460','gmatussevich4l@cbslocal.com','6 Hallows Park','0953202774685247','938','1');
select NewCustomer('Clevie Minifie','cminifie4m','v6q6U1H','94015685','cminifie4m@yolasite.com','1 Oriole Drive','1439529230197529','928','1');
select NewCustomer('Wynne Toombes','wtoombes4n','UA3LvhMjC35','94720834','wtoombes4n@epa.gov','39 Susan Pass','2109323732153364','307','1');
select NewCustomer('Elyn Hurleston','ehurleston4o','ByyIvi','98150299','ehurleston4o@canalblog.com','54 High Crossing Street','4408764766658284','512','1');
select NewCustomer('Aharon Simister','asimister4p','hn2X8kZFDb','96813989','asimister4p@yandex.ru','78 Dottie Avenue','3526340754944399','651','1');
select NewCustomer('Mace Sinclar','msinclar4q','7PUMhEuZ2d','98249070','msinclar4q@free.fr','91392 Vernon Way','6881140658144059','248','1');
select NewCustomer('Harbert Sterrie','hsterrie4r','ZVzv1Wgoa','91054407','hsterrie4r@symantec.com','69683 Mitchell Plaza','5756295465797884','632','1');
select NewCustomer('Spense Sowden','ssowden4s','eVVyDgcI','93131345','ssowden4s@cnn.com','1 Arkansas Way','0084185721947820','893','1');
select NewCustomer('Elsi Blatchford','eblatchford4t','n9QCfAA3','91157694','eblatchford4t@youtu.be','255 Darwin Terrace','8784435934252615','158','1');
select NewCustomer('Sergeant Ferrant','sferrant4u','iZPMPtI8','91645811','sferrant4u@latimes.com','9874 Trailsway Point','8555053088809206','835','1');
select NewCustomer('Hedi Masseo','hmasseo4v','GBWMBLCO','91261829','hmasseo4v@vinaora.com','84045 Helena Parkway','6590552618781851','202','1');
select NewCustomer('Belia Devil','bdevil4w','BR95rSuD','90030565','bdevil4w@theguardian.com','88 Schiller Hill','2495814186347146','414','1');
select NewCustomer('Cynthia Itshak','citshak4x','apDmR4Ko','91049229','citshak4x@technorati.com','975 Green Pass','0649967798683489','701','1');
select NewCustomer('Naoma Skehens','nskehens4y','pGHEU4LyFBTj','97755357','nskehens4y@forbes.com','6711 Cody Place','2436379542514898','085','1');
select NewCustomer('Jewell Rowly','jrowly4z','bHFqYTL1k6','90500874','jrowly4z@yellowbook.com','5353 Clyde Gallagher Drive','8773490689474488','626','1');
select NewCustomer('Corey Vollam','cvollam50','FCeY78T','92138920','cvollam50@phoca.cz','186 Summit Way','4933257476025879','184','1');
select NewCustomer('Nealy Gudd','ngudd51','tvbmT9CftXx','98197473','ngudd51@cbslocal.com','8 Sycamore Circle','3798928167086440','700','0');
select NewCustomer('Delphinia Jepps','djepps52','Cvke4djud7C','92004593','djepps52@mozilla.com','8719 Schiller Street','1669964978492729','984','1');
select NewCustomer('Jennine Skerritt','jskerritt53','z5gDXbvI8','93853188','jskerritt53@live.com','4340 Haas Court','6032291440225537','419','0');
select NewCustomer('Wren Buckham','wbuckham54','SpAsIRq','93321080','wbuckham54@i2i.jp','4645 Hayes Avenue','6813858808883225','119','0');
select NewCustomer('Elroy Brosnan','ebrosnan55','zINBIvyhDyCe','93352824','ebrosnan55@mac.com','46098 Atwood Way','4417869881614236','380','0');
select NewCustomer('Beatrix Yorkston','byorkston56','OjGNi3i9w','91663641','byorkston56@disqus.com','2 Transport Road','4308892505436978','051','1');
select NewCustomer('Geoff Reen','green57','5GG7f0I','98378290','green57@constantcontact.com','8699 Nevada Crossing','6066346628669914','952','1');
select NewCustomer('Kaycee Delong','kdelong58','mdTBYFY3t','91920068','kdelong58@mashable.com','6 Cascade Crossing','4190587799767021','664','0');
select NewCustomer('Rubina Traice','rtraice59','sL8MWj6fZsn','90010637','rtraice59@shareasale.com','565 Ryan Trail','2756809315379814','978','1');
select NewCustomer('Jania Fawdrie','jfawdrie5a','kZV5KAkWU','93458568','jfawdrie5a@yellowpages.com','3 Debra Junction','3708280907489206','130','1');
select NewCustomer('Carmelle Mashal','cmashal5b','lUIWI0J','94738014','cmashal5b@wunderground.com','969 American Way','7035507290812511','461','0');
select NewCustomer('Maurene Earie','mearie5c','SqFBEXRuV4W','90600243','mearie5c@timesonline.co.uk','90 Lawn Point','7494043083400505','541','0');
select NewCustomer('Drucill Tourle','dtourle5d','YE4Fuj','98124866','dtourle5d@statcounter.com','24547 Aberg Plaza','5374072712924747','830','0');
select NewCustomer('Lisle Priditt','lpriditt5e','gd9QwZay','94421001','lpriditt5e@rediff.com','572 Novick Park','7424739592867154','657','0');
select NewCustomer('Carlynne Bruckshaw','cbruckshaw5f','iOfvNu31FwQ7','97488232','cbruckshaw5f@columbia.edu','028 Waywood Parkway','3680127185067963','882','1');
select NewCustomer('Pietro Archibold','parchibold5g','TZqpGoHy','97402331','parchibold5g@buzzfeed.com','68970 Orin Court','0742962870568722','670','1');
select NewCustomer('Wilhelmine Raisbeck','wraisbeck5h','rdbS0WO','91149370','wraisbeck5h@nytimes.com','86354 Farragut Pass','8254375525020519','914','0');
select NewCustomer('Bobbette Dannehl','bdannehl5i','AYRGGdl','90761040','bdannehl5i@slideshare.net','70 Becker Way','0200022668223086','142','1');
select NewCustomer('Andres Branthwaite','abranthwaite5j','FpCqut','94800804','abranthwaite5j@rambler.ru','4357 Westport Parkway','0146181427994652','925','0');
select NewCustomer('Shermy Ottley','sottley5k','ltbWPTwtfmRs','93309419','sottley5k@addtoany.com','4 Fairfield Street','5126096538564940','069','1');
select NewCustomer('Melli Lovejoy','mlovejoy5l','1LnaCc','98076392','mlovejoy5l@liveinternet.ru','1 New Castle Point','0592557871821199','464','1');
select NewCustomer('Lind Blythe','lblythe5m','tGvfKr1m','95951050','lblythe5m@zdnet.com','524 Corscot Avenue','6633810670816308','392','0');
select NewCustomer('Nerty Gomersal','ngomersal5n','3mNUKDec','95558562','ngomersal5n@columbia.edu','6756 Sauthoff Hill','8893200116498570','472','0');
select NewCustomer('Mamie Fareweather','mfareweather5o','eRYVvta','96198671','mfareweather5o@google.com','026 Bonner Hill','6555050915544546','499','0');
select NewCustomer('Pennie Donald','pdonald5p','23IJ0XPn','90066577','pdonald5p@tmall.com','09769 Helena Lane','6412568469488397','891','1');
select NewCustomer('Kelly Osant','kosant5q','H7mjCl','90757332','kosant5q@pagesperso-orange.fr','1040 Westport Avenue','0026251744038308','814','0');
select NewCustomer('Nanice Simmings','nsimmings5r','5rzxsk3','97576987','nsimmings5r@blinklist.com','3 Crownhardt Place','7892204950013016','603','1');
select NewCustomer('Tallou Guerrazzi','tguerrazzi5s','HtCHeKnmw','93597123','tguerrazzi5s@auda.org.au','688 Coolidge Place','0446731075188054','404','0');
select NewCustomer('Suzi Gilogly','sgilogly5t','87gmgeiPQN','97373414','sgilogly5t@foxnews.com','1365 Farragut Avenue','7926345446315067','474','0');
select NewCustomer('Tonya Newlan','tnewlan5u','lczJDv8vBH','98856824','tnewlan5u@kickstarter.com','4 Spohn Center','3263643919090497','947','1');
select NewCustomer('Yul Durdan','ydurdan5v','PzBG8Xj9EjVU','93414376','ydurdan5v@theatlantic.com','1 Helena Junction','9664038689523364','282','1');
select NewCustomer('Creigh McCunn','cmccunn5w','LFotNZFnu','90587473','cmccunn5w@delicious.com','480 Banding Center','2582734350360101','546','1');
select NewCustomer('Florry Mayhew','fmayhew5x','Nve8GgVlFN','94872264','fmayhew5x@indiegogo.com','32 Claremont Circle','9701748065815040','377','1');
select NewCustomer('Jacquetta Batson','jbatson5y','axHm13G','96901264','jbatson5y@jalbum.net','7758 Pleasure Hill','2154519671276618','930','1');
select NewCustomer('Sybil Haseldine','shaseldine5z','CegZZsgVwenm','92645331','shaseldine5z@topsy.com','436 Lien Crossing','1789273599439857','691','0');
select NewCustomer('Oralla Vedyasov','ovedyasov60','gqoQKbf7','98337021','ovedyasov60@zimbio.com','297 Hooker Place','9265760374185339','852','0');
select NewCustomer('Karla Bratten','kbratten61','jXm6vKlVxGwT','99030137','kbratten61@naver.com','1 Mcguire Park','3969023100842601','723','0');
select NewCustomer('Arlina Decruse','adecruse62','ePg94c2dS','97294804','adecruse62@cmu.edu','834 Armistice Center','4488087336540990','631','0');
select NewCustomer('Micheal McGinley','mmcginley63','6Ha7t6dTVA','91108021','mmcginley63@bloglovin.com','32 Barnett Place','2928637925984034','811','1');
select NewCustomer('Shanon Sorrie','ssorrie64','rz3FjPg8uq','97637558','ssorrie64@psu.edu','0915 Kingsford Hill','9873829040207938','625','0');
select NewCustomer('Gregorio Skae','gskae65','3lrpqIkAhxg','96513116','gskae65@statcounter.com','526 Muir Junction','2465788188084074','476','0');
select NewCustomer('Dulcia McAughtrie','dmcaughtrie66','yCKMPBx','96293960','dmcaughtrie66@jimdo.com','69 Ryan Hill','4063905047633353','413','1');
select NewCustomer('Mart Alejo','malejo67','eeJZy3xa9vdI','90779725','malejo67@hc360.com','79588 Ridgeway Plaza','4905579554079657','198','0');
select NewCustomer('Marcia Remington','mremington68','WVI2hAlUwT27','97433882','mremington68@chronoengine.com','8137 Katie Street','0425594309369071','934','0');
select NewCustomer('Ford Saffe','fsaffe69','43mUomIffUH','98495700','fsaffe69@cornell.edu','2137 Dawn Drive','8127437752731259','370','1');
select NewCustomer('Ibbie Render','irender6a','wdGs6O9J62R','93713174','irender6a@hc360.com','491 Union Center','8525770362546500','447','1');
select NewCustomer('Hoyt Pietruszewicz','hpietruszewicz6b','tvV8y1gtDR3','92552594','hpietruszewicz6b@bbc.co.uk','697 Westend Circle','5771230048361563','477','1');
select NewCustomer('Shaun Dulinty','sdulinty6c','OdHcHJRWV','93451959','sdulinty6c@domainmarket.com','3171 Reinke Alley','6891887478879210','312','0');
select NewCustomer('Alisha Butcher','abutcher6d','UoCcjqO','96829027','abutcher6d@patch.com','092 Warbler Junction','6787119131240498','366','0');
select NewCustomer('Maribeth de Clerc','mde6e','pHnNCThE5','92950486','mde6e@admin.ch','8 Blackbird Center','5686949779701429','456','1');
select NewCustomer('Isaac Gubbin','igubbin6f','ldj8Cu','93838933','igubbin6f@accuweather.com','78198 Drewry Park','2971321245961248','027','0');
select NewCustomer('Monty Mocquer','mmocquer6g','7AeerHub','92308523','mmocquer6g@mlb.com','8060 Stephen Park','1139885642848076','798','1');
select NewCustomer('Teresa Howsley','thowsley6h','0GOCyabV6','91274343','thowsley6h@wiley.com','43 Schurz Crossing','6946439154988871','472','0');
select NewCustomer('Brittani Heffernon','bheffernon6i','QlkZOko6xc','94201396','bheffernon6i@dagondesign.com','2 Buhler Avenue','1627825656865492','054','0');
select NewCustomer('Vergil Buchanan','vbuchanan6j','gAiD3T','96690897','vbuchanan6j@blog.com','42994 Mcbride Circle','4306496040636246','044','1');
select NewCustomer('Urbain Fulk','ufulk6k','3cxLbI7FwCCr','96879513','ufulk6k@tiny.cc','2 Hayes Street','0534537678426641','744','0');
select NewCustomer('Jo-ann Everiss','jeveriss6l','pDosmPd99hjf','97326504','jeveriss6l@bloglines.com','15 Elgar Terrace','0952259912840431','912','1');
select NewCustomer('Germain Trappe','gtrappe6m','XrktUSLce','94964149','gtrappe6m@auda.org.au','779 Burning Wood Lane','9305655197400511','258','1');
select NewCustomer('Carlo Hetterich','chetterich6n','8iSRLjSbBv','98663959','chetterich6n@gov.uk','1806 Northport Point','7147647975154753','836','1');
select NewCustomer('Rica Weerdenburg','rweerdenburg6o','IfKe2v871TV8','90876020','rweerdenburg6o@wordpress.com','90 Dennis Place','8792105525785456','156','0');
select NewCustomer('Regen Gilardoni','rgilardoni6p','Dzg4grl','90016968','rgilardoni6p@nhs.uk','81 Annamark Trail','5664915474978660','110','1');
select NewCustomer('Merwin Pallent','mpallent6q','l2E44zAS','99269910','mpallent6q@prnewswire.com','496 Portage Trail','9387528689699220','271','1');
select NewCustomer('Lek Syred','lsyred6r','Ds1gJ0sN','98658577','lsyred6r@twitpic.com','4 Northfield Pass','3112477286650245','929','0');
select NewCustomer('Budd Kastel','bkastel6s','H4XTlmw','98017016','bkastel6s@tinypic.com','1 Warrior Terrace','8501736591080392','658','0');
select NewCustomer('Jervis Benkin','jbenkin6t','hXlRwgycYWM','90466229','jbenkin6t@cmu.edu','84 Welch Terrace','5722769281174329','021','0');
select NewCustomer('Elisabeth Graveney','egraveney6u','i5BewkED4NLy','98963748','egraveney6u@acquirethisname.com','543 Lunder Lane','4189397260829762','672','0');
select NewCustomer('Drew Ferriman','dferriman6v','CtbTW1J6i7fj','93036944','dferriman6v@usda.gov','95 Manufacturers Center','9674984743290250','990','0');
select NewCustomer('Lynelle Chomicki','lchomicki6w','BCePXqCoO','94302288','lchomicki6w@stanford.edu','079 Dottie Circle','8627334006336689','934','0');
select NewCustomer('Ruddy Chipps','rchipps6x','a5KY0AQ','91278465','rchipps6x@jimdo.com','02547 Golden Leaf Parkway','8426679371312194','211','1');
select NewCustomer('Luciana Bentson','lbentson6y','UJ9xUodIR','98826396','lbentson6y@w3.org','400 Shelley Terrace','7145584138387666','831','0');
select NewCustomer('Swen Davy','sdavy6z','GsRxXpZAv','94794996','sdavy6z@163.com','036 Delladonna Place','6953309078782171','530','1');
select NewCustomer('Murdock Dullingham','mdullingham70','WcOTKxJA','91331957','mdullingham70@google.es','5098 Lyons Road','0015760651670549','115','0');
select NewCustomer('Reinaldos Giddons','rgiddons71','t70TcK42','95965350','rgiddons71@dot.gov','58 Dennis Point','4818683108576999','349','1');
select NewCustomer('Krysta Losseljong','klosseljong72','U7r0MiAc6O','95651784','klosseljong72@go.com','7 Florence Drive','9534495048799477','212','0');
select NewCustomer('Thomasin Veare','tveare73','GcRWa2u4XwRl','96775774','tveare73@nsw.gov.au','50 Spohn Crossing','2637173599859590','462','0');
select NewCustomer('Bree Medler','bmedler74','voTr5Fu','95830694','bmedler74@sina.com.cn','9825 Larry Terrace','8707142220380487','736','0');
select NewCustomer('Stanly Kleinstub','skleinstub75','ERNAdd','92207146','skleinstub75@google.com.au','0 Stang Road','2124381076647675','693','0');
select NewCustomer('Rosamund Rosenblad','rrosenblad76','3g0meOiURrx9','98736947','rrosenblad76@zimbio.com','930 Hermina Park','3678001211156856','644','1');
select NewCustomer('Michaella Howerd','mhowerd77','5O2vDhSSy1','95713444','mhowerd77@mashable.com','556 Helena Trail','2416012281054539','062','1');
select NewCustomer('Austin Grigoire','agrigoire78','oNblVq6HUC','90563729','agrigoire78@cornell.edu','2 Del Mar Way','4835325349687738','199','0');
select NewCustomer('Mara Tingly','mtingly79','C12Yqdr','93281549','mtingly79@sakura.ne.jp','7214 Old Gate Drive','1684416175771705','232','1');
select NewCustomer('Sibby Kearey','skearey7a','2Zcp4eRu8e3r','94832804','skearey7a@last.fm','3560 Utah Circle','6584922575251533','436','1');
select NewCustomer('Cassandre Kimble','ckimble7b','ESGOVT','91814142','ckimble7b@mapy.cz','19918 Mitchell Lane','8537618396399205','512','0');
select NewCustomer('Eloisa Horry','ehorry7c','CyLX69r','95374455','ehorry7c@netvibes.com','9135 Troy Terrace','4401431392861492','041','1');
select NewCustomer('Branden Kaman','bkaman7d','KYta4NSR3','92433503','bkaman7d@opensource.org','47312 Bartelt Pass','4919917366915688','693','0');
select NewCustomer('Vinson McNeice','vmcneice7e','XIPt61iHxdC','96026120','vmcneice7e@blog.com','1337 Farmco Parkway','1311956808917587','621','1');
select NewCustomer('Sidnee Horsewood','shorsewood7f','XPsZzq','91600447','shorsewood7f@apache.org','12 Melrose Place','0416642703292903','103','1');
select NewCustomer('Oriana Adamsen','oadamsen7g','5QsLtI4r','96776680','oadamsen7g@nps.gov','22 8th Court','0428056027629603','745','1');
select NewCustomer('Bernice Karleman','bkarleman7h','POS37YoM','99961817','bkarleman7h@com.com','29030 Waubesa Crossing','9138864474998810','473','0');
select NewCustomer('Farris Wipfler','fwipfler7i','hmTmnYMY','96853609','fwipfler7i@google.es','4973 Hansons Junction','3796493637884070','925','1');
select NewCustomer('Hart Filyaev','hfilyaev7j','kqrn9Lpkdrug','95221803','hfilyaev7j@bloomberg.com','03 Clyde Gallagher Street','6883709833744834','554','0');
select NewCustomer('Florella Nevill','fnevill7k','UQYKKzRhVGT','96037928','fnevill7k@statcounter.com','4 Colorado Way','7412254841307772','034','1');
select NewCustomer('Colly Kemble','ckemble7l','SCrgT6wj4MU','98729828','ckemble7l@hugedomains.com','548 Lukken Pass','2639816860424429','718','1');
select NewCustomer('Brittni Scholl','bscholl7m','V9fxQfv15r','93849128','bscholl7m@bloglines.com','7 Marquette Drive','2209961930788012','097','0');
select NewCustomer('Adore MacCrossan','amaccrossan7n','Q1o7bUN','90509805','amaccrossan7n@intel.com','9204 Sutteridge Court','0445641045478382','341','1');
select NewCustomer('Jazmin Somner','jsomner7o','AYEpnN','90911611','jsomner7o@chron.com','01 Prairie Rose Pass','6129758875983786','306','1');
select NewCustomer('Karrie Liston','kliston7p','DM4w3w5a0zU','92430781','kliston7p@github.com','776 Dryden Place','6666269234259629','080','0');
select NewCustomer('Ricca Empson','rempson7q','Y2sbB6TNVOh4','98749605','rempson7q@ftc.gov','2477 Petterle Street','0374496226181099','879','1');
select NewCustomer('Wayland Antic','wantic7r','FFwEctcS','96996097','wantic7r@sciencedaily.com','74 Rowland Hill','6013511444102834','617','1');
select NewCustomer('Craig Heisham','cheisham7s','jV78jSHN','94425327','cheisham7s@pbs.org','14 Magdeline Court','4427524764424294','090','1');
select NewCustomer('Evin Acome','eacome7t','mC3KQp','92349526','eacome7t@discuz.net','0 Autumn Leaf Center','8423929272335177','239','1');
select NewCustomer('Muire O'' Gara','mo7u','IuWypxX','92328392','mo7u@furl.net','2 Eastwood Circle','9823105277316171','235','0');
select NewCustomer('Doti Harget','dharget7v','LnRx1u8tM','97274768','dharget7v@rediff.com','3530 Meadow Valley Court','8827590012530106','581','0');
select NewCustomer('Stefania Sharply','ssharply7w','UPl9PaY4r','93294536','ssharply7w@plala.or.jp','8403 Hintze Court','9560376191118634','061','1');
select NewCustomer('Ileane Sloy','isloy7x','D06adl','96956053','isloy7x@tuttocitta.it','45 Michigan Court','3171333868331740','494','0');
select NewCustomer('Leo Fanshaw','lfanshaw7y','FQF1jr7Ut','98715348','lfanshaw7y@wix.com','303 Del Mar Parkway','4875169347272089','107','1');
select NewCustomer('Maribeth Husbands','mhusbands7z','ptXXLXHGu5co','99039484','mhusbands7z@tumblr.com','0 Blaine Court','7554600417167225','676','1');
select NewCustomer('Camey Ferrer','cferrer80','QhgLATb5Nef0','97516881','cferrer80@wikia.com','84 Miller Center','4738858450168630','409','1');
select NewCustomer('Asher Possek','apossek81','2JIK9tPzk','93221625','apossek81@kickstarter.com','21150 Division Center','9303237021010643','642','0');
select NewCustomer('Jacenta Winkworth','jwinkworth82','5zGc2Pw729','93523049','jwinkworth82@shareasale.com','7014 Eagle Crest Way','9121071545697001','648','1');
select NewCustomer('Clarinda Gellibrand','cgellibrand83','Kbd6t00v63dJ','98993912','cgellibrand83@indiatimes.com','80814 Sommers Court','8225730209148526','794','1');
select NewCustomer('Garnet Olive','golive84','lt1mhFf','96425181','golive84@independent.co.uk','77731 Warner Crossing','9474562593054230','087','0');
select NewCustomer('Nowell Passmore','npassmore85','zugrJKrE','91755160','npassmore85@comcast.net','8 Butterfield Crossing','4603541646044731','978','0');
select NewCustomer('Ursola Spaldin','uspaldin86','FC7WK1aHd','94077319','uspaldin86@economist.com','3 High Crossing Circle','2350301552946421','495','0');
select NewCustomer('Estevan Geraldini','egeraldini87','XHXxJ4V8','93984043','egeraldini87@ftc.gov','6 Eagle Crest Avenue','0225235036197470','551','1');
select NewCustomer('Kurt Wixon','kwixon88','7OswyvmgMJ5c','93103309','kwixon88@goo.ne.jp','5 Ridgeway Trail','7446841661892762','768','0');
select NewCustomer('Rabi Kalf','rkalf89','zfZs3V','99587480','rkalf89@unicef.org','51 Talmadge Parkway','3594768616302254','723','1');
select NewCustomer('Quincey Humbert','qhumbert8a','8mi6CCye','96952449','qhumbert8a@webnode.com','3876 Blackbird Point','4566568251679511','658','0');
select NewCustomer('Walt Klimes','wklimes8b','XGhFn5LsURqK','90838815','wklimes8b@amazonaws.com','8768 8th Court','6220199892143526','844','1');
select NewCustomer('Nikolos Golightly','ngolightly8c','92jFo0y4Cj','95664869','ngolightly8c@cbsnews.com','457 Evergreen Avenue','2784813176342320','518','0');
select NewCustomer('Alwin Wenger','awenger8d','EUjkMUeQf5Fo','96296758','awenger8d@irs.gov','0 Golf Course Road','7697533668495453','698','0');
select NewCustomer('Berte Darbey','bdarbey8e','g5NtR0MIlV','98285308','bdarbey8e@artisteer.com','759 Stang Plaza','6448636091048938','809','0');
select NewCustomer('Beverley Ridger','bridger8f','hclxovD','97984808','bridger8f@pinterest.com','481 Mallory Hill','9322940409414395','811','1');
select NewCustomer('Ailey Pedder','apedder8g','RC3NmmAvol','98034851','apedder8g@quantcast.com','0811 Forest Run Plaza','6914392683251390','794','0');
select NewCustomer('Boy Willets','bwillets8h','DSnEnY6','93887583','bwillets8h@bloglovin.com','243 Artisan Point','6044380415413498','480','1');
select NewCustomer('Eveline Simononsky','esimononsky8i','ozc6wifr','94828077','esimononsky8i@sciencedaily.com','51 Shelley Pass','8588957471442440','386','1');
select NewCustomer('Bernadene Nickerson','bnickerson8j','E1E1cGj','94374403','bnickerson8j@howstuffworks.com','05589 Fieldstone Junction','3542412655910458','427','0');
select NewCustomer('Giffard Lyven','glyven8k','yadPTkFqv','92639609','glyven8k@msu.edu','3 Elmside Hill','5834932123272489','932','1');
select NewCustomer('Rikki Darycott','rdarycott8l','QDZ9u2Rpuz0','99833788','rdarycott8l@xing.com','3 1st Alley','7238940785208513','688','1');
select NewCustomer('Margarethe Bread','mbread8m','k1jKhcgXJ','95467381','mbread8m@msn.com','9 Glendale Lane','0498119779504550','220','1');
select NewCustomer('Hilde Kennelly','hkennelly8n','XrvZTRTR5','97642127','hkennelly8n@google.pl','30323 Erie Trail','0455304927816241','448','0');
select NewCustomer('Tuesday Crump','tcrump8o','k6h7PO','96227493','tcrump8o@wix.com','5 Thompson Pass','0961737309239030','752','0');
select NewCustomer('Nadiya Grinyakin','ngrinyakin8p','JEkLNTs0w','97673496','ngrinyakin8p@twitpic.com','40505 Chinook Hill','4586472544380947','005','1');
select NewCustomer('Tarah De Benedetti','tde8q','1XEqkiXw8M','96239380','tde8q@amazon.co.uk','416 Dottie Way','0182357212948094','345','0');
select NewCustomer('Aeriel Willers','awillers8r','gLLOclFwjouu','97421603','awillers8r@twitpic.com','82 Artisan Circle','7874421577250861','667','1');
select NewCustomer('Tara Stranahan','tstranahan8s','fWfw1MSWoOx','98080793','tstranahan8s@tumblr.com','102 Loomis Point','2544461052299138','204','1');
select NewCustomer('Massimo Issac','missac8t','3xkpXfoe9U','94325015','missac8t@weibo.com','06 Algoma Parkway','5984765945602723','324','1');
select NewCustomer('Madelaine Flipsen','mflipsen8u','OsETOvN','98377462','mflipsen8u@cbslocal.com','3 Bay Way','6909906700524442','268','0');
select NewCustomer('Cicely Dunderdale','cdunderdale8v','TCEuD2Dk','99402290','cdunderdale8v@booking.com','6 Birchwood Drive','6567973269328949','775','1');
select NewCustomer('Simonne Mongan','smongan8w','DFcHHHCj','90079351','smongan8w@washington.edu','01418 Buena Vista Drive','3611391390714032','117','1');
select NewCustomer('Lauralee Savidge','lsavidge8x','bLQ96JooGXg','95035163','lsavidge8x@scientificamerican.com','31 Lindbergh Road','2334138612965269','018','0');
select NewCustomer('Barnaby Boays','bboays8y','dVAbMpg','91818255','bboays8y@dropbox.com','7716 Briar Crest Crossing','3458914319972507','905','0');
select NewCustomer('Casey Crittal','ccrittal8z','NZrJxoLgu3V','95363020','ccrittal8z@bizjournals.com','6566 Prentice Avenue','7001103666998588','954','0');
select NewCustomer('Keir L'' Estrange','kl90','RuxgmuNakuq','93452657','kl90@sfgate.com','495 Buhler Center','2115378254173770','428','0');
select NewCustomer('Trudi Scammell','tscammell91','9k7YFF2','91626057','tscammell91@blogspot.com','61 Larry Point','0783769097045729','190','1');
select NewCustomer('Ursala Furst','ufurst92','2lLTaRC4NI','98276475','ufurst92@bravesites.com','4499 Rutledge Center','2761919592489386','949','0');
select NewCustomer('Mervin Meas','mmeas93','bnZnNlQoK','90806199','mmeas93@amazon.de','7130 Merry Crossing','1986605786525646','822','0');
select NewCustomer('Mervin Glover','mglover94','rfr3m5wP','97522033','mglover94@sun.com','63 Warner Trail','8741047572466288','103','1');
select NewCustomer('Brynne Geaves','bgeaves95','ONSLxzMoHT','97813548','bgeaves95@lycos.com','8381 Dunning Crossing','2504817067634839','732','1');
select NewCustomer('Linda Heater','lheater96','xhFWLPO79SKE','91081720','lheater96@freewebs.com','99264 2nd Crossing','6507369507811619','151','1');
select NewCustomer('Lois Jancso','ljancso97','T7sgmMyNGall','96146573','ljancso97@reverbnation.com','1 Bultman Drive','5764248890659291','620','1');
select NewCustomer('Krissie Byng','kbyng98','IBnG0ptoVVM','92961422','kbyng98@live.com','92585 Evergreen Hill','0319817225502402','407','0');
select NewCustomer('Inez Tarn','itarn99','iSRMkrW3znDS','92395265','itarn99@t-online.de','10988 Schiller Court','2268058956398747','048','0');
select NewCustomer('Corissa Metterick','cmetterick9a','h8MS3r6w','98446677','cmetterick9a@independent.co.uk','96 Portage Drive','7014545737669627','627','1');
select NewCustomer('Kathryne Ollett','kollett9b','jzVil8JCUWWT','92138042','kollett9b@webeden.co.uk','48449 Del Mar Street','6015830335160970','671','1');
select NewCustomer('Lavena Youthead','lyouthead9c','H6fwB3','91156007','lyouthead9c@state.gov','29 Dakota Crossing','4536544622481484','085','1');
select NewCustomer('Danya Stainson','dstainson9d','3gjKOrgh','90942279','dstainson9d@yolasite.com','16375 Dunning Plaza','3739946586541360','331','1');
select NewCustomer('Beale Geraudel','bgeraudel9e','WILvcIs','90241347','bgeraudel9e@mapy.cz','6 Crowley Trail','4898349901560374','370','0');
select NewCustomer('Boot McHarry','bmcharry9f','f87yUtUPj','91217749','bmcharry9f@quantcast.com','45 Dahle Plaza','5841766144737411','553','1');
select NewCustomer('Vickie Vamplew','vvamplew9g','wlsvQ5p','90202433','vvamplew9g@washingtonpost.com','6 Dunning Circle','3819615115981762','459','0');
select NewCustomer('Reid Tewkesbury.','rtewkesbury9h','S98kFFIZb3','99171642','rtewkesbury9h@canalblog.com','4 Briar Crest Lane','5142022286007450','481','1');
select NewCustomer('Cristy Marle','cmarle9i','9GvZAYox','92448924','cmarle9i@themeforest.net','814 Macpherson Alley','7718656924920064','966','1');
select NewCustomer('Scarlet Laughrey','slaughrey9j','imH4T5','94383008','slaughrey9j@nsw.gov.au','91351 Independence Park','1102397097022163','172','1');
select NewCustomer('Emmalynn Barwick','ebarwick9k','IG0UDCuTvtI','93402940','ebarwick9k@macromedia.com','55 Starling Terrace','3597464446947614','632','1');
select NewCustomer('Mame Pepon','mpepon9l','gptMyYKPaN','92639593','mpepon9l@walmart.com','6 Knutson Pass','9117580998595388','637','0');
select NewCustomer('Margareta Climo','mclimo9m','9mTZvwxp','98672812','mclimo9m@harvard.edu','695 Esker Avenue','1829490877027783','013','0');
select NewCustomer('Stearne Blackley','sblackley9n','KE6KirLC0L7B','91495885','sblackley9n@oakley.com','7831 Bellgrove Street','1309287195791433','761','1');
select NewCustomer('Archy Lovelace','alovelace9o','I2C2ds4','99628376','alovelace9o@printfriendly.com','23758 Northview Pass','5658873428062515','717','0');
select NewCustomer('Denise Rhymes','drhymes9p','Xgxpu1P','91267888','drhymes9p@samsung.com','6 Carberry Park','5102944187923678','286','0');
select NewCustomer('Bryce Decort','bdecort9q','MSxOFhRVdyS','95072855','bdecort9q@fda.gov','37847 Summit Hill','1578174107527563','829','0');
select NewCustomer('Waverley Mowatt','wmowatt9r','SVefzL','90894889','wmowatt9r@wikimedia.org','70 Cody Crossing','7860604996825341','501','0');
select NewCustomer('Odelia Badcock','obadcock9s','N13zPZj','92443123','obadcock9s@multiply.com','9 Coleman Terrace','8332267129747019','475','1');
select NewCustomer('Mick Glazyer','mglazyer9t','5FoYvlN','95265329','mglazyer9t@wisc.edu','873 Center Avenue','1896763444628882','286','0');
select NewCustomer('Allina Faulder','afaulder9u','R0n7MQ9AI','94268758','afaulder9u@gmpg.org','71914 Sunfield Center','0504712015309903','161','1');
select NewCustomer('Serena Gajewski','sgajewski9v','m4lRiyCisDOj','99639452','sgajewski9v@globo.com','5 Arrowood Circle','1409291677365893','322','0');
select NewCustomer('Cam Sanzio','csanzio9w','ByOwApQEqKog','90032425','csanzio9w@census.gov','23 Bartillon Court','4295628938736495','631','1');
select NewCustomer('Shaylyn Hagart','shagart9x','AoiXVbJBfd1','93443836','shagart9x@home.pl','63038 Coolidge Alley','5956581760882185','058','1');
select NewCustomer('Toddy de Amaya','tde9y','LcMIjX','95258296','tde9y@ucoz.com','91 Heffernan Drive','5789325000114372','272','1');
select NewCustomer('Trevar Marrable','tmarrable9z','nTb20qWKd7e','91983923','tmarrable9z@twitpic.com','35 Leroy Drive','7877455448917509','805','0');
select NewCustomer('Rosemarie Bewick','rbewicka0','On8BUV7Icr','97388571','rbewicka0@bizjournals.com','74559 Waubesa Avenue','8579840069806483','656','0');
select NewCustomer('Domenico Sarch','dsarcha1','jX5B303g8','99775052','dsarcha1@kickstarter.com','45688 Golf Course Pass','1585229848819937','021','0');
select NewCustomer('Farlee Vizard','fvizarda2','MUiBhsSO','91888017','fvizarda2@w3.org','21927 Harbort Plaza','1620680821587386','104','1');
select NewCustomer('Aurora Birt','abirta3','FzySJRDmZ7','95313207','abirta3@slate.com','17 Sherman Hill','5007184222136165','138','0');
select NewCustomer('Duncan Webb','dwebba4','khRQIzOWF','93309216','dwebba4@shinystat.com','93 Duke Plaza','2489908586492074','157','0');
select NewCustomer('Connie Tumulty','ctumultya5','HfCCpMQG','95418453','ctumultya5@bizjournals.com','652 Novick Avenue','2117124263288366','830','0');
select NewCustomer('Shoshana Southern','ssoutherna6','rGYqzW','95314056','ssoutherna6@toplist.cz','441 Carioca Lane','5997415521475588','331','0');
select NewCustomer('Dan Sedwick','dsedwicka7','uZgqO6','99551574','dsedwicka7@jigsy.com','066 Anhalt Crossing','9608556346218551','655','0');
select NewCustomer('Lura Senner','lsennera8','QJFD14DML5r','95211709','lsennera8@canalblog.com','913 Huxley Avenue','8967431147886943','963','1');
select NewCustomer('Basilius Atcock','batcocka9','zbvrPvLf','99025617','batcocka9@yandex.ru','75031 Farwell Street','9632103875285783','151','0');
select NewCustomer('Robin Baines','rbainesaa','vxv6vIfs','91285141','rbainesaa@addtoany.com','3 Wayridge Avenue','8847168436975319','810','0');
select NewCustomer('Marlyn Corradeschi','mcorradeschiab','y4fy1pxuD1','90250877','mcorradeschiab@1und1.de','563 Heath Hill','6830105757284739','178','0');
select NewCustomer('Gerri Laven','glavenac','ZDRLhLcZiR','96030699','glavenac@netscape.com','4797 Sycamore Place','9578940986074913','180','1');
select NewCustomer('Floria Chettoe','fchettoead','WpmiM1T8U2Kb','93087400','fchettoead@nba.com','94 Heath Circle','3757055176095935','282','1');
select NewCustomer('Rutger Lindner','rlindnerae','CCtN8RP9','95663276','rlindnerae@google.nl','36888 Summit Avenue','0569712138535739','210','0');
select NewCustomer('Bethany Ostick','bostickaf','HXCg1Lc8L','92684329','bostickaf@tiny.cc','606 Haas Point','0889750998579517','493','1');
select NewCustomer('Bordy Boniface','bbonifaceag','3hw6nRnnIx','93181032','bbonifaceag@irs.gov','1319 Grover Terrace','1862115489902474','097','1');
select NewCustomer('Alexina Elliston','aellistonah','iX1VoKQak','97195981','aellistonah@bbb.org','4393 Elgar Trail','6510635552648265','149','0');
select NewCustomer('Perren Frane','pfraneai','5NDWuGTV4','90703973','pfraneai@lycos.com','4883 Caliangt Hill','2247711058961724','439','1');
select NewCustomer('Chantalle Gerrit','cgerritaj','2mbxeYTrI','93376283','cgerritaj@typepad.com','7625 Sunbrook Hill','4078184334770377','432','1');
select NewCustomer('Scotty Bourner','sbournerak','BpNAqoyJ','93066476','sbournerak@cdc.gov','21 Welch Avenue','5767401505701663','302','0');
select NewCustomer('Charlie Dunphy','cdunphyal','jV08Jjy','90560529','cdunphyal@msu.edu','6865 South Crossing','4153059660836223','874','1');
select NewCustomer('Agnes Jurczak','ajurczakam','vJFU63','91302341','ajurczakam@livejournal.com','22 Roxbury Road','8408626131679612','610','0');
select NewCustomer('Hastie Penquet','hpenquetan','lnxVLLh','91383926','hpenquetan@flickr.com','3 Crowley Court','4782740918655609','701','1');
select NewCustomer('Silvester Dukelow','sdukelowao','3rNtVi7','91615415','sdukelowao@opera.com','68 Warbler Alley','8968131340674846','165','1');
select NewCustomer('Rog Maurice','rmauriceap','1ODYmAPac','98171734','rmauriceap@rambler.ru','0 Schiller Point','9876680741152232','175','0');
select NewCustomer('Netta Stothard','nstothardaq','o2bLB5wDrOvN','99387001','nstothardaq@disqus.com','0069 Pine View Center','4146213900827603','108','1');
select NewCustomer('Tris Byrom','tbyromar','TQGrcwU89r','97286621','tbyromar@bizjournals.com','41 Anthes Trail','4629589773880780','788','0');
select NewCustomer('Cyndy Kerbey','ckerbeyas','KvdizC','98972439','ckerbeyas@meetup.com','332 Spohn Lane','5229829435413037','680','1');
select NewCustomer('Emmalyn Burrows','eburrowsat','dwIKnXh8sdbF','90710043','eburrowsat@shutterfly.com','732 Bluejay Crossing','7136376708725902','088','0');
select NewCustomer('Conney Thompson','cthompsonau','p7smpUKLNvcX','98042491','cthompsonau@mozilla.org','4756 Texas Alley','3975009899934556','307','0');
select NewCustomer('Deny Van Der Vlies','dvanav','oGiUI1wZ8V','94024202','dvanav@latimes.com','10 Surrey Court','1988625625108945','944','0');
select NewCustomer('Bonita Mintoff','bmintoffaw','5PRUZSUfkDHw','92991653','bmintoffaw@wired.com','143 Village Parkway','1105502959140555','780','1');
select NewCustomer('Claybourne Bilam','cbilamax','OZgECgQBbkIk','96957893','cbilamax@home.pl','4 Dovetail Drive','4095684417649331','426','0');
select NewCustomer('Julie Keam','jkeamay','BsdTZ2hu1yC','90708288','jkeamay@issuu.com','699 Center Point','1146815011826821','713','1');
select NewCustomer('Valene Booler','vbooleraz','lT215Xy','92879701','vbooleraz@sogou.com','44 Ilene Parkway','1470547616126046','695','0');
select NewCustomer('Ambros Somerville','asomervilleb0','GYkKX84WRyBn','96209914','asomervilleb0@jugem.jp','29 Heath Plaza','7861980806370743','728','1');
select NewCustomer('Tab Asquith','tasquithb1','PgfUHZHy2','91763380','tasquithb1@sciencedirect.com','4 Canary Street','7702579249820137','907','0');
select NewCustomer('Hilary MacDermott','hmacdermottb2','oySZ0CMGUxzt','94150704','hmacdermottb2@dailymotion.com','8 Thompson Way','1173210992841286','625','1');
select NewCustomer('Perl Huske','phuskeb3','Sb4ViOJlzR5','97237248','phuskeb3@is.gd','8 Hanson Place','9470842097722369','708','1');
select NewCustomer('Bob','bobbytables','bobby','91343651','bobbyyyy@hotmail.com','72 Tampines Street','5694029593029105','234','0');

-- -- Restaurants
insert into Restaurants (name, address, min_amt_threshold, delivery_fee) values ('Pizza World', '86486 Melrose Street', 14, 3);
insert into Restaurants (name, address, min_amt_threshold, delivery_fee) values ('Chocolate Land', '40 Independence Terrace', 13, 5);
insert into Restaurants (name, address, min_amt_threshold, delivery_fee) values ('Chicken Corner', '7304 Gale Trail', 15, 5);
insert into Restaurants (name, address, min_amt_threshold, delivery_fee) values ('Fish Delights', '46 Spohn Junction', 15, 4);
insert into Restaurants (name, address, min_amt_threshold, delivery_fee) values ('Tavern Place', '8342 Mitchell Parkway', 14, 3);
insert into Restaurants (name, address, min_amt_threshold, delivery_fee) values ('Indian Delights', '733 Main Junction', 15, 5);
insert into Restaurants (name, address, min_amt_threshold, delivery_fee) values ('Pizza Hut', '65205 Manufacturers Terrace', 15, 7);
insert into Restaurants (name, address, min_amt_threshold, delivery_fee) values ('KFC', '8371 Granby Circle', 12, 3);
insert into Restaurants (name, address, min_amt_threshold, delivery_fee) values ('Foodie Paradise', '39 Anhalt Pass', 12, 2);
insert into Restaurants (name, address, min_amt_threshold, delivery_fee) values ('Chinese World', '110 Montana Way', 10, 5);
insert into Restaurants (name, address, min_amt_threshold, delivery_fee) values ('Gourmet Land', '6 Monument Circle', 14, 6);
insert into Restaurants (name, address, min_amt_threshold, delivery_fee) values ('Lim Eatery', '58 Mayer Junction', 16, 4);
insert into Restaurants (name, address, min_amt_threshold, delivery_fee) values ('Koi', '9929 School Parkway', 16, 5);
insert into Restaurants (name, address, min_amt_threshold, delivery_fee) values ('Llao Llao', '8 Lakeland Court', 12, 3);
insert into Restaurants (name, address, min_amt_threshold, delivery_fee) values ('MacDonalds', '9051 Golden Leaf Way', 12, 2);
insert into Restaurants (name, address, min_amt_threshold, delivery_fee) values ('Wendys', '7 Shasta Court', 14, 5);
insert into Restaurants (name, address, min_amt_threshold, delivery_fee) values ('Fried Chicken Specials', '85 Springs Drive', 15, 6);
insert into Restaurants (name, address, min_amt_threshold, delivery_fee) values ('Arnolds', '9460 Maple Wood Crossing', 16, 8);
insert into Restaurants (name, address, min_amt_threshold, delivery_fee) values ('Canton Paradise', '34 Dakota Terrace', 11, 8);
insert into Restaurants (name, address, min_amt_threshold, delivery_fee) values ('Dian Xiao Er', '36228 Golf Course Avenue', 10, 10);
insert into Restaurants (name, address, min_amt_threshold, delivery_fee) values ('FoodKing', '59686 Rutledge Terrace', 15, 6);
insert into Restaurants (name, address, min_amt_threshold, delivery_fee) values ('Pizza Place', '11904 Pleasure Pass', 12, 4);
insert into Restaurants (name, address, min_amt_threshold, delivery_fee) values ('Corleone Corner', '015 Thompson Crossing', 15, 7);
insert into Restaurants (name, address, min_amt_threshold, delivery_fee) values ('Hainan Chicken', '84674 Alpine Alley', 15, 3);
insert into Restaurants (name, address, min_amt_threshold, delivery_fee) values ('Laksa Mama', '9 Crownhardt Terrace', 12, 7);

<<<<<<< HEAD
-- --FDSManagers
=======
--FDSManagers
>>>>>>> origin/master
select NewFDSManager('Chadd Dumper','cdumper0','password','90075393','cdumper0@google.pl');
select NewFDSManager('Lemuel Dignan','ldignan1','fe4C1rQ6h','96155025','ldignan1@weibo.com');
select NewFDSManager('Doe Pickerin','dpickerin2','6cVuU03no','95909190','dpickerin2@photobucket.com');
select NewFDSManager('Theresa Tummasutti','ttummasutti3','cND5KOWN','96001329','ttummasutti3@mediafire.com');
select NewFDSManager('Deirdre Rickert','drickert4','nTvg1K','95604078','drickert4@europa.eu');
select NewFDSManager('Carolin Lebourn','clebourn5','BE4DBUM2V','92050445','clebourn5@netlog.com');
select NewFDSManager('Raff Sutter','rsutter6','sMYNqESMz','95097268','rsutter6@toplist.cz');
select NewFDSManager('Rosamond Stavers','rstavers7','dEWfiU4RGD3y','90026533','rstavers7@hud.gov');
select NewFDSManager('Yasmin Vibert','yvibert8','jkXnGUv8','94624539','yvibert8@godaddy.com');
select NewFDSManager('Julieta Currier','jcurrier9','W5JXxgyM5H','92479125','jcurrier9@hc360.com');
select NewFDSManager('Quent Lukovic','qlukovica','PjFDwDyM','93942666','qlukovica@bigcartel.com');
select NewFDSManager('Sella Tower','stowerb','pmdtcr4jDk7E','96489245','stowerb@netvibes.com');
select NewFDSManager('Tomlin Gurton','tgurtonc','Bdt5CKJU','90338841','tgurtonc@msu.edu');
select NewFDSManager('Vinson Raithbie','vraithbied','PZfp5R','91716706','vraithbied@digg.com');
select NewFDSManager('Shannon Losebie','slosebiee','W6bvozp','91553627','slosebiee@woothemes.com');
select NewFDSManager('Daren Punyer','dpunyerf','cXu4e7X','96010548','dpunyerf@columbia.edu');
select NewFDSManager('Aida Coldrick','acoldrickg','OiAYJpH8Y6Ha','93083968','acoldrickg@howstuffworks.com');
select NewFDSManager('Darcy Dumbell','ddumbellh','5qW62WP0tGZk','94408767','ddumbellh@hexun.com');
select NewFDSManager('Joice Roderigo','jroderigoi','YzeaBH8qIWip','94466455','jroderigoi@blinklist.com');
select NewFDSManager('Hermon Birdwhistell','hbirdwhistellj','mePsDCZZTkZp','92893717','hbirdwhistellj@hugedomains.com');
select NewFDSManager('Doria Yukhnin','dyukhnink','7Lkmsjr','91934675','dyukhnink@mapquest.com');
select NewFDSManager('Webster Brackenridge','wbrackenridgel','EvuqyP7O','91929017','wbrackenridgel@harvard.edu');
select NewFDSManager('Siouxie Peidro','speidrom','H3i26SIzmtA','96929913','speidrom@sourceforge.net');
select NewFDSManager('Halsey Danielis','hdanielisn','9wAGCXco4bjp','98529424','hdanielisn@ebay.com');
select NewFDSManager('Bette-ann Boyet','bboyeto','AcEde0kr05x5','91041938','bboyeto@seesaa.net');
select NewFDSManager('Sean Gallichan','sgallichanp','YTVhMc','97105235','sgallichanp@multiply.com');
select NewFDSManager('Jeannine Terbruggen','jterbruggenq','vMDxIoEX5','90605278','jterbruggenq@elpais.com');
select NewFDSManager('Field Carlyon','fcarlyonr','KUbWT3v2B','93816831','fcarlyonr@fc2.com');
select NewFDSManager('Selestina Fundell','sfundells','JyIzgqTeXy','98024591','sfundells@slashdot.org');
select NewFDSManager('Rickie Gallon','rgallont','bmKQIvEfLTCD','90677183','rgallont@army.mil');
select NewFDSManager('Elmore Rodrigues','erodriguesu','rBEY9dnfy2Gi','98596024','erodriguesu@npr.org');
select NewFDSManager('Steffen Giurio','sgiuriov','L2Sup1Gsn','93404709','sgiuriov@sun.com');
select NewFDSManager('Mirilla Scrivener','mscrivenerw','GdFBOJ5B','91380124','mscrivenerw@rakuten.co.jp');
select NewFDSManager('Christalle Bynold','cbynoldx','pSte7Os','99344692','cbynoldx@goodreads.com');
select NewFDSManager('Dorothy Cornillot','dcornilloty','aZF7tK','94518256','dcornilloty@wiley.com');
select NewFDSManager('Tyson Bolan','tbolanz','z2ZCaMRsh','97135852','tbolanz@ebay.co.uk');
select NewFDSManager('Lexi Roome','lroome10','S5YdSIzZP','99930865','lroome10@tmall.com');
select NewFDSManager('Dallas Hurton','dhurton11','tU6g3Au10','90250553','dhurton11@constantcontact.com');
select NewFDSManager('Kingsley Quinn','kquinn12','SYyfjYjDvkUq','92825489','kquinn12@indiatimes.com');
select NewFDSManager('Eldridge Maciaszek','emaciaszek13','pMC6kqJEElRD','91308420','emaciaszek13@addthis.com');
select NewFDSManager('Van Montier','vmontier14','iSA1DBzHF','90183467','vmontier14@yolasite.com');
select NewFDSManager('Si Leuchars','sleuchars15','JJ0yxJl','90091970','sleuchars15@boston.com');
select NewFDSManager('Adey Doumerc','adoumerc16','8Pqxf7Av7E','94845397','adoumerc16@globo.com');
select NewFDSManager('Myrilla Heinicke','mheinicke17','Z9Bp3eCVaY','92172749','mheinicke17@sina.com.cn');
select NewFDSManager('Ninnetta Coggan','ncoggan18','Lh4Bdw0Z','92050267','ncoggan18@jimdo.com');
select NewFDSManager('Tonie Antosik','tantosik19','bMlwgpY','91421334','tantosik19@chron.com');
select NewFDSManager('Corette Havesides','chavesides1a','AgFrGmzMs6','97173441','chavesides1a@angelfire.com');
select NewFDSManager('Denney Harcourt','dharcourt1b','O3ltmVx8','98449631','dharcourt1b@weebly.com');
select NewFDSManager('Phip Kiefer','pkiefer1c','XbAb0zAj8up','94492167','pkiefer1c@discuz.net');
select NewFDSManager('Myrle Jelf','mjelf1d','WB8jVyxnhL','92191824','mjelf1d@taobao.com');
select NewFDSManager('Bernetta Hamnett','bhamnett1e','yg6JbiA62Sm','97963837','bhamnett1e@yale.edu');
select NewFDSManager('Javier Notti','jnotti1f','13qbGM','99061454','jnotti1f@linkedin.com');
select NewFDSManager('Roxine Mitcham','rmitcham1g','8dB3lA','93612101','rmitcham1g@geocities.com');
select NewFDSManager('Virge Paynton','vpaynton1h','UwZv8tK9Jw','95132740','vpaynton1h@baidu.com');
select NewFDSManager('Milicent Lenham','mlenham1i','IqSnhne2PV','91695818','mlenham1i@wsj.com');
select NewFDSManager('Danie Di Roberto','ddi1j','YKb2R3ssejs','98410641','ddi1j@wiley.com');
select NewFDSManager('Adel Kintish','akintish1k','QoUiuA','98729146','akintish1k@goo.gl');
select NewFDSManager('Brandise Buret','bburet1l','zD1za6SG','91120629','bburet1l@buzzfeed.com');
select NewFDSManager('Kaile Gothard','kgothard1m','GrittDjFX','95755619','kgothard1m@shinystat.com');
select NewFDSManager('Rivkah McInnery','rmcinnery1n','0Yj9TpczV4F','99958373','rmcinnery1n@va.gov');
select NewFDSManager('Morie Goodsell','mgoodsell1o','23PbrGQLY','94080724','mgoodsell1o@infoseek.co.jp');
select NewFDSManager('Izaak Yea','iyea1p','GIJ6rT5C','97608897','iyea1p@oaic.gov.au');
select NewFDSManager('Juan Tidmarsh','jtidmarsh1q','nkbClhTb','91307056','jtidmarsh1q@canalblog.com');
select NewFDSManager('Wallache Slocom','wslocom1r','QcvinDhJ3G','94950182','wslocom1r@jugem.jp');
select NewFDSManager('Jamil Snepp','jsnepp1s','kU3m4b27wno2','99679312','jsnepp1s@comsenz.com');
select NewFDSManager('Kali Andor','kandor1t','jpMkMZPfk9Q','93122078','kandor1t@pen.io');
select NewFDSManager('Aleta Wrates','awrates1u','ZHr02j3Os','96777052','awrates1u@example.com');
select NewFDSManager('Hanson Howarth','hhowarth1v','yGVrWEoy','98272587','hhowarth1v@scientificamerican.com');
select NewFDSManager('Reagan Carette','rcarette1w','N4CweN46mf','98818087','rcarette1w@printfriendly.com');
select NewFDSManager('Peggie Ffrench','pffrench1x','kxdZo6','92185683','pffrench1x@guardian.co.uk');
select NewFDSManager('Vasilis Lambourn','vlambourn1y','YCldYKGg','94173328','vlambourn1y@moonfruit.com');
select NewFDSManager('Codi Ceschi','cceschi1z','COtHhSh8','93667950','cceschi1z@pinterest.com');
select NewFDSManager('Adrienne Franceschi','afranceschi20','XCYXMZF1n','93116150','afranceschi20@economist.com');
select NewFDSManager('Philomena Macura','pmacura21','U5uFWVd0SUBr','90845409','pmacura21@bravesites.com');
select NewFDSManager('Carleton Pawellek','cpawellek22','skEzaN02','90930853','cpawellek22@ezinearticles.com');
select NewFDSManager('Rhodie Wagstaff','rwagstaff23','XZEQvXS1','96944152','rwagstaff23@ebay.co.uk');
select NewFDSManager('Ruthe Hateley','rhateley24','IeuqT3','91360463','rhateley24@bing.com');
select NewFDSManager('Pietro Vanini','pvanini25','tAhhur','93191137','pvanini25@elegantthemes.com');
select NewFDSManager('Joeann MacNalley','jmacnalley26','zFsYMcWG','91201356','jmacnalley26@deviantart.com');
select NewFDSManager('Annecorinne Keightley','akeightley27','SMXkITz8ZoVe','93918385','akeightley27@cdbaby.com');
select NewFDSManager('Burnaby Veryan','bveryan28','qdKnBPL6p','93172985','bveryan28@google.nl');
select NewFDSManager('Nealon Cullingworth','ncullingworth29','ML7r9tu','92015027','ncullingworth29@irs.gov');
select NewFDSManager('Early Devers','edevers2a','GtoUDj82y','91826615','edevers2a@virginia.edu');
select NewFDSManager('Lucinda Bischoff','lbischoff2b','eof2TA1eo','98530536','lbischoff2b@state.tx.us');
select NewFDSManager('Mella Twaits','mtwaits2c','UEMqjuaJ','92404959','mtwaits2c@clickbank.net');
select NewFDSManager('Mara McCloid','mmccloid2d','CZYiy3TpYpn','94335264','mmccloid2d@sfgate.com');
select NewFDSManager('Cybill Ledwich','cledwich2e','hG64Yr2Rgll','92003942','cledwich2e@cam.ac.uk');
select NewFDSManager('Haslett Corps','hcorps2f','1sKVQkTli','97617378','hcorps2f@live.com');
select NewFDSManager('Kalina Belfit','kbelfit2g','ZrPwNpQM','94389284','kbelfit2g@hexun.com');
select NewFDSManager('Sadella Wolfendale','swolfendale2h','DYbTrfqIP','94045685','swolfendale2h@vimeo.com');
select NewFDSManager('Roxy Teek','rteek2i','f83z7yj5L','98825580','rteek2i@nps.gov');
select NewFDSManager('Lesly Downs','ldowns2j','WDiBfkG0wc5L','94702630','ldowns2j@patch.com');
select NewFDSManager('Garreth Follan','gfollan2k','wYG2cSTiR9','94350334','gfollan2k@com.com');
select NewFDSManager('Emlynne Whitsey','ewhitsey2l','bmyr1APFqMcc','94846212','ewhitsey2l@dyndns.org');
select NewFDSManager('Christa Bravington','cbravington2m','Fur9bUSpvZB','90846381','cbravington2m@wikia.com');
select NewFDSManager('Valeda Snoxell','vsnoxell2n','o5Yj8A1m4Go','98709606','vsnoxell2n@whitehouse.gov');
select NewFDSManager('Guthrey Gaddas','ggaddas2o','oCJVG6JbN','98955516','ggaddas2o@spiegel.de');
select NewFDSManager('Barbette Panchin','bpanchin2p','vIWE0zE','92305907','bpanchin2p@list-manage.com');
select NewFDSManager('Raddy Weatherhogg','rweatherhogg2q','z6i0jb','93405805','rweatherhogg2q@usnews.com');
select NewFDSManager('Nicolas Etherington','netherington2r','pZ2rNufHwt','93319714','netherington2r@ebay.co.uk');

-- --RestaurantStaff
select NewRestaurantStaff('Joscelin Strephan','jstrephan0','password','92204063','jstrephan0@hhs.gov', 1);
select NewRestaurantStaff('Georgianna Pasmore','gpasmore1','bnUJ8b','91553711','gpasmore1@earthlink.net', 14);
select NewRestaurantStaff('Nicholle Cater','ncater2','uydRNZo','95412617','ncater2@dropbox.com', 7);
select NewRestaurantStaff('Aldric Lattka','alattka3','4p9mWbSMG','98884131','alattka3@icio.us', 24);
select NewRestaurantStaff('Dav Reddan','dreddan4','qp7LerP','92767850','dreddan4@odnoklassniki.ru', 6);
select NewRestaurantStaff('Zonda Challicombe','zchallicombe5','dARKtM9','95771065','zchallicombe5@printfriendly.com', 7);
select NewRestaurantStaff('Kerrin Di Pietro','kdi6','HqBhDXq9Gb','99913167','kdi6@icio.us', 17);
select NewRestaurantStaff('Gunner McLevie','gmclevie7','Sje988wh','96804731','gmclevie7@cbsnews.com', 24);
select NewRestaurantStaff('Kermy Pinnigar','kpinnigar8','Gubg7Qe','90171243','kpinnigar8@dot.gov', 25);
select NewRestaurantStaff('Viviene Streeton','vstreeton9','XJHkznac7','98708107','vstreeton9@dropbox.com', 16);
select NewRestaurantStaff('Fernandina Sibly','fsiblya','OrZWwRcKBp2','91716337','fsiblya@photobucket.com', 10);
select NewRestaurantStaff('Lydia Tomalin','ltomalinb','2Yl8LIkVB','97911996','ltomalinb@printfriendly.com', 21);
select NewRestaurantStaff('Keeley Terris','kterrisc','Q5AjqjuRy','99049374','kterrisc@de.vu', 23);
select NewRestaurantStaff('Cathleen Fellenor','cfellenord','8ik1izM3','90381241','cfellenord@earthlink.net', 13);
select NewRestaurantStaff('Royall Caherny','rcahernye','rYnYur','91584266','rcahernye@businesswire.com', 13);
select NewRestaurantStaff('Melita Cubberley','mcubberleyf','LEqQSx171','90668753','mcubberleyf@cargocollective.com', 8);
select NewRestaurantStaff('Bobinette Klimke','bklimkeg','XlTetmrJW','92221245','bklimkeg@ed.gov', 24);
select NewRestaurantStaff('Belia De Cruze','bdeh','w0RxrA','90722431','bdeh@theglobeandmail.com', 12);
select NewRestaurantStaff('Monah Weare','mwearei','ar5hTjKHN8g','93741289','mwearei@liveinternet.ru', 18);
select NewRestaurantStaff('Kirbie Riglar','kriglarj','eJwhIDJ','97334087','kriglarj@cafepress.com', 25);
select NewRestaurantStaff('Conn Payton','cpaytonk','okG9zbB','99811022','cpaytonk@photobucket.com', 19);
select NewRestaurantStaff('Tommi Ricketts','trickettsl','ISuHLKEqr7','94843776','trickettsl@ibm.com', 3);
select NewRestaurantStaff('Willy Titcom','wtitcomm','Zb8tplkU6yhZ','97740150','wtitcomm@bbc.co.uk', 8);
select NewRestaurantStaff('Albert Ramage','aramagen','hPvdXKvmk','91505573','aramagen@multiply.com', 20);
select NewRestaurantStaff('Misha Orys','moryso','BRpcZFgceG','94447393','moryso@baidu.com', 7);
select NewRestaurantStaff('Abbie Stivens','astivensp','fT0czZnGbEa9','97104225','astivensp@patch.com', 3);
select NewRestaurantStaff('Conrade Farragher','cfarragherq','ui2nx0hghGh','90296162','cfarragherq@ebay.co.uk', 13);
select NewRestaurantStaff('Ariel Siveyer','asiveyerr','eMtTRStsxN','96619311','asiveyerr@japanpost.jp', 10);
select NewRestaurantStaff('Konrad Grant','kgrants','NIDe353W4','93982306','kgrants@nydailynews.com', 25);
select NewRestaurantStaff('Hermon Dohmer','hdohmert','Vf24Bh0PLp2','93077081','hdohmert@hatena.ne.jp', 11);
select NewRestaurantStaff('Felicio MacDonogh','fmacdonoghu','C3IwRo1zR','92403086','fmacdonoghu@amazon.co.jp', 20);
select NewRestaurantStaff('Noelani Emeny','nemenyv','T41glnMLm','93914582','nemenyv@studiopress.com', 9);
select NewRestaurantStaff('Joshia Levensky','jlevenskyw','URY5YWt9WWE','90755226','jlevenskyw@rambler.ru', 20);
select NewRestaurantStaff('Jacky Jaffrey','jjaffreyx','1TfFoWIn5GVc','93074635','jjaffreyx@meetup.com', 20);
select NewRestaurantStaff('Orrin Milner','omilnery','ITfABGI1O1r4','97190193','omilnery@thetimes.co.uk', 1);
select NewRestaurantStaff('Aridatha Limon','alimonz','88IWcgvwuey','94106146','alimonz@desdev.cn', 4);
select NewRestaurantStaff('Jackie Rodda','jrodda10','QNZI0PeHJT','96179953','jrodda10@ovh.net', 15);
select NewRestaurantStaff('Boote Fauguel','bfauguel11','hqqoOsn17P51','90020543','bfauguel11@gravatar.com', 8);
select NewRestaurantStaff('Lizzy Parnby','lparnby12','2X2R4Qlr','96250443','lparnby12@barnesandnoble.com', 7);
select NewRestaurantStaff('Nadiya Nisius','nnisius13','GIgthF','97954594','nnisius13@trellian.com', 25);
select NewRestaurantStaff('Stacey Gobel','sgobel14','WkR9kVNAR','91953579','sgobel14@rakuten.co.jp', 22);
select NewRestaurantStaff('Willard Barltrop','wbarltrop15','x0Tflt','98855211','wbarltrop15@technorati.com', 13);
select NewRestaurantStaff('Rosamund Sarch','rsarch16','bVzHhoPQWHgw','96359672','rsarch16@princeton.edu', 3);
select NewRestaurantStaff('Dionysus Hacker','dhacker17','RsgGhRlr1s0','97775091','dhacker17@yale.edu', 20);
select NewRestaurantStaff('Had Grahame','hgrahame18','kn5BmfP4ElgG','95451498','hgrahame18@nps.gov', 20);
select NewRestaurantStaff('Bee Dutteridge','bdutteridge19','Iokigf','98771602','bdutteridge19@wordpress.com', 24);
select NewRestaurantStaff('Dell Roselli','droselli1a','2zawrhJ','97674018','droselli1a@independent.co.uk', 3);
select NewRestaurantStaff('Elvin Gilffillan','egilffillan1b','6mSJvzRm9mIk','92332901','egilffillan1b@1und1.de', 18);
select NewRestaurantStaff('Prescott Diplock','pdiplock1c','NJI3u3mXO','96818494','pdiplock1c@meetup.com', 15);
select NewRestaurantStaff('Trula Muxworthy','tmuxworthy1d','nR5ktSA','95487067','tmuxworthy1d@nsw.gov.au', 21);
select NewRestaurantStaff('Rubin Fenny','rfenny1e','Y7Lji53rGcA','95443522','rfenny1e@cloudflare.com', 16);
select NewRestaurantStaff('Hendrick Starton','hstarton1f','WGNFUAUF','96662278','hstarton1f@columbia.edu', 10);
select NewRestaurantStaff('Easter Boardman','eboardman1g','NjUtfAB','93866544','eboardman1g@google.com.hk', 5);
select NewRestaurantStaff('Tristan Gheorghescu','tgheorghescu1h','LTjka0emYwUU','91743516','tgheorghescu1h@blogger.com', 12);
select NewRestaurantStaff('Anissa Olfert','aolfert1i','sCt1pPsct','90663662','aolfert1i@engadget.com', 14);
select NewRestaurantStaff('Nealy Cowdroy','ncowdroy1j','3xqsBT58vu','91755272','ncowdroy1j@sciencedaily.com', 5);
select NewRestaurantStaff('Rhona Billham','rbillham1k','odpoYiU','98579090','rbillham1k@stumbleupon.com', 8);
select NewRestaurantStaff('Siusan Wakerley','swakerley1l','lsQcFrR','97457748','swakerley1l@springer.com', 17);
select NewRestaurantStaff('Una Halfacree','uhalfacree1m','mfWc3nDJxp89','94766020','uhalfacree1m@51.la', 9);
select NewRestaurantStaff('Sammie Rand','srand1n','X3elKP','98545809','srand1n@usatoday.com', 25);
select NewRestaurantStaff('Talbert Grannell','tgrannell1o','kDrh3njgNhi','93380911','tgrannell1o@networkadvertising.org', 19);
select NewRestaurantStaff('Raphaela Girardi','rgirardi1p','VNHBSl','95796884','rgirardi1p@icio.us', 20);
select NewRestaurantStaff('Conroy Roseaman','croseaman1q','bUnUcmFxcEO','90156356','croseaman1q@delicious.com', 3);
select NewRestaurantStaff('Stanleigh Littefair','slittefair1r','OLjXt8','90415571','slittefair1r@hatena.ne.jp', 8);
select NewRestaurantStaff('Clair Garrould','cgarrould1s','HqCZpmi','91418471','cgarrould1s@army.mil', 18);
select NewRestaurantStaff('Jada Targett','jtargett1t','iDoukpLb','99567105','jtargett1t@usatoday.com', 24);
select NewRestaurantStaff('Mildrid Nial','mnial1u','wB1Xf2Q','96913108','mnial1u@histats.com', 25);
select NewRestaurantStaff('Denys Mawford','dmawford1v','cHdw7QL06','91381554','dmawford1v@ifeng.com', 4);
select NewRestaurantStaff('Zackariah Brewer','zbrewer1w','vg9MS3','91349099','zbrewer1w@ask.com', 25);
select NewRestaurantStaff('Keary Giottoi','kgiottoi1x','XqeUd2','98959826','kgiottoi1x@paginegialle.it', 4);
select NewRestaurantStaff('Tanya Chant','tchant1y','z7cNvia09h','92773257','tchant1y@over-blog.com', 2);
select NewRestaurantStaff('Jennee Desvignes','jdesvignes1z','xiS36P0RB','91379009','jdesvignes1z@cafepress.com', 10);
select NewRestaurantStaff('Brett Goward','bgoward20','hEejo0pa','98128868','bgoward20@examiner.com', 22);
select NewRestaurantStaff('Clara Coltan','ccoltan21','667EEzjUE3Tj','93648952','ccoltan21@buzzfeed.com', 13);
select NewRestaurantStaff('Bartholomew Grandin','bgrandin22','rBevTdkvGb','95092545','bgrandin22@house.gov', 22);
select NewRestaurantStaff('Tedda Minall','tminall23','ROFeLShZ','98621092','tminall23@reference.com', 4);
select NewRestaurantStaff('Weider Verlander','wverlander24','8bHzhsTP','90747212','wverlander24@pcworld.com', 20);
select NewRestaurantStaff('Shauna Bernolet','sbernolet25','6zuZ89KYuRr','92427193','sbernolet25@ed.gov', 3);
select NewRestaurantStaff('Rhianon Westhoff','rwesthoff26','o7rU9d18N','98830236','rwesthoff26@ycombinator.com', 11);
select NewRestaurantStaff('Dominga Kloser','dkloser27','t22WL7fWwkk6','90902262','dkloser27@webnode.com', 21);
select NewRestaurantStaff('Barty Nurse','bnurse28','kEH5UpO','93110004','bnurse28@reference.com', 19);
select NewRestaurantStaff('Katina Windmill','kwindmill29','8LhVzjF','98104395','kwindmill29@uol.com.br', 10);
select NewRestaurantStaff('Christiano Lambrook','clambrook2a','tba98y2kWDD','94578137','clambrook2a@whitehouse.gov', 9);
select NewRestaurantStaff('Hughie Giraudat','hgiraudat2b','cIKymwtoVHO','94247657','hgiraudat2b@scribd.com', 13);
select NewRestaurantStaff('Silvana Fishleigh','sfishleigh2c','FyOdCB21GD','92872177','sfishleigh2c@jiathis.com', 5);
select NewRestaurantStaff('Myranda Pedron','mpedron2d','9NbxlpX4f46','90860799','mpedron2d@addtoany.com', 11);
select NewRestaurantStaff('Reiko Probetts','rprobetts2e','yRxo8sU','92740808','rprobetts2e@arstechnica.com', 2);
select NewRestaurantStaff('Gretta Gibbe','ggibbe2f','cqWBYq93U9MW','93868580','ggibbe2f@google.fr', 15);
select NewRestaurantStaff('Jemmie Sokell','jsokell2g','n9TGrO','93744744','jsokell2g@techcrunch.com', 1);
select NewRestaurantStaff('Cleo Olechnowicz','colechnowicz2h','yQ6GFO4HFcy','91634230','colechnowicz2h@time.com', 10);
select NewRestaurantStaff('Orel Daintree','odaintree2i','9XoezF0DgWz','93469596','odaintree2i@prlog.org', 12);
select NewRestaurantStaff('Mag Tellenbroker','mtellenbroker2j','3JPJ8Wns','91903589','mtellenbroker2j@ibm.com', 25);
select NewRestaurantStaff('Rudyard Vallery','rvallery2k','pIXfhW','92277601','rvallery2k@google.com', 19);
select NewRestaurantStaff('Selie Skellon','sskellon2l','a4FWXG','97787763','sskellon2l@whitehouse.gov', 12);
select NewRestaurantStaff('Emiline Reichardt','ereichardt2m','MmSUpRGC072R','96594780','ereichardt2m@hubpages.com', 12);
select NewRestaurantStaff('Wheeler Bartholomaus','wbartholomaus2n','NU9eM4XPJWKv','97103857','wbartholomaus2n@kickstarter.com', 6);
select NewRestaurantStaff('Paulie McAllen','pmcallen2o','LsgWWDG3pCC','90161413','pmcallen2o@netscape.com', 6);
select NewRestaurantStaff('Iona Itscowics','iitscowics2p','QaQy2FwfGM','98984056','iitscowics2p@time.com', 24);
select NewRestaurantStaff('Fiona Francis','ffrancis2q','1vlJQb','94051860','ffrancis2q@opera.com', 20);
select NewRestaurantStaff('Merry Preator','mpreator2r','9q8gDhdSx','99384508','mpreator2r@unblog.fr', 21);
select NewRestaurantStaff('Nadean Whitechurch','nwhitechurch2s','jysgbBJnCLWr','90726561','nwhitechurch2s@mozilla.com', 5);
select NewRestaurantStaff('Vachel Oakley','voakley2t','EicCub5bFEp','93327405','voakley2t@shareasale.com', 5);
select NewRestaurantStaff('Eugenius Sandwich','esandwich2u','ZyAJyWrZ','94288850','esandwich2u@paypal.com', 3);
select NewRestaurantStaff('Allsun Turfin','aturfin2v','Jpnoj9bWUejc','98970109','aturfin2v@github.com', 1);
select NewRestaurantStaff('Thebault Longfield','tlongfield2w','OAmFgFmJfmM','97366272','tlongfield2w@oaic.gov.au', 20);
select NewRestaurantStaff('Jeth Shine','jshine2x','Bqxg7HZ5Pv','90606093','jshine2x@mediafire.com', 21);
select NewRestaurantStaff('Meyer Brinsden','mbrinsden2y','4TMHWb8Zx','93385839','mbrinsden2y@usda.gov', 14);
select NewRestaurantStaff('Elisha Snare','esnare2z','KZz9EcIEcW1C','94896790','esnare2z@bizjournals.com', 11);
select NewRestaurantStaff('Trixie Lauritsen','tlauritsen30','72ryAQhehPZ','94715922','tlauritsen30@npr.org', 12);
select NewRestaurantStaff('Tobey Gurnay','tgurnay31','PAGENSsFJ','97832372','tgurnay31@blogtalkradio.com', 12);
select NewRestaurantStaff('Elenore Redwing','eredwing32','Y5l3ZVKr','92117317','eredwing32@cbslocal.com', 18);
select NewRestaurantStaff('Datha Errichiello','derrichiello33','Zz4zcbO','90150312','derrichiello33@businessweek.com', 13);
select NewRestaurantStaff('Lulu Neary','lneary34','rjMFNVYO','96942072','lneary34@cbsnews.com', 25);
select NewRestaurantStaff('Jennifer Mourant','jmourant35','EBO0p3gT','96301570','jmourant35@chicagotribune.com', 22);
select NewRestaurantStaff('Cori Medmore','cmedmore36','bHUsWPAei3','93803178','cmedmore36@ifeng.com', 14);
select NewRestaurantStaff('Rriocard Kleinsinger','rkleinsinger37','3Zdw4rPqv','99360543','rkleinsinger37@weibo.com', 24);
select NewRestaurantStaff('Rosmunda Mays','rmays38','APkrPF','95815318','rmays38@mashable.com', 16);
select NewRestaurantStaff('Halli Bartholomew','hbartholomew39','vItKMhwEb1YV','94476806','hbartholomew39@dot.gov', 5);
select NewRestaurantStaff('Ardys Brougham','abrougham3a','R13ldKFraJRO','98810614','abrougham3a@macromedia.com', 16);
select NewRestaurantStaff('Carlee Parnall','cparnall3b','Z7H7Nhh','90959906','cparnall3b@gravatar.com', 16);
select NewRestaurantStaff('Milzie Galier','mgalier3c','d1ocbCVx1swL','93685194','mgalier3c@vinaora.com', 15);
select NewRestaurantStaff('Belva Doohan','bdoohan3d','ACxsnN','98979719','bdoohan3d@economist.com', 8);
select NewRestaurantStaff('Cody Hucke','chucke3e','gpi7tF4DOLsy','95141705','chucke3e@virginia.edu', 9);
select NewRestaurantStaff('Aldric Bradshaw','abradshaw3f','pDCfaqP2Zi','90130713','abradshaw3f@uiuc.edu', 23);
select NewRestaurantStaff('Fenelia Le Maitre','fle3g','uLQyXF5','90365656','fle3g@seesaa.net', 2);
select NewRestaurantStaff('Kev Moyne','kmoyne3h','CvxHSz','94049516','kmoyne3h@wikimedia.org', 19);
select NewRestaurantStaff('Shandie Druett','sdruett3i','BsI6bhc3gJw','93874918','sdruett3i@youtube.com', 25);
select NewRestaurantStaff('Theodore Merck','tmerck3j','5HhUyaq','97001812','tmerck3j@zdnet.com', 17);
select NewRestaurantStaff('Michael Wagenen','mwagenen3k','aAMAma8','90472598','mwagenen3k@phoca.cz', 20);
select NewRestaurantStaff('Ginger Klampt','gklampt3l','hIrAk8','99785569','gklampt3l@mashable.com', 16);
select NewRestaurantStaff('Nat Sooley','nsooley3m','ontHm54KRIb','96306423','nsooley3m@ox.ac.uk', 6);
select NewRestaurantStaff('Ruthann Steinhammer','rsteinhammer3n','suvQv1VCQL','96876089','rsteinhammer3n@redcross.org', 12);
select NewRestaurantStaff('Katerina Eary','keary3o','SV45XqrgV6e','97408440','keary3o@cloudflare.com', 12);
select NewRestaurantStaff('Emyle Lauder','elauder3p','cJ5SSby49lj','98909454','elauder3p@infoseek.co.jp', 23);
select NewRestaurantStaff('Jillene Realy','jrealy3q','cQalhP5','99358007','jrealy3q@exblog.jp', 6);
select NewRestaurantStaff('Leslie Ransom','lransom3r','06DPDOJN3Nf','95548226','lransom3r@cmu.edu', 3);
select NewRestaurantStaff('Ambros Goodings','agoodings3s','iBSMLDnQRKo','96789607','agoodings3s@behance.net', 24);
select NewRestaurantStaff('Coletta McSherry','cmcsherry3t','sqYaDnFwsQD','99851386','cmcsherry3t@scientificamerican.com', 19);
select NewRestaurantStaff('Diego Hewkin','dhewkin3u','MBUdEkQnugX1','92612505','dhewkin3u@salon.com', 12);
select NewRestaurantStaff('Beth Kornilov','bkornilov3v','hVFNUDdc8iP','95159211','bkornilov3v@nasa.gov', 4);
select NewRestaurantStaff('Jeremias Rounsefull','jrounsefull3w','OEg0qLHh','90162105','jrounsefull3w@state.tx.us', 5);
select NewRestaurantStaff('Gayelord Leven','gleven3x','XOyLXkyU','97230652','gleven3x@w3.org', 22);
select NewRestaurantStaff('Claire Sancroft','csancroft3y','fkXTyLz','91117698','csancroft3y@prlog.org', 3);
select NewRestaurantStaff('Lucian Drain','ldrain3z','973tQPsZFcI','92992554','ldrain3z@businesswire.com', 17);
select NewRestaurantStaff('Danice Keppel','dkeppel40','ZLqpwR','92240094','dkeppel40@marriott.com', 25);
select NewRestaurantStaff('Arleta Pawle','apawle41','F1anpMfbGPHj','93986400','apawle41@dailymotion.com', 7);
select NewRestaurantStaff('Kalle Kettlesing','kkettlesing42','h6JnBoh','92345272','kkettlesing42@latimes.com', 3);
select NewRestaurantStaff('Ilka Cardo','icardo43','cpDUg4','92747241','icardo43@constantcontact.com', 4);
select NewRestaurantStaff('Ilene Acom','iacom44','5T8jsR6PhR','90722345','iacom44@merriam-webster.com', 9);
select NewRestaurantStaff('Orran Seeney','oseeney45','IAaGiG4NA','97928279','oseeney45@booking.com', 19);
select NewRestaurantStaff('Fayth Roddick','froddick46','4I8c7QeUYIb','91942714','froddick46@theatlantic.com', 21);
select NewRestaurantStaff('Moishe Curedell','mcuredell47','5jhH3yXaxRKm','93431973','mcuredell47@google.fr', 9);
select NewRestaurantStaff('Hana Aspenlon','haspenlon48','TbSura','98671027','haspenlon48@free.fr', 14);
select NewRestaurantStaff('Toiboid Wasteney','twasteney49','0QulEoa','97668389','twasteney49@adobe.com', 4);
select NewRestaurantStaff('Derek Gash','dgash4a','kviOZfAP0ebE','92877180','dgash4a@about.me', 17);
select NewRestaurantStaff('Wren Bettenson','wbettenson4b','fEToULKy','99421157','wbettenson4b@hubpages.com', 5);
select NewRestaurantStaff('Tiena Gutans','tgutans4c','AucOiiNUqA','90985335','tgutans4c@state.gov', 18);
select NewRestaurantStaff('Dita Legges','dlegges4d','wy4VlEKxm5','90733931','dlegges4d@scientificamerican.com', 12);
select NewRestaurantStaff('Benito Whitley','bwhitley4e','mtxwafoFy','93654385','bwhitley4e@lycos.com', 13);
select NewRestaurantStaff('Kirstyn McAllaster','kmcallaster4f','yQ631aC','93556994','kmcallaster4f@reference.com', 12);
select NewRestaurantStaff('Aliza Spelling','aspelling4g','5NEKJpluNfgq','95704396','aspelling4g@tripod.com', 13);
select NewRestaurantStaff('Horatio McGaugey','hmcgaugey4h','i4sCY6GHkoO','94952271','hmcgaugey4h@jigsy.com', 17);
select NewRestaurantStaff('Port Crowest','pcrowest4i','8up3ic','99955059','pcrowest4i@addtoany.com', 15);
select NewRestaurantStaff('Amerigo Averall','aaverall4j','WAFfeLO','92970464','aaverall4j@elegantthemes.com', 23);
select NewRestaurantStaff('Janos Izakov','jizakov4k','nIFMaFSz4LgC','97891620','jizakov4k@ftc.gov', 10);
select NewRestaurantStaff('Sherilyn Moncarr','smoncarr4l','NhdmySMhm0','91647336','smoncarr4l@ehow.com', 21);
select NewRestaurantStaff('Sapphira Oguz','soguz4m','7gmYjrP','97643953','soguz4m@people.com.cn', 2);
select NewRestaurantStaff('Rriocard Cheak','rcheak4n','mRwSXkk','93778481','rcheak4n@ucoz.com', 1);
select NewRestaurantStaff('Chrystal Crouse','ccrouse4o','DISxwER','90331928','ccrouse4o@lulu.com', 24);
select NewRestaurantStaff('Sarita Snaden','ssnaden4p','boDyppXvQLg','93457755','ssnaden4p@sun.com', 2);
select NewRestaurantStaff('Prissie Osgordby','posgordby4q','x90E3gUNOD','98020111','posgordby4q@arizona.edu', 15);
select NewRestaurantStaff('Cindelyn Realff','crealff4r','msnwKcZ4ho3','97715500','crealff4r@sbwire.com', 12);
select NewRestaurantStaff('Trix Muldrew','tmuldrew4s','GiquY6UjK','90354801','tmuldrew4s@cnet.com', 23);
select NewRestaurantStaff('Rossy Asquez','rasquez4t','ZST61qun8hj','97265375','rasquez4t@opensource.org', 1);
select NewRestaurantStaff('Laurianne Brahm','lbrahm4u','4dHcyd2','91550217','lbrahm4u@weather.com', 17);
select NewRestaurantStaff('Rosalinde Slimmon','rslimmon4v','dxqSGaLi','99183606','rslimmon4v@wsj.com', 22);
select NewRestaurantStaff('Carissa Cathenod','ccathenod4w','Hhw0rF36Secx','98812420','ccathenod4w@i2i.jp', 21);
select NewRestaurantStaff('Rudd Silcox','rsilcox4x','tYtR9HTS','93970363','rsilcox4x@last.fm', 23);
select NewRestaurantStaff('Benjamen Fairrie','bfairrie4y','J63HjJPHo35','99740285','bfairrie4y@ask.com', 18);
select NewRestaurantStaff('Daniella Brash','dbrash4z','hLX9UQ','92370311','dbrash4z@umn.edu', 7);
select NewRestaurantStaff('Saree Hursey','shursey50','fDr1uF8ujeH','90677565','shursey50@unblog.fr', 16);
select NewRestaurantStaff('Helena Marquis','hmarquis51','wQ8GqpAxb','95369274','hmarquis51@1und1.de', 15);
select NewRestaurantStaff('Cordell Coils','ccoils52','zZlFphs','94861192','ccoils52@slideshare.net', 4);
select NewRestaurantStaff('Rick Cripin','rcripin53','JfG6aomjz','97268413','rcripin53@answers.com', 11);
select NewRestaurantStaff('Quincy Yitzowitz','qyitzowitz54','PhIy1SWpl','98045933','qyitzowitz54@ucoz.ru', 3);
select NewRestaurantStaff('Krispin Pien','kpien55','iwDOgyEL3','95687351','kpien55@japanpost.jp', 22);
select NewRestaurantStaff('Olwen Boyall','oboyall56','0HyxjMIr','94004622','oboyall56@mac.com', 21);
select NewRestaurantStaff('Feliks Littleton','flittleton57','o5zOdzjayQE','98087756','flittleton57@technorati.com', 4);
select NewRestaurantStaff('Harriett Scothron','hscothron58','CQVqJ1','95385721','hscothron58@deliciousdays.com', 12);
select NewRestaurantStaff('Aleece Spon','aspon59','tijTWcH0bj','92251282','aspon59@vinaora.com', 4);
select NewRestaurantStaff('Ursulina Annatt','uannatt5a','4tjAOP','90410637','uannatt5a@mozilla.org', 6);
select NewRestaurantStaff('Bryn Laphorn','blaphorn5b','uEcTYL18','92645472','blaphorn5b@adobe.com', 3);
select NewRestaurantStaff('Demeter Wards','dwards5c','rfQTO6uShPF','93473823','dwards5c@reddit.com', 1);
select NewRestaurantStaff('Wallache Corton','wcorton5d','csRh9kGX86','92133030','wcorton5d@si.edu', 2);
select NewRestaurantStaff('Elene Whife','ewhife5e','ZyzUTip','91189026','ewhife5e@wufoo.com', 3);
select NewRestaurantStaff('Skyler Matas','smatas5f','7M76H44M8hta','91629299','smatas5f@last.fm', 18);
select NewRestaurantStaff('Anselma Goslin','agoslin5g','uNIAdwjVa','90014067','agoslin5g@people.com.cn', 25);
select NewRestaurantStaff('Aindrea Harby','aharby5h','xfxqfvfHu9','91259638','aharby5h@marketwatch.com', 14);
select NewRestaurantStaff('Daune Keene','dkeene5i','QDT0qKu','99817092','dkeene5i@geocities.jp', 2);
select NewRestaurantStaff('Daryle Gillooly','dgillooly5j','6uw24fkrH8V','98169474','dgillooly5j@mysql.com', 17);

-- --PTRiders
select NewPTRider('Nanette Pikesley','npikesley0','zpVoRZsHqYIe','96864928','npikesley0@goo.gl','200');
select NewPTRider('Sandro Lashmar','slashmar1','hLiTYYkq','90567762','slashmar1@wisc.edu','193');
select NewPTRider('Brianna Foldes','bfoldes2','PydhZXEJz','90785978','bfoldes2@nba.com','177');
select NewPTRider('Marcia Sines','msines3','obzSnk8ja0Y3','96812798','msines3@geocities.jp','136');
select NewPTRider('Nelli Malthus','nmalthus4','SvPiHE2rJ3','98044103','nmalthus4@twitter.com','185');
select NewPTRider('Rowena Castro','rcastro5','5xvpSQ6F','99461534','rcastro5@plala.or.jp','141');
select NewPTRider('Dionisio Wigley','dwigley6','4weO601o5z8','90261383','dwigley6@admin.ch','160');
select NewPTRider('Bess Josef','bjosef7','X9G6hzXrhM','95724042','bjosef7@simplemachines.org','104');
select NewPTRider('Gizela Vawton','gvawton8','Iftzflv','92272181','gvawton8@1und1.de','198');
select NewPTRider('Neddy Whitechurch','nwhitechurch9','QBii6WqFJRQ','90340053','nwhitechurch9@reddit.com','120');
select NewPTRider('Sam Towler','stowlera','ejOk4bKIt','94678034','stowlera@nps.gov','176');
select NewPTRider('Deina Wallworke','dwallworkeb','RRlQDBVJiRCd','93294790','dwallworkeb@google.de','117');
select NewPTRider('Emmet Regelous','eregelousc','nloAC7WwKWA','92583124','eregelousc@comsenz.com','125');
select NewPTRider('Kylen Miners','kminersd','NBvGyQGb','91527574','kminersd@live.com','200');
select NewPTRider('Elinore Baggott','ebaggotte','ne5x8urQ72YN','95619460','ebaggotte@cam.ac.uk','152');
select NewPTRider('Chas Possa','cpossaf','4gtybnr6ZD7','93595943','cpossaf@examiner.com','125');
select NewPTRider('Tabbie Cleland','tclelandg','fka5sC8dmo','98835810','tclelandg@yolasite.com','127');
select NewPTRider('Coreen Roote','crooteh','67aVYJ','92848158','crooteh@ezinearticles.com','195');
select NewPTRider('Tristam Buttel','tbutteli','dx6dyuxSTBX','91599141','tbutteli@npr.org','171');
select NewPTRider('Hardy Sibthorp','hsibthorpj','6qZEdyMtsu','94261065','hsibthorpj@digg.com','198');
select NewPTRider('Barbaraanne Westwick','bwestwickk','3sMo9kIC0tR3','98097122','bwestwickk@mayoclinic.com','155');
select NewPTRider('Dacey Folliss','dfollissl','lIQZP8Sm','93694392','dfollissl@digg.com','164');
select NewPTRider('Kittie Snozzwell','ksnozzwellm','cnxGxok','91010780','ksnozzwellm@wikipedia.org','147');
select NewPTRider('Jeremie Mc Elory','jmcn','1R71y2c','94316721','jmcn@samsung.com','168');
select NewPTRider('Doralin McAndrew','dmcandrewo','aeVqliLvr','94220911','dmcandrewo@scribd.com','137');
select NewPTRider('Julianne Giamuzzo','jgiamuzzop','21hLdP','96871356','jgiamuzzop@stumbleupon.com','127');
select NewPTRider('Querida MacHostie','qmachostieq','UVh9W2AJBEEI','90749072','qmachostieq@about.me','197');
select NewPTRider('Wilt Codd','wcoddr','GEBFc5','99430534','wcoddr@cbsnews.com','148');
select NewPTRider('Twyla Blindt','tblindts','kceRW9uSPue','91884799','tblindts@domainmarket.com','130');
select NewPTRider('Meredeth Mynott','mmynottt','n7Dw6YV4Ge','96390666','mmynottt@discuz.net','134');
select NewPTRider('Sophi Hayhurst','shayhurstu','55NKetje6KLN','99224608','shayhurstu@blogtalkradio.com','117');
select NewPTRider('Conrado Smalman','csmalmanv','TjIJass','99803093','csmalmanv@blinklist.com','194');
select NewPTRider('Ingmar McPharlain','imcpharlainw','0ah4dg','96009918','imcpharlainw@plala.or.jp','123');
select NewPTRider('Glendon Fittis','gfittisx','j4ucxC7SRu','99775823','gfittisx@google.com.br','190');
select NewPTRider('Juditha MacHoste','jmachostey','JNKEsBMDLRF','91920703','jmachostey@engadget.com','164');
select NewPTRider('Gayla Rowthorne','growthornez','QM0aCEJnLng','96634764','growthornez@quantcast.com','108');
select NewPTRider('Vanessa Chaize','vchaize10','Up59jswbor','91334337','vchaize10@businessinsider.com','165');
select NewPTRider('Laural Greenlies','lgreenlies11','0DOb7YE4Ve3','92749143','lgreenlies11@google.co.jp','189');
select NewPTRider('Horatius Filkin','hfilkin12','QuufqUu35P1U','92321257','hfilkin12@xrea.com','171');
select NewPTRider('Zorina Eskrigg','zeskrigg13','hZ80WP5i6J','92043598','zeskrigg13@geocities.com','178');
select NewPTRider('Calvin Readwood','creadwood14','DWuJqyLx9ev','90761430','creadwood14@zdnet.com','137');
select NewPTRider('Zebulon Wadelin','zwadelin15','NMczIG','96439764','zwadelin15@oakley.com','166');
select NewPTRider('Celeste Arndtsen','carndtsen16','EVdELdlBE','90131973','carndtsen16@eepurl.com','122');
select NewPTRider('Jerome Delgardo','jdelgardo17','ql28xYHxvxwA','98075569','jdelgardo17@ocn.ne.jp','173');
select NewPTRider('Erhard Skoggings','eskoggings18','NaAMNHMZx','93480971','eskoggings18@comcast.net','174');
select NewPTRider('Garvey Peaden','gpeaden19','GmkZJc0','99653876','gpeaden19@auda.org.au','149');
select NewPTRider('Archer Jorin','ajorin1a','BFBQ8hEfICde','92839639','ajorin1a@blinklist.com','169');
select NewPTRider('Sheffie Lippett','slippett1b','dyEttXeoad','93530921','slippett1b@theguardian.com','159');
select NewPTRider('Sharai Eborall','seborall1c','9xNW7f','96784570','seborall1c@wsj.com','151');
select NewPTRider('Heall Gutowska','hgutowska1d','Lsde3lw','98798949','hgutowska1d@istockphoto.com','114');
select NewPTRider('Sidoney Mackinder','smackinder1e','nzYKRLDco','94825487','smackinder1e@indiegogo.com','184');
select NewPTRider('Sylas Mantripp','smantripp1f','S7PpQ5Vwg','92227898','smantripp1f@1und1.de','191');
select NewPTRider('Darnell Filliskirk','dfilliskirk1g','gW3YDqQ4ht','99585320','dfilliskirk1g@so-net.ne.jp','183');
select NewPTRider('Eda Kyd','ekyd1h','WjlmSbymO','97480075','ekyd1h@walmart.com','152');
select NewPTRider('Prince Colaco','pcolaco1i','zoQ8mH7ccwB','95855918','pcolaco1i@npr.org','181');
select NewPTRider('Ware Vaudrey','wvaudrey1j','x5rbtIp','99730849','wvaudrey1j@quantcast.com','176');
select NewPTRider('Sidonnie Jamblin','sjamblin1k','iu9kthVyPG4','98617143','sjamblin1k@psu.edu','172');
select NewPTRider('Creight Jentin','cjentin1l','mkHZfpxvPQu','94135493','cjentin1l@oakley.com','151');
select NewPTRider('Birch Maddern','bmaddern1m','tZxOb3','96289594','bmaddern1m@ted.com','157');
select NewPTRider('Aguste Christene','achristene1n','opsePPUKMCY','96938992','achristene1n@vk.com','103');
select NewPTRider('Mei Maymand','mmaymand1o','w8XrvtXV','97612780','mmaymand1o@webmd.com','127');
select NewPTRider('Olympe Blanket','oblanket1p','rMPGNpmrF5I','97487448','oblanket1p@theglobeandmail.com','191');
select NewPTRider('Keen Bewlay','kbewlay1q','Pd8p44','99085655','kbewlay1q@chronoengine.com','196');
select NewPTRider('Beverly McGinlay','bmcginlay1r','e2a4IwU','93879401','bmcginlay1r@mail.ru','181');
select NewPTRider('Theo Halms','thalms1s','apA9ciO3Mism','96097564','thalms1s@privacy.gov.au','145');
select NewPTRider('Alidia McGaraghan','amcgaraghan1t','Nz6mxPuqJca','91482284','amcgaraghan1t@tinyurl.com','109');
select NewPTRider('Amber Ludlem','aludlem1u','OJygXf','98086538','aludlem1u@hc360.com','111');
select NewPTRider('Bunni Wakeham','bwakeham1v','trG7Kf8OGm','94494001','bwakeham1v@google.nl','184');
select NewPTRider('Fowler Tatershall','ftatershall1w','CTIMwN5Qp','96295964','ftatershall1w@icq.com','102');
select NewPTRider('Merle Kemell','mkemell1x','kHAkRGtBy4y','97846997','mkemell1x@webeden.co.uk','187');
select NewPTRider('Kenyon Paunsford','kpaunsford1y','iWBdIywfi','98200902','kpaunsford1y@mtv.com','174');
select NewPTRider('Hinda Beville','hbeville1z','AumOXNz','96302928','hbeville1z@epa.gov','170');
select NewPTRider('Augie Matuskiewicz','amatuskiewicz20','Fy6MVB9','92222238','amatuskiewicz20@networksolutions.com','196');
select NewPTRider('Ealasaid Le Gallo','ele21','iP49MKPTLe3s','95849963','ele21@ed.gov','155');
select NewPTRider('Bevin Very','bvery22','R3hDRRV','95469259','bvery22@ycombinator.com','187');
select NewPTRider('Faulkner Hein','fhein23','48TJuJYzG4M','97427350','fhein23@weibo.com','129');
select NewPTRider('Noelle O''Dulchonta','nodulchonta24','Hr1Tg7y8P8B','98726178','nodulchonta24@quantcast.com','126');
select NewPTRider('Hilario Siehard','hsiehard25','56eV5MA','95647815','hsiehard25@a8.net','136');
select NewPTRider('Bondy Mendes','bmendes26','BBQXaGpeZ','91558590','bmendes26@cbsnews.com','163');
select NewPTRider('Ky Kellert','kkellert27','WUW6d0kjSI','90297459','kkellert27@cdc.gov','191');
select NewPTRider('Noah Oakwell','noakwell28','ofo7Hb7LmIB','94397462','noakwell28@shareasale.com','177');
select NewPTRider('Jo ann Neve','jann29','DI8px0OCGIGH','99612915','jann29@discovery.com','143');
select NewPTRider('Judas Junkison','jjunkison2a','6NaKEdaEP','94526316','jjunkison2a@apple.com','104');
select NewPTRider('Aube Lydiate','alydiate2b','jeUXyL654iV','99234259','alydiate2b@mapquest.com','140');
select NewPTRider('Chev Stathor','cstathor2c','qTl8oK6nbBHc','90372554','cstathor2c@shinystat.com','153');
select NewPTRider('Brandise Gilbank','bgilbank2d','QIhXgIHdCgY','95092686','bgilbank2d@salon.com','158');
select NewPTRider('Dory Strooband','dstrooband2e','AHlVrd2YDaDh','93959286','dstrooband2e@drupal.org','107');
select NewPTRider('Cassi Hatwells','chatwells2f','Qbbrdam','95244723','chatwells2f@umn.edu','117');
select NewPTRider('Reiko McArthur','rmcarthur2g','XiRx8qZ2','94759355','rmcarthur2g@networksolutions.com','133');
select NewPTRider('Haily Paaso','hpaaso2h','RSa8q7M2h','92732157','hpaaso2h@addtoany.com','102');
select NewPTRider('Esma Stott','estott2i','InH59oso','98875663','estott2i@so-net.ne.jp','109');
select NewPTRider('Quent Saberton','qsaberton2j','IfyoR87ZrbQF','95252365','qsaberton2j@odnoklassniki.ru','108');
select NewPTRider('Cam Rosenfarb','crosenfarb2k','yWoaiG55PxF','99147113','crosenfarb2k@nasa.gov','183');
select NewPTRider('Adan Chable','achable2l','XDlvb7CFz','97399045','achable2l@ezinearticles.com','196');
select NewPTRider('Jodie Reford','jreford2m','C5VoXCbkGK','98891027','jreford2m@flickr.com','199');
select NewPTRider('Webb Braid','wbraid2n','beMbWnuMr','91027794','wbraid2n@cafepress.com','129');
select NewPTRider('Gabi Chesley','gchesley2o','TDaWTVYu','97968812','gchesley2o@nytimes.com','116');
select NewPTRider('Oralee Powdrell','opowdrell2p','mHpRolLO','90978465','opowdrell2p@zdnet.com','134');
select NewPTRider('Hendrika Piens','hpiens2q','Ivcw5PJcak','96809630','hpiens2q@elegantthemes.com','140');
select NewPTRider('Sean Furst','sfurst2r','kVdzgJi5','93353280','sfurst2r@smh.com.au','157');
select NewPTRider('Imojean Abrahmovici','iabrahmovici2s','eSxCzAonQ','97796961','iabrahmovici2s@netvibes.com','155');
select NewPTRider('Engracia Meijer','emeijer2t','80OL3T','95219093','emeijer2t@java.com','180');
select NewPTRider('Benedikta Mauvin','bmauvin2u','lvGDwiksd','92275055','bmauvin2u@wikispaces.com','187');
select NewPTRider('Idalia Snowden','isnowden2v','vjF79knx5E','93106173','isnowden2v@gnu.org','103');
select NewPTRider('Nelle Etheridge','netheridge2w','SLO9WB5D','95248450','netheridge2w@slashdot.org','123');
select NewPTRider('Sissie Wardle','swardle2x','7n9FGOY','90041172','swardle2x@theglobeandmail.com','135');
select NewPTRider('Dex Ribbon','dribbon2y','B3gWMY','99454587','dribbon2y@is.gd','158');
select NewPTRider('Siusan Livezey','slivezey2z','SPSKec','92625295','slivezey2z@privacy.gov.au','113');
select NewPTRider('Valaria Ealles','vealles30','QoYFW3Mi8A','99121104','vealles30@hubpages.com','199');
select NewPTRider('Kristal Mandrier','kmandrier31','rCW9OJFpNE','93331989','kmandrier31@rakuten.co.jp','154');
select NewPTRider('Sidney Hillin','shillin32','bz8APGUrTF','99374152','shillin32@un.org','140');
select NewPTRider('Boone Sinclair','bsinclair33','1j4WPeiUDI','91959582','bsinclair33@ed.gov','188');
select NewPTRider('Gwyneth Owen','gowen34','VZtMSOXzW1R','97763094','gowen34@bandcamp.com','121');
select NewPTRider('Edward Lepard','elepard35','CAS8SdQM','99542478','elepard35@webnode.com','122');
select NewPTRider('Mervin Shernock','mshernock36','N3zfb0ffxK','98293507','mshernock36@twitter.com','197');
select NewPTRider('Weider Tal','wtal37','NuKLHggwnt','94207917','wtal37@omniture.com','116');
select NewPTRider('Sarine Dukesbury','sdukesbury38','USUsaR','99344438','sdukesbury38@ed.gov','155');
select NewPTRider('Mallory Fellenor','mfellenor39','aI3Jv39','91128938','mfellenor39@phpbb.com','191');
select NewPTRider('Ertha Laurence','elaurence3a','51zIQNh','98729549','elaurence3a@dell.com','154');
select NewPTRider('Reginald Ramsier','rramsier3b','z0Lzxe4Ezpht','95749445','rramsier3b@zdnet.com','152');
select NewPTRider('Eilis Mingauld','emingauld3c','81JPQ78','94916077','emingauld3c@facebook.com','140');
select NewPTRider('Delaney Frays','dfrays3d','2F2wUk92','94978832','dfrays3d@is.gd','144');
select NewPTRider('Jacinta Carlisle','jcarlisle3e','3KCNLspi6M8','91363003','jcarlisle3e@home.pl','136');
select NewPTRider('Pepe Straun','pstraun3f','SLmgc5Z','97832145','pstraun3f@e-recht24.de','118');
select NewPTRider('Dominique Petren','dpetren3g','meAuUViWtv8','98897472','dpetren3g@eventbrite.com','188');
select NewPTRider('Sallie Braidford','sbraidford3h','6VuJFs','95945151','sbraidford3h@dmoz.org','124');
select NewPTRider('Ibbie Blaszczak','iblaszczak3i','s530VmQMIEr2','94151487','iblaszczak3i@istockphoto.com','147');
select NewPTRider('Rhonda Di Biaggi','rdi3j','bL44GdGWO','93824417','rdi3j@elegantthemes.com','119');
select NewPTRider('Roldan Novic','rnovic3k','dK4SWg3J8ZP','95240905','rnovic3k@example.com','197');
select NewPTRider('Aleda Whisson','awhisson3l','8Br9IM9','96016915','awhisson3l@usda.gov','106');
select NewPTRider('Brittany Tander','btander3m','bidHi7nIfmMr','94310047','btander3m@dagondesign.com','177');
select NewPTRider('Burtie Fransemai','bfransemai3n','LB5o19vdj','92399373','bfransemai3n@naver.com','127');
select NewPTRider('Donnell Baress','dbaress3o','t1U52I8QkU1','93754030','dbaress3o@cbsnews.com','172');
select NewPTRider('Jenn Woolmer','jwoolmer3p','wWYm1bCj6','92246395','jwoolmer3p@ucoz.ru','115');
select NewPTRider('Elsinore Dundon','edundon3q','RNTGUSRmK','99766794','edundon3q@qq.com','131');
select NewPTRider('Rosalia Beauchamp','rbeauchamp3r','8Lq4hPbHgRN','92149696','rbeauchamp3r@creativecommons.org','191');
select NewPTRider('Jeno Sictornes','jsictornes3s','ymb4Zuk','97942168','jsictornes3s@example.com','106');
select NewPTRider('Filide Nardrup','fnardrup3t','8vHmo8cLlS','91929320','fnardrup3t@tuttocitta.it','126');
select NewPTRider('Bernadina Reyson','breyson3u','xY2AP0qw7OuK','92655921','breyson3u@bloomberg.com','174');
select NewPTRider('Ailsun McElhargy','amcelhargy3v','j5trB1tjoz9','92860935','amcelhargy3v@engadget.com','156');
select NewPTRider('Lilli Alldritt','lalldritt3w','GNpaTTgwe2','94236215','lalldritt3w@ibm.com','197');
select NewPTRider('Alessandro Bettleson','abettleson3x','waSnjFRc','90871693','abettleson3x@4shared.com','175');
select NewPTRider('Penelope Fewless','pfewless3y','zXfZ4S','95986746','pfewless3y@blog.com','165');
select NewPTRider('Jeanette Rubinlicht','jrubinlicht3z','df0zv66bBT','91140356','jrubinlicht3z@hatena.ne.jp','102');
select NewPTRider('Hillery Lowfill','hlowfill40','gVU9lYKBoVrz','93511395','hlowfill40@toplist.cz','135');
select NewPTRider('Maxwell Bemwell','mbemwell41','W8GJUysbuxl','95547070','mbemwell41@360.cn','148');
select NewPTRider('Brew Haste','bhaste42','yBdlLMYMwemd','97390842','bhaste42@ucoz.com','163');
select NewPTRider('Silvio Kitchingham','skitchingham43','DqM3kMene8S','97471784','skitchingham43@imageshack.us','142');
select NewPTRider('Enrica Balnaves','ebalnaves44','HqU47zYOK','96918300','ebalnaves44@nyu.edu','142');
select NewPTRider('Arabelle Hadaway','ahadaway45','poglP3G','90470635','ahadaway45@dropbox.com','197');
select NewPTRider('Terry Rosiello','trosiello46','TlPDjkrRnd','92965633','trosiello46@altervista.org','200');
select NewPTRider('Letitia Toffaloni','ltoffaloni47','tjIfLxMlO','90716568','ltoffaloni47@house.gov','105');
select NewPTRider('Adrian Guare','aguare48','KtgjiQZk','94284078','aguare48@twitpic.com','146');
select NewPTRider('Shandeigh Sales','ssales49','vqRdAw','92949228','ssales49@ebay.com','140');
select NewPTRider('Noreen Towler','ntowler4a','gaCj7qfj','93853527','ntowler4a@icio.us','200');
select NewPTRider('Natal Rallinshaw','nrallinshaw4b','LfpL8vn','98396099','nrallinshaw4b@walmart.com','182');
select NewPTRider('Celestine Robelow','crobelow4c','T0YuOB','92485094','crobelow4c@php.net','170');
select NewPTRider('Kikelia Yurchishin','kyurchishin4d','kKshSpm9JZlA','93515655','kyurchishin4d@vkontakte.ru','170');
select NewPTRider('Olwen Pouton','opouton4e','3ncmFath','92466138','opouton4e@geocities.jp','144');
select NewPTRider('Pammie Woolaston','pwoolaston4f','7sx2ar','99268438','pwoolaston4f@webmd.com','188');
select NewPTRider('Merrick Shardlow','mshardlow4g','yLK0dw','93062461','mshardlow4g@tinyurl.com','125');
select NewPTRider('Pat Elliff','pelliff4h','SMStTFJgH','92632021','pelliff4h@marketwatch.com','155');
select NewPTRider('Geoff MacDougall','gmacdougall4i','5Or1HjLuBdBt','93617755','gmacdougall4i@reverbnation.com','104');
select NewPTRider('Hanna Larmor','hlarmor4j','0XdFfG9x','99962783','hlarmor4j@npr.org','174');
select NewPTRider('Eveline Gencke','egencke4k','6YpUKQophlQW','95563563','egencke4k@themeforest.net','168');
select NewPTRider('Stephenie Sarle','ssarle4l','6IQkxFRj','96982520','ssarle4l@gmpg.org','154');
select NewPTRider('Patricia Shoreson','pshoreson4m','8TnCtuq','96830365','pshoreson4m@psu.edu','135');
select NewPTRider('Amity Padwick','apadwick4n','nqTl5xksG','90674713','apadwick4n@typepad.com','147');
select NewPTRider('Lionello Whorlton','lwhorlton4o','QtGmTPJLLI','91831089','lwhorlton4o@slate.com','182');
select NewPTRider('Dougy Trethowan','dtrethowan4p','xRIUBdPeC','99260810','dtrethowan4p@sakura.ne.jp','185');
select NewPTRider('Marlo Tant','mtant4q','QsuC04We','97682711','mtant4q@ustream.tv','139');
select NewPTRider('Berte Rizzi','brizzi4r','ZKW3C5qs','98515926','brizzi4r@netvibes.com','106');
select NewPTRider('Fionnula Ingliss','fingliss4s','TQnaZLl','98140646','fingliss4s@blogtalkradio.com','138');
select NewPTRider('Huberto Streather','hstreather4t','Kd3CGgXd','99423150','hstreather4t@loc.gov','150');
select NewPTRider('Ashien Searsby','asearsby4u','hxnAK6QM','90997895','asearsby4u@i2i.jp','145');
select NewPTRider('Ruttger McCurt','rmccurt4v','i4xfDtpCu','98404341','rmccurt4v@engadget.com','111');
select NewPTRider('Luelle Durrell','ldurrell4w','fqg5TIqmBVL','91231117','ldurrell4w@hibu.com','164');
select NewPTRider('Gavan Goodge','ggoodge4x','NnRkdtM1kaZ','99186279','ggoodge4x@sohu.com','154');
select NewPTRider('Terrijo Gonnel','tgonnel4y','1YiySdzOV','98098081','tgonnel4y@addtoany.com','188');
select NewPTRider('Carine Dawtry','cdawtry4z','KdaVTtVF','99436769','cdawtry4z@wikimedia.org','100');
select NewPTRider('Gerhardine Daulton','gdaulton50','ZZklUXp7z3C3','91593786','gdaulton50@gnu.org','142');
select NewPTRider('Edin Flukes','eflukes51','7q3oMnKW8o6x','98407958','eflukes51@wisc.edu','142');
select NewPTRider('Rockie Huddlestone','rhuddlestone52','fxyl1foaE8','96442234','rhuddlestone52@independent.co.uk','156');
select NewPTRider('Jaquelin Chess','jchess53','fgTyZo','99908505','jchess53@printfriendly.com','199');
select NewPTRider('Cecil Ochterlonie','cochterlonie54','wPDnc2u','95283327','cochterlonie54@weebly.com','195');
select NewPTRider('Syd Georgeau','sgeorgeau55','OvEk4q','97665410','sgeorgeau55@google.co.uk','188');
select NewPTRider('Lisabeth Spowage','lspowage56','Kdnbq42hW','96567684','lspowage56@prweb.com','168');
select NewPTRider('Elita Dopson','edopson57','5JyCEDUhY','97189193','edopson57@histats.com','186');
select NewPTRider('Fara Birts','fbirts58','3PXevYdY','90328113','fbirts58@tiny.cc','116');
select NewPTRider('Fania Bartolozzi','fbartolozzi59','UdmdyEGR','95857105','fbartolozzi59@163.com','138');
select NewPTRider('Griffie Glencross','gglencross5a','Gx8wau','95499638','gglencross5a@w3.org','130');
select NewPTRider('Bertine Verty','bverty5b','9q6UVnOLkKz','99801058','bverty5b@yahoo.com','183');
select NewPTRider('Tedmund Danilovitch','tdanilovitch5c','rVE6jP','96413384','tdanilovitch5c@imdb.com','103');
select NewPTRider('Amitie Kerslake','akerslake5d','tq4D37uI','91379977','akerslake5d@archive.org','123');
select NewPTRider('Omar Chancelier','ochancelier5e','3YvWa1','97024637','ochancelier5e@newyorker.com','146');
select NewPTRider('Samantha Aitken','saitken5f','AyHCZa','92718794','saitken5f@netlog.com','119');
select NewPTRider('Gris Trower','gtrower5g','kUGZjjrv','91712127','gtrower5g@ftc.gov','180');
select NewPTRider('Cornie Ruddock','cruddock5h','x4ZTfG','94580900','cruddock5h@google.pl','110');
select NewPTRider('Cathrin Anstiss','canstiss5i','w1L20whqSj','99879644','canstiss5i@hao123.com','136');
select NewPTRider('Harman Quan','hquan5j','LWFYqeUVyp8c','93707897','hquan5j@github.com','191');

-- --FTRiders
select NewFTRider('Kylen Paye','kpaye0','password','90011634','kpaye0@livejournal.com','578','7','3','1','3','3','1');
select NewFTRider('Maritsa De Avenell','mde1','FKCWYEu0pyo','93802009','mde1@columbia.edu','484','7','3','2','4','3','1');
select NewFTRider('Natka Haldane','nhaldane2','xZob3VTni0','93974018','nhaldane2@cornell.edu','535','6','2','3','1','1','4');
select NewFTRider('Erin Schuler','eschuler3','hW85h9IB1VQw','94644903','eschuler3@dot.gov','474','4','3','4','3','4','2');
select NewFTRider('Imojean Lintall','ilintall4','m6a35chLIIUL','92263713','ilintall4@spiegel.de','406','7','2','1','3','1','1');
select NewFTRider('Renell Whittaker','rwhittaker5','CfuE94y','97333567','rwhittaker5@slideshare.net','467','6','1','4','3','1','2');
select NewFTRider('Marline Feedham','mfeedham6','tzfasA','92993708','mfeedham6@prweb.com','444','6','3','4','2','3','2');
select NewFTRider('Elli Neiland','eneiland7','wJAmZkU','95201654','eneiland7@ustream.tv','590','4','4','3','4','3','2');
select NewFTRider('Felice Sainte Paul','fsainte8','hoR3NWM3o','93864579','fsainte8@ifeng.com','433','3','2','3','4','4','1');
select NewFTRider('Maurene Carville','mcarville9','zhSnJ2uCm7','99896138','mcarville9@reference.com','501','3','3','2','2','4','4');
select NewFTRider('Bobbette Cadlock','bcadlocka','4mTrONzJ','90834712','bcadlocka@cocolog-nifty.com','403','6','4','2','1','4','4');
select NewFTRider('Jobyna Breit','jbreitb','Gmm6lif','94761038','jbreitb@harvard.edu','507','6','1','1','2','1','3');
select NewFTRider('Dania Gors','dgorsc','bweHvRH','99236311','dgorsc@csmonitor.com','431','1','3','3','2','3','2');
select NewFTRider('Lorri Nickols','lnickolsd','WZ3fcLkU','98555348','lnickolsd@acquirethisname.com','430','3','3','4','2','3','3');
select NewFTRider('Saundra Josifovitz','sjosifovitze','Q9YCLxK','95432623','sjosifovitze@patch.com','574','5','3','1','2','1','4');
select NewFTRider('Kayne Dargavel','kdargavelf','ap0QJEjvNtp','91460833','kdargavelf@usatoday.com','506','1','3','2','1','3','3');
select NewFTRider('Way Joannic','wjoannicg','B1a2Ndn','92222102','wjoannicg@ucoz.ru','478','6','1','4','2','4','4');
select NewFTRider('Brigg Emmerson','bemmersonh','0qPsfC4GyD','94209828','bemmersonh@chronoengine.com','426','7','4','2','4','4','2');
select NewFTRider('Arleyne Beddoes','abeddoesi','a63Qpb83x','96694411','abeddoesi@tiny.cc','500','4','1','3','3','3','4');
select NewFTRider('Gretna Luxton','gluxtonj','GVScqrpTb','95247607','gluxtonj@gov.uk','525','1','4','3','1','2','1');
select NewFTRider('Trey Hains','thainsk','787oVpWy7mc','94067979','thainsk@phoca.cz','495','5','3','2','2','2','4');
select NewFTRider('Robinett Allott','rallottl','93wQbn','90772103','rallottl@latimes.com','567','1','3','2','1','4','2');
select NewFTRider('Timmie Ritmeier','tritmeierm','BPBye8','97354498','tritmeierm@infoseek.co.jp','484','6','3','4','4','1','4');
select NewFTRider('Micheil Heaslip','mheaslipn','G75ZroJWC','96175893','mheaslipn@a8.net','554','5','1','4','4','1','3');
select NewFTRider('Ronnica McIlwaine','rmcilwaineo','SyfVnAZOR','97818133','rmcilwaineo@cmu.edu','529','6','2','3','4','3','1');
select NewFTRider('Wilfrid Isson','wissonp','r6wHHr6Sh','93568529','wissonp@cam.ac.uk','474','2','4','2','4','3','3');
select NewFTRider('Maureene Spellesy','mspellesyq','be5zXf','98673996','mspellesyq@nytimes.com','485','3','4','3','1','4','4');
select NewFTRider('Denys Haste','dhaster','KtyNhEF1qZ','91460118','dhaster@abc.net.au','560','2','2','2','1','2','4');
select NewFTRider('Carine Corless','ccorlesss','FesnZIHKptzU','97366152','ccorlesss@g.co','471','4','4','2','3','3','3');
select NewFTRider('Doll Cavet','dcavett','ptqXhUDW4d','96111957','dcavett@vimeo.com','513','3','1','2','4','4','1');
select NewFTRider('Ruperta Stedman','rstedmanu','ab8uIGjxHngC','91240582','rstedmanu@utexas.edu','402','7','2','2','4','1','1');
select NewFTRider('Estevan Jeves','ejevesv','lXrT6zm743X','96013035','ejevesv@wunderground.com','482','7','1','2','2','1','3');
select NewFTRider('Mona Angrick','mangrickw','RldWztNqiQ','96950141','mangrickw@domainmarket.com','465','2','4','4','4','4','4');
select NewFTRider('Lilla Goolden','lgooldenx','OKdd1J8oYF','90943707','lgooldenx@desdev.cn','510','3','3','1','1','4','2');
select NewFTRider('Antonietta Woolnough','awoolnoughy','gohS1STRH6t','97213364','awoolnoughy@mapquest.com','540','5','2','4','3','2','4');
select NewFTRider('Toddie Butte','tbuttez','1qlfVfMiZf','92589841','tbuttez@wix.com','493','3','2','3','4','3','1');
select NewFTRider('Elisabet Redsull','eredsull10','2UqB6SfOTqav','91776958','eredsull10@nhs.uk','479','6','4','4','1','2','4');
select NewFTRider('Ade Van De Cappelle','avan11','AXOu7XA','95881803','avan11@nature.com','489','4','2','3','4','3','2');
select NewFTRider('Erhart Hucklesby','ehucklesby12','kJbY9CPFShY','91797073','ehucklesby12@sina.com.cn','587','5','2','4','2','2','3');
select NewFTRider('Burgess Tetford','btetford13','oWVPkcnl','95132941','btetford13@noaa.gov','407','1','3','2','3','4','3');
select NewFTRider('Aloise Hurdle','ahurdle14','aH8ivUt','97851825','ahurdle14@php.net','572','6','3','4','4','4','3');
select NewFTRider('Valle Ridel','vridel15','IHdXowD','91994735','vridel15@tripadvisor.com','499','5','2','3','3','2','3');
select NewFTRider('Pepi Cluse','pcluse16','f1HtaLODS','99867435','pcluse16@barnesandnoble.com','489','7','2','3','4','4','4');
select NewFTRider('Lezley Klaas','lklaas17','x2hbJl','99947826','lklaas17@moonfruit.com','474','5','3','1','3','4','2');
select NewFTRider('Boot Bruckstein','bbruckstein18','Mvn7Y4UULH','96933750','bbruckstein18@jimdo.com','478','5','2','1','3','1','2');
select NewFTRider('Bernie Kingzeth','bkingzeth19','bJwsQLxH','98980175','bkingzeth19@whitehouse.gov','426','2','3','2','3','4','2');
select NewFTRider('Kalle Levitt','klevitt1a','ikyVIsl','93377807','klevitt1a@edublogs.org','494','5','1','3','2','1','3');
select NewFTRider('Staci Pashen','spashen1b','lYjYZuUg9br','96212121','spashen1b@nymag.com','408','5','1','4','1','3','3');
select NewFTRider('Kitti Kidder','kkidder1c','F911MXcSMkp6','99521932','kkidder1c@quantcast.com','465','1','4','4','4','4','3');
select NewFTRider('Shirl Hadgkiss','shadgkiss1d','79RI67wvAiK','94587240','shadgkiss1d@gnu.org','600','4','3','2','3','2','4');
select NewFTRider('Shayna Matveiko','smatveiko1e','bYgMxP8','95698011','smatveiko1e@forbes.com','507','7','4','4','1','1','3');
select NewFTRider('Mallissa Conigsby','mconigsby1f','ieIkOuH7I0mU','92090041','mconigsby1f@bigcartel.com','570','4','4','4','4','2','3');
select NewFTRider('Emmie Roscamps','eroscamps1g','LXUTxHwv','98515207','eroscamps1g@japanpost.jp','548','5','2','1','3','2','4');
select NewFTRider('Donica Livings','dlivings1h','8CmIeguIT3iM','95854868','dlivings1h@bing.com','448','4','2','3','1','2','3');
select NewFTRider('Annecorinne Scupham','ascupham1i','DidjRIoI','94507865','ascupham1i@soup.io','473','4','4','3','4','1','3');
select NewFTRider('Avril Oakeby','aoakeby1j','s93JvOq','94393749','aoakeby1j@hostgator.com','507','5','2','3','1','3','2');
select NewFTRider('Jerry Byrnes','jbyrnes1k','vbLsCkI','93388293','jbyrnes1k@lycos.com','506','4','1','3','3','1','3');
select NewFTRider('Correy Skill','cskill1l','BgOR98aXd','97169647','cskill1l@mashable.com','502','5','4','2','3','3','1');
select NewFTRider('Keene Runham','krunham1m','JbjGjQT2g','92278637','krunham1m@tripod.com','412','7','3','4','4','4','1');
select NewFTRider('Morena Cutcliffe','mcutcliffe1n','zwg9FhE','93250122','mcutcliffe1n@harvard.edu','588','6','4','2','2','1','1');
select NewFTRider('Clemmie Byrnes','cbyrnes1o','nyUSLhovdA0','96570489','cbyrnes1o@goodreads.com','551','2','4','4','1','3','3');
select NewFTRider('Omero Eccles','oeccles1p','S0YxkB2xL','94966258','oeccles1p@cafepress.com','560','2','2','1','4','2','3');
select NewFTRider('Donovan Parsley','dparsley1q','AYklY9B','99469689','dparsley1q@163.com','545','1','1','2','4','2','4');
select NewFTRider('Isak Marrison','imarrison1r','z8Awqbj8eh','90546896','imarrison1r@yahoo.co.jp','448','4','3','4','3','4','2');
select NewFTRider('Aurelia Warmisham','awarmisham1s','qO3YROY','91098868','awarmisham1s@g.co','572','5','4','4','4','1','4');
select NewFTRider('Mariejeanne Roll','mroll1t','txnL7b68I3','93799680','mroll1t@senate.gov','561','3','3','4','1','2','4');
select NewFTRider('Rriocard Bleasdille','rbleasdille1u','EgHZhNCYKdL','91923825','rbleasdille1u@phoca.cz','530','3','3','3','4','1','2');
select NewFTRider('Emmeline Lagneaux','elagneaux1v','cV6jYpSEn','95138306','elagneaux1v@admin.ch','523','2','2','2','4','2','4');
select NewFTRider('Marla Binstead','mbinstead1w','YRwy8K','96676504','mbinstead1w@last.fm','506','5','1','3','4','2','3');
select NewFTRider('Killian Petch','kpetch1x','di0LMjTm1','90599908','kpetch1x@hp.com','482','4','1','1','1','1','2');
select NewFTRider('Gram Hamal','ghamal1y','o9ZdKj2i','99271285','ghamal1y@mozilla.com','481','2','2','2','2','4','1');
select NewFTRider('Stephenie Rosensaft','srosensaft1z','4qMlOSI','99466919','srosensaft1z@slashdot.org','475','5','3','2','4','2','2');
select NewFTRider('Mandy Lampbrecht','mlampbrecht20','4r92tsgbFRfR','92062905','mlampbrecht20@tripadvisor.com','568','4','4','2','3','4','4');
select NewFTRider('Thomasina Korda','tkorda21','195K5RZF','97099635','tkorda21@google.com.br','495','1','1','4','4','4','1');
select NewFTRider('Alexio Boate','aboate22','p3tffHb9UgV','96427038','aboate22@storify.com','494','4','3','4','3','4','4');
select NewFTRider('Lynnet Skirling','lskirling23','fAMHJnkfG2qW','93619359','lskirling23@addthis.com','530','4','1','4','4','3','3');
select NewFTRider('Ulrikaumeko Monan','umonan24','xaJoxr','94723083','umonan24@com.com','442','1','4','1','4','1','2');
select NewFTRider('Aldo Boffey','aboffey25','051WS1OTjSY','94929465','aboffey25@amazon.com','417','6','4','1','4','2','2');
select NewFTRider('Loralyn Condell','lcondell26','BoHUbPFIv','93953981','lcondell26@reuters.com','509','3','2','1','4','3','4');
select NewFTRider('Lorenza Peter','lpeter27','FYgAYtYrb','97393700','lpeter27@naver.com','493','6','4','3','2','2','3');
select NewFTRider('Chiquia Pentecust','cpentecust28','Xs1gO4TzS','97704783','cpentecust28@chron.com','511','3','4','2','1','2','2');
select NewFTRider('Cleon Bromet','cbromet29','rKs5Dt','95132741','cbromet29@eventbrite.com','522','5','1','2','2','3','4');
select NewFTRider('Beverie Borge','bborge2a','Y9jNyqC71','95332282','bborge2a@blogs.com','588','7','3','4','1','2','1');
select NewFTRider('Bambi Kempston','bkempston2b','aziU3tn3Cfs','95109305','bkempston2b@wix.com','551','2','3','3','3','4','4');
select NewFTRider('Jessika Greste','jgreste2c','k8RnJ64774Oq','92278999','jgreste2c@psu.edu','537','6','4','2','1','4','1');
select NewFTRider('Ewan De la Yglesia','ede2d','GqjY9QzDE','99467888','ede2d@360.cn','491','1','3','1','1','4','1');
select NewFTRider('Edd Wrankmore','ewrankmore2e','ovycTbR2eDIc','91213203','ewrankmore2e@hhs.gov','492','3','2','3','2','2','2');
select NewFTRider('Moll Hilldrop','mhilldrop2f','09SKIZ','92092075','mhilldrop2f@posterous.com','421','3','4','3','4','2','2');
select NewFTRider('Othello Chasier','ochasier2g','Rz6YPzbTmUZ','98229364','ochasier2g@cyberchimps.com','523','4','1','2','1','3','1');
select NewFTRider('Deeanne Kellitt','dkellitt2h','y0einoi4Ru','93988410','dkellitt2h@mediafire.com','533','1','2','3','4','4','4');
select NewFTRider('Dulcie Cobon','dcobon2i','EqhKyNZ5M0B','95114802','dcobon2i@qq.com','496','1','2','3','1','1','4');
select NewFTRider('Amalle Videler','avideler2j','EIiobou','97868866','avideler2j@lycos.com','518','1','2','3','4','1','1');
select NewFTRider('Raymund Rubenov','rrubenov2k','VeMxNB','97833460','rrubenov2k@slate.com','533','5','4','4','3','4','2');
select NewFTRider('Humphrey Carswell','hcarswell2l','pTbt60X','92239355','hcarswell2l@newyorker.com','448','6','1','1','4','4','3');
select NewFTRider('Estell Champneys','echampneys2m','cfJ5YTW1He','92617802','echampneys2m@webnode.com','481','4','2','1','1','3','2');
select NewFTRider('Anselm Tilburn','atilburn2n','2tNFnBsEw','95404742','atilburn2n@ovh.net','590','7','3','2','1','3','2');
select NewFTRider('Farley Gibbings','fgibbings2o','68d2V7','97517217','fgibbings2o@ow.ly','418','5','1','1','1','2','4');
select NewFTRider('Pate Saben','psaben2p','zJMVoa','97348463','psaben2p@flickr.com','484','4','3','3','2','3','2');
select NewFTRider('Krystalle Shobrook','kshobrook2q','2iQBF4B','91382081','kshobrook2q@cdc.gov','561','3','1','4','3','3','1');
select NewFTRider('Alaster Di Domenico','adi2r','zMtagPB92lGb','98733863','adi2r@time.com','420','4','4','2','2','3','2');

-- --Promos
select NewRPromo (502, '01/04/2020', '01/06/2020', 1, 15);
select NewRPromo (502, '14/03/2020', '20/03/2020', 1, 10);
select NewRPromo (502, '05/06/2020', '30/06/2020', 1, 20);
select NewRPromo (502, '01/02/2020', '29/02/2020', 1, 10);
select NewRPromo (502, '02/06/2020', '13/08/2020', 1, 5);
select NewFDSPromo (402, '17/01/2020', '25/01/2020', 0, 2);
select NewFDSPromo (402, '1/02/2020', '14/02/2020', 1, 20);
select NewFDSPromo (402, '1/03/2020', '30/03/2020', 0, 3);
select NewFDSPromo (402, '05/04/2020', '12/04/2020', 1, 50);
select NewFDSPromo (402, '01/05/2020', '20/05/2020', 0, 2);

-- --Food
insert into food(rid, name, category, price, food_limit, isRemoved) values (1, 'Hawaiian Pizza', 'Pizza', 20.00, 50, False);
insert into food(rid, name, category, price, food_limit, isRemoved) values (1, 'Meat Lovers Pizza', 'Pizza', 20.00, 50, False);
insert into food(rid, name, category, price, food_limit, isRemoved) values (1, 'Mushroom Pizza', 'Pizza', 18.00, 50, False);
insert into food(rid, name, category, price, food_limit, isRemoved) values (1, 'BBQ Chicken Pizza', 'Pizza', 18.00, 50, False);
insert into food(rid, name, category, price, food_limit, isRemoved) values (1, 'Pepperoni Pizza', 'Pizza', 18.00, 50, False);
insert into food(rid, name, category, price, food_limit, isRemoved) values (1, 'Chicken Ham & Shroom Pizza', 'Pizza', 18.00, 50, False);
insert into food(rid, name, category, price, food_limit, isRemoved) values (1, 'Cheezy Chicken Pizza', 'Pizza', 18.00, 50, False);
insert into food(rid, name, category, price, food_limit, isRemoved) values (1, 'Drumlets, 6pc', 'Sides', 10.00, 150, False);
insert into food(rid, name, category, price, food_limit, isRemoved) values (1, 'Wings, 6pc', 'Sides', 10.00, 150, False);
insert into food(rid, name, category, price, food_limit, isRemoved) values (1, 'Garlic Bread, 4pc', 'Sides', 7, 200, False);
insert into food(rid, name, category, price, food_limit, isRemoved) values (1, 'Coca-Cola, 1.5L', 'Drinks', 3.20, 120, False);
insert into food(rid, name, category, price, food_limit, isRemoved) values (1, 'Pepsi, 1.5L', 'Drinks', 3.20, 120, False);
insert into food(rid, name, category, price, food_limit, isRemoved) values (1, 'Sprite, 1.5L', 'Drinks', 3.20, 120, False);
insert into food(rid, name, category, price, food_limit, isRemoved) values (1, '7-Up, 1.5L', 'Drinks', 3.20, 120, False);
insert into food(rid, name, category, price, food_limit, isRemoved) values (1, 'Mountain Dew, 1.5L', 'Drinks', 3.20, 120, False);
insert into food(rid, name, category, price, food_limit, isRemoved) values (1, 'Root Beer, 1.5L', 'Drinks', 3.20, 120, False);
<<<<<<< HEAD
insert into food(rid, name, category, price, food_limit, isRemoved) values (2, 'Hershey White Chocolate', 'Chocolate', 2.50, 150, False);
insert into food(rid, name, category, price, food_limit, isRemoved) values (2, 'Hershey Dark Chocolate', 'Chocolate', 2.50, 150, False);
insert into food(rid, name, category, price, food_limit, isRemoved) values (2, 'Hershey Milk Chocolate', 'Chocolate', 2.50, 150, False);
insert into food(rid, name, category, price, food_limit, isRemoved) values (2, 'Ferrero Rocher, 24pc', 'Chocolate', 12.00, 150, False);
insert into food(rid, name, category, price, food_limit, isRemoved) values (2, 'Ferrero Rocher, 16pc', 'Chocolate', 9.00, 150, False);
insert into food(rid, name, category, price, food_limit, isRemoved) values (2, 'Kit Kat, Milk Chocolate', 'Chocolate', 1.50, 150, False);
insert into food(rid, name, category, price, food_limit, isRemoved) values (2, 'Kit Kat, Dark Chocolate', 'Chocolate', 1.50, 150, False);
insert into food(rid, name, category, price, food_limit, isRemoved) values (2, 'Kit Kat, White Chocolate', 'Chocolate', 1.50, 150, False);
insert into food(rid, name, category, price, food_limit, isRemoved) values (2, 'Toblerone Milk', 'Chocolate', 2.50, 150, False);
insert into food(rid, name, category, price, food_limit, isRemoved) values (2, 'Toblerone Dark', 'Chocolate', 2.50, 120, False);
insert into food(rid, name, category, price, food_limit, isRemoved) values (2, 'Toblerone White', 'Chocolate', 2.50, 120, False);
insert into food(rid, name, category, price, food_limit, isRemoved) values (2, 'Cadbury Dairy Milk', 'Chocolate', 6.40, 100, False);
insert into food(rid, name, category, price, food_limit, isRemoved) values (2, 'Kinder Bueno', 'Chocolate', 3.00, 200, False);
insert into food(rid, name, category, price, food_limit, isRemoved) values (2, 'Sour Power', 'Candy', 1.50, 300, False);
insert into food(rid, name, category, price, food_limit, isRemoved) values (2, 'Pop Rocks', 'Candy', 0.90, 500, False);
insert into food(rid, name, category, price, food_limit, isRemoved) values (2, 'Twisterz', 'Candy', 2.00, 200, False);
insert into food(rid, name, category, price, food_limit, isRemoved) values (2, 'Jellybeans', 'Candy', 0.50, 1500, False);
insert into food(rid, name, category, price, food_limit, isRemoved) values (2, 'Chewing Gum', 'Candy', 0.70, 120, False);
insert into food(rid, name, category, price, food_limit, isRemoved) values (2, 'Monster Sweet', 'Candy', 0.50, 1000, False);
insert into food(rid, name, category, price, food_limit, isRemoved) values (2, 'Double Choc Chip Cookie', 'Cookie', 2.50, 40, False);
insert into food(rid, name, category, price, food_limit, isRemoved) values (2, 'White Chocolate Cookie', 'Cookie', 2.50, 40, False);
insert into food(rid, name, category, price, food_limit, isRemoved) values (2, 'Oatmeal Raisin Cookie', 'Cookie', 3.00, 30, False);
insert into food(rid, name, category, price, food_limit, isRemoved) values (3, 'Peri-Peri Fried Chicken', 'Chicken', 6.00, 200, False);
insert into food(rid, name, category, price, food_limit, isRemoved) values (3, 'BBQ Chicken', 'Chicken', 6.00, 150, False);
insert into food(rid, name, category, price, food_limit, isRemoved) values (3, 'Secret Sauce Chicken', 'Chicken', 6.00, 300, False);
insert into food(rid, name, category, price, food_limit, isRemoved) values (3, 'Sweet N Sour Chicken', 'Chicken', 6.00, 100, False);
insert into food(rid, name, category, price, food_limit, isRemoved) values (3, 'Teriyaki Chicken', 'Chicken', 6.00, 200, False);
insert into food(rid, name, category, price, food_limit, isRemoved) values (3, 'Chicken Sandwich', 'Sandwiches', 4.00, 40, False);
insert into food(rid, name, category, price, food_limit, isRemoved) values (3, 'Double Chicken Sandwich', 'Sandwiches', 5.50, 30, False);
insert into food(rid, name, category, price, food_limit, isRemoved) values (3, 'Fries', 'Sides', 2.50, 150, False);
insert into food(rid, name, category, price, food_limit, isRemoved) values (3, 'Chicken Nuggets, 6pc', 'Sides', 3.00, 75, False);
insert into food(rid, name, category, price, food_limit, isRemoved) values (3, 'Popcorn Chicken', 'Sides', 3.00, 75, False);
insert into food(rid, name, category, price, food_limit, isRemoved) values (3, 'Pepsi, 1.5L', 'Drinks', 3.00, 100, False);
insert into food(rid, name, category, price, food_limit, isRemoved) values (3, 'Coco-Cola, 1.5L', 'Drinks', 3.00, 100, False);
insert into food(rid, name, category, price, food_limit, isRemoved) values (3, 'Fresh Lemonade, 1.5L', 'Drinks', 3.60, 50, False);
insert into food(rid, name, category, price, food_limit, isRemoved) values (4, 'Grilled Salmon', 'Fish', 22.50, 40, False);
insert into food(rid, name, category, price, food_limit, isRemoved) values (4, 'Pan-Seared Tuna', 'Fish', 20.00, 40, False);
insert into food(rid, name, category, price, food_limit, isRemoved) values (4, 'Seared Sea Bass', 'Fish', 20.00, 40, False);
insert into food(rid, name, category, price, food_limit, isRemoved) values (4, 'Baked Cod', 'Fish', 18.00, 40, False);
insert into food(rid, name, category, price, food_limit, isRemoved) values (4, 'Fried Barramundi', 'Fish', 18.00, 40, False);
insert into food(rid, name, category, price, food_limit, isRemoved) values (4, 'Grilled Halibut', 'Fish', 20.00, 40, False);
insert into food(rid, name, category, price, food_limit, isRemoved) values (4, 'Fish & Chips', 'Fish', 15.00, 60, False);
insert into food(rid, name, category, price, food_limit, isRemoved) values (4, 'Chowder Soup', 'Sides', 5.00, 50, False);
insert into food(rid, name, category, price, food_limit, isRemoved) values (4, 'Fish Sticks, 4pc', 'Sides', 4.00, 30, False);
insert into food(rid, name, category, price, food_limit, isRemoved) values (4, 'Crab Sticks, 4pc', 'Sides', 4.00, 20, False);
insert into food(rid, name, category, price, food_limit, isRemoved) values (4, 'Fizzy Lime, 1.5L', 'Drinks', 3.20, 100, False);
insert into food(rid, name, category, price, food_limit, isRemoved) values (4, 'Lemon Tea, 1.5L', 'Drinks', 2.80, 100, False);
insert into food(rid, name, category, price, food_limit, isRemoved) values (5, 'Roast Lamb with Honey Mustard', 'Mains', 20.50, 30, False);
insert into food(rid, name, category, price, food_limit, isRemoved) values (5, 'Braised Lamb Shanks', 'Mains', 19.50, 30, False);
insert into food(rid, name, category, price, food_limit, isRemoved) values (5, 'BBQ Pork Ribs', 'Mains', 17.20, 30, False);
insert into food(rid, name, category, price, food_limit, isRemoved) values (5, 'Fried Teriyaki Pork Chops', 'Mains', 16.00, 30, False);
insert into food(rid, name, category, price, food_limit, isRemoved) values (5, 'Honey Glazed Chicken Steak', 'Mains', 16.00, 30, False);
insert into food(rid, name, category, price, food_limit, isRemoved) values (5, 'Grilled Chicken Steak', 'Mains', 16.00, 30, False);
insert into food(rid, name, category, price, food_limit, isRemoved) values (5, 'Breaded Fish & Chips', 'Mains', 16.00, 30, False);
insert into food(rid, name, category, price, food_limit, isRemoved) values (5, 'Seafood Marinara', 'Mains', 16.00, 30, False);
insert into food(rid, name, category, price, food_limit, isRemoved) values (5, 'Seafood Aglio Olio', 'Mains', 16.00, 30, False);
insert into food(rid, name, category, price, food_limit, isRemoved) values (5, 'Pasta Carbonara', 'Mains', 15.00, 30, False);
insert into food(rid, name, category, price, food_limit, isRemoved) values (5, 'Black Pepper Seafood Pasta', 'Mains', 16.00, 30, False);
insert into food(rid, name, category, price, food_limit, isRemoved) values (5, 'Double Cheeseburger', 'Mains', 19.00, 30, False);
insert into food(rid, name, category, price, food_limit, isRemoved) values (5, 'Cheeseburger', 'Mains', 13.00, 30, False);
insert into food(rid, name, category, price, food_limit, isRemoved) values (5, 'Fried Chicken Burger', 'Mains', 13.00, 30, False);
insert into food(rid, name, category, price, food_limit, isRemoved) values (5, 'Coca-Cola', 'Drinks', 4.00, 60, False);
insert into food(rid, name, category, price, food_limit, isRemoved) values (5, 'Sprite', 'Drinks', 4.00, 60, False);
insert into food(rid, name, category, price, food_limit, isRemoved) values (5, 'Lemon Tea', 'Drinks', 4.00, 60, False);
insert into food(rid, name, category, price, food_limit, isRemoved) values (5, 'Green Tea', 'Drinks', 4.00, 60, False);
insert into food(rid, name, category, price, food_limit, isRemoved) values (5, 'Chicken Sausage', 'Sides', 5.00, 50, False);
insert into food(rid, name, category, price, food_limit, isRemoved) values (5, 'Truffle Fries', 'Sides', 8.00, 50, False);
insert into food(rid, name, category, price, food_limit, isRemoved) values (5, 'Meatballs', 'Sides', 4.00, 80, False);
insert into food(rid, name, category, price, food_limit, isRemoved) values (5, 'Chicken Wings', 'Sides', 4.00, 80, False);
insert into food(rid, name, category, price, food_limit, isRemoved) values (6, 'Chicken Vindaloo', 'Mains', 15.00, 60, False);
insert into food(rid, name, category, price, food_limit, isRemoved) values (6, 'Beef Madras', 'Mains', 15.00, 60, False);
insert into food(rid, name, category, price, food_limit, isRemoved) values (6, 'Prawn Malabar', 'Mains', 18.00, 120, False);
insert into food(rid, name, category, price, food_limit, isRemoved) values (6, 'Kashmiri Chicken', 'Mains', 16.00, 40, False);
insert into food(rid, name, category, price, food_limit, isRemoved) values (6, 'Chicken Pistachio', 'Mains', 16.00, 40, False);
insert into food(rid, name, category, price, food_limit, isRemoved) values (6, 'Garlic Naan', 'Sides', 2.50, 80, False);
insert into food(rid, name, category, price, food_limit, isRemoved) values (6, 'Paratha', 'Sides', 3.50, 80, False);
insert into food(rid, name, category, price, food_limit, isRemoved) values (6, 'Jafrani Fish', 'Sides', 9.50, 60, False);
insert into food(rid, name, category, price, food_limit, isRemoved) values (6, 'Masala Tea', 'Drinks', 3.00, 80, False);
insert into food(rid, name, category, price, food_limit, isRemoved) values (6, 'Fresh Lemon Juice', 'Drinks', 4.20, 80, False);
insert into food(rid, name, category, price, food_limit, isRemoved) values (7, 'Sardine Pizza', 'Pizza', 25.10, 50, False);
insert into food(rid, name, category, price, food_limit, isRemoved) values (7, 'Laksalicious Pizza', 'Pizza', 25.10, 50, False);
insert into food(rid, name, category, price, food_limit, isRemoved) values (7, 'Hawaiian Pizza', 'Pizza', 14.00, 50, False);
insert into food(rid, name, category, price, food_limit, isRemoved) values (7, 'Chicken Supreme', 'Pizza', 14.00, 50, False);
insert into food(rid, name, category, price, food_limit, isRemoved) values (7, 'Super Supreme', 'Pizza', 14.00, 50, False);
insert into food(rid, name, category, price, food_limit, isRemoved) values (7, 'Pepperoni', 'Pizza', 14.00, 50, False);
insert into food(rid, name, category, price, food_limit, isRemoved) values (7, 'Veggie Lover', 'Pizza', 14.00, 50, False);
insert into food(rid, name, category, price, food_limit, isRemoved) values (7, 'Meat Galore', 'Pizza', 14.00, 50, False);
insert into food(rid, name, category, price, food_limit, isRemoved) values (7, 'Cheese n Chic', 'Pizza', 11.00, 50, False);
insert into food(rid, name, category, price, food_limit, isRemoved) values (7, 'Ocean Delight', 'Pizza', 11.00, 50, False);
insert into food(rid, name, category, price, food_limit, isRemoved) values (7, 'BBQ Chicken', 'Pizza', 13.00, 50, False);
insert into food(rid, name, category, price, food_limit, isRemoved) values (7, 'Buffalo Wings', 'Sides', 6.00, 100, False);
insert into food(rid, name, category, price, food_limit, isRemoved) values (7, 'Garlic Bread', 'Sides', 4.00, 200, False);
insert into food(rid, name, category, price, food_limit, isRemoved) values (7, 'Cheese Fries', 'Sides', 6.00, 80, False);
insert into food(rid, name, category, price, food_limit, isRemoved) values (7, 'Honey Roasted Wings', 'Sides', 9.00, 100, False);
insert into food(rid, name, category, price, food_limit, isRemoved) values (7, 'Pepsi, 1.5L', '', 4.20, 100, False);
insert into food(rid, name, category, price, food_limit, isRemoved) values (7, 'Iced Lemon Tea, 1.5L', '', 4.20, 100, False);
insert into food(rid, name, category, price, food_limit, isRemoved) values (8, 'Zinger Burger', 'Mains', 5.00, 100, False);
insert into food(rid, name, category, price, food_limit, isRemoved) values (8, 'Cheesy BBQ Meltz', 'Mains', 5.00, 100, False);
insert into food(rid, name, category, price, food_limit, isRemoved) values (8, 'Pockett Bandito', 'Mains', 5.00, 100, False);
insert into food(rid, name, category, price, food_limit, isRemoved) values (8, 'Curry Rice Bucket', 'Mains', 5.50, 50, False);
insert into food(rid, name, category, price, food_limit, isRemoved) values (8, 'Original Recipe Chicken', 'Mains', 3.00, 120, False);
insert into food(rid, name, category, price, food_limit, isRemoved) values (8, 'Crispy Chicken', 'Mains', 3.00, 120, False);
insert into food(rid, name, category, price, food_limit, isRemoved) values (8, 'Colonel Burger', 'Mains', 5.00, 100, False);
insert into food(rid, name, category, price, food_limit, isRemoved) values (8, 'Crispy Tenders Burger', 'Mains', 5.00, 100, False);
insert into food(rid, name, category, price, food_limit, isRemoved) values (8, 'Shrooms Fillet Burger', 'Mains', 5.00, 100, False);
insert into food(rid, name, category, price, food_limit, isRemoved) values (8, 'Popcorn Chicken', 'Sides', 3.00, 100, False);
insert into food(rid, name, category, price, food_limit, isRemoved) values (8, 'French Fries', 'Sides', 3.00, 200, False);
insert into food(rid, name, category, price, food_limit, isRemoved) values (8, 'Cheese Fries', 'Sides', 4.00, 100, False);
insert into food(rid, name, category, price, food_limit, isRemoved) values (8, 'Whipped Potato', 'Sides', 2.00, 150, False);
insert into food(rid, name, category, price, food_limit, isRemoved) values (8, 'Coleslaw', 'Sides', 2.00, 150, False);
insert into food(rid, name, category, price, food_limit, isRemoved) values (8, 'Pepsi', 'Drinks', 2.00, 120, False);
insert into food(rid, name, category, price, food_limit, isRemoved) values (8, 'Mountain Dew', 'Drinks', 2.00, 120, False);
insert into food(rid, name, category, price, food_limit, isRemoved) values (8, 'Root Beer', 'Drinks', 2.00, 120, False);
insert into food(rid, name, category, price, food_limit, isRemoved) values (9, 'Bolognese Pasta', 'Mains', 8.00, 50, False);
insert into food(rid, name, category, price, food_limit, isRemoved) values (9, 'Aglio Olio Pasta', 'Mains', 7.00, 50, False);
insert into food(rid, name, category, price, food_limit, isRemoved) values (9, 'Seafood Pasta', 'Mains', 9.00, 50, False);
insert into food(rid, name, category, price, food_limit, isRemoved) values (9, 'Fish & Chips', 'Mains', 10.00, 50, False);
insert into food(rid, name, category, price, food_limit, isRemoved) values (9, 'Chicken Chop', 'Mains', 11.00, 50, False);
insert into food(rid, name, category, price, food_limit, isRemoved) values (9, 'Chicken Lasagna', 'Mains', 8.00, 50, False);
insert into food(rid, name, category, price, food_limit, isRemoved) values (9, 'Beef Stroganoff', 'Mains', 9.00, 50, False);
insert into food(rid, name, category, price, food_limit, isRemoved) values (9, 'Laksa', 'Mains', 5.00, 50, False);
insert into food(rid, name, category, price, food_limit, isRemoved) values (9, 'Nasi Lemak', 'Mains', 5.00, 50, False);
insert into food(rid, name, category, price, food_limit, isRemoved) values (9, 'Pineapple Fried Rice', 'Mains', 6.00, 50, False);
insert into food(rid, name, category, price, food_limit, isRemoved) values (9, 'Tom Yum Fried Rice', 'Mains', 6.00, 50, False);
insert into food(rid, name, category, price, food_limit, isRemoved) values (9, 'Teochew Fried Rice', 'Mains', 5.50, 50, False);
insert into food(rid, name, category, price, food_limit, isRemoved) values (9, 'Hokkien Mee', 'Mains', 5.00, 50, False);
insert into food(rid, name, category, price, food_limit, isRemoved) values (9, 'Pad Thai', 'Mains', 5.00, 50, False);
insert into food(rid, name, category, price, food_limit, isRemoved) values (9, 'Vietnamese Beef Pho', 'Mains', 7.00, 50, False);
insert into food(rid, name, category, price, food_limit, isRemoved) values (9, 'Korean Glass Noodles', 'Mains', 6.00, 50, False);
insert into food(rid, name, category, price, food_limit, isRemoved) values (9, 'Kimchi Fried Rice', 'Mains', 6.00, 50, False);
insert into food(rid, name, category, price, food_limit, isRemoved) values (9, 'Butter Chicken and Rice', 'Mains', 6.00, 50, False);
insert into food(rid, name, category, price, food_limit, isRemoved) values (9, 'Creamy Butter Chicken', 'Mains', 6.00, 50, False);
insert into food(rid, name, category, price, food_limit, isRemoved) values (9, 'Minced Pork Porridge', 'Mains', 5.00, 50, False);
insert into food(rid, name, category, price, food_limit, isRemoved) values (9, 'Steamed Duck Porridge', 'Mains', 10.00, 50, False);
insert into food(rid, name, category, price, food_limit, isRemoved) values (9, 'Mee siam', 'Mains', 4.00, 50, False);
insert into food(rid, name, category, price, food_limit, isRemoved) values (9, 'Mee Rebus', 'Mains', 4.00, 50, False);
insert into food(rid, name, category, price, food_limit, isRemoved) values (9, 'BBQ Fish and Rice Hot Plate', 'Mains', 9.00, 50, False);
insert into food(rid, name, category, price, food_limit, isRemoved) values (9, 'Iced Lemon Tea', 'Drinks', 2.00, 80, False);
insert into food(rid, name, category, price, food_limit, isRemoved) values (9, 'Sugercane Juice', 'Drinks', 2.00, 80, False);
insert into food(rid, name, category, price, food_limit, isRemoved) values (9, 'Avocado Milk', 'Drinks', 3.00, 50, False);
insert into food(rid, name, category, price, food_limit, isRemoved) values (9, 'Milk Tea', 'Drinks', 2.00, 80, False);
insert into food(rid, name, category, price, food_limit, isRemoved) values (10, 'Lemon Chicken Rice', 'Mains', 6.00, 80, False);
insert into food(rid, name, category, price, food_limit, isRemoved) values (10, 'Hainanese Chicken Rice', 'Mains', 6.00, 50, False);
insert into food(rid, name, category, price, food_limit, isRemoved) values (10, 'Hainanese Steamed Chicken', 'Mains', 15.00, 30, False);
insert into food(rid, name, category, price, food_limit, isRemoved) values (10, 'Truffle Fried Rice', 'Mains', 8.00, 50, False);
insert into food(rid, name, category, price, food_limit, isRemoved) values (10, 'Seafood Hor Fun', 'Mains', 6.00, 50, False);
insert into food(rid, name, category, price, food_limit, isRemoved) values (10, 'Pineapple Fried Rice', 'Mains', 7.00, 50, False);
insert into food(rid, name, category, price, food_limit, isRemoved) values (10, 'Curry Fish', 'Mains', 20.00, 50, False);
insert into food(rid, name, category, price, food_limit, isRemoved) values (10, 'Ginger and Spring Onion Fish', 'Mains', 10.00, 50, False);
insert into food(rid, name, category, price, food_limit, isRemoved) values (10, 'Sweet and Sour Pork', 'Sides', 8.00, 50, False);
insert into food(rid, name, category, price, food_limit, isRemoved) values (10, 'Crispy Cereal Prawn', 'Sides', 12.00, 50, False);
insert into food(rid, name, category, price, food_limit, isRemoved) values (10, 'Onion Omelette', 'Sides', 8.00, 50, False);
insert into food(rid, name, category, price, food_limit, isRemoved) values (10, 'Stir Fry French Bean', 'Sides', 8.00, 50, False);
insert into food(rid, name, category, price, food_limit, isRemoved) values (10, 'Sambal Kang Kong', 'Sides', 8.00, 50, False);
insert into food(rid, name, category, price, food_limit, isRemoved) values (10, 'Tom Yum Seafood Soup', 'Soup', 9.00, 50, False);
insert into food(rid, name, category, price, food_limit, isRemoved) values (10, 'Chicken Herbal Soup', 'Soup', 10.00, 50, False);
insert into food(rid, name, category, price, food_limit, isRemoved) values (10, 'Iced Lemon Tea', 'Drinks', 3.00, 50, False);
insert into food(rid, name, category, price, food_limit, isRemoved) values (10, 'Coca-Cola', 'Drinks', 2.00, 50, False);
insert into food(rid, name, category, price, food_limit, isRemoved) values (11, 'Fried Rice Chicken', 'Mains', 7.00, 50, False);
insert into food(rid, name, category, price, food_limit, isRemoved) values (11, 'Fried Rice Pork', 'Mains', 7.00, 50, False);
insert into food(rid, name, category, price, food_limit, isRemoved) values (11, 'Fried Rice Beef', 'Mains', 7.00, 50, False);
insert into food(rid, name, category, price, food_limit, isRemoved) values (11, 'Lo Mein Chicken', 'Mains', 7.00, 50, False);
insert into food(rid, name, category, price, food_limit, isRemoved) values (11, 'Lo Mein Pork', 'Mains', 7.00, 50, False);
insert into food(rid, name, category, price, food_limit, isRemoved) values (11, 'Lo Mein Beef', 'Mains', 7.00, 50, False);
insert into food(rid, name, category, price, food_limit, isRemoved) values (11, 'Chow Fun', 'Mains', 7.00, 50, False);
insert into food(rid, name, category, price, food_limit, isRemoved) values (11, 'Garlic Noodles', 'Mains', 5.00, 50, False);
insert into food(rid, name, category, price, food_limit, isRemoved) values (11, 'Sesame Beef', 'Mains', 10.00, 50, False);
insert into food(rid, name, category, price, food_limit, isRemoved) values (11, 'Crispy Beef Shingle', 'Mains', 11.00, 50, False);
insert into food(rid, name, category, price, food_limit, isRemoved) values (11, 'Sweet and Sour Pork', 'Mains', 9.00, 50, False);
insert into food(rid, name, category, price, food_limit, isRemoved) values (11, 'Garlic Chicken', 'Mains', 9.00, 60, False);
insert into food(rid, name, category, price, food_limit, isRemoved) values (11, 'Pork Dumplings', 'Sides', 4.50, 80, False);
insert into food(rid, name, category, price, food_limit, isRemoved) values (11, 'Vegetable Dumplings', 'Sides', 4.00, 80, False);
insert into food(rid, name, category, price, food_limit, isRemoved) values (11, 'Spring Roll', 'Sides', 3.00, 80, False);
insert into food(rid, name, category, price, food_limit, isRemoved) values (11, 'Honey Shrimp', 'Sides', 6.00, 100, False);
insert into food(rid, name, category, price, food_limit, isRemoved) values (11, 'Crabmeat Soup Bun', 'Sides', 7.00, 100, False);
insert into food(rid, name, category, price, food_limit, isRemoved) values (11, 'Onion Pancakes', 'Sides', 5.00, 40, False);
insert into food(rid, name, category, price, food_limit, isRemoved) values (12, 'Chicken Chop', 'Mains', 12.00, 30, False);
insert into food(rid, name, category, price, food_limit, isRemoved) values (12, 'Chicken Baked Rice', 'Mains', 13.00, 30, False);
insert into food(rid, name, category, price, food_limit, isRemoved) values (12, 'Spencer Steak', 'Mains', 22.00, 30, False);
insert into food(rid, name, category, price, food_limit, isRemoved) values (12, 'Burger Steak', 'Mains', 18.00, 30, False);
insert into food(rid, name, category, price, food_limit, isRemoved) values (12, 'Mushroom Soup', 'Sides', 6.00, 60, False);
insert into food(rid, name, category, price, food_limit, isRemoved) values (12, 'French Onion Soup', 'Sides', 6.00, 60, False);
insert into food(rid, name, category, price, food_limit, isRemoved) values (12, 'Seafood Chowder', 'Sides', 7.00, 60, False);
insert into food(rid, name, category, price, food_limit, isRemoved) values (12, 'Calamari Rings', 'Sides', 11.00, 120, False);
insert into food(rid, name, category, price, food_limit, isRemoved) values (12, 'Lim Specialty Chicken Wing', 'Sides', 13.00, 120, False);
insert into food(rid, name, category, price, food_limit, isRemoved) values (13, 'Milk Tea', 'Drinks', 3.50, 80, False);
insert into food(rid, name, category, price, food_limit, isRemoved) values (13, 'Green Milk Tea', 'Drinks', 3.50, 80, False);
insert into food(rid, name, category, price, food_limit, isRemoved) values (13, 'Hazelnut Milk Tea', 'Drinks', 4.00, 80, False);
insert into food(rid, name, category, price, food_limit, isRemoved) values (13, 'Caramel Milk Tea', 'Drinks', 4.00, 80, False);
insert into food(rid, name, category, price, food_limit, isRemoved) values (13, 'Honey Milk Tea', 'Drinks', 4.00, 80, False);
insert into food(rid, name, category, price, food_limit, isRemoved) values (13, 'Honey Green Tea', 'Drinks', 3.50, 80, False);
insert into food(rid, name, category, price, food_limit, isRemoved) values (13, 'Four Seasons Tea', 'Drinks', 3.00, 80, False);
insert into food(rid, name, category, price, food_limit, isRemoved) values (13, 'Lemon Lime Green Tea', 'Drinks', 3.50, 80, False);
insert into food(rid, name, category, price, food_limit, isRemoved) values (13, 'Yakult Green Tea', 'Drinks', 4.00, 80, False);
insert into food(rid, name, category, price, food_limit, isRemoved) values (13, 'Brown Sugar Milk Tea', 'Drinks', 4.00, 80, False);
insert into food(rid, name, category, price, food_limit, isRemoved) values (13, 'Black Tea Macchiato', 'Drinks', 3.00, 80, False);
insert into food(rid, name, category, price, food_limit, isRemoved) values (13, 'Chocolate Macchiato', 'Drinks', 4.50, 80, False);
insert into food(rid, name, category, price, food_limit, isRemoved) values (13, 'Ovaltine Macchiato', 'Drinks', 4.50, 80, False);
insert into food(rid, name, category, price, food_limit, isRemoved) values (13, 'Four Seasons Tea Macchiato', 'Drinks', 3.00, 80, False);
insert into food(rid, name, category, price, food_limit, isRemoved) values (13, 'Lemon Plum Juice', 'Drinks', 3.50, 80, False);
insert into food(rid, name, category, price, food_limit, isRemoved) values (13, 'Honey Lemon Juice', 'Drinks', 4.00, 80, False);
insert into food(rid, name, category, price, food_limit, isRemoved) values (13, 'Honey Lemon Lime Juice', 'Drinks', 4.00, 80, False);
insert into food(rid, name, category, price, food_limit, isRemoved) values (14, 'Sanum Frozen Yoghurt', 'Desserts', 17.00, 50, False);
insert into food(rid, name, category, price, food_limit, isRemoved) values (14, 'Frozen Yoghurt, Tub', 'Desserts', 10.00, 50, False);
insert into food(rid, name, category, price, food_limit, isRemoved) values (14, 'Golden Plus Smoothie', 'Desserts', 17.00, 50, False);
insert into food(rid, name, category, price, food_limit, isRemoved) values (14, 'Coconut Smoothie', 'Desserts', 14.00, 50, False);
insert into food(rid, name, category, price, food_limit, isRemoved) values (14, 'Bariloche Smoothie', 'Desserts', 14.00, 50, False);
insert into food(rid, name, category, price, food_limit, isRemoved) values (14, 'Golden Smoothie', 'Desserts', 14.00, 50, False);
insert into food(rid, name, category, price, food_limit, isRemoved) values (15, 'McSpicy', 'Mains', 5.00, 80, False);
insert into food(rid, name, category, price, food_limit, isRemoved) values (15, 'Double McSpicy', 'Mains', 7.00, 80, False);
insert into food(rid, name, category, price, food_limit, isRemoved) values (15, 'Buttermilk Crispy Chicken', 'Mains', 7.00, 80, False);
insert into food(rid, name, category, price, food_limit, isRemoved) values (15, 'McWings, 4pc', 'Mains', 4.00, 80, False);
insert into food(rid, name, category, price, food_limit, isRemoved) values (15, 'Chicken Nugget, 6pc', 'Mains', 4.50, 80, False);
insert into food(rid, name, category, price, food_limit, isRemoved) values (15, 'McChicken', 'Mains', 2.00, 80, False);
insert into food(rid, name, category, price, food_limit, isRemoved) values (15, 'Grilled Chicken Salad', 'Mains', 5.50, 80, False);
insert into food(rid, name, category, price, food_limit, isRemoved) values (15, 'Grilled Chicken Wrap', 'Mains', 5.50, 80, False);
insert into food(rid, name, category, price, food_limit, isRemoved) values (15, 'Fillet-O-Fish', 'Mains', 3.00, 80, False);
insert into food(rid, name, category, price, food_limit, isRemoved) values (15, 'Double Fillet-O-Fish', 'Mains', 5.50, 80, False);
insert into food(rid, name, category, price, food_limit, isRemoved) values (15, 'Classic Angus Beef Burger', 'Mains', 9.00, 80, False);
insert into food(rid, name, category, price, food_limit, isRemoved) values (15, 'Double Cheeseburger', 'Mains', 4.00, 80, False);
insert into food(rid, name, category, price, food_limit, isRemoved) values (15, 'Big Mac', 'Mains', 6.00, 80, False);
insert into food(rid, name, category, price, food_limit, isRemoved) values (15, 'The Original Angus', 'Mains', 6.00, 80, False);
insert into food(rid, name, category, price, food_limit, isRemoved) values (15, 'Vanilla Cone', 'Desserts', 1.00, 200, False);
insert into food(rid, name, category, price, food_limit, isRemoved) values (15, 'McFlurry', 'Desserts', 3.50, 120, False);
insert into food(rid, name, category, price, food_limit, isRemoved) values (15, 'Hot Fudge Sundae', 'Desserts', 2.00, 120, False);
insert into food(rid, name, category, price, food_limit, isRemoved) values (15, 'Ice Lemon Tea', 'Drinks', 3.50, 120, False);
insert into food(rid, name, category, price, food_limit, isRemoved) values (15, 'Coca-Cola', 'Desserts', 3.00, 120, False);
insert into food(rid, name, category, price, food_limit, isRemoved) values (16, 'Spicy Chicken Sensation', 'Mains', 4.00, 80, False);
insert into food(rid, name, category, price, food_limit, isRemoved) values (16, 'Ultimate Chicken Grill', 'Mains', 4.50, 80, False);
insert into food(rid, name, category, price, food_limit, isRemoved) values (16, 'Chicken Nuggets, 6pc', 'Mains', 3.50, 200, False);
insert into food(rid, name, category, price, food_limit, isRemoved) values (16, 'Daves Hot N Juicy Single ', 'Mains', 4.00, 80, False);
insert into food(rid, name, category, price, food_limit, isRemoved) values (16, 'Daves Hot N Juicy Double', 'Mains', 5.50, 80, False);
insert into food(rid, name, category, price, food_limit, isRemoved) values (16, 'Single Mushroom Melt', 'Mains', 4.50, 80, False);
insert into food(rid, name, category, price, food_limit, isRemoved) values (16, 'Double Mushroom Melt', 'Mains', 5.50, 80, False);
insert into food(rid, name, category, price, food_limit, isRemoved) values (16, 'Shrimp Supreme', 'Mains', 4.00, 80, False);
insert into food(rid, name, category, price, food_limit, isRemoved) values (16, 'Parmesan Caesar', 'Sides', 5.00, 80, False);
insert into food(rid, name, category, price, food_limit, isRemoved) values (16, 'Southwest Avocado', 'Sides', 5.00, 80, False);
insert into food(rid, name, category, price, food_limit, isRemoved) values (16, 'Coca-Cola', 'Drinks', 3.00, 120, False);
insert into food(rid, name, category, price, food_limit, isRemoved) values (16, 'Craft Lemonades', 'Drinks', 3.00, 120, False);
insert into food(rid, name, category, price, food_limit, isRemoved) values (17, 'Original Chicken Wings', 'Mains', 4.00, 200, False);
insert into food(rid, name, category, price, food_limit, isRemoved) values (17, 'Spicy Chicken', 'Mains', 4.00, 80, False);
insert into food(rid, name, category, price, food_limit, isRemoved) values (17, 'Chicken Tenders', 'Mains', 4.00, 120, False);
insert into food(rid, name, category, price, food_limit, isRemoved) values (17, 'Chicken Supreme Burger', 'Mains', 7.00, 60, False);
insert into food(rid, name, category, price, food_limit, isRemoved) values (17, 'Chicken Wrap', 'Mains', 6.00, 60, False);
insert into food(rid, name, category, price, food_limit, isRemoved) values (17, 'Fried Teriyaki Chicken', 'Mains', 6.00, 60, False);
insert into food(rid, name, category, price, food_limit, isRemoved) values (17, 'Grilled Chicken and Egg Burger', 'Mains', 5.00, 60, False);
insert into food(rid, name, category, price, food_limit, isRemoved) values (17, 'BBQ Chicken Chop', 'Mains', 7.00, 60, False);
insert into food(rid, name, category, price, food_limit, isRemoved) values (17, 'Black Pepper Chicken Chop', 'Mains', 7.00, 60, False);
insert into food(rid, name, category, price, food_limit, isRemoved) values (18, 'Spring Chicken', 'Mains', 14.00, 80, False);
insert into food(rid, name, category, price, food_limit, isRemoved) values (18, '1/2 Spring Chicken', 'Mains', 7.50, 80, False);
insert into food(rid, name, category, price, food_limit, isRemoved) values (18, 'Fish & Chips', 'Mains', 10.00, 80, False);
insert into food(rid, name, category, price, food_limit, isRemoved) values (18, 'Fragrant Chicken Rice', 'Mains', 4.00, 80, False);
insert into food(rid, name, category, price, food_limit, isRemoved) values (18, 'Potato Platter', 'Sides', 7.00, 100, False);
insert into food(rid, name, category, price, food_limit, isRemoved) values (18, 'Potato Fries', 'Sides', 3.00, 100, False);
insert into food(rid, name, category, price, food_limit, isRemoved) values (18, 'Potato Wedges', 'Sides', 3.00, 100, False);
insert into food(rid, name, category, price, food_limit, isRemoved) values (18, 'Popcorn Chicken', 'Sides', 5.00, 100, False);
insert into food(rid, name, category, price, food_limit, isRemoved) values (18, 'Onion Rings', 'Sides', 3.50, 100, False);
insert into food(rid, name, category, price, food_limit, isRemoved) values (18, 'Spiral Fries', 'Sides', 3.50, 100, False);
insert into food(rid, name, category, price, food_limit, isRemoved) values (18, 'Coleslaw', 'Sides', 3.00, 100, False);
insert into food(rid, name, category, price, food_limit, isRemoved) values (18, 'Coke Float', 'Drinks', 3.50, 100, False);
insert into food(rid, name, category, price, food_limit, isRemoved) values (18, 'Ice Milo', 'Drinks', 3.00, 100, False);
insert into food(rid, name, category, price, food_limit, isRemoved) values (18, 'Ice Lemon Tea', 'Drinks', 3.00, 100, False);
insert into food(rid, name, category, price, food_limit, isRemoved) values (19, 'Signature Canton Wanton Soup', 'Mains', 11.50, 50, False);
insert into food(rid, name, category, price, food_limit, isRemoved) values (19, 'Prawn Dumpling Soup', 'Mains', 11.50, 50, False);
insert into food(rid, name, category, price, food_limit, isRemoved) values (19, 'Stewed Beef Brisket Noodle', 'Mains', 13.50, 50, False);
insert into food(rid, name, category, price, food_limit, isRemoved) values (19, 'Shrimp Roe Noodle', 'Mains', 8.00, 50, False);
insert into food(rid, name, category, price, food_limit, isRemoved) values (19, 'Sliced Grass Carp Fish Noodle', 'Mains', 11.00, 50, False);
insert into food(rid, name, category, price, food_limit, isRemoved) values (19, 'Fresh Prawn Congee', 'Mains', 12.00, 50, False);
insert into food(rid, name, category, price, food_limit, isRemoved) values (19, 'Sliced Grass Carp Fish Congee', 'Mains', 11.50, 50, False);
insert into food(rid, name, category, price, food_limit, isRemoved) values (19, 'Handmade Meatball Congee', 'Mains', 9.50, 50, False);
insert into food(rid, name, category, price, food_limit, isRemoved) values (19, 'Sliced Beef Congee', 'Mains', 10.50, 50, False);
insert into food(rid, name, category, price, food_limit, isRemoved) values (19, 'Yang Zhou Fried Rice', 'Mains', 13.00, 50, False);
insert into food(rid, name, category, price, food_limit, isRemoved) values (19, 'Salted Fish Fried Rice', 'Mains', 13.00, 50, False);
insert into food(rid, name, category, price, food_limit, isRemoved) values (19, 'Hor Fun with Sliced Beef', 'Mains', 15.00, 50, False);
insert into food(rid, name, category, price, food_limit, isRemoved) values (19, 'Stewed Ee-fu Noodles', 'Mains', 14.00, 50, False);
insert into food(rid, name, category, price, food_limit, isRemoved) values (19, 'Braised Hor Fun with Seafood', 'Mains', 16.00, 50, False);
insert into food(rid, name, category, price, food_limit, isRemoved) values (19, 'Crisp-Fried Tofu', 'Sides', 9.00, 100, False);
insert into food(rid, name, category, price, food_limit, isRemoved) values (19, 'Carrot Cake in XO sauce', 'Sides', 9.50, 80, False);
insert into food(rid, name, category, price, food_limit, isRemoved) values (19, 'Double-Boiled Chicken Soup', 'Sides', 11.50, 80, False);
insert into food(rid, name, category, price, food_limit, isRemoved) values (19, 'Hot and Spicy Soup', 'Sides', 9.00, 80, False);
insert into food(rid, name, category, price, food_limit, isRemoved) values (19, 'Crispy BBQ Honey Pork Bun', 'Sides', 6.50, 100, False);
insert into food(rid, name, category, price, food_limit, isRemoved) values (19, 'Beancurd Skin Prawn Fritters', 'Sides', 7.00, 100, False);
insert into food(rid, name, category, price, food_limit, isRemoved) values (19, 'Crispy Vegetable Spring Roll', 'Sides', 5.00, 100, False);
insert into food(rid, name, category, price, food_limit, isRemoved) values (20, 'Herbal Roast Duck Bento', 'Mains', 13.00, 80, False);
insert into food(rid, name, category, price, food_limit, isRemoved) values (20, 'Marmite Chicken Bento', 'Mains', 11.00, 80, False);
insert into food(rid, name, category, price, food_limit, isRemoved) values (20, 'Mongolian Pork Ribs Bento', 'Mains', 13.00, 80, False);
insert into food(rid, name, category, price, food_limit, isRemoved) values (20, 'Sweet and Sour Pork Bento', 'Mains', 11.00, 80, False);
insert into food(rid, name, category, price, food_limit, isRemoved) values (20, 'Char Siew Rice', 'Mains', 9.00, 80, False);
insert into food(rid, name, category, price, food_limit, isRemoved) values (20, 'Meatballs Congee', 'Mains', 6.00, 80, False);
insert into food(rid, name, category, price, food_limit, isRemoved) values (20, 'Egg Minced Pork Congee', 'Mains', 7.00, 80, False);
insert into food(rid, name, category, price, food_limit, isRemoved) values (20, 'Duck Roasted w/ Angelica Herb', 'Mains', 18.00, 80, False);
insert into food(rid, name, category, price, food_limit, isRemoved) values (20, 'Sweet and Sour Pork', 'Sides', 13.00, 80, False);
insert into food(rid, name, category, price, food_limit, isRemoved) values (20, 'Braised Pork Belly', 'Sides', 17.00, 80, False);
insert into food(rid, name, category, price, food_limit, isRemoved) values (20, 'Kang Kong', 'Sides', 11.00, 80, False);
insert into food(rid, name, category, price, food_limit, isRemoved) values (20, 'Sauteed French Bean', 'Sides', 14.00, 80, False);
insert into food(rid, name, category, price, food_limit, isRemoved) values (20, 'Golden Lotus Root with Pumpkin', 'Sides', 14.00, 80, False);
insert into food(rid, name, category, price, food_limit, isRemoved) values (20, 'Chinese Spinach', 'Sides', 15.00, 80, False);
insert into food(rid, name, category, price, food_limit, isRemoved) values (20, 'Poached Spinach with Eggs', 'Sides', 16.00, 80, False);
insert into food(rid, name, category, price, food_limit, isRemoved) values (20, 'Silver Cod Fish in Soy Sauce', 'Sides', 30.00, 80, False);
insert into food(rid, name, category, price, food_limit, isRemoved) values (20, 'Prawn Balls with Mayo Sauce', 'Sides', 19.00, 80, False);
insert into food(rid, name, category, price, food_limit, isRemoved) values (20, 'Scrambled Eggs with Tomato', 'Sides', 9.00, 80, False);
insert into food(rid, name, category, price, food_limit, isRemoved) values (20, 'Crispy Golden Tofu', 'Sides', 15.00, 80, False);
insert into food(rid, name, category, price, food_limit, isRemoved) values (20, 'Mini Mantou', 'Sides', 4.00, 80, False);
insert into food(rid, name, category, price, food_limit, isRemoved) values (20, 'Homemade Iced Lemon Tea', 'Drinks', 3.00, 80, False);
insert into food(rid, name, category, price, food_limit, isRemoved) values (20, 'Lohan Guo with Longan', 'Drinks', 3.00, 80, False);
insert into food(rid, name, category, price, food_limit, isRemoved) values (21, 'Chicken Chow Mein', 'Mains', 6.00, 50, False);
insert into food(rid, name, category, price, food_limit, isRemoved) values (21, 'Roast Pork Chow Mein', 'Mains', 6.00, 50, False);
insert into food(rid, name, category, price, food_limit, isRemoved) values (21, 'Shrimp Chow Mein', 'Mains', 6.00, 50, False);
insert into food(rid, name, category, price, food_limit, isRemoved) values (21, 'Pepper Steak with Onion', 'Mains', 6.00, 50, False);
insert into food(rid, name, category, price, food_limit, isRemoved) values (21, 'Beef with Broccoli', 'Mains', 6.00, 50, False);
insert into food(rid, name, category, price, food_limit, isRemoved) values (21, 'Chicken with Broccoli', 'Mains', 6.00, 50, False);
insert into food(rid, name, category, price, food_limit, isRemoved) values (21, 'Shrimp with Chinese Vegetable', 'Mains', 6.00, 50, False);
insert into food(rid, name, category, price, food_limit, isRemoved) values (21, 'Chicken with Snow Peas', 'Mains', 6.00, 50, False);
insert into food(rid, name, category, price, food_limit, isRemoved) values (21, 'Sweet and Sour Chicken', 'Mains', 6.00, 50, False);
insert into food(rid, name, category, price, food_limit, isRemoved) values (21, 'Sweet and Sour Pork', 'Mains', 6.00, 50, False);
insert into food(rid, name, category, price, food_limit, isRemoved) values (21, 'General Tsos Chicken', 'Mains', 6.00, 50, False);
insert into food(rid, name, category, price, food_limit, isRemoved) values (21, 'Sesame Chicken', 'Mains', 6.00, 50, False);
insert into food(rid, name, category, price, food_limit, isRemoved) values (21, 'Szechuan Chicken', 'Mains', 6.00, 50, False);
insert into food(rid, name, category, price, food_limit, isRemoved) values (21, 'Kung Pao Chicken', 'Mains', 6.00, 50, False);
insert into food(rid, name, category, price, food_limit, isRemoved) values (22, 'Magherita Pizza', 'Pizza', 20.00, 50, False);
insert into food(rid, name, category, price, food_limit, isRemoved) values (22, 'Pepperoni Pizza', 'Pizza', 22.00, 50, False);
insert into food(rid, name, category, price, food_limit, isRemoved) values (22, 'Chicken Fajita Pizza', 'Pizza', 22.00, 50, False);
insert into food(rid, name, category, price, food_limit, isRemoved) values (22, 'Hawaiian Supreme', 'Pizza', 24.00, 50, False);
insert into food(rid, name, category, price, food_limit, isRemoved) values (22, 'BBQ Chicken Pizza', 'Pizza', 24.00, 50, False);
insert into food(rid, name, category, price, food_limit, isRemoved) values (22, 'Spinach and Ricotta Pizza', 'Pizza', 24.00, 50, False);
insert into food(rid, name, category, price, food_limit, isRemoved) values (22, 'Garden Delight Pizza', 'Pizza', 24.00, 50, False);
insert into food(rid, name, category, price, food_limit, isRemoved) values (22, 'New Yorker Pizza', 'Pizza', 24.00, 50, False);
insert into food(rid, name, category, price, food_limit, isRemoved) values (22, 'Italian Pizza', 'Pizza', 24.00, 50, False);
insert into food(rid, name, category, price, food_limit, isRemoved) values (22, 'Sensational Seafood Pizza', 'Pizza', 26.00, 50, False);
insert into food(rid, name, category, price, food_limit, isRemoved) values (22, 'Chicken Royale Pizza', 'Pizza', 26.00, 50, False);
insert into food(rid, name, category, price, food_limit, isRemoved) values (22, 'King\s Special Pizza', 'Pizza', 26.00, 50, False);
insert into food(rid, name, category, price, food_limit, isRemoved) values (22, 'The Fiery Extreme Pizza', 'Pizza', 26.00, 50, False);
insert into food(rid, name, category, price, food_limit, isRemoved) values (22, 'Bolognese Linguine', 'Mains', 13.00, 50, False);
insert into food(rid, name, category, price, food_limit, isRemoved) values (22, 'Meatball Linguine', 'Mains', 15.00, 50, False);
insert into food(rid, name, category, price, food_limit, isRemoved) values (22, 'Carbonara Linguine', 'Mains', 11.00, 50, False);
insert into food(rid, name, category, price, food_limit, isRemoved) values (22, 'Lasagna', 'Mains', 17.00, 50, False);
insert into food(rid, name, category, price, food_limit, isRemoved) values (22, 'Seafood Carbonara', 'Mains', 17.00, 50, False);
insert into food(rid, name, category, price, food_limit, isRemoved) values (22, 'Thai Curry Baked Rice', 'Mains', 15.00, 50, False);
insert into food(rid, name, category, price, food_limit, isRemoved) values (22, 'Potato Wedges', 'Sides', 7.00, 80, False);
insert into food(rid, name, category, price, food_limit, isRemoved) values (22, 'Truffle Fries', 'Sides', 7.00, 80, False);
insert into food(rid, name, category, price, food_limit, isRemoved) values (22, 'Calamari', 'Sides', 7.00, 80, False);
insert into food(rid, name, category, price, food_limit, isRemoved) values (22, 'Baked Meatballs', 'Sides', 7.00, 80, False);
insert into food(rid, name, category, price, food_limit, isRemoved) values (22, 'Fish Fingers', 'Sides', 7.00, 80, False);
insert into food(rid, name, category, price, food_limit, isRemoved) values (22, 'Root Beer', 'Drinks', 4.00, 80, False);
insert into food(rid, name, category, price, food_limit, isRemoved) values (22, 'Iced Lemon Tea', 'Drinks', 4.00, 80, False);
insert into food(rid, name, category, price, food_limit, isRemoved) values (23, 'Traditional Pizza', 'Pizza', 8.00, 50, False);
insert into food(rid, name, category, price, food_limit, isRemoved) values (23, 'White Pizza', 'Pizza', 8.00, 50, False);
insert into food(rid, name, category, price, food_limit, isRemoved) values (23, 'Spaghetti and Meatballs', 'Mains', 7.00, 50, False);
insert into food(rid, name, category, price, food_limit, isRemoved) values (23, 'Fettucine Alfredo', 'Mains', 7.00, 50, False);
insert into food(rid, name, category, price, food_limit, isRemoved) values (23, 'Manicotti', 'Mains', 7.00, 50, False);
insert into food(rid, name, category, price, food_limit, isRemoved) values (23, 'Lasagna', 'Mains', 7.00, 50, False);
insert into food(rid, name, category, price, food_limit, isRemoved) values (23, 'Primavera Panini', 'Mains', 6.00, 50, False);
insert into food(rid, name, category, price, food_limit, isRemoved) values (23, 'Grilled Chicken Panini', 'Mains', 7.00, 50, False);
insert into food(rid, name, category, price, food_limit, isRemoved) values (23, 'Chicken Italiano', 'Mains', 8.00, 50, False);
insert into food(rid, name, category, price, food_limit, isRemoved) values (23, 'Parmesan Chicken', 'Mains', 8.00, 50, False);
insert into food(rid, name, category, price, food_limit, isRemoved) values (23, 'Sausage and Peppers Panini', 'Mains', 7.00, 50, False);
insert into food(rid, name, category, price, food_limit, isRemoved) values (23, 'Tiramisu', 'Desserts', 6.00, 50, False);
insert into food(rid, name, category, price, food_limit, isRemoved) values (23, 'Cannoli', 'Desserts', 6.00, 50, False);
insert into food(rid, name, category, price, food_limit, isRemoved) values (23, 'New York Cheesecake', 'Desserts', 6.00, 50, False);
insert into food(rid, name, category, price, food_limit, isRemoved) values (23, 'Creme Brulee', 'Desserts', 4.00, 50, False);
insert into food(rid, name, category, price, food_limit, isRemoved) values (23, 'Raspberry Spongecake', 'Desserts', 4.00, 50, False);
insert into food(rid, name, category, price, food_limit, isRemoved) values (24, 'Hainan Chicken, Half', 'Mains', 20.00, 50, False);
insert into food(rid, name, category, price, food_limit, isRemoved) values (24, 'Bak Kut Teh', 'Mains', 15.00, 50, False);
insert into food(rid, name, category, price, food_limit, isRemoved) values (24, 'Teochew Mixed Platter', 'Mains', 24.00, 50, False);
insert into food(rid, name, category, price, food_limit, isRemoved) values (24, 'Yam Pork', 'Mains', 20.00, 50, False);
insert into food(rid, name, category, price, food_limit, isRemoved) values (25, 'Hainanese Chicken Rice', 'Mains', 13.00, 50, False);
insert into food(rid, name, category, price, food_limit, isRemoved) values (25, 'Chicken Laksa', 'Mains', 12.50, 50, False);
insert into food(rid, name, category, price, food_limit, isRemoved) values (25, 'Nasi Goreng', 'Mains', 13.00, 50, False);
insert into food(rid, name, category, price, food_limit, isRemoved) values (25, 'Chicken Noodle Salad', 'Mains', 12.00, 50, False);
insert into food(rid, name, category, price, food_limit, isRemoved) values (25, 'Bean Curd Laksa', 'Mains', 12.00, 50, False);
insert into food(rid, name, category, price, food_limit, isRemoved) values (25, 'Fried Chicken Laksa', 'Mains', 15.00, 50, False);
insert into food(rid, name, category, price, food_limit, isRemoved) values (25, 'King Prawn Laksa', 'Mains', 14.50, 50, False);
insert into food(rid, name, category, price, food_limit, isRemoved) values (25, 'Red Curry Chicken Rice', 'Mains', 14.00, 50, False);
insert into food(rid, name, category, price, food_limit, isRemoved) values (25, 'Nasi Lemak Curry', 'Mains', 15.00, 50, False);
insert into food(rid, name, category, price, food_limit, isRemoved) values (25, 'Char Kway Teow', 'Mains', 15.00, 50, False);
insert into food(rid, name, category, price, food_limit, isRemoved) values (25, 'Mee Goreng', 'Mains', 14.00, 50, False);
insert into food(rid, name, category, price, food_limit, isRemoved) values (25, 'Mee Siam Goreng', 'Mains', 14.00, 50, False);
insert into food(rid, name, category, price, food_limit, isRemoved) values (25, 'Prawn Fried Noodles', 'Mains', 15.00, 50, False);
insert into food(rid, name, category, price, food_limit, isRemoved) values (25, 'Vegetable Curry Rice', 'Mains', 12.50, 50, False);
=======

-- insert into food(rid, name, category, price, food_limit, isRemoved) values (2, 'Hershey White Chocolate', 'Chocolate', 2.50, 150, False);
-- insert into food(rid, name, category, price, food_limit, isRemoved) values (2, 'Hershey Dark Chocolate', 'Chocolate', 2.50, 150, False);
-- insert into food(rid, name, category, price, food_limit, isRemoved) values (2, 'Hershey Milk Chocolate', 'Chocolate', 2.50, 150, False);
-- insert into food(rid, name, category, price, food_limit, isRemoved) values (2, 'Ferrero Rocher, 24pc', 'Chocolate', 12.00, 150, False);
-- insert into food(rid, name, category, price, food_limit, isRemoved) values (2, 'Ferrero Rocher, 16pc', 'Chocolate', 9.00, 150, False);
-- insert into food(rid, name, category, price, food_limit, isRemoved) values (2, 'Kit Kat, Milk Chocolate', 'Chocolate', 1.50, 150, False);
-- insert into food(rid, name, category, price, food_limit, isRemoved) values (2, 'Kit Kat, Dark Chocolate', 'Chocolate', 1.50, 150, False);
-- insert into food(rid, name, category, price, food_limit, isRemoved) values (2, 'Kit Kat, White Chocolate', 'Chocolate', 1.50, 150, False);
-- insert into food(rid, name, category, price, food_limit, isRemoved) values (2, 'Toblerone Milk', 'Chocolate', 2.50, 150, False);
-- insert into food(rid, name, category, price, food_limit, isRemoved) values (2, 'Toblerone Dark', 'Chocolate', 2.50, 120, False);
-- insert into food(rid, name, category, price, food_limit, isRemoved) values (2, 'Toblerone White', 'Chocolate', 2.50, 120, False);
-- insert into food(rid, name, category, price, food_limit, isRemoved) values (2, 'Cadbury Dairy Milk', 'Chocolate', 6.40, 100, False);
-- insert into food(rid, name, category, price, food_limit, isRemoved) values (2, 'Kinder Bueno', 'Chocolate', 3.00, 200, False);
-- insert into food(rid, name, category, price, food_limit, isRemoved) values (2, 'Sour Power', 'Candy', 1.50, 300, False);
-- insert into food(rid, name, category, price, food_limit, isRemoved) values (2, 'Pop Rocks', 'Candy', 0.90, 500, False);
-- insert into food(rid, name, category, price, food_limit, isRemoved) values (2, 'Twisterz', 'Candy', 2.00, 200, False);
-- insert into food(rid, name, category, price, food_limit, isRemoved) values (2, 'Jellybeans', 'Candy', 0.50, 1500, False);
-- insert into food(rid, name, category, price, food_limit, isRemoved) values (2, 'Chewing Gum', 'Candy', 0.70, 120, False);
-- insert into food(rid, name, category, price, food_limit, isRemoved) values (2, 'Monster Sweet', 'Candy', 0.50, 1000, False);
-- insert into food(rid, name, category, price, food_limit, isRemoved) values (2, 'Double Choc Chip Cookie', 'Cookie', 2.50, 40, False);
-- insert into food(rid, name, category, price, food_limit, isRemoved) values (2, 'White Chocolate Cookie', 'Cookie', 2.50, 40, False);
-- insert into food(rid, name, category, price, food_limit, isRemoved) values (2, 'Oatmeal Raisin Cookie', 'Cookie', 3.00, 30, False);
-- insert into food(rid, name, category, price, food_limit, isRemoved) values (3, 'Peri-Peri Fried Chicken', 'Chicken', 6.00, 200, False);
-- insert into food(rid, name, category, price, food_limit, isRemoved) values (3, 'BBQ Chicken', 'Chicken', 6.00, 150, False);
-- insert into food(rid, name, category, price, food_limit, isRemoved) values (3, 'Secret Sauce Chicken', 'Chicken', 6.00, 300, False);
-- insert into food(rid, name, category, price, food_limit, isRemoved) values (3, 'Sweet N Sour Chicken', 'Chicken', 6.00, 100, False);
-- insert into food(rid, name, category, price, food_limit, isRemoved) values (3, 'Teriyaki Chicken', 'Chicken', 6.00, 200, False);
-- insert into food(rid, name, category, price, food_limit, isRemoved) values (3, 'Chicken Sandwich', 'Sandwiches', 4.00, 40, False);
-- insert into food(rid, name, category, price, food_limit, isRemoved) values (3, 'Double Chicken Sandwich', 'Sandwiches', 5.50, 30, False);
-- insert into food(rid, name, category, price, food_limit, isRemoved) values (3, 'Fries', 'Sides', 2.50, 150, False);
-- insert into food(rid, name, category, price, food_limit, isRemoved) values (3, 'Chicken Nuggets, 6pc', 'Sides', 3.00, 75, False);
-- insert into food(rid, name, category, price, food_limit, isRemoved) values (3, 'Popcorn Chicken', 'Sides', 3.00, 75, False);
-- insert into food(rid, name, category, price, food_limit, isRemoved) values (3, 'Pepsi, 1.5L', 'Drinks', 3.00, 100, False);
-- insert into food(rid, name, category, price, food_limit, isRemoved) values (3, 'Coco-Cola, 1.5L', 'Drinks', 3.00, 100, False);
-- insert into food(rid, name, category, price, food_limit, isRemoved) values (3, 'Fresh Lemonade, 1.5L', 'Drinks', 3.60, 50, False);
-- insert into food(rid, name, category, price, food_limit, isRemoved) values (4, 'Grilled Salmon', 'Fish', 22.50, 40, False);
-- insert into food(rid, name, category, price, food_limit, isRemoved) values (4, 'Pan-Seared Tuna', 'Fish', 20.00, 40, False);
-- insert into food(rid, name, category, price, food_limit, isRemoved) values (4, 'Seared Sea Bass', 'Fish', 20.00, 40, False);
-- insert into food(rid, name, category, price, food_limit, isRemoved) values (4, 'Baked Cod', 'Fish', 18.00, 40, False);
-- insert into food(rid, name, category, price, food_limit, isRemoved) values (4, 'Fried Barramundi', 'Fish', 18.00, 40, False);
-- insert into food(rid, name, category, price, food_limit, isRemoved) values (4, 'Grilled Halibut', 'Fish', 20.00, 40, False);
-- insert into food(rid, name, category, price, food_limit, isRemoved) values (4, 'Fish & Chips', 'Fish', 15.00, 60, False);
-- insert into food(rid, name, category, price, food_limit, isRemoved) values (4, 'Chowder Soup', 'Sides', 5.00, 50, False);
-- insert into food(rid, name, category, price, food_limit, isRemoved) values (4, 'Fish Sticks, 4pc', 'Sides', 4.00, 30, False);
-- insert into food(rid, name, category, price, food_limit, isRemoved) values (4, 'Crab Sticks, 4pc', 'Sides', 4.00, 20, False);
-- insert into food(rid, name, category, price, food_limit, isRemoved) values (4, 'Fizzy Lime, 1.5L', 'Drinks', 3.20, 100, False);
-- insert into food(rid, name, category, price, food_limit, isRemoved) values (4, 'Lemon Tea, 1.5L', 'Drinks', 2.80, 100, False);
-- insert into food(rid, name, category, price, food_limit, isRemoved) values (5, 'Roast Lamb with Honey Mustard', 'Mains', 20.50, 30, False);
-- insert into food(rid, name, category, price, food_limit, isRemoved) values (5, 'Braised Lamb Shanks', 'Mains', 19.50, 30, False);
-- insert into food(rid, name, category, price, food_limit, isRemoved) values (5, 'BBQ Pork Ribs', 'Mains', 17.20, 30, False);
-- insert into food(rid, name, category, price, food_limit, isRemoved) values (5, 'Fried Teriyaki Pork Chops', 'Mains', 16.00, 30, False);
-- insert into food(rid, name, category, price, food_limit, isRemoved) values (5, 'Honey Glazed Chicken Steak', 'Mains', 16.00, 30, False);
-- insert into food(rid, name, category, price, food_limit, isRemoved) values (5, 'Grilled Chicken Steak', 'Mains', 16.00, 30, False);
-- insert into food(rid, name, category, price, food_limit, isRemoved) values (5, 'Breaded Fish & Chips', 'Mains', 16.00, 30, False);
-- insert into food(rid, name, category, price, food_limit, isRemoved) values (5, 'Seafood Marinara', 'Mains', 16.00, 30, False);
-- insert into food(rid, name, category, price, food_limit, isRemoved) values (5, 'Seafood Aglio Olio', 'Mains', 16.00, 30, False);
-- insert into food(rid, name, category, price, food_limit, isRemoved) values (5, 'Pasta Carbonara', 'Mains', 15.00, 30, False);
-- insert into food(rid, name, category, price, food_limit, isRemoved) values (5, 'Black Pepper Seafood Pasta', 'Mains', 16.00, 30, False);
-- insert into food(rid, name, category, price, food_limit, isRemoved) values (5, 'Double Cheeseburger', 'Mains', 19.00, 30, False);
-- insert into food(rid, name, category, price, food_limit, isRemoved) values (5, 'Cheeseburger', 'Mains', 13.00, 30, False);
-- insert into food(rid, name, category, price, food_limit, isRemoved) values (5, 'Fried Chicken Burger', 'Mains', 13.00, 30, False);
-- insert into food(rid, name, category, price, food_limit, isRemoved) values (5, 'Coca-Cola', 'Drinks', 4.00, 60, False);
-- insert into food(rid, name, category, price, food_limit, isRemoved) values (5, 'Sprite', 'Drinks', 4.00, 60, False);
-- insert into food(rid, name, category, price, food_limit, isRemoved) values (5, 'Lemon Tea', 'Drinks', 4.00, 60, False);
-- insert into food(rid, name, category, price, food_limit, isRemoved) values (5, 'Green Tea', 'Drinks', 4.00, 60, False);
-- insert into food(rid, name, category, price, food_limit, isRemoved) values (5, 'Chicken Sausage', 'Sides', 5.00, 50, False);
-- insert into food(rid, name, category, price, food_limit, isRemoved) values (5, 'Truffle Fries', 'Sides', 8.00, 50, False);
-- insert into food(rid, name, category, price, food_limit, isRemoved) values (5, 'Meatballs', 'Sides', 4.00, 80, False);
-- insert into food(rid, name, category, price, food_limit, isRemoved) values (5, 'Chicken Wings', 'Sides', 4.00, 80, False);
-- insert into food(rid, name, category, price, food_limit, isRemoved) values (6, 'Chicken Vindaloo', 'Mains', 15.00, 60, False);
-- insert into food(rid, name, category, price, food_limit, isRemoved) values (6, 'Beef Madras', 'Mains', 15.00, 60, False);
-- insert into food(rid, name, category, price, food_limit, isRemoved) values (6, 'Prawn Malabar', 'Mains', 18.00, 120, False);
-- insert into food(rid, name, category, price, food_limit, isRemoved) values (6, 'Kashmiri Chicken', 'Mains', 16.00, 40, False);
-- insert into food(rid, name, category, price, food_limit, isRemoved) values (6, 'Chicken Pistachio', 'Mains', 16.00, 40, False);
-- insert into food(rid, name, category, price, food_limit, isRemoved) values (6, 'Garlic Naan', 'Sides', 2.50, 80, False);
-- insert into food(rid, name, category, price, food_limit, isRemoved) values (6, 'Paratha', 'Sides', 3.50, 80, False);
-- insert into food(rid, name, category, price, food_limit, isRemoved) values (6, 'Jafrani Fish', 'Sides', 9.50, 60, False);
-- insert into food(rid, name, category, price, food_limit, isRemoved) values (6, 'Masala Tea', 'Drinks', 3.00, 80, False);
-- insert into food(rid, name, category, price, food_limit, isRemoved) values (6, 'Fresh Lemon Juice', 'Drinks', 4.20, 80, False);
-- insert into food(rid, name, category, price, food_limit, isRemoved) values (7, 'Sardine Pizza', 'Pizza', 25.10, 50, False);
-- insert into food(rid, name, category, price, food_limit, isRemoved) values (7, 'Laksalicious Pizza', 'Pizza', 25.10, 50, False);
-- insert into food(rid, name, category, price, food_limit, isRemoved) values (7, 'Hawaiian Pizza', 'Pizza', 14.00, 50, False);
-- insert into food(rid, name, category, price, food_limit, isRemoved) values (7, 'Chicken Supreme', 'Pizza', 14.00, 50, False);
-- insert into food(rid, name, category, price, food_limit, isRemoved) values (7, 'Super Supreme', 'Pizza', 14.00, 50, False);
-- insert into food(rid, name, category, price, food_limit, isRemoved) values (7, 'Pepperoni', 'Pizza', 14.00, 50, False);
-- insert into food(rid, name, category, price, food_limit, isRemoved) values (7, 'Veggie Lover', 'Pizza', 14.00, 50, False);
-- insert into food(rid, name, category, price, food_limit, isRemoved) values (7, 'Meat Galore', 'Pizza', 14.00, 50, False);
-- insert into food(rid, name, category, price, food_limit, isRemoved) values (7, 'Cheese n Chic', 'Pizza', 11.00, 50, False);
-- insert into food(rid, name, category, price, food_limit, isRemoved) values (7, 'Ocean Delight', 'Pizza', 11.00, 50, False);
-- insert into food(rid, name, category, price, food_limit, isRemoved) values (7, 'BBQ Chicken', 'Pizza', 13.00, 50, False);
-- insert into food(rid, name, category, price, food_limit, isRemoved) values (7, 'Buffalo Wings', 'Sides', 6.00, 100, False);
-- insert into food(rid, name, category, price, food_limit, isRemoved) values (7, 'Garlic Bread', 'Sides', 4.00, 200, False);
-- insert into food(rid, name, category, price, food_limit, isRemoved) values (7, 'Cheese Fries', 'Sides', 6.00, 80, False);
-- insert into food(rid, name, category, price, food_limit, isRemoved) values (7, 'Honey Roasted Wings', 'Sides', 9.00, 100, False);
-- insert into food(rid, name, category, price, food_limit, isRemoved) values (7, 'Pepsi, 1.5L', '', 4.20, 100, False);
-- insert into food(rid, name, category, price, food_limit, isRemoved) values (7, 'Iced Lemon Tea, 1.5L', '', 4.20, 100, False);
-- insert into food(rid, name, category, price, food_limit, isRemoved) values (8, 'Zinger Burger', 'Mains', 5.00, 100, False);
-- insert into food(rid, name, category, price, food_limit, isRemoved) values (8, 'Cheesy BBQ Meltz', 'Mains', 5.00, 100, False);
-- insert into food(rid, name, category, price, food_limit, isRemoved) values (8, 'Pockett Bandito', 'Mains', 5.00, 100, False);
-- insert into food(rid, name, category, price, food_limit, isRemoved) values (8, 'Curry Rice Bucket', 'Mains', 5.50, 50, False);
-- insert into food(rid, name, category, price, food_limit, isRemoved) values (8, 'Original Recipe Chicken', 'Mains', 3.00, 120, False);
-- insert into food(rid, name, category, price, food_limit, isRemoved) values (8, 'Crispy Chicken', 'Mains', 3.00, 120, False);
-- insert into food(rid, name, category, price, food_limit, isRemoved) values (8, 'Colonel Burger', 'Mains', 5.00, 100, False);
-- insert into food(rid, name, category, price, food_limit, isRemoved) values (8, 'Crispy Tenders Burger', 'Mains', 5.00, 100, False);
-- insert into food(rid, name, category, price, food_limit, isRemoved) values (8, 'Shrooms Fillet Burger', 'Mains', 5.00, 100, False);
-- insert into food(rid, name, category, price, food_limit, isRemoved) values (8, 'Popcorn Chicken', 'Sides', 3.00, 100, False);
-- insert into food(rid, name, category, price, food_limit, isRemoved) values (8, 'French Fries', 'Sides', 3.00, 200, False);
-- insert into food(rid, name, category, price, food_limit, isRemoved) values (8, 'Cheese Fries', 'Sides', 4.00, 100, False);
-- insert into food(rid, name, category, price, food_limit, isRemoved) values (8, 'Whipped Potato', 'Sides', 2.00, 150, False);
-- insert into food(rid, name, category, price, food_limit, isRemoved) values (8, 'Coleslaw', 'Sides', 2.00, 150, False);
-- insert into food(rid, name, category, price, food_limit, isRemoved) values (8, 'Pepsi', 'Drinks', 2.00, 120, False);
-- insert into food(rid, name, category, price, food_limit, isRemoved) values (8, 'Mountain Dew', 'Drinks', 2.00, 120, False);
-- insert into food(rid, name, category, price, food_limit, isRemoved) values (8, 'Root Beer', 'Drinks', 2.00, 120, False);
-- insert into food(rid, name, category, price, food_limit, isRemoved) values (9, 'Bolognese Pasta', 'Mains', 8.00, 50, False);
-- insert into food(rid, name, category, price, food_limit, isRemoved) values (9, 'Aglio Olio Pasta', 'Mains', 7.00, 50, False);
-- insert into food(rid, name, category, price, food_limit, isRemoved) values (9, 'Seafood Pasta', 'Mains', 9.00, 50, False);
-- insert into food(rid, name, category, price, food_limit, isRemoved) values (9, 'Fish & Chips', 'Mains', 10.00, 50, False);
-- insert into food(rid, name, category, price, food_limit, isRemoved) values (9, 'Chicken Chop', 'Mains', 11.00, 50, False);
-- insert into food(rid, name, category, price, food_limit, isRemoved) values (9, 'Chicken Lasagna', 'Mains', 8.00, 50, False);
-- insert into food(rid, name, category, price, food_limit, isRemoved) values (9, 'Beef Stroganoff', 'Mains', 9.00, 50, False);
-- insert into food(rid, name, category, price, food_limit, isRemoved) values (9, 'Laksa', 'Mains', 5.00, 50, False);
-- insert into food(rid, name, category, price, food_limit, isRemoved) values (9, 'Nasi Lemak', 'Mains', 5.00, 50, False);
-- insert into food(rid, name, category, price, food_limit, isRemoved) values (9, 'Pineapple Fried Rice', 'Mains', 6.00, 50, False);
-- insert into food(rid, name, category, price, food_limit, isRemoved) values (9, 'Tom Yum Fried Rice', 'Mains', 6.00, 50, False);
-- insert into food(rid, name, category, price, food_limit, isRemoved) values (9, 'Teochew Fried Rice', 'Mains', 5.50, 50, False);
-- insert into food(rid, name, category, price, food_limit, isRemoved) values (9, 'Hokkien Mee', 'Mains', 5.00, 50, False);
-- insert into food(rid, name, category, price, food_limit, isRemoved) values (9, 'Pad Thai', 'Mains', 5.00, 50, False);
-- insert into food(rid, name, category, price, food_limit, isRemoved) values (9, 'Vietnamese Beef Pho', 'Mains', 7.00, 50, False);
-- insert into food(rid, name, category, price, food_limit, isRemoved) values (9, 'Korean Glass Noodles', 'Mains', 6.00, 50, False);
-- insert into food(rid, name, category, price, food_limit, isRemoved) values (9, 'Kimchi Fried Rice', 'Mains', 6.00, 50, False);
-- insert into food(rid, name, category, price, food_limit, isRemoved) values (9, 'Butter Chicken and Rice', 'Mains', 6.00, 50, False);
-- insert into food(rid, name, category, price, food_limit, isRemoved) values (9, 'Creamy Butter Chicken', 'Mains', 6.00, 50, False);
-- insert into food(rid, name, category, price, food_limit, isRemoved) values (9, 'Minced Pork Porridge', 'Mains', 5.00, 50, False);
-- insert into food(rid, name, category, price, food_limit, isRemoved) values (9, 'Steamed Duck Porridge', 'Mains', 10.00, 50, False);
-- insert into food(rid, name, category, price, food_limit, isRemoved) values (9, 'Mee siam', 'Mains', 4.00, 50, False);
-- insert into food(rid, name, category, price, food_limit, isRemoved) values (9, 'Mee Rebus', 'Mains', 4.00, 50, False);
-- insert into food(rid, name, category, price, food_limit, isRemoved) values (9, 'BBQ Fish and Rice Hot Plate', 'Mains', 9.00, 50, False);
-- insert into food(rid, name, category, price, food_limit, isRemoved) values (9, 'Iced Lemon Tea', 'Drinks', 2.00, 80, False);
-- insert into food(rid, name, category, price, food_limit, isRemoved) values (9, 'Sugercane Juice', 'Drinks', 2.00, 80, False);
-- insert into food(rid, name, category, price, food_limit, isRemoved) values (9, 'Avocado Milk', 'Drinks', 3.00, 50, False);
-- insert into food(rid, name, category, price, food_limit, isRemoved) values (9, 'Milk Tea', 'Drinks', 2.00, 80, False);
-- insert into food(rid, name, category, price, food_limit, isRemoved) values (10, 'Lemon Chicken Rice', 'Mains', 6.00, 80, False);
-- insert into food(rid, name, category, price, food_limit, isRemoved) values (10, 'Hainanese Chicken Rice', 'Mains', 6.00, 50, False);
-- insert into food(rid, name, category, price, food_limit, isRemoved) values (10, 'Hainanese Steamed Chicken', 'Mains', 15.00, 30, False);
-- insert into food(rid, name, category, price, food_limit, isRemoved) values (10, 'Truffle Fried Rice', 'Mains', 8.00, 50, False);
-- insert into food(rid, name, category, price, food_limit, isRemoved) values (10, 'Seafood Hor Fun', 'Mains', 6.00, 50, False);
-- insert into food(rid, name, category, price, food_limit, isRemoved) values (10, 'Pineapple Fried Rice', 'Mains', 7.00, 50, False);
-- insert into food(rid, name, category, price, food_limit, isRemoved) values (10, 'Curry Fish', 'Mains', 20.00, 50, False);
-- insert into food(rid, name, category, price, food_limit, isRemoved) values (10, 'Ginger and Spring Onion Fish', 'Mains', 10.00, 50, False);
-- insert into food(rid, name, category, price, food_limit, isRemoved) values (10, 'Sweet and Sour Pork', 'Sides', 8.00, 50, False);
-- insert into food(rid, name, category, price, food_limit, isRemoved) values (10, 'Crispy Cereal Prawn', 'Sides', 12.00, 50, False);
-- insert into food(rid, name, category, price, food_limit, isRemoved) values (10, 'Onion Omelette', 'Sides', 8.00, 50, False);
-- insert into food(rid, name, category, price, food_limit, isRemoved) values (10, 'Stir Fry French Bean', 'Sides', 8.00, 50, False);
-- insert into food(rid, name, category, price, food_limit, isRemoved) values (10, 'Sambal Kang Kong', 'Sides', 8.00, 50, False);
-- insert into food(rid, name, category, price, food_limit, isRemoved) values (10, 'Tom Yum Seafood Soup', 'Soup', 9.00, 50, False);
-- insert into food(rid, name, category, price, food_limit, isRemoved) values (10, 'Chicken Herbal Soup', 'Soup', 10.00, 50, False);
-- insert into food(rid, name, category, price, food_limit, isRemoved) values (10, 'Iced Lemon Tea', 'Drinks', 3.00, 50, False);
-- insert into food(rid, name, category, price, food_limit, isRemoved) values (10, 'Coca-Cola', 'Drinks', 2.00, 50, False);
-- insert into food(rid, name, category, price, food_limit, isRemoved) values (11, 'Fried Rice Chicken', 'Mains', 7.00, 50, False);
-- insert into food(rid, name, category, price, food_limit, isRemoved) values (11, 'Fried Rice Pork', 'Mains', 7.00, 50, False);
-- insert into food(rid, name, category, price, food_limit, isRemoved) values (11, 'Fried Rice Beef', 'Mains', 7.00, 50, False);
-- insert into food(rid, name, category, price, food_limit, isRemoved) values (11, 'Lo Mein Chicken', 'Mains', 7.00, 50, False);
-- insert into food(rid, name, category, price, food_limit, isRemoved) values (11, 'Lo Mein Pork', 'Mains', 7.00, 50, False);
-- insert into food(rid, name, category, price, food_limit, isRemoved) values (11, 'Lo Mein Beef', 'Mains', 7.00, 50, False);
-- insert into food(rid, name, category, price, food_limit, isRemoved) values (11, 'Chow Fun', 'Mains', 7.00, 50, False);
-- insert into food(rid, name, category, price, food_limit, isRemoved) values (11, 'Garlic Noodles', 'Mains', 5.00, 50, False);
-- insert into food(rid, name, category, price, food_limit, isRemoved) values (11, 'Sesame Beef', 'Mains', 10.00, 50, False);
-- insert into food(rid, name, category, price, food_limit, isRemoved) values (11, 'Crispy Beef Shingle', 'Mains', 11.00, 50, False);
-- insert into food(rid, name, category, price, food_limit, isRemoved) values (11, 'Sweet and Sour Pork', 'Mains', 9.00, 50, False);
-- insert into food(rid, name, category, price, food_limit, isRemoved) values (11, 'Garlic Chicken', 'Mains', 9.00, 60, False);
-- insert into food(rid, name, category, price, food_limit, isRemoved) values (11, 'Pork Dumplings', 'Sides', 4.50, 80, False);
-- insert into food(rid, name, category, price, food_limit, isRemoved) values (11, 'Vegetable Dumplings', 'Sides', 4.00, 80, False);
-- insert into food(rid, name, category, price, food_limit, isRemoved) values (11, 'Spring Roll', 'Sides', 3.00, 80, False);
-- insert into food(rid, name, category, price, food_limit, isRemoved) values (11, 'Honey Shrimp', 'Sides', 6.00, 100, False);
-- insert into food(rid, name, category, price, food_limit, isRemoved) values (11, 'Crabmeat Soup Bun', 'Sides', 7.00, 100, False);
-- insert into food(rid, name, category, price, food_limit, isRemoved) values (11, 'Onion Pancakes', 'Sides', 5.00, 40, False);
-- insert into food(rid, name, category, price, food_limit, isRemoved) values (12, 'Chicken Chop', 'Mains', 12.00, 30, False);
-- insert into food(rid, name, category, price, food_limit, isRemoved) values (12, 'Chicken Baked Rice', 'Mains', 13.00, 30, False);
-- insert into food(rid, name, category, price, food_limit, isRemoved) values (12, 'Spencer Steak', 'Mains', 22.00, 30, False);
-- insert into food(rid, name, category, price, food_limit, isRemoved) values (12, 'Burger Steak', 'Mains', 18.00, 30, False);
-- insert into food(rid, name, category, price, food_limit, isRemoved) values (12, 'Mushroom Soup', 'Sides', 6.00, 60, False);
-- insert into food(rid, name, category, price, food_limit, isRemoved) values (12, 'French Onion Soup', 'Sides', 6.00, 60, False);
-- insert into food(rid, name, category, price, food_limit, isRemoved) values (12, 'Seafood Chowder', 'Sides', 7.00, 60, False);
-- insert into food(rid, name, category, price, food_limit, isRemoved) values (12, 'Calamari Rings', 'Sides', 11.00, 120, False);
-- insert into food(rid, name, category, price, food_limit, isRemoved) values (12, 'Lim Specialty Chicken Wing', 'Sides', 13.00, 120, False);
-- insert into food(rid, name, category, price, food_limit, isRemoved) values (13, 'Milk Tea', 'Drinks', 3.50, 80, False);
-- insert into food(rid, name, category, price, food_limit, isRemoved) values (13, 'Green Milk Tea', 'Drinks', 3.50, 80, False);
-- insert into food(rid, name, category, price, food_limit, isRemoved) values (13, 'Hazelnut Milk Tea', 'Drinks', 4.00, 80, False);
-- insert into food(rid, name, category, price, food_limit, isRemoved) values (13, 'Caramel Milk Tea', 'Drinks', 4.00, 80, False);
-- insert into food(rid, name, category, price, food_limit, isRemoved) values (13, 'Honey Milk Tea', 'Drinks', 4.00, 80, False);
-- insert into food(rid, name, category, price, food_limit, isRemoved) values (13, 'Honey Green Tea', 'Drinks', 3.50, 80, False);
-- insert into food(rid, name, category, price, food_limit, isRemoved) values (13, 'Four Seasons Tea', 'Drinks', 3.00, 80, False);
-- insert into food(rid, name, category, price, food_limit, isRemoved) values (13, 'Lemon Lime Green Tea', 'Drinks', 3.50, 80, False);
-- insert into food(rid, name, category, price, food_limit, isRemoved) values (13, 'Yakult Green Tea', 'Drinks', 4.00, 80, False);
-- insert into food(rid, name, category, price, food_limit, isRemoved) values (13, 'Brown Sugar Milk Tea', 'Drinks', 4.00, 80, False);
-- insert into food(rid, name, category, price, food_limit, isRemoved) values (13, 'Black Tea Macchiato', 'Drinks', 3.00, 80, False);
-- insert into food(rid, name, category, price, food_limit, isRemoved) values (13, 'Chocolate Macchiato', 'Drinks', 4.50, 80, False);
-- insert into food(rid, name, category, price, food_limit, isRemoved) values (13, 'Ovaltine Macchiato', 'Drinks', 4.50, 80, False);
-- insert into food(rid, name, category, price, food_limit, isRemoved) values (13, 'Four Seasons Tea Macchiato', 'Drinks', 3.00, 80, False);
-- insert into food(rid, name, category, price, food_limit, isRemoved) values (13, 'Lemon Plum Juice', 'Drinks', 3.50, 80, False);
-- insert into food(rid, name, category, price, food_limit, isRemoved) values (13, 'Honey Lemon Juice', 'Drinks', 4.00, 80, False);
-- insert into food(rid, name, category, price, food_limit, isRemoved) values (13, 'Honey Lemon Lime Juice', 'Drinks', 4.00, 80, False);
-- insert into food(rid, name, category, price, food_limit, isRemoved) values (14, 'Sanum Frozen Yoghurt', 'Desserts', 17.00, 50, False);
-- insert into food(rid, name, category, price, food_limit, isRemoved) values (14, 'Frozen Yoghurt, Tub', 'Desserts', 10.00, 50, False);
-- insert into food(rid, name, category, price, food_limit, isRemoved) values (14, 'Golden Plus Smoothie', 'Desserts', 17.00, 50, False);
-- insert into food(rid, name, category, price, food_limit, isRemoved) values (14, 'Coconut Smoothie', 'Desserts', 14.00, 50, False);
-- insert into food(rid, name, category, price, food_limit, isRemoved) values (14, 'Bariloche Smoothie', 'Desserts', 14.00, 50, False);
-- insert into food(rid, name, category, price, food_limit, isRemoved) values (14, 'Golden Smoothie', 'Desserts', 14.00, 50, False);
-- insert into food(rid, name, category, price, food_limit, isRemoved) values (15, 'McSpicy', 'Mains', 5.00, 80, False);
-- insert into food(rid, name, category, price, food_limit, isRemoved) values (15, 'Double McSpicy', 'Mains', 7.00, 80, False);
-- insert into food(rid, name, category, price, food_limit, isRemoved) values (15, 'Buttermilk Crispy Chicken', 'Mains', 7.00, 80, False);
-- insert into food(rid, name, category, price, food_limit, isRemoved) values (15, 'McWings, 4pc', 'Mains', 4.00, 80, False);
-- insert into food(rid, name, category, price, food_limit, isRemoved) values (15, 'Chicken Nugget, 6pc', 'Mains', 4.50, 80, False);
-- insert into food(rid, name, category, price, food_limit, isRemoved) values (15, 'McChicken', 'Mains', 2.00, 80, False);
-- insert into food(rid, name, category, price, food_limit, isRemoved) values (15, 'Grilled Chicken Salad', 'Mains', 5.50, 80, False);
-- insert into food(rid, name, category, price, food_limit, isRemoved) values (15, 'Grilled Chicken Wrap', 'Mains', 5.50, 80, False);
-- insert into food(rid, name, category, price, food_limit, isRemoved) values (15, 'Fillet-O-Fish', 'Mains', 3.00, 80, False);
-- insert into food(rid, name, category, price, food_limit, isRemoved) values (15, 'Double Fillet-O-Fish', 'Mains', 5.50, 80, False);
-- insert into food(rid, name, category, price, food_limit, isRemoved) values (15, 'Classic Angus Beef Burger', 'Mains', 9.00, 80, False);
-- insert into food(rid, name, category, price, food_limit, isRemoved) values (15, 'Double Cheeseburger', 'Mains', 4.00, 80, False);
-- insert into food(rid, name, category, price, food_limit, isRemoved) values (15, 'Big Mac', 'Mains', 6.00, 80, False);
-- insert into food(rid, name, category, price, food_limit, isRemoved) values (15, 'The Original Angus', 'Mains', 6.00, 80, False);
-- insert into food(rid, name, category, price, food_limit, isRemoved) values (15, 'Vanilla Cone', 'Desserts', 1.00, 200, False);
-- insert into food(rid, name, category, price, food_limit, isRemoved) values (15, 'McFlurry', 'Desserts', 3.50, 120, False);
-- insert into food(rid, name, category, price, food_limit, isRemoved) values (15, 'Hot Fudge Sundae', 'Desserts', 2.00, 120, False);
-- insert into food(rid, name, category, price, food_limit, isRemoved) values (15, 'Ice Lemon Tea', 'Drinks', 3.50, 120, False);
-- insert into food(rid, name, category, price, food_limit, isRemoved) values (15, 'Coca-Cola', 'Desserts', 3.00, 120, False);
-- insert into food(rid, name, category, price, food_limit, isRemoved) values (16, 'Spicy Chicken Sensation', 'Mains', 4.00, 80, False);
-- insert into food(rid, name, category, price, food_limit, isRemoved) values (16, 'Ultimate Chicken Grill', 'Mains', 4.50, 80, False);
-- insert into food(rid, name, category, price, food_limit, isRemoved) values (16, 'Chicken Nuggets, 6pc', 'Mains', 3.50, 200, False);
-- insert into food(rid, name, category, price, food_limit, isRemoved) values (16, 'Daves Hot N Juicy Single ', 'Mains', 4.00, 80, False);
-- insert into food(rid, name, category, price, food_limit, isRemoved) values (16, 'Daves Hot N Juicy Double', 'Mains', 5.50, 80, False);
-- insert into food(rid, name, category, price, food_limit, isRemoved) values (16, 'Single Mushroom Melt', 'Mains', 4.50, 80, False);
-- insert into food(rid, name, category, price, food_limit, isRemoved) values (16, 'Double Mushroom Melt', 'Mains', 5.50, 80, False);
-- insert into food(rid, name, category, price, food_limit, isRemoved) values (16, 'Shrimp Supreme', 'Mains', 4.00, 80, False);
-- insert into food(rid, name, category, price, food_limit, isRemoved) values (16, 'Parmesan Caesar', 'Sides', 5.00, 80, False);
-- insert into food(rid, name, category, price, food_limit, isRemoved) values (16, 'Southwest Avocado', 'Sides', 5.00, 80, False);
-- insert into food(rid, name, category, price, food_limit, isRemoved) values (16, 'Coca-Cola', 'Drinks', 3.00, 120, False);
-- insert into food(rid, name, category, price, food_limit, isRemoved) values (16, 'Craft Lemonades', 'Drinks', 3.00, 120, False);
-- insert into food(rid, name, category, price, food_limit, isRemoved) values (17, 'Original Chicken Wings', 'Mains', 4.00, 200, False);
-- insert into food(rid, name, category, price, food_limit, isRemoved) values (17, 'Spicy Chicken', 'Mains', 4.00, 80, False);
-- insert into food(rid, name, category, price, food_limit, isRemoved) values (17, 'Chicken Tenders', 'Mains', 4.00, 120, False);
-- insert into food(rid, name, category, price, food_limit, isRemoved) values (17, 'Chicken Supreme Burger', 'Mains', 7.00, 60, False);
-- insert into food(rid, name, category, price, food_limit, isRemoved) values (17, 'Chicken Wrap', 'Mains', 6.00, 60, False);
-- insert into food(rid, name, category, price, food_limit, isRemoved) values (17, 'Fried Teriyaki Chicken', 'Mains', 6.00, 60, False);
-- insert into food(rid, name, category, price, food_limit, isRemoved) values (17, 'Grilled Chicken and Egg Burger', 'Mains', 5.00, 60, False);
-- insert into food(rid, name, category, price, food_limit, isRemoved) values (17, 'BBQ Chicken Chop', 'Mains', 7.00, 60, False);
-- insert into food(rid, name, category, price, food_limit, isRemoved) values (17, 'Black Pepper Chicken Chop', 'Mains', 7.00, 60, False);
-- insert into food(rid, name, category, price, food_limit, isRemoved) values (18, 'Spring Chicken', 'Mains', 14.00, 80, False);
-- insert into food(rid, name, category, price, food_limit, isRemoved) values (18, '1/2 Spring Chicken', 'Mains', 7.50, 80, False);
-- insert into food(rid, name, category, price, food_limit, isRemoved) values (18, 'Fish & Chips', 'Mains', 10.00, 80, False);
-- insert into food(rid, name, category, price, food_limit, isRemoved) values (18, 'Fragrant Chicken Rice', 'Mains', 4.00, 80, False);
-- insert into food(rid, name, category, price, food_limit, isRemoved) values (18, 'Potato Platter', 'Sides', 7.00, 100, False);
-- insert into food(rid, name, category, price, food_limit, isRemoved) values (18, 'Potato Fries', 'Sides', 3.00, 100, False);
-- insert into food(rid, name, category, price, food_limit, isRemoved) values (18, 'Potato Wedges', 'Sides', 3.00, 100, False);
-- insert into food(rid, name, category, price, food_limit, isRemoved) values (18, 'Popcorn Chicken', 'Sides', 5.00, 100, False);
-- insert into food(rid, name, category, price, food_limit, isRemoved) values (18, 'Onion Rings', 'Sides', 3.50, 100, False);
-- insert into food(rid, name, category, price, food_limit, isRemoved) values (18, 'Spiral Fries', 'Sides', 3.50, 100, False);
-- insert into food(rid, name, category, price, food_limit, isRemoved) values (18, 'Coleslaw', 'Sides', 3.00, 100, False);
-- insert into food(rid, name, category, price, food_limit, isRemoved) values (18, 'Coke Float', 'Drinks', 3.50, 100, False);
-- insert into food(rid, name, category, price, food_limit, isRemoved) values (18, 'Ice Milo', 'Drinks', 3.00, 100, False);
-- insert into food(rid, name, category, price, food_limit, isRemoved) values (18, 'Ice Lemon Tea', 'Drinks', 3.00, 100, False);
-- insert into food(rid, name, category, price, food_limit, isRemoved) values (19, 'Signature Canton Wanton Soup', 'Mains', 11.50, 50, False);
-- insert into food(rid, name, category, price, food_limit, isRemoved) values (19, 'Prawn Dumpling Soup', 'Mains', 11.50, 50, False);
-- insert into food(rid, name, category, price, food_limit, isRemoved) values (19, 'Stewed Beef Brisket Noodle', 'Mains', 13.50, 50, False);
-- insert into food(rid, name, category, price, food_limit, isRemoved) values (19, 'Shrimp Roe Noodle', 'Mains', 8.00, 50, False);
-- insert into food(rid, name, category, price, food_limit, isRemoved) values (19, 'Sliced Grass Carp Fish Noodle', 'Mains', 11.00, 50, False);
-- insert into food(rid, name, category, price, food_limit, isRemoved) values (19, 'Fresh Prawn Congee', 'Mains', 12.00, 50, False);
-- insert into food(rid, name, category, price, food_limit, isRemoved) values (19, 'Sliced Grass Carp Fish Congee', 'Mains', 11.50, 50, False);
-- insert into food(rid, name, category, price, food_limit, isRemoved) values (19, 'Handmade Meatball Congee', 'Mains', 9.50, 50, False);
-- insert into food(rid, name, category, price, food_limit, isRemoved) values (19, 'Sliced Beef Congee', 'Mains', 10.50, 50, False);
-- insert into food(rid, name, category, price, food_limit, isRemoved) values (19, 'Yang Zhou Fried Rice', 'Mains', 13.00, 50, False);
-- insert into food(rid, name, category, price, food_limit, isRemoved) values (19, 'Salted Fish Fried Rice', 'Mains', 13.00, 50, False);
-- insert into food(rid, name, category, price, food_limit, isRemoved) values (19, 'Hor Fun with Sliced Beef', 'Mains', 15.00, 50, False);
-- insert into food(rid, name, category, price, food_limit, isRemoved) values (19, 'Stewed Ee-fu Noodles', 'Mains', 14.00, 50, False);
-- insert into food(rid, name, category, price, food_limit, isRemoved) values (19, 'Braised Hor Fun with Seafood', 'Mains', 16.00, 50, False);
-- insert into food(rid, name, category, price, food_limit, isRemoved) values (19, 'Crisp-Fried Tofu', 'Sides', 9.00, 100, False);
-- insert into food(rid, name, category, price, food_limit, isRemoved) values (19, 'Carrot Cake in XO sauce', 'Sides', 9.50, 80, False);
-- insert into food(rid, name, category, price, food_limit, isRemoved) values (19, 'Double-Boiled Chicken Soup', 'Sides', 11.50, 80, False);
-- insert into food(rid, name, category, price, food_limit, isRemoved) values (19, 'Hot and Spicy Soup', 'Sides', 9.00, 80, False);
-- insert into food(rid, name, category, price, food_limit, isRemoved) values (19, 'Crispy BBQ Honey Pork Bun', 'Sides', 6.50, 100, False);
-- insert into food(rid, name, category, price, food_limit, isRemoved) values (19, 'Beancurd Skin Prawn Fritters', 'Sides', 7.00, 100, False);
-- insert into food(rid, name, category, price, food_limit, isRemoved) values (19, 'Crispy Vegetable Spring Roll', 'Sides', 5.00, 100, False);
-- insert into food(rid, name, category, price, food_limit, isRemoved) values (20, 'Herbal Roast Duck Bento', 'Mains', 13.00, 80, False);
-- insert into food(rid, name, category, price, food_limit, isRemoved) values (20, 'Marmite Chicken Bento', 'Mains', 11.00, 80, False);
-- insert into food(rid, name, category, price, food_limit, isRemoved) values (20, 'Mongolian Pork Ribs Bento', 'Mains', 13.00, 80, False);
-- insert into food(rid, name, category, price, food_limit, isRemoved) values (20, 'Sweet and Sour Pork Bento', 'Mains', 11.00, 80, False);
-- insert into food(rid, name, category, price, food_limit, isRemoved) values (20, 'Char Siew Rice', 'Mains', 9.00, 80, False);
-- insert into food(rid, name, category, price, food_limit, isRemoved) values (20, 'Meatballs Congee', 'Mains', 6.00, 80, False);
-- insert into food(rid, name, category, price, food_limit, isRemoved) values (20, 'Egg Minced Pork Congee', 'Mains', 7.00, 80, False);
-- insert into food(rid, name, category, price, food_limit, isRemoved) values (20, 'Duck Roasted w/ Angelica Herb', 'Mains', 18.00, 80, False);
-- insert into food(rid, name, category, price, food_limit, isRemoved) values (20, 'Sweet and Sour Pork', 'Sides', 13.00, 80, False);
-- insert into food(rid, name, category, price, food_limit, isRemoved) values (20, 'Braised Pork Belly', 'Sides', 17.00, 80, False);
-- insert into food(rid, name, category, price, food_limit, isRemoved) values (20, 'Kang Kong', 'Sides', 11.00, 80, False);
-- insert into food(rid, name, category, price, food_limit, isRemoved) values (20, 'Sauteed French Bean', 'Sides', 14.00, 80, False);
-- insert into food(rid, name, category, price, food_limit, isRemoved) values (20, 'Golden Lotus Root with Pumpkin', 'Sides', 14.00, 80, False);
-- insert into food(rid, name, category, price, food_limit, isRemoved) values (20, 'Chinese Spinach', 'Sides', 15.00, 80, False);
-- insert into food(rid, name, category, price, food_limit, isRemoved) values (20, 'Poached Spinach with Eggs', 'Sides', 16.00, 80, False);
-- insert into food(rid, name, category, price, food_limit, isRemoved) values (20, 'Silver Cod Fish in Soy Sauce', 'Sides', 30.00, 80, False);
-- insert into food(rid, name, category, price, food_limit, isRemoved) values (20, 'Prawn Balls with Mayo Sauce', 'Sides', 19.00, 80, False);
-- insert into food(rid, name, category, price, food_limit, isRemoved) values (20, 'Scrambled Eggs with Tomato', 'Sides', 9.00, 80, False);
-- insert into food(rid, name, category, price, food_limit, isRemoved) values (20, 'Crispy Golden Tofu', 'Sides', 15.00, 80, False);
-- insert into food(rid, name, category, price, food_limit, isRemoved) values (20, 'Mini Mantou', 'Sides', 4.00, 80, False);
-- insert into food(rid, name, category, price, food_limit, isRemoved) values (20, 'Homemade Iced Lemon Tea', 'Drinks', 3.00, 80, False);
-- insert into food(rid, name, category, price, food_limit, isRemoved) values (20, 'Lohan Guo with Longan', 'Drinks', 3.00, 80, False);
-- insert into food(rid, name, category, price, food_limit, isRemoved) values (21, 'Chicken Chow Mein', 'Mains', 6.00, 50, False);
-- insert into food(rid, name, category, price, food_limit, isRemoved) values (21, 'Roast Pork Chow Mein', 'Mains', 6.00, 50, False);
-- insert into food(rid, name, category, price, food_limit, isRemoved) values (21, 'Shrimp Chow Mein', 'Mains', 6.00, 50, False);
-- insert into food(rid, name, category, price, food_limit, isRemoved) values (21, 'Pepper Steak with Onion', 'Mains', 6.00, 50, False);
-- insert into food(rid, name, category, price, food_limit, isRemoved) values (21, 'Beef with Broccoli', 'Mains', 6.00, 50, False);
-- insert into food(rid, name, category, price, food_limit, isRemoved) values (21, 'Chicken with Broccoli', 'Mains', 6.00, 50, False);
-- insert into food(rid, name, category, price, food_limit, isRemoved) values (21, 'Shrimp with Chinese Vegetable', 'Mains', 6.00, 50, False);
-- insert into food(rid, name, category, price, food_limit, isRemoved) values (21, 'Chicken with Snow Peas', 'Mains', 6.00, 50, False);
-- insert into food(rid, name, category, price, food_limit, isRemoved) values (21, 'Sweet and Sour Chicken', 'Mains', 6.00, 50, False);
-- insert into food(rid, name, category, price, food_limit, isRemoved) values (21, 'Sweet and Sour Pork', 'Mains', 6.00, 50, False);
-- insert into food(rid, name, category, price, food_limit, isRemoved) values (21, 'General Tsos Chicken', 'Mains', 6.00, 50, False);
-- insert into food(rid, name, category, price, food_limit, isRemoved) values (21, 'Sesame Chicken', 'Mains', 6.00, 50, False);
-- insert into food(rid, name, category, price, food_limit, isRemoved) values (21, 'Szechuan Chicken', 'Mains', 6.00, 50, False);
-- insert into food(rid, name, category, price, food_limit, isRemoved) values (21, 'Kung Pao Chicken', 'Mains', 6.00, 50, False);
-- insert into food(rid, name, category, price, food_limit, isRemoved) values (22, 'Magherita Pizza', 'Pizza', 20.00, 50, False);
-- insert into food(rid, name, category, price, food_limit, isRemoved) values (22, 'Pepperoni Pizza', 'Pizza', 22.00, 50, False);
-- insert into food(rid, name, category, price, food_limit, isRemoved) values (22, 'Chicken Fajita Pizza', 'Pizza', 22.00, 50, False);
-- insert into food(rid, name, category, price, food_limit, isRemoved) values (22, 'Hawaiian Supreme', 'Pizza', 24.00, 50, False);
-- insert into food(rid, name, category, price, food_limit, isRemoved) values (22, 'BBQ Chicken Pizza', 'Pizza', 24.00, 50, False);
-- insert into food(rid, name, category, price, food_limit, isRemoved) values (22, 'Spinach and Ricotta Pizza', 'Pizza', 24.00, 50, False);
-- insert into food(rid, name, category, price, food_limit, isRemoved) values (22, 'Garden Delight Pizza', 'Pizza', 24.00, 50, False);
-- insert into food(rid, name, category, price, food_limit, isRemoved) values (22, 'New Yorker Pizza', 'Pizza', 24.00, 50, False);
-- insert into food(rid, name, category, price, food_limit, isRemoved) values (22, 'Italian Pizza', 'Pizza', 24.00, 50, False);
-- insert into food(rid, name, category, price, food_limit, isRemoved) values (22, 'Sensational Seafood Pizza', 'Pizza', 26.00, 50, False);
-- insert into food(rid, name, category, price, food_limit, isRemoved) values (22, 'Chicken Royale Pizza', 'Pizza', 26.00, 50, False);
-- insert into food(rid, name, category, price, food_limit, isRemoved) values (22, 'King\s Special Pizza', 'Pizza', 26.00, 50, False);
-- insert into food(rid, name, category, price, food_limit, isRemoved) values (22, 'The Fiery Extreme Pizza', 'Pizza', 26.00, 50, False);
-- insert into food(rid, name, category, price, food_limit, isRemoved) values (22, 'Bolognese Linguine', 'Mains', 13.00, 50, False);
-- insert into food(rid, name, category, price, food_limit, isRemoved) values (22, 'Meatball Linguine', 'Mains', 15.00, 50, False);
-- insert into food(rid, name, category, price, food_limit, isRemoved) values (22, 'Carbonara Linguine', 'Mains', 11.00, 50, False);
-- insert into food(rid, name, category, price, food_limit, isRemoved) values (22, 'Lasagna', 'Mains', 17.00, 50, False);
-- insert into food(rid, name, category, price, food_limit, isRemoved) values (22, 'Seafood Carbonara', 'Mains', 17.00, 50, False);
-- insert into food(rid, name, category, price, food_limit, isRemoved) values (22, 'Thai Curry Baked Rice', 'Mains', 15.00, 50, False);
-- insert into food(rid, name, category, price, food_limit, isRemoved) values (22, 'Potato Wedges', 'Sides', 7.00, 80, False);
-- insert into food(rid, name, category, price, food_limit, isRemoved) values (22, 'Truffle Fries', 'Sides', 7.00, 80, False);
-- insert into food(rid, name, category, price, food_limit, isRemoved) values (22, 'Calamari', 'Sides', 7.00, 80, False);
-- insert into food(rid, name, category, price, food_limit, isRemoved) values (22, 'Baked Meatballs', 'Sides', 7.00, 80, False);
-- insert into food(rid, name, category, price, food_limit, isRemoved) values (22, 'Fish Fingers', 'Sides', 7.00, 80, False);
-- insert into food(rid, name, category, price, food_limit, isRemoved) values (22, 'Root Beer', 'Drinks', 4.00, 80, False);
-- insert into food(rid, name, category, price, food_limit, isRemoved) values (22, 'Iced Lemon Tea', 'Drinks', 4.00, 80, False);
-- insert into food(rid, name, category, price, food_limit, isRemoved) values (23, 'Traditional Pizza', 'Pizza', 8.00, 50, False);
-- insert into food(rid, name, category, price, food_limit, isRemoved) values (23, 'White Pizza', 'Pizza', 8.00, 50, False);
-- insert into food(rid, name, category, price, food_limit, isRemoved) values (23, 'Spaghetti and Meatballs', 'Mains', 7.00, 50, False);
-- insert into food(rid, name, category, price, food_limit, isRemoved) values (23, 'Fettucine Alfredo', 'Mains', 7.00, 50, False);
-- insert into food(rid, name, category, price, food_limit, isRemoved) values (23, 'Manicotti', 'Mains', 7.00, 50, False);
-- insert into food(rid, name, category, price, food_limit, isRemoved) values (23, 'Lasagna', 'Mains', 7.00, 50, False);
-- insert into food(rid, name, category, price, food_limit, isRemoved) values (23, 'Primavera Panini', 'Mains', 6.00, 50, False);
-- insert into food(rid, name, category, price, food_limit, isRemoved) values (23, 'Grilled Chicken Panini', 'Mains', 7.00, 50, False);
-- insert into food(rid, name, category, price, food_limit, isRemoved) values (23, 'Chicken Italiano', 'Mains', 8.00, 50, False);
-- insert into food(rid, name, category, price, food_limit, isRemoved) values (23, 'Parmesan Chicken', 'Mains', 8.00, 50, False);
-- insert into food(rid, name, category, price, food_limit, isRemoved) values (23, 'Sausage and Peppers Panini', 'Mains', 7.00, 50, False);
-- insert into food(rid, name, category, price, food_limit, isRemoved) values (23, 'Tiramisu', 'Desserts', 6.00, 50, False);
-- insert into food(rid, name, category, price, food_limit, isRemoved) values (23, 'Cannoli', 'Desserts', 6.00, 50, False);
-- insert into food(rid, name, category, price, food_limit, isRemoved) values (23, 'New York Cheesecake', 'Desserts', 6.00, 50, False);
-- insert into food(rid, name, category, price, food_limit, isRemoved) values (23, 'Creme Brulee', 'Desserts', 4.00, 50, False);
-- insert into food(rid, name, category, price, food_limit, isRemoved) values (23, 'Raspberry Spongecake', 'Desserts', 4.00, 50, False);
-- insert into food(rid, name, category, price, food_limit, isRemoved) values (24, 'Hainan Chicken, Half', 'Mains', 20.00, 50, False);
-- insert into food(rid, name, category, price, food_limit, isRemoved) values (24, 'Bak Kut Teh', 'Mains', 15.00, 50, False);
-- insert into food(rid, name, category, price, food_limit, isRemoved) values (24, 'Teochew Mixed Platter', 'Mains', 24.00, 50, False);
-- insert into food(rid, name, category, price, food_limit, isRemoved) values (24, 'Yam Pork', 'Mains', 20.00, 50, False);
-- insert into food(rid, name, category, price, food_limit, isRemoved) values (25, 'Hainanese Chicken Rice', 'Mains', 13.00, 50, False);
-- insert into food(rid, name, category, price, food_limit, isRemoved) values (25, 'Chicken Laksa', 'Mains', 12.50, 50, False);
-- insert into food(rid, name, category, price, food_limit, isRemoved) values (25, 'Nasi Goreng', 'Mains', 13.00, 50, False);
-- insert into food(rid, name, category, price, food_limit, isRemoved) values (25, 'Chicken Noodle Salad', 'Mains', 12.00, 50, False);
-- insert into food(rid, name, category, price, food_limit, isRemoved) values (25, 'Bean Curd Laksa', 'Mains', 12.00, 50, False);
-- insert into food(rid, name, category, price, food_limit, isRemoved) values (25, 'Fried Chicken Laksa', 'Mains', 15.00, 50, False);
-- insert into food(rid, name, category, price, food_limit, isRemoved) values (25, 'King Prawn Laksa', 'Mains', 14.50, 50, False);
-- insert into food(rid, name, category, price, food_limit, isRemoved) values (25, 'Red Curry Chicken Rice', 'Mains', 14.00, 50, False);
-- insert into food(rid, name, category, price, food_limit, isRemoved) values (25, 'Nasi Lemak Curry', 'Mains', 15.00, 50, False);
-- insert into food(rid, name, category, price, food_limit, isRemoved) values (25, 'Char Kway Teow', 'Mains', 15.00, 50, False);
-- insert into food(rid, name, category, price, food_limit, isRemoved) values (25, 'Mee Goreng', 'Mains', 14.00, 50, False);
-- insert into food(rid, name, category, price, food_limit, isRemoved) values (25, 'Mee Siam Goreng', 'Mains', 14.00, 50, False);
-- insert into food(rid, name, category, price, food_limit, isRemoved) values (25, 'Prawn Fried Noodles', 'Mains', 15.00, 50, False);
-- insert into food(rid, name, category, price, food_limit, isRemoved) values (25, 'Vegetable Curry Rice', 'Mains', 12.50, 50, False);
>>>>>>> origin/master

-- --Orders
--Customer uid: 1 to 401; pid: 1 to 29
-- FID: (1)1 - 16 (2)17 - 38 (3)39 - 51 (4)52 - 63 (5)64 - 85; (6)86 - 95 (7)96 - 112 (8)113 - 129
--(9)130 - 157 (10)158 - 174 (11)175 - 192 (12)193 - 201 (13)202 - 218 (14)219 - 224 (15)225 - 243
--(16)244 - 255 (17)256 - 264 (18)265 - 278 (19)279 - 299 (20)300 - 321 (21)322 - 335 (22)336 - 361
--(23)362 - 377 (24)378 - 381 (25)382 - 395
insert into Orders(uid, location, order_time, payment_type, used_points) values (1, '3 Ronald Regan Street', '2020-04-20 10:03:00', 1, 0);
insert into FoodOrders(fid, oid, qty) values (1, 1, 2);
insert into FoodOrders(fid, oid, qty) values (4, 1, 2);
insert into FoodOrders(fid, oid, qty) values (15, 1, 2);
insert into Orders(uid, location, order_time, payment_type, used_points) values (4, '97550 Kipling Avenue', '2020-04-20 10:17:00', 0, 0);
insert into FoodOrders(fid, oid, qty) values (265, 2, 5);
insert into FoodOrders(fid, oid, qty) values (271, 2, 4);
insert into FoodOrders(fid, oid, qty) values (276, 2, 3);
insert into FoodOrders(fid, oid, qty) values (278, 2, 4);
insert into Orders(uid, location, order_time, payment_type, used_points) values (36, '349 Montana Point', '2020-04-20 10:28:00', 0, 0);
insert into FoodOrders(fid, oid, qty) values (178, 3, 2);
insert into FoodOrders(fid, oid, qty) values (188, 3, 1);
insert into Orders(uid, location, order_time, payment_type, used_points) values (64, '542 Northridge Center', '2020-04-20 10:39:00', 0, 0);
insert into FoodOrders(fid, oid, qty) values (86, 4, 2);
insert into FoodOrders(fid, oid, qty) values (88, 4, 1);
insert into FoodOrders(fid, oid, qty) values (90, 4, 1);
insert into FoodOrders(fid, oid, qty) values (92, 4, 1);
insert into FoodOrders(fid, oid, qty) values (95, 4, 3);
insert into Orders(uid, location, order_time, payment_type, used_points) values (157, '84379 Brown Plaza', '2020-04-20 10:51:00', 1, 0);
insert into FoodOrders(fid, oid, qty) values (18, 5, 5);
insert into FoodOrders(fid, oid, qty) values (22, 5, 5);
insert into Orders(uid, location, order_time, payment_type, used_points) values (201, '4 Fairfield Street', '2020-04-20 11:40:00', 1, 0);
insert into FoodOrders(fid, oid, qty) values (65, 6, 3);
insert into FoodOrders(fid, oid, qty) values (66, 6, 1);
insert into FoodOrders(fid, oid, qty) values (82, 6, 1);
insert into FoodOrders(fid, oid, qty) values (85, 6, 2);
insert into Orders(uid, location, order_time, payment_type, used_points) values (208, '3 Crownhardt Place', '2020-04-20 12:30:00', 1, 0);
insert into FoodOrders(fid, oid, qty) values (322, 7, 3);
insert into FoodOrders(fid, oid, qty) values (323, 7, 2);
insert into FoodOrders(fid, oid, qty) values (326, 7, 2);
insert into FoodOrders(fid, oid, qty) values (330, 7, 2);
insert into FoodOrders(fid, oid, qty) values (334, 7, 1);
insert into Orders(uid, location, order_time, payment_type, used_points) values (280, '74 Rowland Hill', '2020-04-20 13:11:00', 1, 0);
insert into FoodOrders(fid, oid, qty) values (245, 8, 4);
insert into Orders(uid, location, order_time, payment_type, used_points) values (32, '29827 Fuller Trail', '2020-04-20 14:42:00', 1, 0);
insert into FoodOrders(fid, oid, qty) values (40, 9, 3);
insert into FoodOrders(fid, oid, qty) values (43, 9, 2);
insert into FoodOrders(fid, oid, qty) values (45, 9, 2);
insert into FoodOrders(fid, oid, qty) values (51, 9, 3);
insert into Orders(uid, location, order_time, payment_type, used_points) values (78, '974 Maple Circle', '2020-04-20 15:36:00', 1, 0);
insert into FoodOrders(fid, oid, qty) values (131, 10, 2);
insert into FoodOrders(fid, oid, qty) values (150, 10, 3);
insert into Orders(uid, location, order_time, payment_type, used_points) values (101, '135 Lighthouse Bay Parkway', '2020-04-20 18:21:00', 1, 0);
insert into FoodOrders(fid, oid, qty) values (158, 11, 2);
insert into FoodOrders(fid, oid, qty) values (160, 11, 1);
insert into FoodOrders(fid, oid, qty) values (165, 11, 1);
insert into FoodOrders(fid, oid, qty) values (169, 11, 2);
insert into Orders(uid, location, order_time, payment_type, used_points) values (134, '950 Buell Road', '2020-04-20 20:59:00', 0, 0);
insert into FoodOrders(fid, oid, qty) values (219, 12, 4);
insert into Orders(uid, location, order_time, payment_type, used_points) values (162, '04 Evergreen Center', '2020-04-21 10:38:00', 0, 0);
insert into FoodOrders(fid, oid, qty) values (114, 13, 3);
insert into FoodOrders(fid, oid, qty) values (124, 13, 1);
insert into FoodOrders(fid, oid, qty) values (128, 13, 3);
insert into Orders(uid, location, order_time, payment_type, used_points) values (199, '70 Becker Way', '2020-04-21 12:49:00', 1, 0);
insert into FoodOrders(fid, oid, qty) values (267, 14, 3);
insert into FoodOrders(fid, oid, qty) values (268, 14, 2);
insert into FoodOrders(fid, oid, qty) values (271, 14, 2);
insert into FoodOrders(fid, oid, qty) values (272, 14, 2);
insert into FoodOrders(fid, oid, qty) values (275, 14, 3);
insert into FoodOrders(fid, oid, qty) values (278, 14, 2);
insert into Orders(uid, location, order_time, payment_type, used_points) values (225, '8137 Katie Street', '2020-04-21 15:32:00', 0, 0);
insert into FoodOrders(fid, oid, qty) values (336, 15, 2);
insert into Orders(uid, location, order_time, payment_type, used_points) values (264, '19918 Mitchell Lane', '2020-04-21 17:03:00', 0, 0);
insert into FoodOrders(fid, oid, qty) values (194, 16, 3);
insert into FoodOrders(fid, oid, qty) values (196, 16, 1);
insert into FoodOrders(fid, oid, qty) values (200, 16, 2);
insert into Orders(uid, location, order_time, payment_type, used_points) values (297, '5 Ridgeway Trail', '2020-04-21 18:22:00', 0, 0);
insert into FoodOrders(fid, oid, qty) values (39, 17, 8);
insert into Orders(uid, location, order_time, payment_type, used_points) values (361, '74559 Waubesa Avenue', '2020-04-21 21:02:00', 0, 0);
insert into FoodOrders(fid, oid, qty) values (55, 18, 3);
insert into Orders(uid, location, order_time, payment_type, used_points) values (362, '45688 Golf Course Pass', '2020-04-22 11:05:00', 0, 0);
insert into FoodOrders(fid, oid, qty) values (4, 19, 1);
insert into FoodOrders(fid, oid, qty) values (6, 19, 2);
insert into FoodOrders(fid, oid, qty) values (11, 19, 3);
insert into Orders(uid, location, order_time, payment_type, used_points) values (26, '4034 Knutson Point', '2020-04-22 13:11:00', 0, 0);
insert into FoodOrders(fid, oid, qty) values (378, 20, 3);
insert into FoodOrders(fid, oid, qty) values (380, 20, 1);
insert into Orders(uid, location, order_time, payment_type, used_points) values (14, '57 Waywood Drive', '2020-04-22 15:02:00', 1, 0);
insert into FoodOrders(fid, oid, qty) values (66, 21, 2);
insert into FoodOrders(fid, oid, qty) values (68, 21, 1);
insert into FoodOrders(fid, oid, qty) values (71, 21, 1);
insert into FoodOrders(fid, oid, qty) values (79, 21, 1);
insert into Orders(uid, location, order_time, payment_type, used_points) values (189, '6 Cascade Crossing', '2020-04-22 16:06:00', 0, 0);
insert into FoodOrders(fid, oid, qty) values (301, 22, 2);
insert into FoodOrders(fid, oid, qty) values (302, 22, 1);
insert into Orders(uid, location, order_time, payment_type, used_points) values (271, '4973 Hansons Junction', '2020-04-22 20:06:00', 1, 0);
insert into FoodOrders(fid, oid, qty) values (230, 23, 6);
insert into FoodOrders(fid, oid, qty) values (233, 23, 5);
insert into FoodOrders(fid, oid, qty) values (242, 23, 4);
insert into Orders(uid, location, order_time, payment_type, used_points) values (85, '885 Sunnyside Trail', '2020-04-22 20:49:00', 0, 0);
insert into FoodOrders(fid, oid, qty) values (382, 24, 2);
insert into FoodOrders(fid, oid, qty) values (384, 24, 1);
insert into FoodOrders(fid, oid, qty) values (387, 24, 2);
insert into FoodOrders(fid, oid, qty) values (392, 24, 1);
insert into Orders(uid, location, order_time, payment_type, used_points) values (188, '8699 Nevada Crossing', '2020-04-23 10:54:00', 1, 0);
insert into FoodOrders(fid, oid, qty) values (86, 25, 4);
insert into Orders(uid, location, order_time, payment_type, used_points) values (126, '078 John Wall Way', '2020-04-23 12:03:00', 0, 0);
insert into FoodOrders(fid, oid, qty) values (28, 26, 3);
insert into FoodOrders(fid, oid, qty) values (30, 26, 1);
insert into Orders(uid, location, order_time, payment_type, used_points) values (277, '01 Prairie Rose Pass', '2020-04-23 15:21:00', 1, 0);
insert into FoodOrders(fid, oid, qty) values (219, 27, 2);
insert into FoodOrders(fid, oid, qty) values (220, 27, 3);
insert into Orders(uid, location, order_time, payment_type, used_points) values (160, '52590 Sunbrook Parkway', '2020-04-23 17:40:00', 1, 0);
insert into FoodOrders(fid, oid, qty) values (99, 28, 2);
insert into FoodOrders(fid, oid, qty) values (101, 28, 1);
insert into FoodOrders(fid, oid, qty) values (102, 28, 1);
insert into Orders(uid, location, order_time, payment_type, used_points) values (375, '36888 Summit Avenue', '2020-04-23 19:33:00', 0, 0);
insert into FoodOrders(fid, oid, qty) values (322, 29, 4);
insert into FoodOrders(fid, oid, qty) values (327, 29, 4);
insert into Orders(uid, location, order_time, payment_type, used_points) values (98, '6 Doe Crossing Terrace', '2020-04-23 20:41:00', 1, 0);
insert into FoodOrders(fid, oid, qty) values (300, 30, 3);
insert into Orders(uid, location, order_time, payment_type, used_points) values (1, '4749 Benson Park Drive', '2020-04-24 11:13:00', 1, 0);
insert into FoodOrders(fid, oid, qty) values (300, 31, 2);
insert into FoodOrders(fid, oid, qty) values (301, 31, 1);
insert into FoodOrders(fid, oid, qty) values (303, 31, 1);
insert into FoodOrders(fid, oid, qty) values (306, 31, 2);
insert into FoodOrders(fid, oid, qty) values (316, 31, 2);
insert into Orders(uid, location, order_time, payment_type, used_points) values (324, '6566 Prentice Avenue', '2020-04-24 13:13:00', 0, 0);
insert into FoodOrders(fid, oid, qty) values (368, 32, 4);
insert into FoodOrders(fid, oid, qty) values (374, 32, 4);
insert into Orders(uid, location, order_time, payment_type, used_points) values (130, '881 Ilene Parkway', '2020-04-24 15:54:00', 1, 0);
insert into FoodOrders(fid, oid, qty) values (205, 33, 4);
insert into FoodOrders(fid, oid, qty) values (208, 33, 3);
insert into FoodOrders(fid, oid, qty) values (215, 33, 3);
insert into Orders(uid, location, order_time, payment_type, used_points) values (288, '0 Blaine Court', '2020-04-24 16:36:00', 1, 0);
insert into FoodOrders(fid, oid, qty) values (327, 34, 4);
insert into FoodOrders(fid, oid, qty) values (330, 34, 3);
insert into FoodOrders(fid, oid, qty) values (335, 34, 4);
insert into Orders(uid, location, order_time, payment_type, used_points) values (139, '50 Buhler Drive', '2020-04-24 18:22:00', 1, 0);
insert into FoodOrders(fid, oid, qty) values (131, 35, 3);
insert into FoodOrders(fid, oid, qty) values (133, 35, 2);
insert into FoodOrders(fid, oid, qty) values (142, 35, 1);
insert into FoodOrders(fid, oid, qty) values (146, 35, 2);
insert into FoodOrders(fid, oid, qty) values (154, 35, 4);
insert into Orders(uid, location, order_time, payment_type, used_points) values (123, '798 Menomonie Parkway', '2020-04-24 21:25:00', 0, 0);
insert into FoodOrders(fid, oid, qty) values (18, 36, 6);
insert into Orders(uid, location, order_time, payment_type, used_points) values (286, '45 Michigan Court', '2020-04-25 10:43:00', 0, 0);
insert into FoodOrders(fid, oid, qty) values (234, 37, 4);
insert into FoodOrders(fid, oid, qty) values (239, 37, 4);
insert into Orders(uid, location, order_time, payment_type, used_points) values (269, '22 8th Court', '2020-04-25 14:12:00', 1, 0);
insert into FoodOrders(fid, oid, qty) values (210, 38, 5);
insert into Orders(uid, location, order_time, payment_type, used_points) values (157, '84379 Brown Plaza', '2020-04-25 17:33:00', 1, 0);
insert into FoodOrders(fid, oid, qty) values (337, 39, 2);
insert into FoodOrders(fid, oid, qty) values (338, 39, 3);
insert into FoodOrders(fid, oid, qty) values (345, 39, 2);
insert into FoodOrders(fid, oid, qty) values (350, 39, 3);
insert into Orders(uid, location, order_time, payment_type, used_points) values (76, '51949 Ryan Pass', '2020-04-25 19:58:00', 1, 0);
insert into FoodOrders(fid, oid, qty) values (52, 40, 2);
insert into FoodOrders(fid, oid, qty) values (55, 40, 2);
insert into Orders(uid, location, order_time, payment_type, used_points) values (55, '5222 Homewood Point', '2020-04-26 11:32:00', 0, 0);
insert into FoodOrders(fid, oid, qty) values (237, 41, 5);
insert into FoodOrders(fid, oid, qty) values (243, 41, 4);
insert into Orders(uid, location, order_time, payment_type, used_points) values (111, '67 Lakewood Way', '2020-04-26 15:11:00', 0, 0);
insert into FoodOrders(fid, oid, qty) values (141, 42, 4);
insert into FoodOrders(fid, oid, qty) values (145, 42, 5);
insert into FoodOrders(fid, oid, qty) values (152, 42, 5);
insert into Orders(uid, location, order_time, payment_type, used_points) values (233, '8060 Stephen Park', '2020-04-26 18:22:00', 1, 0);
insert into FoodOrders(fid, oid, qty) values (245, 43, 4);
insert into FoodOrders(fid, oid, qty) values (248, 43, 3);
insert into Orders(uid, location, order_time, payment_type, used_points) values (4, '97550 Kipling Avenue', '2020-04-26 20:03:00', 0, 0);
insert into FoodOrders(fid, oid, qty) values (3, 44, 3);
insert into FoodOrders(fid, oid, qty) values (5, 44, 3);
insert into FoodOrders(fid, oid, qty) values (10, 44, 3);
insert into FoodOrders(fid, oid, qty) values (13, 44, 2);
insert into Orders(uid, location, order_time, payment_type, used_points) values (366, '652 Novick Avenue', '2020-04-27 10:58:00', 0, 0);
insert into FoodOrders(fid, oid, qty) values (312, 45, 3);
insert into FoodOrders(fid, oid, qty) values (320, 45, 1);
insert into Orders(uid, location, order_time, payment_type, used_points) values (294, '8 Butterfield Crossing', '2020-04-27 16:27:00', 0, 0);
insert into FoodOrders(fid, oid, qty) values (222, 46, 2);
insert into FoodOrders(fid, oid, qty) values (224, 46, 3);
insert into Orders(uid, location, order_time, payment_type, used_points) values (243, '496 Portage Trail', '2020-04-27 17:25:00', 1, 0);
insert into FoodOrders(fid, oid, qty) values (329, 47, 5);
insert into FoodOrders(fid, oid, qty) values (333, 47, 3);
insert into Orders(uid, location, order_time, payment_type, used_points) values (269, '22 8th Court', '2020-04-27 21:31:00', 1, 0);
insert into FoodOrders(fid, oid, qty) values (86, 48, 3);
insert into FoodOrders(fid, oid, qty) values (89, 48, 2);
insert into FoodOrders(fid, oid, qty) values (90, 48, 1);
insert into FoodOrders(fid, oid, qty) values (94, 48, 2);
insert into Orders(uid, location, order_time, payment_type, used_points) values (381, '21 Welch Avenue', '2020-04-28 10:42:00', 0, 0);
insert into FoodOrders(fid, oid, qty) values (39, 49, 3);
insert into FoodOrders(fid, oid, qty) values (42, 49, 4);
insert into FoodOrders(fid, oid, qty) values (49, 49, 3);
insert into Orders(uid, location, order_time, payment_type, used_points) values (349, '23758 Northview Pass', '2020-04-28 13:33:00', 0, 0);
insert into FoodOrders(fid, oid, qty) values (305, 50, 2);
insert into FoodOrders(fid, oid, qty) values (318, 50, 1);
insert into Orders(uid, location, order_time, payment_type, used_points) values (398, '4 Canary Street', '2020-04-28 16:20:00', 0, 0);
insert into FoodOrders(fid, oid, qty) values (67, 51, 4);
insert into Orders(uid, location, order_time, payment_type, used_points) values (266, '47312 Bartelt Pass', '2020-04-28 18:11:00', 0, 0);
insert into FoodOrders(fid, oid, qty) values (219, 52, 2);
insert into Orders(uid, location, order_time, payment_type, used_points) values (130, '881 Ilene Parkway', '2020-04-28 19:37:00', 1, 0);
insert into FoodOrders(fid, oid, qty) values (176, 53, 2);
insert into FoodOrders(fid, oid, qty) values (177, 53, 2);
insert into FoodOrders(fid, oid, qty) values (187, 53, 1);
insert into Orders(uid, location, order_time, payment_type, used_points) values (205, '026 Bonner Hill', '2020-04-28 20:11:00', 0, 0);
insert into FoodOrders(fid, oid, qty) values (20, 54, 2);
insert into FoodOrders(fid, oid, qty) values (23, 54, 2);
insert into FoodOrders(fid, oid, qty) values (25, 54, 3);
insert into FoodOrders(fid, oid, qty) values (26, 54, 2);
insert into FoodOrders(fid, oid, qty) values (33, 54, 4);
insert into Orders(uid, location, order_time, payment_type, used_points) values (69, '32 Tennyson Court', '2020-04-28 21:02:00', 1, 0);
insert into FoodOrders(fid, oid, qty) values (244, 55, 4);
insert into FoodOrders(fid, oid, qty) values (248, 55, 3);
insert into FoodOrders(fid, oid, qty) values (253, 55, 3);
insert into Orders(uid, location, order_time, payment_type, used_points) values (262, '7214 Old Gate Drive', '2020-04-29 11:11:00', 1, 0);
insert into FoodOrders(fid, oid, qty) values (1, 56, 1);
insert into FoodOrders(fid, oid, qty) values (2, 56, 1);
insert into FoodOrders(fid, oid, qty) values (3, 56, 1);
insert into FoodOrders(fid, oid, qty) values (6, 56, 1);
insert into Orders(uid, location, order_time, payment_type, used_points) values (170, '78 Dottie Avenue', '2020-04-29 12:51:00', 1, 0);
insert into FoodOrders(fid, oid, qty) values (308, 57, 2);
insert into FoodOrders(fid, oid, qty) values (311, 57, 1);
insert into FoodOrders(fid, oid, qty) values (318, 57, 1);
insert into Orders(uid, location, order_time, payment_type, used_points) values (209, '688 Coolidge Place', '2020-04-29 15:07:00', 0, 0);
insert into FoodOrders(fid, oid, qty) values (88, 58, 2);
insert into FoodOrders(fid, oid, qty) values (92, 58, 3);
insert into Orders(uid, location, order_time, payment_type, used_points) values (325, '495 Buhler Center', '2020-04-29 17:19:00', 0, 0);
insert into FoodOrders(fid, oid, qty) values (41, 59, 4);
insert into FoodOrders(fid, oid, qty) values (42, 59, 3);
insert into FoodOrders(fid, oid, qty) values (49, 59, 3);
insert into Orders(uid, location, order_time, payment_type, used_points) values (110, '570 Monica Drive', '2020-04-29 19:24:00', 0, 0);
insert into FoodOrders(fid, oid, qty) values (304, 60, 3);
insert into FoodOrders(fid, oid, qty) values (306, 60, 2);
insert into Orders(uid, location, order_time, payment_type, used_points) values (152, '56191 Burning Wood Pass', '2020-04-30 11:43:00', 0, 0);
insert into FoodOrders(fid, oid, qty) values (66, 61, 5);
insert into Orders(uid, location, order_time, payment_type, used_points) values (267, '1337 Farmco Parkway', '2020-04-30 12:54:00', 1, 0);
insert into FoodOrders(fid, oid, qty) values (222, 62, 2);
insert into FoodOrders(fid, oid, qty) values (223, 62, 2);
insert into FoodOrders(fid, oid, qty) values (224, 62, 1);
insert into Orders(uid, location, order_time, payment_type, used_points) values (5, '04809 5th Road', '2020-04-30 13:46:00', 0, 0);
insert into FoodOrders(fid, oid, qty) values (176, 63, 2);
insert into FoodOrders(fid, oid, qty) values (177, 63, 2);
insert into Orders(uid, location, order_time, payment_type, used_points) values (45, '1 Westport Point', '2020-04-30 17:53:00', 0, 0);
insert into FoodOrders(fid, oid, qty) values (18, 64, 5);
insert into FoodOrders(fid, oid, qty) values (19, 64, 5);
insert into FoodOrders(fid, oid, qty) values (20, 64, 10);
insert into FoodOrders(fid, oid, qty) values (30, 64, )5;
insert into Orders(uid, location, order_time, payment_type, used_points) values (299, '3876 Blackbird Point', '2020-04-30 18:33:00', 0, 0);
insert into FoodOrders(fid, oid, qty) values (244, 65, 5);
insert into FoodOrders(fid, oid, qty) values (250, 65, 4);
insert into Orders(uid, location, order_time, payment_type, used_points) values (257, '9825 Larry Terrace', '2020-04-30 19:49:00', 0, 0);
insert into FoodOrders(fid, oid, qty) values (383, 66, 2);
insert into FoodOrders(fid, oid, qty) values (389, 66, 3);
insert into Orders(uid, location, order_time, payment_type, used_points) values (1, '3941 Saints Alley', '2020-05-01 10:00:00', 1, 0);
insert into FoodOrders(fid, oid, qty) values (380, 67, 5);
insert into Orders(uid, location, order_time, payment_type, used_points) values (246, '84 Welch Terrace', '2020-05-01 10:10:00', 0, 0);
insert into FoodOrders(fid, oid, qty) values (256, 68, 5);
insert into FoodOrders(fid, oid, qty) values (258, 68, 4);
insert into FoodOrders(fid, oid, qty) values (259, 68, 4);
insert into FoodOrders(fid, oid, qty) values (262, 68, 3);
insert into Orders(uid, location, order_time, payment_type, used_points) values (108, '48 Artisan Circle', '2020-05-01 11:46:00', 1, 0);
insert into FoodOrders(fid, oid, qty) values (116, 69, 5);
insert into FoodOrders(fid, oid, qty) values (118, 69, 3);
insert into FoodOrders(fid, oid, qty) values (120, 69, 3);
insert into Orders(uid, location, order_time, payment_type, used_points) values (18, '181 Bowman Street', '2020-05-01 12:00:00', 1, 0);
insert into FoodOrders(fid, oid, qty) values (378, 70, 3);
insert into FoodOrders(fid, oid, qty) values (380, 70, 1);
insert into FoodOrders(fid, oid, qty) values (381, 70, 2);
insert into Orders(uid, location, order_time, payment_type, used_points) values (208, '3 Crownhardt Place', '2020-05-01 12:31:00', 1, 0);
insert into FoodOrders(fid, oid, qty) values (159, 71, 4);
insert into FoodOrders(fid, oid, qty) values (167, 71, 6);
insert into Orders(uid, location, order_time, payment_type, used_points) values (122, '53821 Lunder Point', '2020-05-01 17:39:00', 0, 0);
insert into FoodOrders(fid, oid, qty) values (382, 72, 2);
insert into FoodOrders(fid, oid, qty) values (386, 72, 2);
insert into FoodOrders(fid, oid, qty) values (394, 72, 1);
insert into FoodOrders(fid, oid, qty) values (395, 72, 1);
insert into Orders(uid, location, order_time, payment_type, used_points) values (63, '06314 Buhler Place', '2020-05-01 18:58:00', 0, 0);
insert into FoodOrders(fid, oid, qty) values (194, 73, 3);
insert into FoodOrders(fid, oid, qty) values (200, 73, 2);
insert into Orders(uid, location, order_time, payment_type, used_points) values (367, '441 Carioca Lane', '2020-05-02 10:46:00', 0, 0);
insert into FoodOrders(fid, oid, qty) values (246, 74, 8);
insert into Orders(uid, location, order_time, payment_type, used_points) values (400, '8 Hanson Place', '2020-05-02 11:35:00', 1, 0);
insert into FoodOrders(fid, oid, qty) values (246, 75, 5);
insert into FoodOrders(fid, oid, qty) values (249, 75, 6);
insert into FoodOrders(fid, oid, qty) values (252, 75, 6);
insert into Orders(uid, location, order_time, payment_type, used_points) values (144, '58484 Bunting Terrace', '2020-05-02 12:18:00', 0, 0);
insert into FoodOrders(fid, oid, qty) values (256, 76, 5);
insert into FoodOrders(fid, oid, qty) values (260, 76, 7);
insert into Orders(uid, location, order_time, payment_type, used_points) values (274, '548 Lukken Pass', '2020-05-02 12:34:00', 1, 0);
insert into FoodOrders(fid, oid, qty) values (113, 77, 4);
insert into FoodOrders(fid, oid, qty) values (120, 77, 3);
insert into FoodOrders(fid, oid, qty) values (122, 77, 2);
insert into FoodOrders(fid, oid, qty) values (125, 77, 4);
insert into Orders(uid, location, order_time, payment_type, used_points) values (399, '8 Thompson Way', '2020-05-02 14:30:00', 1, 0);
insert into FoodOrders(fid, oid, qty) values (131, 78, 5);
insert into FoodOrders(fid, oid, qty) values (137, 78, 4);
insert into Orders(uid, location, order_time, payment_type, used_points) values (215, '7758 Pleasure Hill', '2020-05-02 18:33:00', 1, 0);
insert into FoodOrders(fid, oid, qty) values (219, 79, 1);
insert into FoodOrders(fid, oid, qty) values (220, 79, 2);
insert into FoodOrders(fid, oid, qty) values (223, 79, 2);
insert into Orders(uid, location, order_time, payment_type, used_points) values (157, '84379 Brown Plaza', '2020-05-02 20:32:00', 1, 0);
insert into FoodOrders(fid, oid, qty) values (144, 80, 4);
insert into FoodOrders(fid, oid, qty) values (145, 80, 3);
insert into FoodOrders(fid, oid, qty) values (149, 80, 4);
insert into Orders(uid, location, order_time, payment_type, used_points) values (316, '82 Artisan Circle', '2020-05-03 10:20:00', 1, 0);
insert into FoodOrders(fid, oid, qty) values (88, 81, 6);
insert into Orders(uid, location, order_time, payment_type, used_points) values (73, '860 Shelley Road', '2020-05-03 11:21:00', 0, 0);
insert into FoodOrders(fid, oid, qty) values (310, 82, 3);
insert into FoodOrders(fid, oid, qty) values (320, 82, 3);
insert into Orders(uid, location, order_time, payment_type, used_points) values (121, '7349 Havey Avenue', '2020-05-03 12:03:00', 0, 0);
insert into FoodOrders(fid, oid, qty) values (141, 83, 4);
insert into FoodOrders(fid, oid, qty) values (142, 83, 3);
insert into FoodOrders(fid, oid, qty) values (150, 83, 4);
insert into FoodOrders(fid, oid, qty) values (157, 83, 4);
insert into Orders(uid, location, order_time, payment_type, used_points) values (1, '1621 Elkview Drive', '2020-05-03 12:54:00', 1, 0);
insert into FoodOrders(fid, oid, qty) values (228, 84, 4);
insert into FoodOrders(fid, oid, qty) values (238, 84, 4);
insert into FoodOrders(fid, oid, qty) values (242, 84, 3);
insert into Orders(uid, location, order_time, payment_type, used_points) values (3, '05 Russell Avenue', '2020-05-03 15:30:00', 0, 0);
insert into FoodOrders(fid, oid, qty) values (382, 85, 2);
insert into FoodOrders(fid, oid, qty) values (390, 85, 3);
insert into Orders(uid, location, order_time, payment_type, used_points) values (349, '23758 Northview Pass', '2020-05-03 17:29:00', 0, 0);
insert into FoodOrders(fid, oid, qty) values (159, 86, 6);
insert into Orders(uid, location, order_time, payment_type, used_points) values (247, '543 Lunder Lane', '2020-05-03 19:12:00', 0, 0);
insert into FoodOrders(fid, oid, qty) values (368, 87, 5);
insert into FoodOrders(fid, oid, qty) values (372, 87, 3);
insert into FoodOrders(fid, oid, qty) values (377, 87, 3);
insert into Orders(uid, location, order_time, payment_type, used_points) values (113, '60955 Summer Ridge Circle', '2020-05-03 21:03:00', 0, 0);
insert into FoodOrders(fid, oid, qty) values (53, 88, 2);
insert into FoodOrders(fid, oid, qty) values (56, 88, 3);
insert into Orders(uid, location, order_time, payment_type, used_points) values (195, '572 Novick Park', '2020-05-04 11:40:00', 0, 0);
insert into FoodOrders(fid, oid, qty) values (228, 89, 5);
insert into FoodOrders(fid, oid, qty) values (239, 89, 7);
insert into Orders(uid, location, order_time, payment_type, used_points) values (42, '27 Lake View Drive', '2020-05-04 13:25:00', 1, 0);
insert into FoodOrders(fid, oid, qty) values (256, 90, 6);
insert into FoodOrders(fid, oid, qty) values (258, 90, 5);
insert into FoodOrders(fid, oid, qty) values (259, 90, 3);
insert into FoodOrders(fid, oid, qty) values (263, 90, 5);
insert into Orders(uid, location, order_time, payment_type, used_points) values (34, '63 Cottonwood Park', '2020-05-04 16:03:00', 1, 0);
insert into FoodOrders(fid, oid, qty) values (339, 91, 5);
insert into FoodOrders(fid, oid, qty) values (346, 91, 4);
insert into FoodOrders(fid, oid, qty) values (359, 91, 3);
insert into Orders(uid, location, order_time, payment_type, used_points) values (327, '4499 Rutledge Center', '2020-05-04 18:32:00', 0, 0);
insert into FoodOrders(fid, oid, qty) values (265, 92, 4);
insert into FoodOrders(fid, oid, qty) values (267, 92, 3);
insert into FoodOrders(fid, oid, qty) values (274, 92, 4);
insert into Orders(uid, location, order_time, payment_type, used_points) values (7, '4153 Carpenter Terrace', '2020-05-04 20:22:00', 1, 0);
insert into FoodOrders(fid, oid, qty) values (287, 93, 4);
insert into FoodOrders(fid, oid, qty) values (290, 93, 4);
insert into Orders(uid, location, order_time, payment_type, used_points) values (159, '9753 Hooker Street', '2020-05-05 10:41:00', 1, 0);
insert into FoodOrders(fid, oid, qty) values (68, 94, 2);
insert into FoodOrders(fid, oid, qty) values (74, 94, 2);
insert into FoodOrders(fid, oid, qty) values (75, 94, 1);
insert into FoodOrders(fid, oid, qty) values (80, 94, 4);
insert into Orders(uid, location, order_time, payment_type, used_points) values (78, '974 Maple Circle', '2020-05-05 11:30:00', 1, 0);
insert into FoodOrders(fid, oid, qty) values (40, 95, 5);
insert into FoodOrders(fid, oid, qty) values (48, 95, 6);
insert into Orders(uid, location, order_time, payment_type, used_points) values (89, '95 Melby Parkway', '2020-05-05 13:43:00', 1, 0);
insert into FoodOrders(fid, oid, qty) values (20, 96, 7);
insert into FoodOrders(fid, oid, qty) values (26, 96, 10);
insert into Orders(uid, location, order_time, payment_type, used_points) values (119, '1543 Farmco Road', '2020-05-05 16:55:00', 1, 0);
insert into FoodOrders(fid, oid, qty) values (219, 97, 6);
insert into Orders(uid, location, order_time, payment_type, used_points) values (250, '02547 Golden Leaf Parkway', '2020-05-05 17:36:00', 1, 0);
insert into FoodOrders(fid, oid, qty) values (162, 98, 4);
insert into FoodOrders(fid, oid, qty) values (165, 98, 3);
insert into Orders(uid, location, order_time, payment_type, used_points) values (337, '29 Dakota Crossing', '2020-05-05 19:22:00', 1, 0);
insert into FoodOrders(fid, oid, qty) values (258, 99, 5);
insert into FoodOrders(fid, oid, qty) values (261, 99, 3);
insert into FoodOrders(fid, oid, qty) values (264, 99, 4);
insert into Orders(uid, location, order_time, payment_type, used_points) values (314, '40505 Chinook Hill', '2020-05-06 11:01:00', 1, 0);
insert into FoodOrders(fid, oid, qty) values (382, 100, 3);
insert into FoodOrders(fid, oid, qty) values (385, 100, 2);


-- --WorkSchedules
--PT uid: 702 - 901;
--FT uid: 902 - 1001;
ALTER TABLE PTWorkSchedules DISABLE TRIGGER ALL;
<<<<<<< HEAD
select NewPTWorkSchedule(702, '2020-04-20 10:00:00', '2020-04-20 13:00:00');
select NewPTWorkSchedule(702, '2020-04-20 14:00:00', '2020-04-20 18:00:00');
select NewPTWorkSchedule(702, '2020-04-22 10:00:00', '2020-04-22 13:00:00');
select NewPTWorkSchedule(702, '2020-04-22 14:00:00', '2020-04-22 18:00:00');
select NewPTWorkSchedule(702, '2020-04-22 19:00:00', '2020-04-22 22:00:00');
select NewPTWorkSchedule(702, '2020-04-24 10:00:00', '2020-04-24 13:00:00');
select NewPTWorkSchedule(702, '2020-04-24 14:00:00', '2020-04-24 18:00:00');
select NewPTWorkSchedule(702, '2020-04-24 19:00:00', '2020-04-24 22:00:00');
select NewPTWorkSchedule(703, '2020-04-20 10:00:00', '2020-04-20 14:00:00');
select NewPTWorkSchedule(703, '2020-04-20 15:00:00', '2020-04-20 19:00:00');
select NewPTWorkSchedule(703, '2020-04-21 10:00:00', '2020-04-21 14:00:00');
select NewPTWorkSchedule(703, '2020-04-21 15:00:00', '2020-04-21 19:00:00');
select NewPTWorkSchedule(703, '2020-04-22 10:00:00', '2020-04-22 14:00:00');
select NewPTWorkSchedule(703, '2020-04-22 15:00:00', '2020-04-22 19:00:00');
select NewPTWorkSchedule(703, '2020-04-23 10:00:00', '2020-04-23 14:00:00');
select NewPTWorkSchedule(703, '2020-04-23 15:00:00', '2020-04-23 19:00:00');
select NewPTWorkSchedule(703, '2020-04-24 10:00:00', '2020-04-24 14:00:00');
select NewPTWorkSchedule(703, '2020-04-24 15:00:00', '2020-04-24 19:00:00');
select NewPTWorkSchedule(703, '2020-04-25 10:00:00', '2020-04-25 14:00:00');
select NewPTWorkSchedule(703, '2020-04-25 15:00:00', '2020-04-25 19:00:00');
select NewPTWorkSchedule(704, '2020-04-20 11:00:00', '2020-04-20 15:00:00');
select NewPTWorkSchedule(704, '2020-04-20 16:00:00', '2020-04-20 20:00:00');
select NewPTWorkSchedule(704, '2020-04-21 11:00:00', '2020-04-21 15:00:00');
select NewPTWorkSchedule(704, '2020-04-21 16:00:00', '2020-04-21 20:00:00');
select NewPTWorkSchedule(704, '2020-04-22 11:00:00', '2020-04-22 15:00:00');
select NewPTWorkSchedule(704, '2020-04-23 11:00:00', '2020-04-23 15:00:00');
select NewPTWorkSchedule(704, '2020-04-24 11:00:00', '2020-04-24 15:00:00');
select NewPTWorkSchedule(704, '2020-04-25 11:00:00', '2020-04-25 15:00:00');
select NewPTWorkSchedule(704, '2020-04-26 18:00:00', '2020-04-26 22:00:00');
select NewPTWorkSchedule(705, '2020-04-20 10:00:00', '2020-04-20 13:00:00');
select NewPTWorkSchedule(705, '2020-04-20 14:00:00', '2020-04-20 17:00:00');
select NewPTWorkSchedule(705, '2020-04-21 10:00:00', '2020-04-21 13:00:00');
select NewPTWorkSchedule(705, '2020-04-21 14:00:00', '2020-04-21 17:00:00');
select NewPTWorkSchedule(705, '2020-04-22 10:00:00', '2020-04-22 13:00:00');
select NewPTWorkSchedule(705, '2020-04-22 14:00:00', '2020-04-22 17:00:00');
select NewPTWorkSchedule(705, '2020-04-23 10:00:00', '2020-04-23 13:00:00');
select NewPTWorkSchedule(705, '2020-04-23 14:00:00', '2020-04-23 17:00:00');
select NewPTWorkSchedule(705, '2020-04-24 10:00:00', '2020-04-24 13:00:00');
select NewPTWorkSchedule(705, '2020-04-24 14:00:00', '2020-04-24 17:00:00');
select NewPTWorkSchedule(706, '2020-04-20 12:00:00', '2020-04-20 16:00:00');
select NewPTWorkSchedule(706, '2020-04-20 17:00:00', '2020-04-20 19:00:00');
select NewPTWorkSchedule(706, '2020-04-22 12:00:00', '2020-04-22 16:00:00');
select NewPTWorkSchedule(706, '2020-04-22 17:00:00', '2020-04-22 19:00:00');
select NewPTWorkSchedule(706, '2020-04-23 12:00:00', '2020-04-23 16:00:00');
select NewPTWorkSchedule(706, '2020-04-23 17:00:00', '2020-04-23 19:00:00');
select NewPTWorkSchedule(706, '2020-04-25 12:00:00', '2020-04-25 16:00:00');
select NewPTWorkSchedule(706, '2020-04-25 17:00:00', '2020-04-25 19:00:00');
select NewPTWorkSchedule(706, '2020-04-26 12:00:00', '2020-04-26 16:00:00');
select NewPTWorkSchedule(706, '2020-04-26 17:00:00', '2020-04-26 19:00:00');
select NewPTWorkSchedule(707, '2020-04-22 15:00:00', '2020-04-22 19:00:00');
select NewPTWorkSchedule(707, '2020-04-23 15:00:00', '2020-04-23 19:00:00');
select NewPTWorkSchedule(707, '2020-04-24 15:00:00', '2020-04-24 19:00:00');
select NewPTWorkSchedule(707, '2020-04-25 15:00:00', '2020-04-25 18:00:00');
select NewPTWorkSchedule(707, '2020-04-26 15:00:00', '2020-04-26 18:00:00');
select NewPTWorkSchedule(708, '2020-04-21 11:00:00', '2020-04-21 15:00:00');
select NewPTWorkSchedule(708, '2020-04-21 16:00:00', '2020-04-21 19:00:00');
select NewPTWorkSchedule(708, '2020-04-22 11:00:00', '2020-04-22 15:00:00');
select NewPTWorkSchedule(708, '2020-04-22 16:00:00', '2020-04-22 19:00:00');
select NewPTWorkSchedule(708, '2020-04-25 11:00:00', '2020-04-25 15:00:00');
select NewPTWorkSchedule(708, '2020-04-25 16:00:00', '2020-04-25 19:00:00');
select NewPTWorkSchedule(709, '2020-04-20 14:00:00', '2020-04-20 18:00:00');
select NewPTWorkSchedule(709, '2020-04-20 19:00:00', '2020-04-20 22:00:00');
select NewPTWorkSchedule(709, '2020-04-22 14:00:00', '2020-04-22 18:00:00');
select NewPTWorkSchedule(709, '2020-04-22 19:00:00', '2020-04-22 22:00:00');
select NewPTWorkSchedule(709, '2020-04-23 14:00:00', '2020-04-23 18:00:00');
select NewPTWorkSchedule(709, '2020-04-24 19:00:00', '2020-04-24 22:00:00');
select NewPTWorkSchedule(709, '2020-04-25 14:00:00', '2020-04-25 18:00:00');
select NewPTWorkSchedule(709, '2020-04-26 19:00:00', '2020-04-26 22:00:00');
select NewPTWorkSchedule(710, '2020-04-20 18:00:00', '2020-04-20 22:00:00');
select NewPTWorkSchedule(710, '2020-04-21 18:00:00', '2020-04-21 22:00:00');
select NewPTWorkSchedule(710, '2020-04-24 18:00:00', '2020-04-24 22:00:00');
select NewPTWorkSchedule(710, '2020-04-25 18:00:00', '2020-04-25 22:00:00');
select NewPTWorkSchedule(711, '2020-04-20 14:00:00', '2020-04-20 18:00:00');
select NewPTWorkSchedule(711, '2020-04-21 14:00:00', '2020-04-21 18:00:00');
select NewPTWorkSchedule(711, '2020-04-22 14:00:00', '2020-04-22 18:00:00');
select NewPTWorkSchedule(711, '2020-04-23 14:00:00', '2020-04-23 18:00:00');
select NewPTWorkSchedule(711, '2020-04-24 14:00:00', '2020-04-24 18:00:00');
select NewPTWorkSchedule(711, '2020-04-24 19:00:00', '2020-04-24 22:00:00');
select NewPTWorkSchedule(711, '2020-04-25 10:00:00', '2020-04-25 14:00:00');
select NewPTWorkSchedule(712, '2020-04-20 11:00:00', '2020-04-20 15:00:00');
select NewPTWorkSchedule(712, '2020-04-21 11:00:00', '2020-04-21 15:00:00');
select NewPTWorkSchedule(712, '2020-04-22 11:00:00', '2020-04-22 15:00:00');
select NewPTWorkSchedule(712, '2020-04-24 11:00:00', '2020-04-24 15:00:00');
select NewPTWorkSchedule(712, '2020-04-25 11:00:00', '2020-04-25 15:00:00');
select NewPTWorkSchedule(713, '2020-04-20 13:00:00', '2020-04-20 15:00:00');
select NewPTWorkSchedule(713, '2020-04-20 16:00:00', '2020-04-20 19:00:00');
select NewPTWorkSchedule(713, '2020-04-21 13:00:00', '2020-04-21 15:00:00');
select NewPTWorkSchedule(713, '2020-04-21 16:00:00', '2020-04-21 19:00:00');
select NewPTWorkSchedule(713, '2020-04-22 13:00:00', '2020-04-22 15:00:00');
select NewPTWorkSchedule(713, '2020-04-22 16:00:00', '2020-04-22 19:00:00');
select NewPTWorkSchedule(713, '2020-04-23 13:00:00', '2020-04-23 15:00:00');
select NewPTWorkSchedule(713, '2020-04-23 16:00:00', '2020-04-23 19:00:00');
select NewPTWorkSchedule(713, '2020-04-24 10:00:00', '2020-04-24 14:00:00');
select NewPTWorkSchedule(713, '2020-04-25 10:00:00', '2020-04-25 14:00:00');
select NewPTWorkSchedule(714, '2020-04-20 15:00:00', '2020-04-20 18:00:00');
select NewPTWorkSchedule(714, '2020-04-20 19:00:00', '2020-04-20 21:00:00');
select NewPTWorkSchedule(714, '2020-04-21 15:00:00', '2020-04-21 18:00:00');
select NewPTWorkSchedule(714, '2020-04-21 19:00:00', '2020-04-21 21:00:00');
select NewPTWorkSchedule(714, '2020-04-26 18:00:00', '2020-04-26 22:00:00');
select NewPTWorkSchedule(715, '2020-04-25 10:00:00', '2020-04-25 14:00:00');
select NewPTWorkSchedule(715, '2020-04-25 15:00:00', '2020-04-25 19:00:00');
select NewPTWorkSchedule(715, '2020-04-26 10:00:00', '2020-04-26 12:00:00');
select NewPTWorkSchedule(715, '2020-04-26 15:00:00', '2020-04-26 17:00:00');
select NewPTWorkSchedule(716, '2020-04-20 10:00:00', '2020-04-20 13:00:00');
select NewPTWorkSchedule(716, '2020-04-21 10:00:00', '2020-04-21 13:00:00');
select NewPTWorkSchedule(716, '2020-04-22 10:00:00', '2020-04-22 13:00:00');
select NewPTWorkSchedule(716, '2020-04-23 10:00:00', '2020-04-23 13:00:00');
select NewPTWorkSchedule(716, '2020-04-24 10:00:00', '2020-04-24 13:00:00');
select NewPTWorkSchedule(716, '2020-04-25 10:00:00', '2020-04-25 13:00:00');
select NewPTWorkSchedule(717, '2020-04-21 14:00:00', '2020-04-21 18:00:00');
select NewPTWorkSchedule(717, '2020-04-21 19:00:00', '2020-04-21 22:00:00');
select NewPTWorkSchedule(717, '2020-04-22 18:00:00', '2020-04-22 21:00:00');
select NewPTWorkSchedule(717, '2020-04-23 18:00:00', '2020-04-23 21:00:00');
select NewPTWorkSchedule(717, '2020-04-24 18:00:00', '2020-04-24 21:00:00');
select NewPTWorkSchedule(717, '2020-04-25 18:00:00', '2020-04-25 21:00:00');
select NewPTWorkSchedule(717, '2020-04-26 18:00:00', '2020-04-26 21:00:00');
select NewPTWorkSchedule(718, '2020-04-24 12:00:00', '2020-04-24 16:00:00');
select NewPTWorkSchedule(718, '2020-04-25 12:00:00', '2020-04-25 16:00:00');
select NewPTWorkSchedule(718, '2020-04-26 12:00:00', '2020-04-26 16:00:00');
select NewPTWorkSchedule(719, '2020-04-20 11:00:00', '2020-04-20 15:00:00');
select NewPTWorkSchedule(719, '2020-04-25 10:00:00', '2020-04-25 13:00:00');
select NewPTWorkSchedule(719, '2020-04-25 14:00:00', '2020-04-25 18:00:00');
select NewPTWorkSchedule(719, '2020-04-26 10:00:00', '2020-04-26 13:00:00');
select NewPTWorkSchedule(719, '2020-04-26 14:00:00', '2020-04-26 18:00:00');
select NewPTWorkSchedule(720, '2020-04-20 18:00:00', '2020-04-20 22:00:00');
select NewPTWorkSchedule(720, '2020-04-21 18:00:00', '2020-04-21 22:00:00');
select NewPTWorkSchedule(720, '2020-04-22 18:00:00', '2020-04-22 22:00:00');
select NewPTWorkSchedule(720, '2020-04-23 18:00:00', '2020-04-23 22:00:00');
select NewPTWorkSchedule(720, '2020-04-24 18:00:00', '2020-04-24 22:00:00');
select NewPTWorkSchedule(720, '2020-04-25 18:00:00', '2020-04-25 22:00:00');
select NewPTWorkSchedule(720, '2020-04-26 18:00:00', '2020-04-26 22:00:00');

select NewPTWorkSchedule(702, '2020-04-27 10:00:00', '2020-04-27 13:00:00');
select NewPTWorkSchedule(702, '2020-04-27 14:00:00', '2020-04-27 18:00:00');
select NewPTWorkSchedule(702, '2020-04-29 10:00:00', '2020-04-29 13:00:00');
select NewPTWorkSchedule(702, '2020-04-29 14:00:00', '2020-04-29 18:00:00');
select NewPTWorkSchedule(702, '2020-04-29 19:00:00', '2020-04-29 22:00:00');
select NewPTWorkSchedule(702, '2020-05-01 10:00:00', '2020-05-01 13:00:00');
select NewPTWorkSchedule(702, '2020-05-01 14:00:00', '2020-05-01 18:00:00');
select NewPTWorkSchedule(702, '2020-05-01 19:00:00', '2020-05-01 22:00:00');
select NewPTWorkSchedule(703, '2020-04-27 10:00:00', '2020-04-27 14:00:00');
select NewPTWorkSchedule(703, '2020-04-27 15:00:00', '2020-04-27 19:00:00');
select NewPTWorkSchedule(703, '2020-04-28 10:00:00', '2020-04-28 14:00:00');
select NewPTWorkSchedule(703, '2020-04-28 15:00:00', '2020-04-28 19:00:00');
select NewPTWorkSchedule(703, '2020-04-29 10:00:00', '2020-04-29 14:00:00');
select NewPTWorkSchedule(703, '2020-04-29 15:00:00', '2020-04-29 19:00:00');
select NewPTWorkSchedule(703, '2020-04-30 10:00:00', '2020-04-30 14:00:00');
select NewPTWorkSchedule(703, '2020-04-30 15:00:00', '2020-04-30 19:00:00');
select NewPTWorkSchedule(703, '2020-05-01 10:00:00', '2020-05-01 14:00:00');
select NewPTWorkSchedule(703, '2020-05-01 15:00:00', '2020-05-01 19:00:00');
select NewPTWorkSchedule(703, '2020-05-02 10:00:00', '2020-05-02 14:00:00');
select NewPTWorkSchedule(703, '2020-05-02 15:00:00', '2020-05-02 19:00:00');
select NewPTWorkSchedule(704, '2020-04-27 11:00:00', '2020-04-27 15:00:00');
select NewPTWorkSchedule(704, '2020-04-27 16:00:00', '2020-04-27 20:00:00');
select NewPTWorkSchedule(704, '2020-04-28 11:00:00', '2020-04-28 15:00:00');
select NewPTWorkSchedule(704, '2020-04-28 16:00:00', '2020-04-28 20:00:00');
select NewPTWorkSchedule(704, '2020-04-29 11:00:00', '2020-04-29 15:00:00');
select NewPTWorkSchedule(704, '2020-04-30 11:00:00', '2020-04-30 15:00:00');
select NewPTWorkSchedule(704, '2020-05-01 11:00:00', '2020-05-01 15:00:00');
select NewPTWorkSchedule(704, '2020-05-02 11:00:00', '2020-05-02 15:00:00');
select NewPTWorkSchedule(704, '2020-05-03 18:00:00', '2020-05-03 22:00:00');
select NewPTWorkSchedule(705, '2020-04-27 10:00:00', '2020-04-27 13:00:00');
select NewPTWorkSchedule(705, '2020-04-27 14:00:00', '2020-04-27 17:00:00');
select NewPTWorkSchedule(705, '2020-04-28 10:00:00', '2020-04-28 13:00:00');
select NewPTWorkSchedule(705, '2020-04-28 14:00:00', '2020-04-28 17:00:00');
select NewPTWorkSchedule(705, '2020-04-29 10:00:00', '2020-04-29 13:00:00');
select NewPTWorkSchedule(705, '2020-04-29 14:00:00', '2020-04-29 17:00:00');
select NewPTWorkSchedule(705, '2020-04-30 10:00:00', '2020-04-30 13:00:00');
select NewPTWorkSchedule(705, '2020-04-30 14:00:00', '2020-04-30 17:00:00');
select NewPTWorkSchedule(705, '2020-05-01 10:00:00', '2020-05-01 13:00:00');
select NewPTWorkSchedule(705, '2020-05-01 14:00:00', '2020-05-01 17:00:00');
select NewPTWorkSchedule(706, '2020-04-27 12:00:00', '2020-04-27 16:00:00');
select NewPTWorkSchedule(706, '2020-04-27 17:00:00', '2020-04-27 19:00:00');
select NewPTWorkSchedule(706, '2020-04-29 12:00:00', '2020-04-29 16:00:00');
select NewPTWorkSchedule(706, '2020-04-29 17:00:00', '2020-04-29 19:00:00');
select NewPTWorkSchedule(706, '2020-04-30 12:00:00', '2020-04-30 16:00:00');
select NewPTWorkSchedule(706, '2020-04-30 17:00:00', '2020-04-30 19:00:00');
select NewPTWorkSchedule(706, '2020-05-02 12:00:00', '2020-05-02 16:00:00');
select NewPTWorkSchedule(706, '2020-05-02 17:00:00', '2020-05-02 19:00:00');
select NewPTWorkSchedule(706, '2020-05-03 12:00:00', '2020-05-03 16:00:00');
select NewPTWorkSchedule(706, '2020-05-03 17:00:00', '2020-05-03 19:00:00');
select NewPTWorkSchedule(707, '2020-04-29 15:00:00', '2020-04-29 19:00:00');
select NewPTWorkSchedule(707, '2020-04-30 15:00:00', '2020-04-30 19:00:00');
select NewPTWorkSchedule(707, '2020-05-01 15:00:00', '2020-05-01 19:00:00');
select NewPTWorkSchedule(707, '2020-05-02 15:00:00', '2020-05-02 18:00:00');
select NewPTWorkSchedule(707, '2020-05-03 15:00:00', '2020-05-03 18:00:00');
select NewPTWorkSchedule(708, '2020-04-28 11:00:00', '2020-04-28 15:00:00');
select NewPTWorkSchedule(708, '2020-04-28 16:00:00', '2020-04-28 19:00:00');
select NewPTWorkSchedule(708, '2020-04-29 11:00:00', '2020-04-29 15:00:00');
select NewPTWorkSchedule(708, '2020-04-29 16:00:00', '2020-04-29 19:00:00');
select NewPTWorkSchedule(708, '2020-05-02 11:00:00', '2020-05-02 15:00:00');
select NewPTWorkSchedule(708, '2020-05-02 16:00:00', '2020-05-02 19:00:00');
select NewPTWorkSchedule(709, '2020-04-27 14:00:00', '2020-04-27 18:00:00');
select NewPTWorkSchedule(709, '2020-04-27 19:00:00', '2020-04-27 22:00:00');
select NewPTWorkSchedule(709, '2020-04-29 14:00:00', '2020-04-29 18:00:00');
select NewPTWorkSchedule(709, '2020-04-29 19:00:00', '2020-04-29 22:00:00');
select NewPTWorkSchedule(709, '2020-04-30 14:00:00', '2020-04-30 18:00:00');
select NewPTWorkSchedule(709, '2020-05-01 19:00:00', '2020-05-01 22:00:00');
select NewPTWorkSchedule(709, '2020-05-02 14:00:00', '2020-05-02 18:00:00');
select NewPTWorkSchedule(709, '2020-05-03 19:00:00', '2020-05-03 22:00:00');
select NewPTWorkSchedule(710, '2020-04-27 18:00:00', '2020-04-27 22:00:00');
select NewPTWorkSchedule(710, '2020-04-28 18:00:00', '2020-04-28 22:00:00');
select NewPTWorkSchedule(710, '2020-05-01 18:00:00', '2020-05-01 22:00:00');
select NewPTWorkSchedule(710, '2020-05-02 18:00:00', '2020-05-02 22:00:00');
select NewPTWorkSchedule(711, '2020-04-27 14:00:00', '2020-04-27 18:00:00');
select NewPTWorkSchedule(711, '2020-04-28 14:00:00', '2020-04-28 18:00:00');
select NewPTWorkSchedule(711, '2020-04-29 14:00:00', '2020-04-29 18:00:00');
select NewPTWorkSchedule(711, '2020-04-30 14:00:00', '2020-04-30 18:00:00');
select NewPTWorkSchedule(711, '2020-05-01 14:00:00', '2020-05-01 18:00:00');
select NewPTWorkSchedule(711, '2020-05-01 19:00:00', '2020-05-01 22:00:00');
select NewPTWorkSchedule(711, '2020-05-02 10:00:00', '2020-05-02 14:00:00');
select NewPTWorkSchedule(712, '2020-04-27 11:00:00', '2020-04-27 15:00:00');
select NewPTWorkSchedule(712, '2020-04-28 11:00:00', '2020-04-28 15:00:00');
select NewPTWorkSchedule(712, '2020-04-29 11:00:00', '2020-04-29 15:00:00');
select NewPTWorkSchedule(712, '2020-05-01 11:00:00', '2020-05-01 15:00:00');
select NewPTWorkSchedule(712, '2020-05-02 11:00:00', '2020-05-02 15:00:00');
select NewPTWorkSchedule(713, '2020-04-27 13:00:00', '2020-04-27 15:00:00');
select NewPTWorkSchedule(713, '2020-04-27 16:00:00', '2020-04-27 19:00:00');
select NewPTWorkSchedule(713, '2020-04-28 13:00:00', '2020-04-28 15:00:00');
select NewPTWorkSchedule(713, '2020-04-28 16:00:00', '2020-04-28 19:00:00');
select NewPTWorkSchedule(713, '2020-04-29 13:00:00', '2020-04-29 15:00:00');
select NewPTWorkSchedule(713, '2020-04-29 16:00:00', '2020-04-29 19:00:00');
select NewPTWorkSchedule(713, '2020-04-30 13:00:00', '2020-04-30 15:00:00');
select NewPTWorkSchedule(713, '2020-04-30 16:00:00', '2020-04-30 19:00:00');
select NewPTWorkSchedule(713, '2020-05-01 10:00:00', '2020-05-01 14:00:00');
select NewPTWorkSchedule(713, '2020-05-02 10:00:00', '2020-05-02 14:00:00');
select NewPTWorkSchedule(714, '2020-04-27 15:00:00', '2020-04-27 18:00:00');
select NewPTWorkSchedule(714, '2020-04-27 19:00:00', '2020-04-27 21:00:00');
select NewPTWorkSchedule(714, '2020-04-28 15:00:00', '2020-04-28 18:00:00');
select NewPTWorkSchedule(714, '2020-04-28 19:00:00', '2020-04-28 21:00:00');
select NewPTWorkSchedule(714, '2020-05-03 18:00:00', '2020-05-03 22:00:00');
select NewPTWorkSchedule(715, '2020-05-02 10:00:00', '2020-05-02 14:00:00');
select NewPTWorkSchedule(715, '2020-05-02 15:00:00', '2020-05-02 19:00:00');
select NewPTWorkSchedule(715, '2020-05-03 10:00:00', '2020-05-03 12:00:00');
select NewPTWorkSchedule(715, '2020-05-03 15:00:00', '2020-05-03 17:00:00');
select NewPTWorkSchedule(716, '2020-04-27 10:00:00', '2020-04-27 13:00:00');
select NewPTWorkSchedule(716, '2020-04-28 10:00:00', '2020-04-28 13:00:00');
select NewPTWorkSchedule(716, '2020-04-29 10:00:00', '2020-04-29 13:00:00');
select NewPTWorkSchedule(716, '2020-04-30 10:00:00', '2020-04-30 13:00:00');
select NewPTWorkSchedule(716, '2020-05-01 10:00:00', '2020-05-01 13:00:00');
select NewPTWorkSchedule(716, '2020-05-02 10:00:00', '2020-05-02 13:00:00');
select NewPTWorkSchedule(717, '2020-04-28 14:00:00', '2020-04-28 18:00:00');
select NewPTWorkSchedule(717, '2020-04-28 19:00:00', '2020-04-28 22:00:00');
select NewPTWorkSchedule(717, '2020-04-29 18:00:00', '2020-04-29 21:00:00');
select NewPTWorkSchedule(717, '2020-04-30 18:00:00', '2020-04-30 21:00:00');
select NewPTWorkSchedule(717, '2020-05-01 18:00:00', '2020-05-01 21:00:00');
select NewPTWorkSchedule(717, '2020-05-02 18:00:00', '2020-05-02 21:00:00');
select NewPTWorkSchedule(717, '2020-05-03 18:00:00', '2020-05-03 21:00:00');
select NewPTWorkSchedule(718, '2020-05-01 12:00:00', '2020-05-01 16:00:00');
select NewPTWorkSchedule(718, '2020-05-02 12:00:00', '2020-05-02 16:00:00');
select NewPTWorkSchedule(718, '2020-05-03 12:00:00', '2020-05-03 16:00:00');
select NewPTWorkSchedule(719, '2020-04-27 11:00:00', '2020-04-27 15:00:00');
select NewPTWorkSchedule(719, '2020-05-02 10:00:00', '2020-05-02 13:00:00');
select NewPTWorkSchedule(719, '2020-05-02 14:00:00', '2020-05-02 18:00:00');
select NewPTWorkSchedule(719, '2020-05-03 10:00:00', '2020-05-03 13:00:00');
select NewPTWorkSchedule(719, '2020-05-03 14:00:00', '2020-05-03 18:00:00');
select NewPTWorkSchedule(720, '2020-04-27 18:00:00', '2020-04-27 22:00:00');
select NewPTWorkSchedule(720, '2020-04-28 18:00:00', '2020-04-28 22:00:00');
select NewPTWorkSchedule(720, '2020-04-29 18:00:00', '2020-04-29 22:00:00');
select NewPTWorkSchedule(720, '2020-04-30 18:00:00', '2020-04-30 22:00:00');
select NewPTWorkSchedule(720, '2020-05-01 18:00:00', '2020-05-01 22:00:00');
select NewPTWorkSchedule(720, '2020-05-02 18:00:00', '2020-05-02 22:00:00');
select NewPTWorkSchedule(720, '2020-05-03 18:00:00', '2020-05-03 22:00:00');

select NewPTWorkSchedule(702, '2020-05-04 10:00:00', '2020-05-04 13:00:00');
select NewPTWorkSchedule(702, '2020-05-04 14:00:00', '2020-05-04 18:00:00');
select NewPTWorkSchedule(702, '2020-05-06 10:00:00', '2020-05-06 13:00:00');
select NewPTWorkSchedule(702, '2020-05-06 14:00:00', '2020-05-06 18:00:00');
select NewPTWorkSchedule(702, '2020-05-06 19:00:00', '2020-05-06 22:00:00');
select NewPTWorkSchedule(702, '2020-05-08 10:00:00', '2020-05-08 13:00:00');
select NewPTWorkSchedule(702, '2020-05-08 14:00:00', '2020-05-08 18:00:00');
select NewPTWorkSchedule(702, '2020-05-08 19:00:00', '2020-05-08 22:00:00');
select NewPTWorkSchedule(703, '2020-05-04 10:00:00', '2020-05-04 14:00:00');
select NewPTWorkSchedule(703, '2020-05-04 15:00:00', '2020-05-04 19:00:00');
select NewPTWorkSchedule(703, '2020-05-05 10:00:00', '2020-05-05 14:00:00');
select NewPTWorkSchedule(703, '2020-05-05 15:00:00', '2020-05-05 19:00:00');
select NewPTWorkSchedule(703, '2020-05-06 10:00:00', '2020-05-06 14:00:00');
select NewPTWorkSchedule(703, '2020-05-06 15:00:00', '2020-05-06 19:00:00');
select NewPTWorkSchedule(703, '2020-05-07 10:00:00', '2020-05-07 14:00:00');
select NewPTWorkSchedule(703, '2020-05-07 15:00:00', '2020-05-07 19:00:00');
select NewPTWorkSchedule(703, '2020-05-08 10:00:00', '2020-05-08 14:00:00');
select NewPTWorkSchedule(703, '2020-05-08 15:00:00', '2020-05-08 19:00:00');
select NewPTWorkSchedule(703, '2020-05-09 10:00:00', '2020-05-09 14:00:00');
select NewPTWorkSchedule(703, '2020-05-09 15:00:00', '2020-05-09 19:00:00');
select NewPTWorkSchedule(704, '2020-05-04 11:00:00', '2020-05-04 15:00:00');
select NewPTWorkSchedule(704, '2020-05-04 16:00:00', '2020-05-04 20:00:00');
select NewPTWorkSchedule(704, '2020-05-05 11:00:00', '2020-05-05 15:00:00');
select NewPTWorkSchedule(704, '2020-05-05 16:00:00', '2020-05-05 20:00:00');
select NewPTWorkSchedule(704, '2020-05-06 11:00:00', '2020-05-06 15:00:00');
select NewPTWorkSchedule(704, '2020-05-07 11:00:00', '2020-05-07 15:00:00');
select NewPTWorkSchedule(704, '2020-05-08 11:00:00', '2020-05-08 15:00:00');
select NewPTWorkSchedule(704, '2020-05-09 11:00:00', '2020-05-09 15:00:00');
select NewPTWorkSchedule(704, '2020-05-10 18:00:00', '2020-05-10 22:00:00');
select NewPTWorkSchedule(705, '2020-05-04 10:00:00', '2020-05-04 13:00:00');
select NewPTWorkSchedule(705, '2020-05-04 14:00:00', '2020-05-04 17:00:00');
select NewPTWorkSchedule(705, '2020-05-05 10:00:00', '2020-05-05 13:00:00');
select NewPTWorkSchedule(705, '2020-05-05 14:00:00', '2020-05-05 17:00:00');
select NewPTWorkSchedule(705, '2020-05-06 10:00:00', '2020-05-06 13:00:00');
select NewPTWorkSchedule(705, '2020-05-06 14:00:00', '2020-05-06 17:00:00');
select NewPTWorkSchedule(705, '2020-05-07 10:00:00', '2020-05-07 13:00:00');
select NewPTWorkSchedule(705, '2020-05-07 14:00:00', '2020-05-07 17:00:00');
select NewPTWorkSchedule(705, '2020-05-08 10:00:00', '2020-05-08 13:00:00');
select NewPTWorkSchedule(705, '2020-05-08 14:00:00', '2020-05-08 17:00:00');
select NewPTWorkSchedule(706, '2020-05-04 12:00:00', '2020-05-04 16:00:00');
select NewPTWorkSchedule(706, '2020-05-04 17:00:00', '2020-05-04 19:00:00');
select NewPTWorkSchedule(706, '2020-05-06 12:00:00', '2020-05-06 16:00:00');
select NewPTWorkSchedule(706, '2020-05-06 17:00:00', '2020-05-06 19:00:00');
select NewPTWorkSchedule(706, '2020-05-07 12:00:00', '2020-05-07 16:00:00');
select NewPTWorkSchedule(706, '2020-05-07 17:00:00', '2020-05-07 19:00:00');
select NewPTWorkSchedule(706, '2020-05-09 12:00:00', '2020-05-09 16:00:00');
select NewPTWorkSchedule(706, '2020-05-09 17:00:00', '2020-05-09 19:00:00');
select NewPTWorkSchedule(706, '2020-05-10 12:00:00', '2020-05-10 16:00:00');
select NewPTWorkSchedule(706, '2020-05-10 17:00:00', '2020-05-10 19:00:00');
select NewPTWorkSchedule(707, '2020-05-06 15:00:00', '2020-05-06 19:00:00');
select NewPTWorkSchedule(707, '2020-05-07 15:00:00', '2020-05-07 19:00:00');
select NewPTWorkSchedule(707, '2020-05-08 15:00:00', '2020-05-08 19:00:00');
select NewPTWorkSchedule(707, '2020-05-09 15:00:00', '2020-05-09 18:00:00');
select NewPTWorkSchedule(707, '2020-05-10 15:00:00', '2020-05-10 18:00:00');
select NewPTWorkSchedule(708, '2020-05-05 11:00:00', '2020-05-05 15:00:00');
select NewPTWorkSchedule(708, '2020-05-05 16:00:00', '2020-05-05 19:00:00');
select NewPTWorkSchedule(708, '2020-05-06 11:00:00', '2020-05-06 15:00:00');
select NewPTWorkSchedule(708, '2020-05-06 16:00:00', '2020-05-06 19:00:00');
select NewPTWorkSchedule(708, '2020-05-09 11:00:00', '2020-05-09 15:00:00');
select NewPTWorkSchedule(708, '2020-05-09 16:00:00', '2020-05-09 19:00:00');
select NewPTWorkSchedule(709, '2020-05-04 14:00:00', '2020-05-04 18:00:00');
select NewPTWorkSchedule(709, '2020-05-04 19:00:00', '2020-05-04 22:00:00');
select NewPTWorkSchedule(709, '2020-05-06 14:00:00', '2020-05-06 18:00:00');
select NewPTWorkSchedule(709, '2020-05-06 19:00:00', '2020-05-06 22:00:00');
select NewPTWorkSchedule(709, '2020-05-07 14:00:00', '2020-05-07 18:00:00');
select NewPTWorkSchedule(709, '2020-05-08 19:00:00', '2020-05-08 22:00:00');
select NewPTWorkSchedule(709, '2020-05-09 14:00:00', '2020-05-09 18:00:00');
select NewPTWorkSchedule(709, '2020-05-10 19:00:00', '2020-05-10 22:00:00');
select NewPTWorkSchedule(710, '2020-05-04 18:00:00', '2020-05-04 22:00:00');
select NewPTWorkSchedule(710, '2020-05-05 18:00:00', '2020-05-05 22:00:00');
select NewPTWorkSchedule(710, '2020-05-08 18:00:00', '2020-05-08 22:00:00');
select NewPTWorkSchedule(710, '2020-05-09 18:00:00', '2020-05-09 22:00:00');
select NewPTWorkSchedule(711, '2020-05-04 14:00:00', '2020-05-04 18:00:00');
select NewPTWorkSchedule(711, '2020-05-05 14:00:00', '2020-05-05 18:00:00');
select NewPTWorkSchedule(711, '2020-05-06 14:00:00', '2020-05-06 18:00:00');
select NewPTWorkSchedule(711, '2020-05-07 14:00:00', '2020-05-07 18:00:00');
select NewPTWorkSchedule(711, '2020-05-08 14:00:00', '2020-05-08 18:00:00');
select NewPTWorkSchedule(711, '2020-05-08 19:00:00', '2020-05-08 22:00:00');
select NewPTWorkSchedule(711, '2020-05-09 10:00:00', '2020-05-09 14:00:00');
select NewPTWorkSchedule(712, '2020-05-04 11:00:00', '2020-05-04 15:00:00');
select NewPTWorkSchedule(712, '2020-05-05 11:00:00', '2020-05-05 15:00:00');
select NewPTWorkSchedule(712, '2020-05-06 11:00:00', '2020-05-06 15:00:00');
select NewPTWorkSchedule(712, '2020-05-08 11:00:00', '2020-05-08 15:00:00');
select NewPTWorkSchedule(712, '2020-05-09 11:00:00', '2020-05-09 15:00:00');
select NewPTWorkSchedule(713, '2020-05-04 13:00:00', '2020-05-04 15:00:00');
select NewPTWorkSchedule(713, '2020-05-04 16:00:00', '2020-05-04 19:00:00');
select NewPTWorkSchedule(713, '2020-05-05 13:00:00', '2020-05-05 15:00:00');
select NewPTWorkSchedule(713, '2020-05-05 16:00:00', '2020-05-05 19:00:00');
select NewPTWorkSchedule(713, '2020-05-06 13:00:00', '2020-05-06 15:00:00');
select NewPTWorkSchedule(713, '2020-05-06 16:00:00', '2020-05-06 19:00:00');
select NewPTWorkSchedule(713, '2020-05-07 13:00:00', '2020-05-07 15:00:00');
select NewPTWorkSchedule(713, '2020-05-07 16:00:00', '2020-05-07 19:00:00');
select NewPTWorkSchedule(713, '2020-05-08 10:00:00', '2020-05-08 14:00:00');
select NewPTWorkSchedule(713, '2020-05-09 10:00:00', '2020-05-09 14:00:00');
select NewPTWorkSchedule(714, '2020-05-04 15:00:00', '2020-05-04 18:00:00');
select NewPTWorkSchedule(714, '2020-05-04 19:00:00', '2020-05-04 21:00:00');
select NewPTWorkSchedule(714, '2020-05-05 15:00:00', '2020-05-05 18:00:00');
select NewPTWorkSchedule(714, '2020-05-05 19:00:00', '2020-05-05 21:00:00');
select NewPTWorkSchedule(714, '2020-05-10 18:00:00', '2020-05-10 22:00:00');
select NewPTWorkSchedule(715, '2020-05-09 10:00:00', '2020-05-09 14:00:00');
select NewPTWorkSchedule(715, '2020-05-09 15:00:00', '2020-05-09 19:00:00');
select NewPTWorkSchedule(715, '2020-05-10 10:00:00', '2020-05-10 12:00:00');
select NewPTWorkSchedule(715, '2020-05-10 15:00:00', '2020-05-10 17:00:00');
select NewPTWorkSchedule(716, '2020-05-04 10:00:00', '2020-05-04 13:00:00');
select NewPTWorkSchedule(716, '2020-05-05 10:00:00', '2020-05-05 13:00:00');
select NewPTWorkSchedule(716, '2020-05-06 10:00:00', '2020-05-06 13:00:00');
select NewPTWorkSchedule(716, '2020-05-07 10:00:00', '2020-05-07 13:00:00');
select NewPTWorkSchedule(716, '2020-05-08 10:00:00', '2020-05-08 13:00:00');
select NewPTWorkSchedule(716, '2020-05-09 10:00:00', '2020-05-09 13:00:00');
select NewPTWorkSchedule(717, '2020-05-05 14:00:00', '2020-05-05 18:00:00');
select NewPTWorkSchedule(717, '2020-05-05 19:00:00', '2020-05-05 22:00:00');
select NewPTWorkSchedule(717, '2020-05-06 18:00:00', '2020-05-06 21:00:00');
select NewPTWorkSchedule(717, '2020-05-07 18:00:00', '2020-05-07 21:00:00');
select NewPTWorkSchedule(717, '2020-05-08 18:00:00', '2020-05-08 21:00:00');
select NewPTWorkSchedule(717, '2020-05-09 18:00:00', '2020-05-09 21:00:00');
select NewPTWorkSchedule(717, '2020-05-10 18:00:00', '2020-05-10 21:00:00');
select NewPTWorkSchedule(718, '2020-05-08 12:00:00', '2020-05-08 16:00:00');
select NewPTWorkSchedule(718, '2020-05-09 12:00:00', '2020-05-09 16:00:00');
select NewPTWorkSchedule(718, '2020-05-10 12:00:00', '2020-05-10 16:00:00');
select NewPTWorkSchedule(719, '2020-05-04 11:00:00', '2020-05-04 15:00:00');
select NewPTWorkSchedule(719, '2020-05-09 10:00:00', '2020-05-09 13:00:00');
select NewPTWorkSchedule(719, '2020-05-09 14:00:00', '2020-05-09 18:00:00');
select NewPTWorkSchedule(719, '2020-05-10 10:00:00', '2020-05-10 13:00:00');
select NewPTWorkSchedule(719, '2020-05-10 14:00:00', '2020-05-10 18:00:00');
select NewPTWorkSchedule(720, '2020-05-04 18:00:00', '2020-05-04 22:00:00');
select NewPTWorkSchedule(720, '2020-05-05 18:00:00', '2020-05-05 22:00:00');
select NewPTWorkSchedule(720, '2020-05-06 18:00:00', '2020-05-06 22:00:00');
select NewPTWorkSchedule(720, '2020-05-07 18:00:00', '2020-05-07 22:00:00');
select NewPTWorkSchedule(720, '2020-05-08 18:00:00', '2020-05-08 22:00:00');
select NewPTWorkSchedule(720, '2020-05-09 18:00:00', '2020-05-09 22:00:00');
select NewPTWorkSchedule(720, '2020-05-10 18:00:00', '2020-05-10 22:00:00');
=======
-- select NewPTWorkSchedule(702, '2020-04-20 10:00:00', '2020-04-20 13:00:00');
-- select NewPTWorkSchedule(702, '2020-04-20 14:00:00', '2020-04-20 18:00:00');
-- select NewPTWorkSchedule(702, '2020-04-22 10:00:00', '2020-04-22 13:00:00');
-- select NewPTWorkSchedule(702, '2020-04-22 14:00:00', '2020-04-22 18:00:00');
-- select NewPTWorkSchedule(702, '2020-04-22 19:00:00', '2020-04-22 22:00:00');
-- select NewPTWorkSchedule(702, '2020-04-24 10:00:00', '2020-04-24 13:00:00');
-- select NewPTWorkSchedule(702, '2020-04-24 14:00:00', '2020-04-24 18:00:00');
-- select NewPTWorkSchedule(702, '2020-04-24 19:00:00', '2020-04-24 22:00:00');
-- select NewPTWorkSchedule(703, '2020-04-20 10:00:00', '2020-04-20 14:00:00');
-- select NewPTWorkSchedule(703, '2020-04-20 15:00:00', '2020-04-20 19:00:00');
-- select NewPTWorkSchedule(703, '2020-04-21 10:00:00', '2020-04-21 14:00:00');
-- select NewPTWorkSchedule(703, '2020-04-21 15:00:00', '2020-04-21 19:00:00');
-- select NewPTWorkSchedule(703, '2020-04-22 10:00:00', '2020-04-22 14:00:00');
-- select NewPTWorkSchedule(703, '2020-04-22 15:00:00', '2020-04-22 19:00:00');
-- select NewPTWorkSchedule(703, '2020-04-23 10:00:00', '2020-04-23 14:00:00');
-- select NewPTWorkSchedule(703, '2020-04-23 15:00:00', '2020-04-23 19:00:00');
-- select NewPTWorkSchedule(703, '2020-04-24 10:00:00', '2020-04-24 14:00:00');
-- select NewPTWorkSchedule(703, '2020-04-24 15:00:00', '2020-04-24 19:00:00');
-- select NewPTWorkSchedule(703, '2020-04-25 10:00:00', '2020-04-25 14:00:00');
-- select NewPTWorkSchedule(703, '2020-04-25 15:00:00', '2020-04-25 19:00:00');
-- select NewPTWorkSchedule(704, '2020-04-20 11:00:00', '2020-04-20 15:00:00');
-- select NewPTWorkSchedule(704, '2020-04-20 16:00:00', '2020-04-20 20:00:00');
-- select NewPTWorkSchedule(704, '2020-04-21 11:00:00', '2020-04-21 15:00:00');
-- select NewPTWorkSchedule(704, '2020-04-21 16:00:00', '2020-04-21 20:00:00');
-- select NewPTWorkSchedule(704, '2020-04-22 11:00:00', '2020-04-22 15:00:00');
-- select NewPTWorkSchedule(704, '2020-04-23 11:00:00', '2020-04-23 15:00:00');
-- select NewPTWorkSchedule(704, '2020-04-24 11:00:00', '2020-04-24 15:00:00');
-- select NewPTWorkSchedule(704, '2020-04-25 11:00:00', '2020-04-25 15:00:00');
-- select NewPTWorkSchedule(704, '2020-04-26 18:00:00', '2020-04-26 22:00:00');
-- select NewPTWorkSchedule(705, '2020-04-20 10:00:00', '2020-04-20 13:00:00');
-- select NewPTWorkSchedule(705, '2020-04-20 14:00:00', '2020-04-20 17:00:00');
-- select NewPTWorkSchedule(705, '2020-04-21 10:00:00', '2020-04-21 13:00:00');
-- select NewPTWorkSchedule(705, '2020-04-21 14:00:00', '2020-04-21 17:00:00');
-- select NewPTWorkSchedule(705, '2020-04-22 10:00:00', '2020-04-22 13:00:00');
-- select NewPTWorkSchedule(705, '2020-04-22 14:00:00', '2020-04-22 17:00:00');
-- select NewPTWorkSchedule(705, '2020-04-23 10:00:00', '2020-04-23 13:00:00');
-- select NewPTWorkSchedule(705, '2020-04-23 14:00:00', '2020-04-23 17:00:00');
-- select NewPTWorkSchedule(705, '2020-04-24 10:00:00', '2020-04-24 13:00:00');
-- select NewPTWorkSchedule(705, '2020-04-24 14:00:00', '2020-04-24 17:00:00');
-- select NewPTWorkSchedule(706, '2020-04-20 12:00:00', '2020-04-20 16:00:00');
-- select NewPTWorkSchedule(706, '2020-04-20 17:00:00', '2020-04-20 19:00:00');
-- select NewPTWorkSchedule(706, '2020-04-22 12:00:00', '2020-04-22 16:00:00');
-- select NewPTWorkSchedule(706, '2020-04-22 17:00:00', '2020-04-22 19:00:00');
-- select NewPTWorkSchedule(706, '2020-04-23 12:00:00', '2020-04-23 16:00:00');
-- select NewPTWorkSchedule(706, '2020-04-23 17:00:00', '2020-04-23 19:00:00');
-- select NewPTWorkSchedule(706, '2020-04-25 12:00:00', '2020-04-25 16:00:00');
-- select NewPTWorkSchedule(706, '2020-04-25 17:00:00', '2020-04-25 19:00:00');
-- select NewPTWorkSchedule(706, '2020-04-26 12:00:00', '2020-04-26 16:00:00');
-- select NewPTWorkSchedule(706, '2020-04-26 17:00:00', '2020-04-26 19:00:00');
-- select NewPTWorkSchedule(707, '2020-04-22 15:00:00', '2020-04-22 19:00:00');
-- select NewPTWorkSchedule(707, '2020-04-23 15:00:00', '2020-04-23 19:00:00');
-- select NewPTWorkSchedule(707, '2020-04-24 15:00:00', '2020-04-24 19:00:00');
-- select NewPTWorkSchedule(707, '2020-04-25 15:00:00', '2020-04-25 18:00:00');
-- select NewPTWorkSchedule(707, '2020-04-26 15:00:00', '2020-04-26 18:00:00');
-- select NewPTWorkSchedule(708, '2020-04-21 11:00:00', '2020-04-21 15:00:00');
-- select NewPTWorkSchedule(708, '2020-04-21 16:00:00', '2020-04-21 19:00:00');
-- select NewPTWorkSchedule(708, '2020-04-22 11:00:00', '2020-04-22 15:00:00');
-- select NewPTWorkSchedule(708, '2020-04-22 16:00:00', '2020-04-22 19:00:00');
-- select NewPTWorkSchedule(708, '2020-04-25 11:00:00', '2020-04-25 15:00:00');
-- select NewPTWorkSchedule(708, '2020-04-25 16:00:00', '2020-04-25 19:00:00');
-- select NewPTWorkSchedule(709, '2020-04-20 14:00:00', '2020-04-20 18:00:00');
-- select NewPTWorkSchedule(709, '2020-04-20 19:00:00', '2020-04-20 22:00:00');
-- select NewPTWorkSchedule(709, '2020-04-22 14:00:00', '2020-04-22 18:00:00');
-- select NewPTWorkSchedule(709, '2020-04-22 19:00:00', '2020-04-22 22:00:00');
-- select NewPTWorkSchedule(709, '2020-04-23 14:00:00', '2020-04-23 18:00:00');
-- select NewPTWorkSchedule(709, '2020-04-24 19:00:00', '2020-04-24 22:00:00');
-- select NewPTWorkSchedule(709, '2020-04-25 14:00:00', '2020-04-25 18:00:00');
-- select NewPTWorkSchedule(709, '2020-04-26 19:00:00', '2020-04-26 22:00:00');
-- select NewPTWorkSchedule(710, '2020-04-20 18:00:00', '2020-04-20 22:00:00');
-- select NewPTWorkSchedule(710, '2020-04-21 18:00:00', '2020-04-21 22:00:00');
-- select NewPTWorkSchedule(710, '2020-04-24 18:00:00', '2020-04-24 22:00:00');
-- select NewPTWorkSchedule(710, '2020-04-25 18:00:00', '2020-04-25 22:00:00');
-- select NewPTWorkSchedule(711, '2020-04-20 14:00:00', '2020-04-20 18:00:00');
-- select NewPTWorkSchedule(711, '2020-04-21 14:00:00', '2020-04-21 18:00:00');
-- select NewPTWorkSchedule(711, '2020-04-22 14:00:00', '2020-04-22 18:00:00');
-- select NewPTWorkSchedule(711, '2020-04-23 14:00:00', '2020-04-23 18:00:00');
-- select NewPTWorkSchedule(711, '2020-04-24 14:00:00', '2020-04-24 18:00:00');
-- select NewPTWorkSchedule(711, '2020-04-24 19:00:00', '2020-04-24 22:00:00');
-- select NewPTWorkSchedule(711, '2020-04-25 10:00:00', '2020-04-25 14:00:00');
-- select NewPTWorkSchedule(712, '2020-04-20 11:00:00', '2020-04-20 15:00:00');
-- select NewPTWorkSchedule(712, '2020-04-21 11:00:00', '2020-04-21 15:00:00');
-- select NewPTWorkSchedule(712, '2020-04-22 11:00:00', '2020-04-22 15:00:00');
-- select NewPTWorkSchedule(712, '2020-04-24 11:00:00', '2020-04-24 15:00:00');
-- select NewPTWorkSchedule(712, '2020-04-25 11:00:00', '2020-04-25 15:00:00');
-- select NewPTWorkSchedule(713, '2020-04-20 13:00:00', '2020-04-20 15:00:00');
-- select NewPTWorkSchedule(713, '2020-04-20 16:00:00', '2020-04-20 19:00:00');
-- select NewPTWorkSchedule(713, '2020-04-21 13:00:00', '2020-04-21 15:00:00');
-- select NewPTWorkSchedule(713, '2020-04-21 16:00:00', '2020-04-21 19:00:00');
-- select NewPTWorkSchedule(713, '2020-04-22 13:00:00', '2020-04-22 15:00:00');
-- select NewPTWorkSchedule(713, '2020-04-22 16:00:00', '2020-04-22 19:00:00');
-- select NewPTWorkSchedule(713, '2020-04-23 13:00:00', '2020-04-23 15:00:00');
-- select NewPTWorkSchedule(713, '2020-04-23 16:00:00', '2020-04-23 19:00:00');
-- select NewPTWorkSchedule(713, '2020-04-24 10:00:00', '2020-04-24 14:00:00');
-- select NewPTWorkSchedule(713, '2020-04-25 10:00:00', '2020-04-25 14:00:00');
-- select NewPTWorkSchedule(714, '2020-04-20 15:00:00', '2020-04-20 18:00:00');
-- select NewPTWorkSchedule(714, '2020-04-20 19:00:00', '2020-04-20 21:00:00');
-- select NewPTWorkSchedule(714, '2020-04-21 15:00:00', '2020-04-21 18:00:00');
-- select NewPTWorkSchedule(714, '2020-04-21 19:00:00', '2020-04-21 21:00:00');
-- select NewPTWorkSchedule(714, '2020-04-26 18:00:00', '2020-04-26 22:00:00');
-- select NewPTWorkSchedule(715, '2020-04-25 10:00:00', '2020-04-25 14:00:00');
-- select NewPTWorkSchedule(715, '2020-04-25 15:00:00', '2020-04-25 19:00:00');
-- select NewPTWorkSchedule(715, '2020-04-26 10:00:00', '2020-04-26 12:00:00');
-- select NewPTWorkSchedule(715, '2020-04-26 15:00:00', '2020-04-26 17:00:00');
-- select NewPTWorkSchedule(716, '2020-04-20 10:00:00', '2020-04-20 13:00:00');
-- select NewPTWorkSchedule(716, '2020-04-21 10:00:00', '2020-04-21 13:00:00');
-- select NewPTWorkSchedule(716, '2020-04-22 10:00:00', '2020-04-22 13:00:00');
-- select NewPTWorkSchedule(716, '2020-04-23 10:00:00', '2020-04-23 13:00:00');
-- select NewPTWorkSchedule(716, '2020-04-24 10:00:00', '2020-04-24 13:00:00');
-- select NewPTWorkSchedule(716, '2020-04-25 10:00:00', '2020-04-25 13:00:00');
-- select NewPTWorkSchedule(717, '2020-04-21 14:00:00', '2020-04-21 18:00:00');
-- select NewPTWorkSchedule(717, '2020-04-21 19:00:00', '2020-04-21 22:00:00');
-- select NewPTWorkSchedule(717, '2020-04-22 18:00:00', '2020-04-22 21:00:00');
-- select NewPTWorkSchedule(717, '2020-04-23 18:00:00', '2020-04-23 21:00:00');
-- select NewPTWorkSchedule(717, '2020-04-24 18:00:00', '2020-04-24 21:00:00');
-- select NewPTWorkSchedule(717, '2020-04-25 18:00:00', '2020-04-25 21:00:00');
-- select NewPTWorkSchedule(717, '2020-04-26 18:00:00', '2020-04-26 21:00:00');
-- select NewPTWorkSchedule(718, '2020-04-24 12:00:00', '2020-04-24 16:00:00');
-- select NewPTWorkSchedule(718, '2020-04-25 12:00:00', '2020-04-25 16:00:00');
-- select NewPTWorkSchedule(718, '2020-04-26 12:00:00', '2020-04-26 16:00:00');
-- select NewPTWorkSchedule(719, '2020-04-20 11:00:00', '2020-04-20 15:00:00');
-- select NewPTWorkSchedule(719, '2020-04-25 10:00:00', '2020-04-25 13:00:00');
-- select NewPTWorkSchedule(719, '2020-04-25 14:00:00', '2020-04-25 18:00:00');
-- select NewPTWorkSchedule(719, '2020-04-26 10:00:00', '2020-04-26 13:00:00');
-- select NewPTWorkSchedule(719, '2020-04-26 14:00:00', '2020-04-26 18:00:00');
-- select NewPTWorkSchedule(720, '2020-04-20 18:00:00', '2020-04-20 22:00:00');
-- select NewPTWorkSchedule(720, '2020-04-21 18:00:00', '2020-04-21 22:00:00');
-- select NewPTWorkSchedule(720, '2020-04-22 18:00:00', '2020-04-22 22:00:00');
-- select NewPTWorkSchedule(720, '2020-04-23 18:00:00', '2020-04-23 22:00:00');
-- select NewPTWorkSchedule(720, '2020-04-24 18:00:00', '2020-04-24 22:00:00');
-- select NewPTWorkSchedule(720, '2020-04-25 18:00:00', '2020-04-25 22:00:00');
-- select NewPTWorkSchedule(720, '2020-04-26 18:00:00', '2020-04-26 22:00:00');

-- select NewPTWorkSchedule(702, '2020-04-27 10:00:00', '2020-04-27 13:00:00');
-- select NewPTWorkSchedule(702, '2020-04-27 14:00:00', '2020-04-27 18:00:00');
-- select NewPTWorkSchedule(702, '2020-04-29 10:00:00', '2020-04-29 13:00:00');
-- select NewPTWorkSchedule(702, '2020-04-29 14:00:00', '2020-04-29 18:00:00');
-- select NewPTWorkSchedule(702, '2020-04-29 19:00:00', '2020-04-29 22:00:00');
-- select NewPTWorkSchedule(702, '2020-05-01 10:00:00', '2020-05-01 13:00:00');
-- select NewPTWorkSchedule(702, '2020-05-01 14:00:00', '2020-05-01 18:00:00');
-- select NewPTWorkSchedule(702, '2020-05-01 19:00:00', '2020-05-01 22:00:00');
-- select NewPTWorkSchedule(703, '2020-04-27 10:00:00', '2020-04-27 14:00:00');
-- select NewPTWorkSchedule(703, '2020-04-27 15:00:00', '2020-04-27 19:00:00');
-- select NewPTWorkSchedule(703, '2020-04-28 10:00:00', '2020-04-28 14:00:00');
-- select NewPTWorkSchedule(703, '2020-04-28 15:00:00', '2020-04-28 19:00:00');
-- select NewPTWorkSchedule(703, '2020-04-29 10:00:00', '2020-04-29 14:00:00');
-- select NewPTWorkSchedule(703, '2020-04-29 15:00:00', '2020-04-29 19:00:00');
-- select NewPTWorkSchedule(703, '2020-04-30 10:00:00', '2020-04-30 14:00:00');
-- select NewPTWorkSchedule(703, '2020-04-30 15:00:00', '2020-04-30 19:00:00');
-- select NewPTWorkSchedule(703, '2020-05-01 10:00:00', '2020-05-01 14:00:00');
-- select NewPTWorkSchedule(703, '2020-05-01 15:00:00', '2020-05-01 19:00:00');
-- select NewPTWorkSchedule(703, '2020-05-02 10:00:00', '2020-05-02 14:00:00');
-- select NewPTWorkSchedule(703, '2020-05-02 15:00:00', '2020-05-02 19:00:00');
-- select NewPTWorkSchedule(704, '2020-04-27 11:00:00', '2020-04-27 15:00:00');
-- select NewPTWorkSchedule(704, '2020-04-27 16:00:00', '2020-04-27 20:00:00');
-- select NewPTWorkSchedule(704, '2020-04-28 11:00:00', '2020-04-28 15:00:00');
-- select NewPTWorkSchedule(704, '2020-04-28 16:00:00', '2020-04-28 20:00:00');
-- select NewPTWorkSchedule(704, '2020-04-29 11:00:00', '2020-04-29 15:00:00');
-- select NewPTWorkSchedule(704, '2020-04-30 11:00:00', '2020-04-30 15:00:00');
-- select NewPTWorkSchedule(704, '2020-05-01 11:00:00', '2020-05-01 15:00:00');
-- select NewPTWorkSchedule(704, '2020-05-02 11:00:00', '2020-05-02 15:00:00');
-- select NewPTWorkSchedule(704, '2020-05-03 18:00:00', '2020-05-03 22:00:00');
-- select NewPTWorkSchedule(705, '2020-04-27 10:00:00', '2020-04-27 13:00:00');
-- select NewPTWorkSchedule(705, '2020-04-27 14:00:00', '2020-04-27 17:00:00');
-- select NewPTWorkSchedule(705, '2020-04-28 10:00:00', '2020-04-28 13:00:00');
-- select NewPTWorkSchedule(705, '2020-04-28 14:00:00', '2020-04-28 17:00:00');
-- select NewPTWorkSchedule(705, '2020-04-29 10:00:00', '2020-04-29 13:00:00');
-- select NewPTWorkSchedule(705, '2020-04-29 14:00:00', '2020-04-29 17:00:00');
-- select NewPTWorkSchedule(705, '2020-04-30 10:00:00', '2020-04-30 13:00:00');
-- select NewPTWorkSchedule(705, '2020-04-30 14:00:00', '2020-04-30 17:00:00');
-- select NewPTWorkSchedule(705, '2020-05-01 10:00:00', '2020-05-01 13:00:00');
-- select NewPTWorkSchedule(705, '2020-05-01 14:00:00', '2020-05-01 17:00:00');
-- select NewPTWorkSchedule(706, '2020-04-27 12:00:00', '2020-04-27 16:00:00');
-- select NewPTWorkSchedule(706, '2020-04-27 17:00:00', '2020-04-27 19:00:00');
-- select NewPTWorkSchedule(706, '2020-04-29 12:00:00', '2020-04-29 16:00:00');
-- select NewPTWorkSchedule(706, '2020-04-29 17:00:00', '2020-04-29 19:00:00');
-- select NewPTWorkSchedule(706, '2020-04-30 12:00:00', '2020-04-30 16:00:00');
-- select NewPTWorkSchedule(706, '2020-04-30 17:00:00', '2020-04-30 19:00:00');
-- select NewPTWorkSchedule(706, '2020-05-02 12:00:00', '2020-05-02 16:00:00');
-- select NewPTWorkSchedule(706, '2020-05-02 17:00:00', '2020-05-02 19:00:00');
-- select NewPTWorkSchedule(706, '2020-05-03 12:00:00', '2020-05-03 16:00:00');
-- select NewPTWorkSchedule(706, '2020-05-03 17:00:00', '2020-05-03 19:00:00');
-- select NewPTWorkSchedule(707, '2020-04-29 15:00:00', '2020-04-29 19:00:00');
-- select NewPTWorkSchedule(707, '2020-04-30 15:00:00', '2020-04-30 19:00:00');
-- select NewPTWorkSchedule(707, '2020-05-01 15:00:00', '2020-05-01 19:00:00');
-- select NewPTWorkSchedule(707, '2020-05-02 15:00:00', '2020-05-02 18:00:00');
-- select NewPTWorkSchedule(707, '2020-05-03 15:00:00', '2020-05-03 18:00:00');
-- select NewPTWorkSchedule(708, '2020-04-28 11:00:00', '2020-04-28 15:00:00');
-- select NewPTWorkSchedule(708, '2020-04-28 16:00:00', '2020-04-28 19:00:00');
-- select NewPTWorkSchedule(708, '2020-04-29 11:00:00', '2020-04-29 15:00:00');
-- select NewPTWorkSchedule(708, '2020-04-29 16:00:00', '2020-04-29 19:00:00');
-- select NewPTWorkSchedule(708, '2020-05-02 11:00:00', '2020-05-02 15:00:00');
-- select NewPTWorkSchedule(708, '2020-05-02 16:00:00', '2020-05-02 19:00:00');
-- select NewPTWorkSchedule(709, '2020-04-27 14:00:00', '2020-04-27 18:00:00');
-- select NewPTWorkSchedule(709, '2020-04-27 19:00:00', '2020-04-27 22:00:00');
-- select NewPTWorkSchedule(709, '2020-04-29 14:00:00', '2020-04-29 18:00:00');
-- select NewPTWorkSchedule(709, '2020-04-29 19:00:00', '2020-04-29 22:00:00');
-- select NewPTWorkSchedule(709, '2020-04-30 14:00:00', '2020-04-30 18:00:00');
-- select NewPTWorkSchedule(709, '2020-05-01 19:00:00', '2020-05-01 22:00:00');
-- select NewPTWorkSchedule(709, '2020-05-02 14:00:00', '2020-05-02 18:00:00');
-- select NewPTWorkSchedule(709, '2020-05-03 19:00:00', '2020-05-03 22:00:00');
-- select NewPTWorkSchedule(710, '2020-04-27 18:00:00', '2020-04-27 22:00:00');
-- select NewPTWorkSchedule(710, '2020-04-28 18:00:00', '2020-04-28 22:00:00');
-- select NewPTWorkSchedule(710, '2020-05-01 18:00:00', '2020-05-01 22:00:00');
-- select NewPTWorkSchedule(710, '2020-05-02 18:00:00', '2020-05-02 22:00:00');
-- select NewPTWorkSchedule(711, '2020-04-27 14:00:00', '2020-04-27 18:00:00');
-- select NewPTWorkSchedule(711, '2020-04-28 14:00:00', '2020-04-28 18:00:00');
-- select NewPTWorkSchedule(711, '2020-04-29 14:00:00', '2020-04-29 18:00:00');
-- select NewPTWorkSchedule(711, '2020-04-30 14:00:00', '2020-04-30 18:00:00');
-- select NewPTWorkSchedule(711, '2020-05-01 14:00:00', '2020-05-01 18:00:00');
-- select NewPTWorkSchedule(711, '2020-05-01 19:00:00', '2020-05-01 22:00:00');
-- select NewPTWorkSchedule(711, '2020-05-02 10:00:00', '2020-05-02 14:00:00');
-- select NewPTWorkSchedule(712, '2020-04-27 11:00:00', '2020-04-27 15:00:00');
-- select NewPTWorkSchedule(712, '2020-04-28 11:00:00', '2020-04-28 15:00:00');
-- select NewPTWorkSchedule(712, '2020-04-29 11:00:00', '2020-04-29 15:00:00');
-- select NewPTWorkSchedule(712, '2020-05-01 11:00:00', '2020-05-01 15:00:00');
-- select NewPTWorkSchedule(712, '2020-05-02 11:00:00', '2020-05-02 15:00:00');
-- select NewPTWorkSchedule(713, '2020-04-27 13:00:00', '2020-04-27 15:00:00');
-- select NewPTWorkSchedule(713, '2020-04-27 16:00:00', '2020-04-27 19:00:00');
-- select NewPTWorkSchedule(713, '2020-04-28 13:00:00', '2020-04-28 15:00:00');
-- select NewPTWorkSchedule(713, '2020-04-28 16:00:00', '2020-04-28 19:00:00');
-- select NewPTWorkSchedule(713, '2020-04-29 13:00:00', '2020-04-29 15:00:00');
-- select NewPTWorkSchedule(713, '2020-04-29 16:00:00', '2020-04-29 19:00:00');
-- select NewPTWorkSchedule(713, '2020-04-30 13:00:00', '2020-04-30 15:00:00');
-- select NewPTWorkSchedule(713, '2020-04-30 16:00:00', '2020-04-30 19:00:00');
-- select NewPTWorkSchedule(713, '2020-05-01 10:00:00', '2020-05-01 14:00:00');
-- select NewPTWorkSchedule(713, '2020-05-02 10:00:00', '2020-05-02 14:00:00');
-- select NewPTWorkSchedule(714, '2020-04-27 15:00:00', '2020-04-27 18:00:00');
-- select NewPTWorkSchedule(714, '2020-04-27 19:00:00', '2020-04-27 21:00:00');
-- select NewPTWorkSchedule(714, '2020-04-28 15:00:00', '2020-04-28 18:00:00');
-- select NewPTWorkSchedule(714, '2020-04-28 19:00:00', '2020-04-28 21:00:00');
-- select NewPTWorkSchedule(714, '2020-05-03 18:00:00', '2020-05-03 22:00:00');
-- select NewPTWorkSchedule(715, '2020-05-02 10:00:00', '2020-05-02 14:00:00');
-- select NewPTWorkSchedule(715, '2020-05-02 15:00:00', '2020-05-02 19:00:00');
-- select NewPTWorkSchedule(715, '2020-05-03 10:00:00', '2020-05-03 12:00:00');
-- select NewPTWorkSchedule(715, '2020-05-03 15:00:00', '2020-05-03 17:00:00');
-- select NewPTWorkSchedule(716, '2020-04-27 10:00:00', '2020-04-27 13:00:00');
-- select NewPTWorkSchedule(716, '2020-04-28 10:00:00', '2020-04-28 13:00:00');
-- select NewPTWorkSchedule(716, '2020-04-29 10:00:00', '2020-04-29 13:00:00');
-- select NewPTWorkSchedule(716, '2020-04-30 10:00:00', '2020-04-30 13:00:00');
-- select NewPTWorkSchedule(716, '2020-05-01 10:00:00', '2020-05-01 13:00:00');
-- select NewPTWorkSchedule(716, '2020-05-02 10:00:00', '2020-05-02 13:00:00');
-- select NewPTWorkSchedule(717, '2020-04-28 14:00:00', '2020-04-28 18:00:00');
-- select NewPTWorkSchedule(717, '2020-04-28 19:00:00', '2020-04-28 22:00:00');
-- select NewPTWorkSchedule(717, '2020-04-29 18:00:00', '2020-04-29 21:00:00');
-- select NewPTWorkSchedule(717, '2020-04-30 18:00:00', '2020-04-30 21:00:00');
-- select NewPTWorkSchedule(717, '2020-05-01 18:00:00', '2020-05-01 21:00:00');
-- select NewPTWorkSchedule(717, '2020-05-02 18:00:00', '2020-05-02 21:00:00');
-- select NewPTWorkSchedule(717, '2020-05-03 18:00:00', '2020-05-03 21:00:00');
-- select NewPTWorkSchedule(718, '2020-05-01 12:00:00', '2020-05-01 16:00:00');
-- select NewPTWorkSchedule(718, '2020-05-02 12:00:00', '2020-05-02 16:00:00');
-- select NewPTWorkSchedule(718, '2020-05-03 12:00:00', '2020-05-03 16:00:00');
-- select NewPTWorkSchedule(719, '2020-04-27 11:00:00', '2020-04-27 15:00:00');
-- select NewPTWorkSchedule(719, '2020-05-02 10:00:00', '2020-05-02 13:00:00');
-- select NewPTWorkSchedule(719, '2020-05-02 14:00:00', '2020-05-02 18:00:00');
-- select NewPTWorkSchedule(719, '2020-05-03 10:00:00', '2020-05-03 13:00:00');
-- select NewPTWorkSchedule(719, '2020-05-03 14:00:00', '2020-05-03 18:00:00');
-- select NewPTWorkSchedule(720, '2020-04-27 18:00:00', '2020-04-27 22:00:00');
-- select NewPTWorkSchedule(720, '2020-04-28 18:00:00', '2020-04-28 22:00:00');
-- select NewPTWorkSchedule(720, '2020-04-29 18:00:00', '2020-04-29 22:00:00');
-- select NewPTWorkSchedule(720, '2020-04-30 18:00:00', '2020-04-30 22:00:00');
-- select NewPTWorkSchedule(720, '2020-05-01 18:00:00', '2020-05-01 22:00:00');
-- select NewPTWorkSchedule(720, '2020-05-02 18:00:00', '2020-05-02 22:00:00');
-- select NewPTWorkSchedule(720, '2020-05-03 18:00:00', '2020-05-03 22:00:00');

-- select NewPTWorkSchedule(702, '2020-05-04 10:00:00', '2020-05-04 13:00:00');
-- select NewPTWorkSchedule(702, '2020-05-04 14:00:00', '2020-05-04 18:00:00');
-- select NewPTWorkSchedule(702, '2020-05-06 10:00:00', '2020-05-06 13:00:00');
-- select NewPTWorkSchedule(702, '2020-05-06 14:00:00', '2020-05-06 18:00:00');
-- select NewPTWorkSchedule(702, '2020-05-06 19:00:00', '2020-05-06 22:00:00');
-- select NewPTWorkSchedule(702, '2020-05-08 10:00:00', '2020-05-08 13:00:00');
-- select NewPTWorkSchedule(702, '2020-05-08 14:00:00', '2020-05-08 18:00:00');
-- select NewPTWorkSchedule(702, '2020-05-08 19:00:00', '2020-05-08 22:00:00');
-- select NewPTWorkSchedule(703, '2020-05-04 10:00:00', '2020-05-04 14:00:00');
-- select NewPTWorkSchedule(703, '2020-05-04 15:00:00', '2020-05-04 19:00:00');
-- select NewPTWorkSchedule(703, '2020-05-05 10:00:00', '2020-05-05 14:00:00');
-- select NewPTWorkSchedule(703, '2020-05-05 15:00:00', '2020-05-05 19:00:00');
-- select NewPTWorkSchedule(703, '2020-05-06 10:00:00', '2020-05-06 14:00:00');
-- select NewPTWorkSchedule(703, '2020-05-06 15:00:00', '2020-05-06 19:00:00');
-- select NewPTWorkSchedule(703, '2020-05-07 10:00:00', '2020-05-07 14:00:00');
-- select NewPTWorkSchedule(703, '2020-05-07 15:00:00', '2020-05-07 19:00:00');
-- select NewPTWorkSchedule(703, '2020-05-08 10:00:00', '2020-05-08 14:00:00');
-- select NewPTWorkSchedule(703, '2020-05-08 15:00:00', '2020-05-08 19:00:00');
-- select NewPTWorkSchedule(703, '2020-05-09 10:00:00', '2020-05-09 14:00:00');
-- select NewPTWorkSchedule(703, '2020-05-09 15:00:00', '2020-05-09 19:00:00');
-- select NewPTWorkSchedule(704, '2020-05-04 11:00:00', '2020-05-04 15:00:00');
-- select NewPTWorkSchedule(704, '2020-05-04 16:00:00', '2020-05-04 20:00:00');
-- select NewPTWorkSchedule(704, '2020-05-05 11:00:00', '2020-05-05 15:00:00');
-- select NewPTWorkSchedule(704, '2020-05-05 16:00:00', '2020-05-05 20:00:00');
-- select NewPTWorkSchedule(704, '2020-05-06 11:00:00', '2020-05-06 15:00:00');
-- select NewPTWorkSchedule(704, '2020-05-07 11:00:00', '2020-05-07 15:00:00');
-- select NewPTWorkSchedule(704, '2020-05-08 11:00:00', '2020-05-08 15:00:00');
-- select NewPTWorkSchedule(704, '2020-05-09 11:00:00', '2020-05-09 15:00:00');
-- select NewPTWorkSchedule(704, '2020-05-10 18:00:00', '2020-05-10 22:00:00');
-- select NewPTWorkSchedule(705, '2020-05-04 10:00:00', '2020-05-04 13:00:00');
-- select NewPTWorkSchedule(705, '2020-05-04 14:00:00', '2020-05-04 17:00:00');
-- select NewPTWorkSchedule(705, '2020-05-05 10:00:00', '2020-05-05 13:00:00');
-- select NewPTWorkSchedule(705, '2020-05-05 14:00:00', '2020-05-05 17:00:00');
-- select NewPTWorkSchedule(705, '2020-05-06 10:00:00', '2020-05-06 13:00:00');
-- select NewPTWorkSchedule(705, '2020-05-06 14:00:00', '2020-05-06 17:00:00');
-- select NewPTWorkSchedule(705, '2020-05-07 10:00:00', '2020-05-07 13:00:00');
-- select NewPTWorkSchedule(705, '2020-05-07 14:00:00', '2020-05-07 17:00:00');
-- select NewPTWorkSchedule(705, '2020-05-08 10:00:00', '2020-05-08 13:00:00');
-- select NewPTWorkSchedule(705, '2020-05-08 14:00:00', '2020-05-08 17:00:00');
-- select NewPTWorkSchedule(706, '2020-05-04 12:00:00', '2020-05-04 16:00:00');
-- select NewPTWorkSchedule(706, '2020-05-04 17:00:00', '2020-05-04 19:00:00');
-- select NewPTWorkSchedule(706, '2020-05-06 12:00:00', '2020-05-06 16:00:00');
-- select NewPTWorkSchedule(706, '2020-05-06 17:00:00', '2020-05-06 19:00:00');
-- select NewPTWorkSchedule(706, '2020-05-07 12:00:00', '2020-05-07 16:00:00');
-- select NewPTWorkSchedule(706, '2020-05-07 17:00:00', '2020-05-07 19:00:00');
-- select NewPTWorkSchedule(706, '2020-05-09 12:00:00', '2020-05-09 16:00:00');
-- select NewPTWorkSchedule(706, '2020-05-09 17:00:00', '2020-05-09 19:00:00');
-- select NewPTWorkSchedule(706, '2020-05-10 12:00:00', '2020-05-10 16:00:00');
-- select NewPTWorkSchedule(706, '2020-05-10 17:00:00', '2020-05-10 19:00:00');
-- select NewPTWorkSchedule(707, '2020-05-06 15:00:00', '2020-05-06 19:00:00');
-- select NewPTWorkSchedule(707, '2020-05-07 15:00:00', '2020-05-07 19:00:00');
-- select NewPTWorkSchedule(707, '2020-05-08 15:00:00', '2020-05-08 19:00:00');
-- select NewPTWorkSchedule(707, '2020-05-09 15:00:00', '2020-05-09 18:00:00');
-- select NewPTWorkSchedule(707, '2020-05-10 15:00:00', '2020-05-10 18:00:00');
-- select NewPTWorkSchedule(708, '2020-05-05 11:00:00', '2020-05-05 15:00:00');
-- select NewPTWorkSchedule(708, '2020-05-05 16:00:00', '2020-05-05 19:00:00');
-- select NewPTWorkSchedule(708, '2020-05-06 11:00:00', '2020-05-06 15:00:00');
-- select NewPTWorkSchedule(708, '2020-05-06 16:00:00', '2020-05-06 19:00:00');
-- select NewPTWorkSchedule(708, '2020-05-09 11:00:00', '2020-05-09 15:00:00');
-- select NewPTWorkSchedule(708, '2020-05-09 16:00:00', '2020-05-09 19:00:00');
-- select NewPTWorkSchedule(709, '2020-05-04 14:00:00', '2020-05-04 18:00:00');
-- select NewPTWorkSchedule(709, '2020-05-04 19:00:00', '2020-05-04 22:00:00');
-- select NewPTWorkSchedule(709, '2020-05-06 14:00:00', '2020-05-06 18:00:00');
-- select NewPTWorkSchedule(709, '2020-05-06 19:00:00', '2020-05-06 22:00:00');
-- select NewPTWorkSchedule(709, '2020-05-07 14:00:00', '2020-05-07 18:00:00');
-- select NewPTWorkSchedule(709, '2020-05-08 19:00:00', '2020-05-08 22:00:00');
-- select NewPTWorkSchedule(709, '2020-05-09 14:00:00', '2020-05-09 18:00:00');
-- select NewPTWorkSchedule(709, '2020-05-10 19:00:00', '2020-05-10 22:00:00');
-- select NewPTWorkSchedule(710, '2020-05-04 18:00:00', '2020-05-04 22:00:00');
-- select NewPTWorkSchedule(710, '2020-05-05 18:00:00', '2020-05-05 22:00:00');
-- select NewPTWorkSchedule(710, '2020-05-08 18:00:00', '2020-05-08 22:00:00');
-- select NewPTWorkSchedule(710, '2020-05-09 18:00:00', '2020-05-09 22:00:00');
-- select NewPTWorkSchedule(711, '2020-05-04 14:00:00', '2020-05-04 18:00:00');
-- select NewPTWorkSchedule(711, '2020-05-05 14:00:00', '2020-05-05 18:00:00');
-- select NewPTWorkSchedule(711, '2020-05-06 14:00:00', '2020-05-06 18:00:00');
-- select NewPTWorkSchedule(711, '2020-05-07 14:00:00', '2020-05-07 18:00:00');
-- select NewPTWorkSchedule(711, '2020-05-08 14:00:00', '2020-05-08 18:00:00');
-- select NewPTWorkSchedule(711, '2020-05-08 19:00:00', '2020-05-08 22:00:00');
-- select NewPTWorkSchedule(711, '2020-05-09 10:00:00', '2020-05-09 14:00:00');
-- select NewPTWorkSchedule(712, '2020-05-04 11:00:00', '2020-05-04 15:00:00');
-- select NewPTWorkSchedule(712, '2020-05-05 11:00:00', '2020-05-05 15:00:00');
-- select NewPTWorkSchedule(712, '2020-05-06 11:00:00', '2020-05-06 15:00:00');
-- select NewPTWorkSchedule(712, '2020-05-08 11:00:00', '2020-05-08 15:00:00');
-- select NewPTWorkSchedule(712, '2020-05-09 11:00:00', '2020-05-09 15:00:00');
-- select NewPTWorkSchedule(713, '2020-05-04 13:00:00', '2020-05-04 15:00:00');
-- select NewPTWorkSchedule(713, '2020-05-04 16:00:00', '2020-05-04 19:00:00');
-- select NewPTWorkSchedule(713, '2020-05-05 13:00:00', '2020-05-05 15:00:00');
-- select NewPTWorkSchedule(713, '2020-05-05 16:00:00', '2020-05-05 19:00:00');
-- select NewPTWorkSchedule(713, '2020-05-06 13:00:00', '2020-05-06 15:00:00');
-- select NewPTWorkSchedule(713, '2020-05-06 16:00:00', '2020-05-06 19:00:00');
-- select NewPTWorkSchedule(713, '2020-05-07 13:00:00', '2020-05-07 15:00:00');
-- select NewPTWorkSchedule(713, '2020-05-07 16:00:00', '2020-05-07 19:00:00');
-- select NewPTWorkSchedule(713, '2020-05-08 10:00:00', '2020-05-08 14:00:00');
-- select NewPTWorkSchedule(713, '2020-05-09 10:00:00', '2020-05-09 14:00:00');
-- select NewPTWorkSchedule(714, '2020-05-04 15:00:00', '2020-05-04 18:00:00');
-- select NewPTWorkSchedule(714, '2020-05-04 19:00:00', '2020-05-04 21:00:00');
-- select NewPTWorkSchedule(714, '2020-05-05 15:00:00', '2020-05-05 18:00:00');
-- select NewPTWorkSchedule(714, '2020-05-05 19:00:00', '2020-05-05 21:00:00');
-- select NewPTWorkSchedule(714, '2020-05-10 18:00:00', '2020-05-10 22:00:00');
-- select NewPTWorkSchedule(715, '2020-05-09 10:00:00', '2020-05-09 14:00:00');
-- select NewPTWorkSchedule(715, '2020-05-09 15:00:00', '2020-05-09 19:00:00');
-- select NewPTWorkSchedule(715, '2020-05-10 10:00:00', '2020-05-10 12:00:00');
-- select NewPTWorkSchedule(715, '2020-05-10 15:00:00', '2020-05-10 17:00:00');
-- select NewPTWorkSchedule(716, '2020-05-04 10:00:00', '2020-05-04 13:00:00');
-- select NewPTWorkSchedule(716, '2020-05-05 10:00:00', '2020-05-05 13:00:00');
-- select NewPTWorkSchedule(716, '2020-05-06 10:00:00', '2020-05-06 13:00:00');
-- select NewPTWorkSchedule(716, '2020-05-07 10:00:00', '2020-05-07 13:00:00');
-- select NewPTWorkSchedule(716, '2020-05-08 10:00:00', '2020-05-08 13:00:00');
-- select NewPTWorkSchedule(716, '2020-05-09 10:00:00', '2020-05-09 13:00:00');
-- select NewPTWorkSchedule(717, '2020-05-05 14:00:00', '2020-05-05 18:00:00');
-- select NewPTWorkSchedule(717, '2020-05-05 19:00:00', '2020-05-05 22:00:00');
-- select NewPTWorkSchedule(717, '2020-05-06 18:00:00', '2020-05-06 21:00:00');
-- select NewPTWorkSchedule(717, '2020-05-07 18:00:00', '2020-05-07 21:00:00');
-- select NewPTWorkSchedule(717, '2020-05-08 18:00:00', '2020-05-08 21:00:00');
-- select NewPTWorkSchedule(717, '2020-05-09 18:00:00', '2020-05-09 21:00:00');
-- select NewPTWorkSchedule(717, '2020-05-10 18:00:00', '2020-05-10 21:00:00');
-- select NewPTWorkSchedule(718, '2020-05-08 12:00:00', '2020-05-08 16:00:00');
-- select NewPTWorkSchedule(718, '2020-05-09 12:00:00', '2020-05-09 16:00:00');
-- select NewPTWorkSchedule(718, '2020-05-10 12:00:00', '2020-05-10 16:00:00');
-- select NewPTWorkSchedule(719, '2020-05-04 11:00:00', '2020-05-04 15:00:00');
-- select NewPTWorkSchedule(719, '2020-05-09 10:00:00', '2020-05-09 13:00:00');
-- select NewPTWorkSchedule(719, '2020-05-09 14:00:00', '2020-05-09 18:00:00');
-- select NewPTWorkSchedule(719, '2020-05-10 10:00:00', '2020-05-10 13:00:00');
-- select NewPTWorkSchedule(719, '2020-05-10 14:00:00', '2020-05-10 18:00:00');
-- select NewPTWorkSchedule(720, '2020-05-04 18:00:00', '2020-05-04 22:00:00');
-- select NewPTWorkSchedule(720, '2020-05-05 18:00:00', '2020-05-05 22:00:00');
-- select NewPTWorkSchedule(720, '2020-05-06 18:00:00', '2020-05-06 22:00:00');
-- select NewPTWorkSchedule(720, '2020-05-07 18:00:00', '2020-05-07 22:00:00');
-- select NewPTWorkSchedule(720, '2020-05-08 18:00:00', '2020-05-08 22:00:00');
-- select NewPTWorkSchedule(720, '2020-05-09 18:00:00', '2020-05-09 22:00:00');
-- select NewPTWorkSchedule(720, '2020-05-10 18:00:00', '2020-05-10 22:00:00');
>>>>>>> origin/master
ALTER TABLE PTWorkSchedules ENABLE TRIGGER ALL;

-- --Deliveries
insert into Deliveries(oid, uid, t1, t2, t3, t4) values (1, 702, '2020-04-20 10:05:00', '2020-04-20 10:08:00', '2020-04-20 10:14:00', '2020-04-20 10:22:00');
insert into Deliveries(oid, uid, t1, t2, t3, t4) values (2, 716, '2020-04-20 10:21:00', '2020-04-20 10:25:00', '2020-04-20 10:31:00', '2020-04-20 10:41:00');
insert into Deliveries(oid, uid, t1, t2, t3, t4) values (3, 702, '2020-04-20 10:35:00', '2020-04-20 10:39:00', '2020-04-20 10:45:00', '2020-04-20 10:58:00');
insert into Deliveries(oid, uid, t1, t2, t3, t4) values (4, 703, '2020-04-20 10:42:00', '2020-04-20 10:47:00', '2020-04-20 10:52:00', '2020-04-20 11:04:00');
insert into Deliveries(oid, uid, t1, t2, t3, t4) values (5, 705, '2020-04-20 10:55:00', '2020-04-20 11:00:00', '2020-04-20 11:09:00', '2020-04-20 11:22:00');
insert into Deliveries(oid, uid, t1, t2, t3, t4) values (6, 704, '2020-04-20 11:43:00', '2020-04-20 11:49:00', '2020-04-20 11:55:00', '2020-04-20 12:04:00');
insert into Deliveries(oid, uid, t1, t2, t3, t4) values (7, 702, '2020-04-20 12:32:00', '2020-04-20 12:35:00', '2020-04-20 12:40:00', '2020-04-20 12:56:00');
insert into Deliveries(oid, uid, t1, t2, t3, t4) values (8, 706, '2020-04-20 13:13:00', '2020-04-20 13:17:00', '2020-04-20 13:24:00', '2020-04-20 13:40:00');
insert into Deliveries(oid, uid, t1, t2, t3, t4) values (9, 709, '2020-04-20 14:46:00', '2020-04-20 14:52:00', '2020-04-20 14:58:00', '2020-04-20 15:11:00');
insert into Deliveries(oid, uid, t1, t2, t3, t4) values (10, 709, '2020-04-20 15:40:00', '2020-04-20 15:45:00', '2020-04-20 15:59:00', '2020-04-20 16:10:00');
insert into Deliveries(oid, uid, t1, t2, t3, t4) values (11, 710, '2020-04-20 18:24:00', '2020-04-20 18:28:00', '2020-04-20 18:45:00', '2020-04-20 18:58:00');
insert into Deliveries(oid, uid, t1, t2, t3, t4) values (12, 720, '2020-04-20 21:03:00', '2020-04-20 21:05:00', '2020-04-20 21:18:00', '2020-04-20 21:28:00');
insert into Deliveries(oid, uid, t1, t2, t3, t4) values (13, 703, '2020-04-21 10:41:00', '2020-04-21 10:44:00', '2020-04-21 10:50:00', '2020-04-21 11:01:00');
insert into Deliveries(oid, uid, t1, t2, t3, t4) values (14, 703, '2020-04-21 12:51:00', '2020-04-21 12:56:00', '2020-04-21 13:02:00', '2020-04-21 13:21:00');
insert into Deliveries(oid, uid, t1, t2, t3, t4) values (15, 712, '2020-04-21 15:35:00', '2020-04-21 15:40:00', '2020-04-21 15:46:00', '2020-04-21 16:00:00');
insert into Deliveries(oid, uid, t1, t2, t3, t4) values (16, 704, '2020-04-21 17:05:00', '2020-04-21 17:08:00', '2020-04-21 17:16:00', '2020-04-21 17:26:00');
insert into Deliveries(oid, uid, t1, t2, t3, t4) values (17, 703, '2020-04-21 18:25:00', '2020-04-21 18:30:00', '2020-04-21 18:34:00', '2020-04-21 18:46:00');
insert into Deliveries(oid, uid, t1, t2, t3, t4) values (18, 720, '2020-04-21 21:04:00', '2020-04-21 21:10:00', '2020-04-21 21:15:00', '2020-04-21 21:30:00');
insert into Deliveries(oid, uid, t1, t2, t3, t4) values (19, 702, '2020-04-22 11:06:00', '2020-04-22 11:11:00', '2020-04-22 11:17:00', '2020-04-22 11:31:00');
insert into Deliveries(oid, uid, t1, t2, t3, t4) values (20, 708, '2020-04-22 13:13:00', '2020-04-22 13:16:00', '2020-04-22 13:22:00', '2020-04-22 13:33:00');
insert into Deliveries(oid, uid, t1, t2, t3, t4) values (21, 709, '2020-04-22 15:05:00', '2020-04-22 15:09:00', '2020-04-22 15:15:00', '2020-04-22 15:29:00');
insert into Deliveries(oid, uid, t1, t2, t3, t4) values (22, 705, '2020-04-22 16:10:00', '2020-04-22 16:15:00', '2020-04-22 16:23:00', '2020-04-22 16:40:00');
insert into Deliveries(oid, uid, t1, t2, t3, t4) values (23, 702, '2020-04-22 20:08:00', '2020-04-22 20:11:00', '2020-04-22 20:17:00', '2020-04-22 20:29:00');
insert into Deliveries(oid, uid, t1, t2, t3, t4) values (24, 709, '2020-04-22 20:51:00', '2020-04-22 20:55:00', '2020-04-22 21:00:00', '2020-04-22 21:11:00');
insert into Deliveries(oid, uid, t1, t2, t3, t4) values (25, 702, '2020-04-23 10:57:00', '2020-04-23 11:04:00', '2020-04-23 11:11:00', '2020-04-23 11:24:00');
insert into Deliveries(oid, uid, t1, t2, t3, t4) values (26, 703, '2020-04-23 12:06:00', '2020-04-23 12:11:00', '2020-04-23 12:17:00', '2020-04-23 12:30:00');
insert into Deliveries(oid, uid, t1, t2, t3, t4) values (27, 711, '2020-04-23 15:24:00', '2020-04-23 15:28:00', '2020-04-23 15:34:00', '2020-04-23 15:48:00');
insert into Deliveries(oid, uid, t1, t2, t3, t4) values (28, 713, '2020-04-23 17:42:00', '2020-04-23 17:46:00', '2020-04-23 17:51:00', '2020-04-23 18:04:00');
insert into Deliveries(oid, uid, t1, t2, t3, t4) values (29, 717, '2020-04-23 19:35:00', '2020-04-23 19:40:00', '2020-04-23 19:46:00', '2020-04-23 19:59:00');
insert into Deliveries(oid, uid, t1, t2, t3, t4) values (30, 720, '2020-04-23 20:44:00', '2020-04-23 20:51:00', '2020-04-23 20:58:00', '2020-04-23 21:10:00');
insert into Deliveries(oid, uid, t1, t2, t3, t4) values (31, 702, '2020-04-24 11:15:00', '2020-04-24 11:18:00', '2020-04-24 11:23:00', '2020-04-24 11:35:00');
insert into Deliveries(oid, uid, t1, t2, t3, t4) values (32, 703, '2020-04-24 13:16:00', '2020-04-24 13:24:00', '2020-04-24 13:29:00', '2020-04-24 13:39:00');
insert into Deliveries(oid, uid, t1, t2, t3, t4) values (33, 705, '2020-04-24 15:58:00', '2020-04-24 16:04:00', '2020-04-24 16:13:00', '2020-04-24 16:30:00');
insert into Deliveries(oid, uid, t1, t2, t3, t4) values (34, 702, '2020-04-24 16:40:00', '2020-04-24 16:44:00', '2020-04-24 16:50:00', '2020-04-24 17:04:00');
insert into Deliveries(oid, uid, t1, t2, t3, t4) values (35, 710, '2020-04-24 18:25:00', '2020-04-24 18:31:00', '2020-04-24 18:36:00', '2020-04-24 18:55:00');
insert into Deliveries(oid, uid, t1, t2, t3, t4) values (36, 720, '2020-04-24 21:27:00', '2020-04-24 21:30:00', '2020-04-24 21:34:00', '2020-04-24 21:47:00');
insert into Deliveries(oid, uid, t1, t2, t3, t4) values (37, 703, '2020-04-25 10:45:00', '2020-04-25 10:49:00', '2020-04-25 10:56:00', '2020-04-25 11:13:00');
insert into Deliveries(oid, uid, t1, t2, t3, t4) values (38, 708, '2020-04-25 14:14:00', '2020-04-25 14:20:00', '2020-04-25 14:27:00', '2020-04-25 14:42:00');
insert into Deliveries(oid, uid, t1, t2, t3, t4) values (39, 709, '2020-04-25 17:35:00', '2020-04-25 17:40:00', '2020-04-25 17:44:00', '2020-04-25 18:00:00');
insert into Deliveries(oid, uid, t1, t2, t3, t4) values (40, 717, '2020-04-25 20:01:00', '2020-04-25 20:04:00', '2020-04-25 20:11:00', '2020-04-25 20:24:00');
insert into Deliveries(oid, uid, t1, t2, t3, t4) values (41, 719, '2020-04-26 11:34:00', '2020-04-26 11:39:00', '2020-04-26 11:48:00', '2020-04-26 12:05:00');
insert into Deliveries(oid, uid, t1, t2, t3, t4) values (42, 706, '2020-04-26 15:14:00', '2020-04-26 15:20:00', '2020-04-26 15:26:00', '2020-04-26 15:41:00');
insert into Deliveries(oid, uid, t1, t2, t3, t4) values (43, 706, '2020-04-26 18:24:00', '2020-04-26 18:28:00', '2020-04-26 18:39:00', '2020-04-26 18:50:00');
insert into Deliveries(oid, uid, t1, t2, t3, t4) values (44, 720, '2020-04-26 20:05:00', '2020-04-26 20:10:00', '2020-04-26 20:15:00', '2020-04-26 20:31:00');
insert into Deliveries(oid, uid, t1, t2, t3, t4) values (45, 705, '2020-04-27 11:02:00', '2020-04-27 11:07:00', '2020-04-27 11:14:00', '2020-04-27 11:28:00');
insert into Deliveries(oid, uid, t1, t2, t3, t4) values (46, 709, '2020-04-27 16:30:00', '2020-04-27 16:37:00', '2020-04-27 16:41:00', '2020-04-27 16:54:00');
insert into Deliveries(oid, uid, t1, t2, t3, t4) values (47, 711, '2020-04-27 17:27:00', '2020-04-27 17:31:00', '2020-04-27 17:36:00', '2020-04-27 17:45:00');
insert into Deliveries(oid, uid, t1, t2, t3, t4) values (48, 720, '2020-04-27 21:33:00', '2020-04-27 21:38:00', '2020-04-27 21:45:00', '2020-04-27 21:58:00');
insert into Deliveries(oid, uid, t1, t2, t3, t4) values (49, 703, '2020-04-28 10:45:00', '2020-04-28 10:50:00', '2020-04-28 10:57:00', '2020-04-28 11:13:00');
insert into Deliveries(oid, uid, t1, t2, t3, t4) values (50, 703, '2020-04-28 13:35:00', '2020-04-28 13:40:00', '2020-04-28 13:48:00', '2020-04-28 14:01:00');
insert into Deliveries(oid, uid, t1, t2, t3, t4) values (51, 704, '2020-04-28 16:23:00', '2020-04-28 16:29:00', '2020-04-28 16:36:00', '2020-04-28 16:50:00');
insert into Deliveries(oid, uid, t1, t2, t3, t4) values (52, 708, '2020-04-28 18:13:00', '2020-04-28 18:18:00', '2020-04-28 18:23:00', '2020-04-28 18:32:00');
insert into Deliveries(oid, uid, t1, t2, t3, t4) values (53, 714, '2020-04-28 19:40:00', '2020-04-28 19:46:00', '2020-04-28 19:50:00', '2020-04-28 20:03:00');
insert into Deliveries(oid, uid, t1, t2, t3, t4) values (54, 714, '2020-04-28 20:12:00', '2020-04-28 20:19:00', '2020-04-28 20:26:00', '2020-04-28 30:40:00');
insert into Deliveries(oid, uid, t1, t2, t3, t4) values (55, 720, '2020-04-28 21:04:00', '2020-04-28 21:11:00', '2020-04-28 21:17:00', '2020-04-28 21:31:00');
insert into Deliveries(oid, uid, t1, t2, t3, t4) values (56, 702, '2020-04-29 11:14:00', '2020-04-29 11:22:00', '2020-04-29 11:31:00', '2020-04-29 11:45:00');
insert into Deliveries(oid, uid, t1, t2, t3, t4) values (57, 706, '2020-04-29 12:53:00', '2020-04-29 12:59:00', '2020-04-29 13:04:00', '2020-04-29 13:17:00');
insert into Deliveries(oid, uid, t1, t2, t3, t4) values (58, 707, '2020-04-29 15:10:00', '2020-04-29 15:15:00', '2020-04-29 15:21:00', '2020-04-29 15:31:00');
insert into Deliveries(oid, uid, t1, t2, t3, t4) values (59, 709, '2020-04-29 17:21:00', '2020-04-29 17:30:00', '2020-04-29 17:38:00', '2020-04-29 17:52:00');
insert into Deliveries(oid, uid, t1, t2, t3, t4) values (60, 717, '2020-04-29 19:26:00', '2020-04-29 19:30:00', '2020-04-29 19:37:00', '2020-04-29 19:45:00');
insert into Deliveries(oid, uid, t1, t2, t3, t4) values (61, 703, '2020-04-30 11:44:00', '2020-04-30 11:48:00', '2020-04-30 11:55:00', '2020-04-30 12:05:00');
insert into Deliveries(oid, uid, t1, t2, t3, t4) values (62, 706, '2020-04-30 12:56:00', '2020-04-30 13:00:00', '2020-04-30 13:08:00', '2020-04-30 13:20:00');
insert into Deliveries(oid, uid, t1, t2, t3, t4) values (63, 706, '2020-04-30 13:49:00', '2020-04-30 13:54:00', '2020-04-30 14:01:00', '2020-04-30 14:16:00');
insert into Deliveries(oid, uid, t1, t2, t3, t4) values (64, 713, '2020-04-30 17:55:00', '2020-04-30 17:58:00', '2020-04-30 18:06:00', '2020-04-30 18:20:00');
insert into Deliveries(oid, uid, t1, t2, t3, t4) values (65, 717, '2020-04-30 18:34:00', '2020-04-30 18:38:00', '2020-04-30 18:44:00', '2020-04-30 18:57:00');
insert into Deliveries(oid, uid, t1, t2, t3, t4) values (66, 720, '2020-04-30 19:51:00', '2020-04-30 19:59:00', '2020-04-30 20:05:00', '2020-04-30 20:14:00');
insert into Deliveries(oid, uid, t1, t2, t3, t4) values (67, 702, '2020-05-01 10:02:00', '2020-05-01 10:08:00', '2020-05-01 10:20:00', '2020-05-01 10:28:00');
insert into Deliveries(oid, uid, t1, t2, t3, t4) values (68, 705, '2020-05-01 10:12:00', '2020-05-01 10:20:00', '2020-05-01 10:28:00', '2020-05-01 10:39:00');
insert into Deliveries(oid, uid, t1, t2, t3, t4) values (69, 712, '2020-05-01 11:47:00', '2020-05-01 11:51:00', '2020-05-01 11:58:00', '2020-05-01 12:10:00');
insert into Deliveries(oid, uid, t1, t2, t3, t4) values (70, 713, '2020-05-01 12:01:00', '2020-05-01 12:05:00', '2020-05-01 12:11:00', '2020-05-01 12:25:00');
insert into Deliveries(oid, uid, t1, t2, t3, t4) values (71, 703, '2020-05-01 12:32:00', '2020-05-01 12:35:00', '2020-05-01 12:40:00', '2020-05-01 12:49:00');
insert into Deliveries(oid, uid, t1, t2, t3, t4) values (72, 707, '2020-05-01 17:41:00', '2020-05-01 17:47:00', '2020-05-01 17:51:00', '2020-05-01 18:02:00');
insert into Deliveries(oid, uid, t1, t2, t3, t4) values (73, 720, '2020-05-01 19:00:00', '2020-05-01 19:03:00', '2020-05-01 19:09:00', '2020-05-01 19:21:00');
insert into Deliveries(oid, uid, t1, t2, t3, t4) values (74, 716, '2020-05-02 10:47:00', '2020-05-02 10:50:00', '2020-05-02 10:57:00', '2020-05-02 11:05:00');
insert into Deliveries(oid, uid, t1, t2, t3, t4) values (75, 703, '2020-05-02 11:38:00', '2020-05-02 11:43:00', '2020-05-02 11:50:00', '2020-05-02 12:02:00');
insert into Deliveries(oid, uid, t1, t2, t3, t4) values (76, 703, '2020-05-02 12:20:00', '2020-05-02 12:25:00', '2020-05-02 12:31:00', '2020-05-02 12:42:00');
insert into Deliveries(oid, uid, t1, t2, t3, t4) values (77, 708, '2020-05-02 12:36:00', '2020-05-02 12:40:00', '2020-05-02 12:48:00', '2020-05-02 13:00:00');
insert into Deliveries(oid, uid, t1, t2, t3, t4) values (78, 709, '2020-05-02 14:31:00', '2020-05-02 14:35:00', '2020-05-02 14:42:00', '2020-05-02 14:53:00');
insert into Deliveries(oid, uid, t1, t2, t3, t4) values (79, 717, '2020-05-02 18:34:00', '2020-05-02 18:39:00', '2020-05-02 18:45:00', '2020-05-02 18:55:00');
insert into Deliveries(oid, uid, t1, t2, t3, t4) values (80, 720, '2020-05-02 20:34:00', '2020-05-02 20:38:00', '2020-05-02 20:46:00', '2020-05-02 20:44:00');
insert into Deliveries(oid, uid, t1, t2, t3, t4) values (81, 719, '2020-05-03 10:22:00', '2020-05-03 10:25:00', '2020-05-03 10:31:00', '2020-05-03 10:39:00');
insert into Deliveries(oid, uid, t1, t2, t3, t4) values (82, 715, '2020-05-03 11:23:00', '2020-05-03 11:27:00', '2020-05-03 11:32:00', '2020-05-03 11:43:00');
insert into Deliveries(oid, uid, t1, t2, t3, t4) values (83, 718, '2020-05-03 12:05:00', '2020-05-03 12:11:00', '2020-05-03 12:17:00', '2020-05-03 12:26:00');
insert into Deliveries(oid, uid, t1, t2, t3, t4) values (84, 718, '2020-05-03 12:56:00', '2020-05-03 13:00:00', '2020-05-03 13:06:00', '2020-05-03 13:17:00');
insert into Deliveries(oid, uid, t1, t2, t3, t4) values (85, 715, '2020-05-03 15:32:00', '2020-05-03 15:34:00', '2020-05-03 15:40:00', '2020-05-03 15:49:00');
insert into Deliveries(oid, uid, t1, t2, t3, t4) values (86, 706, '2020-05-03 17:31:00', '2020-05-03 17:36:00', '2020-05-03 17:42:00', '2020-05-03 17:53:00');
insert into Deliveries(oid, uid, t1, t2, t3, t4) values (87, 704, '2020-05-03 19:14:00', '2020-05-03 19:20:00', '2020-05-03 19:26:00', '2020-05-03 19:38:00');
insert into Deliveries(oid, uid, t1, t2, t3, t4) values (88, 720, '2020-05-03 21:04:00', '2020-05-03 21:09:00', '2020-05-03 21:15:00', '2020-05-03 21:25:00');
insert into Deliveries(oid, uid, t1, t2, t3, t4) values (89, 702, '2020-05-04 11:41:00', '2020-05-04 11:45:00', '2020-05-04 11:50:00', '2020-05-04 12:00:00');
insert into Deliveries(oid, uid, t1, t2, t3, t4) values (90, 704, '2020-05-04 13:27:00', '2020-05-04 13:31:00', '2020-05-04 13:34:00', '2020-05-04 13:41:00');
insert into Deliveries(oid, uid, t1, t2, t3, t4) values (91, 704, '2020-05-04 16:04:00', '2020-05-04 16:08:00', '2020-05-04 16:15:00', '2020-05-04 16:25:00');
insert into Deliveries(oid, uid, t1, t2, t3, t4) values (92, 706, '2020-05-04 18:33:00', '2020-05-04 18:37:00', '2020-05-04 18:42:00', '2020-05-04 18:53:00');
insert into Deliveries(oid, uid, t1, t2, t3, t4) values (93, 710, '2020-05-04 20:23:00', '2020-05-04 20:28:00', '2020-05-04 20:33:00', '2020-05-04 20:42:00');
insert into Deliveries(oid, uid, t1, t2, t3, t4) values (94, 904, '2020-05-05 10:43:00', '2020-05-05 10:45:00', '2020-05-05 10:52:00', '2020-05-05 11:01:00');
insert into Deliveries(oid, uid, t1, t2, t3, t4) values (95, 904, '2020-05-05 11:31:00', '2020-05-05 11:35:00', '2020-05-05 11:39:00', '2020-05-05 11:49:00');
insert into Deliveries(oid, uid, t1, t2, t3, t4) values (96, 902, '2020-05-05 13:45:00', '2020-05-05 13:50:00', '2020-05-05 13:58:00', '2020-05-05 14:10:00');
insert into Deliveries(oid, uid, t1, t2, t3, t4) values (97, 903, '2020-05-05 16:58:00', '2020-05-05 17:01:00', '2020-05-05 17:07:00', '2020-05-05 17:21:00');
insert into Deliveries(oid, uid, t1, t2, t3, t4) values (98, 902, '2020-05-05 17:37:00', '2020-05-05 17:42:00', '2020-05-05 17:46:00', '2020-05-05 17:58:00');
insert into Deliveries(oid, uid, t1, t2, t3, t4) values (99, 903, '2020-05-05 19:23:00', '2020-05-05 19:27:00', '2020-05-05 19:32:00', '2020-05-05 19:41:00');
insert into Deliveries(oid, uid, t1, t2, t3, t4) values (100, 907, '2020-05-06 11:01:00', '2020-05-06 11:03:00', '2020-05-06 11:09:00', '2020-05-06 11:22:00');