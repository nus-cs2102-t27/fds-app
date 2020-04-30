const express = require("express");
const pgPool = require("../pg-pool");

const delRouter = express.Router();

const getDeliveriesQuery = `SELECT oid, rating, t1, t2, t3, t4, R.name
                         FROM Deliveries
                         NATURAL JOIN FoodOrders NATURAL JOIN Food
                         INNER JOIN Restaurants R
                         ON Food.rid = R.rid
                         GROUP BY oid, rating, t1, t2, t3, t4, R.name
                         HAVING uid = $1`;
const getFoodInOrderQuery = `SELECT * FROM Food NATURAL JOIN FoodOrders WHERE oid = $1`;

delRouter.get("/all", async (req, res) => {
    const { rows: deliveryRows } = await pgPool.query(getDeliveriesQuery, [req.cookies.uid]);
    const queries = deliveryRows.map((delivery) => pgPool.query(getFoodInOrderQuery, [delivery.oid]));
    for (let index in deliveryRows) {
        deliveryRows[index].food = (await queries[index]).rows;
    }

    res.send(deliveryRows);
})

module.exports = delRouter;
