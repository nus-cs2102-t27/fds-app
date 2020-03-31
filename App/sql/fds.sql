-- (unsure what to put here) DROP TABLE IF EXISTS Customers, Users, CASCADE;

CREATE TABLE Users (
	email       varchar(30) NOT NULL, -- how long should email be?
            -- i think we can set rules for this right?
            -- like must follow xxxxxx@xxxx.com domain or something
    password    varchar(30) NOT NULL,
    contact     INTEGER     NOT NULL,
    name        varchar(30) NOT NULL,
    joinDate    date        NOT NULL,
    uid         INTEGER,
    PRIMARY KEY (uid)
);

CREATE TABLE Riders (
-- how are we going to connect to deliveries?
    uid         INTEGER,
	FOREIGN KEY (uid) REFERENCES Users (uid)
        on delete cascade 
        on update cascade-- ISA relationship to users
);

CREATE TABLE Customers (
    cardNum         INTEGER,
    address         TEXT         NOT NULL,
    defaultPayment  varchar(4)   NOT NULL, -- card or cash
    points          INTEGER,
	cvc             INTEGER, -- what is cvc? oops
    uid             INTEGER,
	FOREIGN KEY (uid) REFERENCES Users (uid)
        on delete cascade 
        on update cascade-- ISA relationship to users
);

CREATE TABLE FDSManagers (
-- nothing else in this table?
    uid         INTEGER,
    pid         INTEGER,
	FOREIGN KEY (uid) REFERENCES Users (uid)
        on delete cascade 
        on update cascade, -- ISA relationship to users
    FOREIGN KEY (pid) REFERENCES FDSPromos (pid)
        on delete cascade
);

CREATE TABLE RestaurantStaff (
    uid         INTEGER,
    pid         INTEGER,
	FOREIGN KEY (uid) REFERENCES Users (uid)
        on delete cascade 
        on update cascade, -- ISA relationship to users
    FOREIGN KEY (pid) REFERENCES RPromos (pid)
        on delete cascade
    -- actually i'm not too sure about the on update cascade part
);

CREATE TABLE Restaurants (
	rname 			TEXT       NOT NULL,
	minAmt          INTEGER    NOT NULL,
    address         TEXT       NOT NULL,
    rid             INTEGER,
	PRIMARY KEY (rid),
	-- FOREIGN KEY (fid) REFERENCES Food (fid)
);

CREATE TABLE Food (
	price          INTEGER     NOT NULL,
    category       TEXT, -- maybe enum('sides', 'drink', 'main', 'western', 'chinese') ?
    name           TEXT        NOT NULL,
    limit          INTEGER,
    fid            INTEGER,
    rid            INTEGER, -- sold by a restaurant
    PRIMARY KEY (fid, rid),
    FOREIGN KEY (rid) REFERENCES Restaurants (rid) -- should this be here or in restaurants?
);

CREATE TABLE Orders (
    usedPoints     INTEGER,
    review         TEXT, -- text or like number of stars (eg. 4/5 rating)?
    dateOrdered    TIMESTAMP   NOT NULL,
    paymentType    VARCHAR(4)  NOT NULL, -- card or cash
    oid            INTEGER,
    uid            INTEGER,
    PRIMARY KEY (oid, uid), -- identified by the order the customer makes	
    FOREIGN KEY (uid) REFERENCES Customers (uid)
)

CREATE TABLE FoodInOrders (
    -- to link Food and Orders Table?
    fid           INTEGER,
    oid           INTEGER,
    qty           INTEGER, -- actually what was quantity ah
    PRIMARY KEY (fid, oid),
    FOREIGN KEY (fid) REFERENCES Food (fid),
    FOREIGN KEY (oid) REFERENCES Orders (oid)
)

CREATE TABLE Promos (
    startDate    date       NOT NULL,
    endDate      date       NOT NULL,
    promoType    enum ('a', 'b'),
    discount     INTEGER,
    pid          INTEGER,
    PRIMARY KEY (pid)
)

CREATE TABLE RPromos (
    pid         INTEGER,
    FOREIGN KEY (pid) REFERENCES Promos (pid)
        on delete cascade 
        on update cascade-- ISA relationship to Promos
)

CREATE TABLE FDSPromos (
    pid         INTEGER,
    FOREIGN KEY (pid) REFERENCES Promos (pid)
        on delete cascade 
        on update cascade-- ISA relationship to Promos
)

CREATE TABLE FullTimeRiders (
    uid                INTEGER,
    monthlyBaseSalary  INTEGER    NOT NULL,
    PRIMARY KEY (uid),
    FOREIGN KEY (uid) REFERENCES Riders (uid)
        on delete cascade 
)

CREATE TABLE PartTimeRiders (
    uid                INTEGER,
    weeklyBaseSalary  INTEGER    NOT NULL,
    PRIMARY KEY (uid),
    FOREIGN KEY (uid) REFERENCES Riders (uid)
        on delete cascade 
)

CREATE TABLE WorkSchedule (
    wid         INTEGER,
    PRIMARY KEY (wid)
    -- actually is this necessary
)

CREATE TABLE FullTimeWorkSchedule (
    dateCreated      DATE      NOT NULL,
    dayOption        smallint  NOT NULL
                     check dayOption in (1,2,3,4,5,6,7),
    -- or enum?
    --  each WWS must belong to one of the following seven options: Monday to Friday, Tuesday to Saturday, Wednesday to Sunday, Thursday to Monday, Friday to Tuesday, Saturday to Wednesday, or Sunday to Thursday.
    d1              smallint  NOT NULL,
    d2              smallint  NOT NULL,
    d3              smallint  NOT NULL, 
    d4              smallint  NOT NULL,
    d5              smallint  NOT NULL,
    -- these 5 to represent the shifts right? e.g. shift 1 and 2
    -- maybe can use enum or something
    uid                INTEGER,
    wid                INTEGER,
    PRIMARY KEY (uid, wid),
    FOREIGN KEY (uid) REFERENCES FullTimeRiders (uid)
        on delete cascade,
    FOREIGN KEY (wid) REFERENCES WorkSchedule (wid)
        on delete cascade
)

CREATE TABLE PartTimeWorkSchedule (
    date               DATE         NOT NULL,
    startTime          TIMESTAMP    NOT NULL,
    endTime            TIMESTAMP    NOT NULL,
    uid                INTEGER,
    wid                INTEGER,
    PRIMARY KEY (uid, wid),
    FOREIGN KEY (uid) REFERENCES PartTimeRiders (uid)
        on delete cascade,
    FOREIGN KEY (wid) REFERENCES WorkSchedule (wid)
        on delete cascade
)

CREATE TABLE Deliveries (
    fee        INTEGER     NOT NULL,
    rating     INTEGER     NOT NULL,
    -- are the names here too long?
    -- can we just t1 t2 t3 t4 or something then say in appendix or report
    -- because actually the names here are still abit vague and confusing
    -- maybe t1 then provide explanation elsewhere is better? 
    depart_for_restaurant  TIMESTAMP    NOT NULL,
    arrive_at_restaurant   TIMESTAMP    NOT NULL,
    depart_for_location    TIMESTAMP    NOT NULL,
    arrive_at_location     TIMESTAMP    NOT NULL,
    oid         INTEGER,
    uid         INTEGER,
    PRIMARY KEY (oid, uid),
    FOREIGN KEY (oid) REFERENCES Orders (oid),
    FOREIGN KEY (uid) REFERENCES Riders (uid)
)

