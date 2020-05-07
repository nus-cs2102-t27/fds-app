const express = require("express");
const pgPool = require("../pg-pool");

const sumRouter = express.Router();

// 1.For each month, the total number of new customers, the total number of orders, and the total
// cost of all orders
// 2.For each month and for each customer who has placed some order for that month,
// the total number of orders placed by the customer for that month and the total cost of all
// these orders.
// 3. For each hour and for each delivery location area, the total number of orders placed at that
// hour for that location area.
// 4. For each rider and for each month, the total number of orders delivered by the rider for that
// month, the total number of hours worked by the rider for that month, the total salary earned
// by the rider for that month, the average delivery time by the rider for that month, the number
// of ratings received by the rider for all the orders delivered for that month,
const NewCustomersQuery =
    `SELECT EXTRACT(month FROM date_joined) AS month, COUNT(*) AS customers
     FROM Customers NATURAL JOIN Users GROUP BY EXTRACT(month FROM date_joined)`;
const OrdersQuery = 
    `SELECT EXTRACT(month FROM order_time) AS month, COUNT(*) AS orders
    FROM Orders GROUP BY EXTRACT(month FROM order_time)`;
const CostQuery = 
    `SELECT EXTRACT(month FROM order_time) AS month, SUM(qty*price) AS costs
    FROM Orders NATURAL JOIN FoodOrders NATURAL JOIN Food
    GROUP BY EXTRACT(month FROM order_time)`;
const StatusQuery =
    `SELECT AtLeastFiveUsers()`;

const CustOrderSummaryQuery =
    `WITH CO AS (
        SELECT EXTRACT(month FROM order_time) AS month, uid, name, COUNT(*) AS orders
        FROM Orders NATURAL JOIN Users
        GROUP BY EXTRACT(month FROM order_time), uid, name
        ORDER BY uid
    ), CC AS (
        SELECT EXTRACT (month FROM order_time) AS month, uid, SUM(qty*price) AS costs
        FROM Orders NATURAL JOIN FoodOrders NATURAL JOIN Food
        GROUP BY EXTRACT(month FROM order_time), uid
        ORDER BY uid, month
    )
    SELECT uid, name, month, orders, costs FROM CO NATURAL JOIN CC`;

const LocationOrdersQuery = 
    `SELECT EXTRACT (month FROM order_time) AS month, EXTRACT (day FROM order_time) AS day, 
    EXTRACT (hour FROM order_time) AS hour, location, COUNT(*) AS orders
    FROM Orders
    GROUP BY EXTRACT (month FROM order_time), EXTRACT(day FROM order_time), EXTRACT(hour FROM order_time), location
    ORDER BY month, day, hour`;

