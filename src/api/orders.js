const express = require("express");
const pgPool = require("../pg-pool");

const ordRouter = express.Router();

const getUnreviewedOrdersQuery = `SELECT oid, order_time, Restaurants.name as restaurant, SUM(price * qty) AS total_price
                                FROM FoodOrders NATURAL JOIN Food NATURAL JOIN Orders
                                INNER JOIN Restaurants
                                ON Food.rid = Restaurants.rid
                                WHERE uid = $1 AND review IS NULL AND oid IN (
                                    SELECT oid FROM Deliveries
                                )
                                GROUP BY oid, order_time, Restaurants.name`;
const getOrdersQuery = `SELECT oid, order_time, Restaurants.name as restaurant, review, SUM(price * qty) AS total_price
                        FROM FoodOrders NATURAL JOIN Food NATURAL JOIN Orders
                        INNER JOIN Restaurants
                        ON Food.rid = Restaurants.rid
                        WHERE uid = $1
                        GROUP BY oid, order_time, Restaurants.name, review`;
const getFoodInOrderQuery = `SELECT * FROM Food NATURAL JOIN FoodOrders WHERE oid = $1`;
const addReviewQuery = `UPDATE Orders SET review = $2 WHERE oid = $1`;
const addRatingQuery = `UPDATE Deliveries SET rating = $2 WHERE oid = $1`;
ordRouter.get("/all", async (req, res) => {
    const { rows: orderRows } = await pgPool.query(getOrdersQuery, [req.cookies.uid]);
    const queries = orderRows.map((order) => pgPool.query(getFoodInOrderQuery, [order.oid]));
    for (let index in orderRows) {
        orderRows[index].food = (await queries[index]).rows;
    }

    res.send(orderRows);
});

ordRouter.get("/review", async (req, res) => {
    const { rows: orderRows } = await pgPool.query(getUnreviewedOrdersQuery, [req.cookies.uid]);
    const queries = orderRows.map((order) => pgPool.query(getFoodInOrderQuery, [order.oid]));
    for (let index in orderRows) {
        orderRows[index].food = (await queries[index]).rows;
    }

    res.send(orderRows);
})

ordRouter.post("/", async (req, res) => {
	console.log(req.cookies.uid);
    console.log(req.body);
    
	res.sendStatus(201);
});

ordRouter.post("/makereview", async (req, res) => {
    const { oid, review, rating } = req.body;
    await pgPool.query(addReviewQuery, [oid, review]);
    await pgPool.query(addRatingQuery, [oid, rating]);
    res.redirect('/app/review-success.html');
    return;
});

module.exports = ordRouter;
