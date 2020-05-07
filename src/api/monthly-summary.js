const express = require("express");
const pgPool = require("../pg-pool");

const monthsumRouter = express.Router();

const getRestaurantFromStaff = 
    `SELECT rid FROM RestaurantStaff
     WHERE uid = $1`;

const TotalOrdersQuery = 
    `SELECT EXTRACT(month FROM order_time) AS month, COUNT(distinct oid) AS orders
    FROM Orders NATURAL JOIN FoodOrders NATURAL JOIN Food 
    WHERE rid = $1 GROUP BY EXTRACT(month FROM order_time)`;
const TotalCostQuery =
    `SELECT EXTRACT(month FROM order_time) AS month, SUM(qty*price) AS costs 
    FROM Orders NATURAL JOIN FoodOrders NATURAL JOIN Food 
    WHERE rid = $1 GROUP BY EXTRACT(month FROM order_time);`;
const FavoriteItemsQuery = 
    `SELECT name FROM 
    (SELECT fid FROM FoodOrders NATURAL JOIN Food WHERE rid = $1 GROUP BY fid ORDER BY SUM(qty) DESC LIMIT 5) 
    NATURAL JOIN Food;`;


monthsumRouter.get("/orders", async (req, res) => {
    const { rows: restaurant } = await pgPool.query(getRestaurantFromStaff, [req.cookies.uid]);
    const rid = restaurant[0].rid;
    const { rows: totalOrders } = await pgPool.query(TotalOrdersQuery, [rid]);
    const { rows: totalCost } = await pgPool.query(TotalCostQuery, [rid]);
    const { rows: FavouriteItems } = await pgPool.query(FavoriteItemsQuery, [rid]);
    /*
    const { rows: customers } = await pgPool.query(NewCustomersQuery);
    const { rows: orders } = await pgPool.query(TotalOrdersQuery, [rid]);
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
    */
    res.send(customers);
});

function formatDate(date) {
    var year = date.getFullYear(),
        month = monthNames[date.getMonth()];
        day = date.getDate(),
        hour = date.getHours();

    return `${day} ${month} ${year}`;
}

module.exports = monthsumRouter;