const RiderSummaryQuery = 
    `WITH ROD AS (SELECT uid, name, EXTRACT(month FROM t1) as month, COUNT(*) AS orders_delivered
    FROM Riders NATURAL JOIN Deliveries NATURAL JOIN Users
    GROUP BY uid, EXTRACT(month FROM t1), name
    ORDER BY uid
    ), RHW AS (WITH sch AS (SELECT uid, EXTRACT(month FROM start_time) as month,
    SUM(DATE_PART('hour', end_time::timestamp - start_time::timestamp)) as hrs
    FROM Riders NATURAL JOIN PTWorkSchedules 
    GROUP BY uid, EXTRACT(month FROM start_time)
    UNION
    SELECT f.uid, EXTRACT(month FROM start_time) , (40 * 4) 
    FROM riders NATURAL JOIN FTWorkSchedules f, PTWorkSchedules
    GROUP BY f.uid, EXTRACT(month FROM start_time))
    SELECT DISTINCT Riders.uid, sch.month,
    CASE
    WHEN Riders.uid IN (SELECT uid FROM sch)
    THEN (SELECT hrs FROM sch s WHERE Riders.uid = s.uid AND s.month = sch.month)
    ELSE 0
    END AS hrs
    FROM Riders, sch
    ORDER BY uid
    ), RS AS (WITH sal AS (SELECT uid, EXTRACT(month FROM t1) AS month, monthly_base_salary + 2 * COUNT(*) AS monthly_salary
    FROM FTRiders NATURAL JOIN Deliveries GROUP BY uid, EXTRACT(month FROM t1)
    UNION
    SELECT uid, EXTRACT(month FROM t1) AS month, 4 * weekly_base_salary + 2 * COUNT(*) AS monthly_salary
    FROM PTRiders NATURAL JOIN Deliveries GROUP BY uid, EXTRACT(month FROM t1))
    SELECT DISTINCT Riders.uid, sal.month,
    CASE
    WHEN (Riders.uid IN (SELECT uid FROM sal) AND sal.month IN (SELECT month FROM sal WHERE Riders.uid = sal.uid))
    THEN (SELECT monthly_salary FROM sal s WHERE Riders.uid = s.uid AND s.month = sal.month)
    WHEN Riders.uid in (SELECT uid FROM FTRiders)
    THEN (SELECT monthly_base_salary FROM FTRiders F WHERE Riders.uid = F.uid)
    WHEN Riders.uid in (SELECT uid FROM PTRiders)
    THEN 4 * (SELECT weekly_base_salary FROM PTRiders P WHERE Riders.uid = P.uid)
    ELSE 0
    END AS monthly_salary
    FROM Riders, sal
    ORDER BY uid
    ), RD AS (SELECT R.uid, EXTRACT(month FROM t1) as month, COALESCE(COUNT(D.uid),0) AS orders_delivered,
    COALESCE(ROUND((SUM(DATE_PART('minute', t4::timestamp - t1::timestamp)) / COUNT(*))::numeric, 1),0) AS average_delivery_time
    FROM Riders R LEFT OUTER JOIN Deliveries D
    ON R.uid = D.uid
    GROUP BY R.uid, EXTRACT(month FROM t1)
    ORDER BY R.uid
    ), RR AS (SELECT DISTINCT R.uid, COALESCE(D.rating, 'NIL') AS ratings
    FROM Riders R LEFT OUTER JOIN Deliveries D
    ON R.uid = D.uid
    ORDER BY R.uid)
    SELECT uid, name, month, orders_delivered, hrs AS hours_worked, average_delivery_time, monthly_salary, ratings
    FROM ROD NATURAL JOIN RHW NATURAL JOIN RS NATURAL JOIN RD NATURAL JOIN RR`;

sumRouter.get("/cust", async (req, res) => {
    const { rows: customers } = await pgPool.query(NewCustomersQuery);
    const { rows: orders } = await pgPool.query(OrdersQuery);
    const { rows: costs } = await pgPool.query(CostQuery);
    for (let custIndex in customers) {
        for (let ordIndex in orders) {
            if (customers[custIndex].month === orders[ordIndex].month) {
                customers[custIndex].orders = orders[ordIndex].orders;
            }
        }
        if (!customers[custIndex].orders) {
            customers[custIndex].orders = 0;
        }
    }
    for (let custIndex in customers) {
        for (let costIndex in costs) {
            if (customers[custIndex].month === costs[costIndex].month) {
                customers[custIndex].costs = costs[costIndex].costs;
            }
        }
        if (!customers[custIndex].costs) {
            customers[custIndex].costs = 0;
        }
    }
    res.send(customers);
});

sumRouter.get("/custOrder", async(req, res) => {
    const { rows: custOrdersNumber } = await pgPool.query(CustOrderSummaryQuery);
    console.log(custOrdersNumber);
    res.send(custOrdersNumber);
});

sumRouter.get("/loc", async(req, res) => {
    const { rows: locationOrders } = await pgPool.query(LocationOrdersQuery);
    console.log(locationOrders);
    res.send(locationOrders);
});

sumRouter.get("/riderSumm", async(req, res) => {
    const { rows: riderSummary } = await pgPool.query(RiderSummaryQuery);
    console.log(riderSummary);
    res.send(riderSummary);
});

sumRouter.get("/status", async (req, res) => {
    const { rows } = await pgPool.query(StatusQuery);
    res.send(rows[0]);
});

function formatDate(date) {
    var year = date.getFullYear(),
        month = monthNames[date.getMonth()];
        day = date.getDate(),
        hour = date.getHours();

    return `${day} ${month} ${year}`;
}

module.exports = sumRouter;