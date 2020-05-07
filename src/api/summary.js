const express = require("express");
const pgPool = require("../pg-pool");

const sumRouter = express.Router();

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

sumRouter.get("/status", async (req, res) => {
    const { rows } = await pgPool.query(StatusQuery);
    res.send(rows[0].atleastfiveusers);
});

function formatDate(date) {
    var year = date.getFullYear(),
        month = monthNames[date.getMonth()];
        day = date.getDate(),
        hour = date.getHours();

    return `${day} ${month} ${year}`;
}

module.exports = sumRouter;