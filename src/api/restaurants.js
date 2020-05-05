const express = require("express");
const pgPool = require("../pg-pool");

const resRouter = express.Router();

const getRestaurantsQuery = "SELECT rid, name FROM Restaurants";
const getRestaurantQuery = "SELECT * FROM Restaurants WHERE rid = $1";
const getDeliveryFeeQuery = "SELECT delivery_fee FROM Restaurants WHERE rid = $1";
const getRestaurantFromStaff = `SELECT name, rid FROM RestaurantStaff NATURAL JOIN Restaurants
                                WHERE uid = $1`;
const getFoodInOrderQuery = `SELECT * FROM Food NATURAL JOIN FoodOrders WHERE oid = $1`;
const getCurrentRestaurantOrdersQuery = 
    `SELECT Orders.oid, order_time
     FROM Orders NATURAL JOIN FoodOrders NATURAL JOIN Food
     LEFT OUTER JOIN Deliveries
     ON Orders.oid = Deliveries.oid
     WHERE rid = $1 AND (
         Orders.oid NOT IN (SELECT oid FROM Deliveries) OR
         t3 IS NULL
     )
     GROUP BY Orders.oid, order_time`;
const getRestaurantReviews =
    `SELECT u.name, o.oid, order_time, review
     FROM Orders o NATURAL JOIN FoodOrders fo NATURAL JOIN Food f
     INNER JOIN Users u ON o.uid = u.uid
     WHERE rid = $1 AND review IS NOT NULL
     GROUP BY u.name, o.oid, order_time, review`;

resRouter.get("/all", async (req, res) => {
    const { rows } = await pgPool.query(getRestaurantsQuery);
    res.send(rows);
});

resRouter.get("/name", async (req, res) => {
    const { rows } = await pgPool.query(getRestaurantFromStaff, [req.cookies.uid]);
    res.send(rows[0].name);
});

resRouter.get("/current", async (req, res) => {
    const { rows: restaurant } = await pgPool.query(getRestaurantFromStaff, [req.cookies.uid]);
    rid = restaurant[0].rid;
    const { rows: orderRows } = await pgPool.query(getCurrentRestaurantOrdersQuery, [rid]);
    const queries = orderRows.map((order) => pgPool.query(getFoodInOrderQuery, [order.oid]));
    for (let index in orderRows) {
        orderRows[index].food = (await queries[index]).rows;
    }

    res.send(orderRows);
});

resRouter.get("/resreviews", async (req, res) => {
    const { rows: restaurant } = await pgPool.query(getRestaurantFromStaff, [req.cookies.uid]);
    rid = restaurant[0].rid;
    const { rows: orderRows } = await pgPool.query(getRestaurantReviews, [rid]);
    const queries = orderRows.map((order) => pgPool.query(getFoodInOrderQuery, [order.oid]));
    for (let index in orderRows) {
        orderRows[index].food = (await queries[index]).rows;
    }

    res.send(orderRows);
});

resRouter.get("/:rid", async (req, res) => {
    const { rows } = await pgPool.query(getRestaurantQuery, [req.params.rid]);
    if (rows.length === 0) {
        console.log("No such restaurant");
        res.sendStatus(404);
        return;
    }
    res.send(rows[0]);
});

resRouter.get("/:rid/deliveryfee", async (req, res) => {
    const { rows } = await pgPool.query(getDeliveryFeeQuery, [req.params.rid]);
    res.send(String(rows[0].delivery_fee));
});

resRouter.get("/:rid/reviews", async (req, res) => {
    const { rows: orderRows } = await pgPool.query(getRestaurantReviews, [req.params.rid]);
    const queries = orderRows.map((order) => pgPool.query(getFoodInOrderQuery, [order.oid]));
    for (let index in orderRows) {
        orderRows[index].food = (await queries[index]).rows;
    }

    res.send(orderRows);
});

resRouter.get("/:rid/:col", async (req, res) => {
    const { rows } = await pgPool.query(getRestaurantQuery, [req.params.rid]);
    if (rows.length === 0) {
        console.log("No such restaurant");
        res.sendStatus(404);
        return;
    }
    const col = req.params.col;
    if (!(col in rows[0])) {
        console.log(`column ${col} does not exist`);
        res.sendStatus(404);
        return;
    }
    res.send(rows[0][col]);
});

module.exports = resRouter;
