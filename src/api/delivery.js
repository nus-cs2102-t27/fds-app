const express = require("express");
const pgPool = require("../pg-pool");

const delRouter = express.Router();

const getDeliveriesQuery = 
    `SELECT oid, rating, t1, t2, t3, t4, R.name
     FROM Deliveries
     NATURAL JOIN FoodOrders NATURAL JOIN Food
     INNER JOIN Restaurants R
     ON Food.rid = R.rid
     GROUP BY oid, rating, t1, t2, t3, t4, R.name
     HAVING uid = $1`;
const getFoodInOrderQuery = `SELECT * FROM Food NATURAL JOIN FoodOrders WHERE oid = $1`;
const getOrdersQuery = 
    `SELECT oid, order_time, Restaurants.name as restaurant, location
     FROM Orders NATURAL JOIN FoodOrders
     NATURAL JOIN Food INNER JOIN Restaurants
     ON Food.rid = Restaurants.rid
     WHERE oid NOT IN (
         SELECT DISTINCT oid FROM Deliveries
     )
     ORDER BY order_time ASC`;

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
