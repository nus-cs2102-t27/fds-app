const express = require("express");
const pgPool = require("../pg-pool");

const delRouter = express.Router();

const getDeliveriesQuery = 
    `SELECT oid, rating, t1, t2, t3, t4, R.name
     FROM Deliveries
     NATURAL JOIN FoodOrders NATURAL JOIN Food
     INNER JOIN Restaurants R
     ON Food.rid = R.rid
     WHERE t4 IS NOT NULL
     GROUP BY oid, rating, t1, t2, t3, t4, R.name
     HAVING uid = $1`;
const getFoodInOrderQuery = `SELECT * FROM Food NATURAL JOIN FoodOrders WHERE oid = $1`;
const getOrdersQuery = 
    `SELECT DISTINCT oid, order_time, Restaurants.name as restaurant, location
     FROM Orders NATURAL JOIN FoodOrders
     NATURAL JOIN Food INNER JOIN Restaurants
     ON Food.rid = Restaurants.rid
     WHERE oid NOT IN (
         SELECT DISTINCT oid FROM Deliveries
     )
     ORDER BY order_time ASC`;
const getCurrentOrderQuery =
    `SELECT * FROM Deliveries WHERE uid = $1
     AND ((t2 IS NULL) OR (t3 IS NULL) OR (t4 IS NULL))`;
const chooseOrderQuery = 
    `INSERT INTO Deliveries(oid, uid, t1)
     VALUES ($1, $2, now())`;
const updateT2Query =
    `UPDATE Deliveries
     SET t2 = now()
     WHERE oid = $1`;
const updateT3Query = 
    `UPDATE Deliveries
     SET t3 = now()
     WHERE oid = $1`;
const updateT4Query = 
    `UPDATE Deliveries
     SET t4 = now()
     WHERE oid = $1`;

delRouter.post("/loghours", async (req, res) => {
    const shifts = {};
    for (const key in req.body) {
        if (!req.body[key]) {
            continue;
        }
        const keySplit = key.split("-");
        const shiftKey = keySplit[1] + keySplit[2];
        if (!(shiftKey in shifts)) {
            shifts[shiftKey] = {};
        }
        date = getWorkDate(keySplit[2]);
        time = getWorkTime(req.body[key]);
        shifts[shiftKey][keySplit[0]] = date + " " + time;
    }

    duration = 0;
    for (const shift in shifts) {
        const date1 = shifts[shift]["start"];
        const date2 = shifts[shift]["end"];
        const diff = Math.abs(date2 - date1) / 360000;
        duration = duration + diff;
    }

    if (duration < 10) {
        res.status(400).send("Too little hours supplied");
        return;
    }
    
    if (duration > 48) {
        res.status(400).send("Too many hours supplied");
        return;
    }

    (async () => {
        const client = await pgPool.connect();

        try {
            await client.query('BEGIN');
            for (const shift in shifts) {
                const queryText = `SELECT NewPTWorkSchedule($1, $2, $3)`;
                await client.query(queryText, [req.cookies.uid, shifts[shift]["start"], shifts[shift]["end"]]);
            }
            await client.query('COMMIT');
        } catch (e) {
            await client.query('ROLLBACK');
        } finally {
            client.release();
        }
    }) ().catch(e => console.error(e.stack));
    res.status(200);
    res.redirect('/app/loghours-success.html');
    return;
});

delRouter.post("/choose", async (req, res) => {
    const { oid } = req.body;
    await pgPool.query(chooseOrderQuery, [oid, req.cookies.uid]);
    res.redirect('/app/rider.html');
    return;
})

delRouter.get("/all", async (req, res) => {
    const { rows: deliveryRows } = await pgPool.query(getDeliveriesQuery, [req.cookies.uid]);
    const queries = deliveryRows.map((delivery) => pgPool.query(getFoodInOrderQuery, [delivery.oid]));
    for (let index in deliveryRows) {
        deliveryRows[index].food = (await queries[index]).rows;
    }

    res.send(deliveryRows);
});

delRouter.get("/orders", async (req, res) => {
    const { rows: orderRows } = await pgPool.query(getOrdersQuery);
    const queries = orderRows.map((order) => pgPool.query(getFoodInOrderQuery, [order.oid]));
    for (let index in orderRows) {
        orderRows[index].food = (await queries[index]).rows;
    }

    res.send(orderRows);
});

delRouter.get("/status", async (req, res) => {
    const { rows } = await pgPool.query(getCurrentOrderQuery, [req.cookies.uid]);
    if (rows.length === 0) {
        res.send("No current delivery");
        return;
    }

    const order = rows[0];
    
    if (!order.t2) {
        res.send("Travelling to restaurant");
        return;
    }

    if (!order.t3) {
        res.send("Waiting for customer's order");
        return;
    }

    if (!order.t4) {
        res.send("Travelling to delivery address");
        return;
    }
});

delRouter.post("/t2", async (req, res) => {
    const { rows } = await pgPool.query(getCurrentOrderQuery, [req.cookies.uid]);
    const order = rows[0].oid;
    await pgPool.query(updateT2Query, [order]);
    res.redirect('/app/rider.html');
});

delRouter.post("/t3", async (req, res) => {
    const { rows } = await pgPool.query(getCurrentOrderQuery, [req.cookies.uid]);
    const order = rows[0].oid;
    await pgPool.query(updateT3Query, [order]);
    res.redirect('/app/rider.html');
});

delRouter.post("/t4", async (req, res) => {
    const { rows } = await pgPool.query(getCurrentOrderQuery, [req.cookies.uid]);
    const order = rows[0].oid;
    await pgPool.query(updateT4Query, [order]);
    res.redirect('/app/rider.html');
});

function getWorkTime(string) {
    const period = string.slice(string.length - 2); // am OR pm
    const time = string.slice(0, string.length - 2);
    return (period.toLowerCase() === "am" ? (time === "12" ? "00" : time) : 
                                            time === "12" ? "12" : (parseInt(time) + 12)) + ":00:00";
}

function getDaysToNextMon(day_today) {
    if (day_today === 0) {
        return 8;
    } else {
        return 15 - day_today;
    }
} 

function addDays(val, date) {
    const temp_date = new Date(date);
    temp_date.setDate(temp_date.getDate() + val);
    return temp_date;
}

function getWorkDate(val) {
    const today = new Date();
    const day_today = today.getDay();
    const days_to_add = getDaysToNextMon(day_today) + parseInt(val);
    const date = addDays(days_to_add, today);
    return date.getDate() + '/' + (date.getMonth()+1) + '/' + date.getFullYear();
}

module.exports = delRouter;
