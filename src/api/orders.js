const express = require("express");
const pgPool = require("../pg-pool");

const ordRouter = express.Router();

const getUnreviewedOrdersQuery = `SELECT oid, order_time, SUM(price * qty) AS total_price
                                FROM FoodOrders NATURAL JOIN Food NATURAL JOIN Orders
                                WHERE uid = $1 AND review IS NULL
                                GROUP BY oid, order_time`;
const getOrdersQuery = `SELECT oid, order_time, SUM(price * qty) AS total_price
                        FROM FoodOrders NATURAL JOIN Food NATURAL JOIN Orders
                        WHERE uid = $1
                        GROUP BY oid, order_time`;
const getFoodInOrderQuery = `SELECT * FROM Food NATURAL JOIN FoodOrders WHERE oid = $1`;

ordRouter.get("/all", async (req, res) => {
    const { rows: orderRows } = await pgPool.query(getOrdersQuery, [req.cookies.uid]);
    const queries = orderRows.map((order) => pgPool.query(getFoodInOrderQuery, [order.oid]));
    for (let index in orderRows) {
        orderRows[index].food = (await queries[index]).rows;
    }

    res.send(orderRows);
})

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
})

module.exports = ordRouter;
