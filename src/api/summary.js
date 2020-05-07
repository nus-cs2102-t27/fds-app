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

const CustomerOrdersQuery = 
    `SELECT EXTRACT(month FROM order_time) AS month, uid, COUNT(*) AS orders
    FROM Orders
    GROUP BY EXTRACT(month FROM order_time), uid
    ORDER BY uid`;
const CustomerCostQuery = 
    `SELECT EXTRACT (month FROM order_time) AS month, uid, SUM(qty*price) AS costs
    FROM Orders NATURAL JOIN FoodOrders NATURAL JOIN Food
    GROUP BY EXTRACT(month FROM order_time), uid
    ORDER BY uid`;

const LocationOrdersQuery = 
    `SELECT EXTRACT(hour FROM order_time) AS hour, location, COUNT(*) AS orders
    FROM Orders
    GROUP BY EXTRACT(hour FROM order_time), location
    ORDER BY location`;

const RiderOrdersDeliveredQuery = 
    `SELECT uid, EXTRACT(month FROM t1) as month, COUNT(*) AS orders_delivered
    FROM Riders NATURAL JOIN Deliveries
    GROUP BY uid, EXTRACT(month FROM t1)
    ORDER BY uid`;

// SELECT DATE_PART('day', '2020-05-05 18:00:00'::timestamp - '2020-05-05 12:00:00'::timestamp) * 24 + 
//                 DATE_PART('hour', '2020-05-05 18:00:00'::timestamp - '2020-05-05 12:00:00'::timestamp) as hrs;
const RiderHoursWorkedQuery = 
    `SELECT uid, EXTRACT(month FROM date_joined) AS month,
    CASE
    WHEN uid in (SELECT uid FROM FTRiders)
    THEN (40 * 4)
    WHEN uid in (SELECT uid FROM PTRiders)
    THEN SUM((SELECT DATE_PART('day', start_time::timestamp - end_time::timestamp) * 24 + 
                    DATE_PART('hour', start_time::timestamp - end_time::timestamp)
                    FROM PTWorkSchedules P
                    WHERE uid = P.uid))
    else 0
    END AS Hours_Worked
    FROM Users NATURAL JOIN Riders NATURAL JOIN FTWorkSchedules NATURAL JOIN PTWorkSchedules`;
const RiderSalaryQuery = 
    `SELECT uid, EXTRACT(month FROM date_joined) AS month
    CASE
    WHEN uid in (SELECT uid FROM FTRiders)
    THEN (SELECT monthly_base_salary FROM FTRiders F WHERE uid = F.uid)`;
const RiderDeliveryTimeQuery = 0;
const RiderRatingsQuery = 0;
const RiderAverageRatingsQuery = 0;

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

function formatDate(date) {
    var year = date.getFullYear(),
        month = monthNames[date.getMonth()];
        day = date.getDate(),
        hour = date.getHours();

    return `${day} ${month} ${year}`;
}

module.exports = sumRouter;