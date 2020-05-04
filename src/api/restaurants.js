const express = require("express");
const pgPool = require("../pg-pool");

const resRouter = express.Router();

const getRestaurantsQuery = "SELECT rid, name FROM Restaurants";
const getRestaurantQuery = "SELECT * FROM Restaurants WHERE rid = $1";
const getDeliveryFeeQuery = "SELECT delivery_fee FROM Restaurants WHERE rid = $1";

resRouter.get("/all", async (req, res) => {
    const { rows } = await pgPool.query(getRestaurantsQuery);
    res.send(rows);
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
