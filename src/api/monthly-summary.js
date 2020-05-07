const express = require("express");
const pgPool = require("../pg-pool");

const monthsumRouter = express.Router();

const getRestaurantID = 
    `SELECT rid FROM RestaurantStaff
    WHERE uid = $1`;

const restaurantMonthlySummaryQuery = 
    `WITH totOrder AS (SELECT rid, EXTRACT(month FROM order_time) AS month, COUNT(distinct oid) AS orders
    FROM Orders NATURAL JOIN FoodOrders NATURAL JOIN Food
    WHERE rid = $1 GROUP BY rid, EXTRACT(month FROM order_time)
    ), totCost AS (SELECT rid, EXTRACT(month FROM order_time) AS month, SUM(qty*price) AS costs 
    FROM Orders NATURAL JOIN FoodOrders NATURAL JOIN Food
    WHERE rid = $1 GROUP BY rid, EXTRACT(month FROM order_time)
    ), favItem AS (SELECT rid, fid, name FROM FoodOrders NATURAL JOIN Food 
    WHERE rid = $1 GROUP BY rid, fid, name ORDER BY SUM(qty) DESC LIMIT 5)
    SELECT distinct month, orders, costs, name 
    FROM totOrder NATURAL JOIN totCost NATURAL JOIN favItem`;

monthsumRouter.get("/orders", async (req, res) => {
    const { rows: restaurant } = await pgPool.query(getRestaurantID, [req.cookies.uid]);
    const rid = restaurant[0].rid;
    const { rows: monthlySummary } = await pgPool.query(restaurantMonthlySummaryQuery, [rid]);
    res.send(monthlySummary);
});

module.exports = monthsumRouter;