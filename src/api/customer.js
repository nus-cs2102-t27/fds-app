const express = require("express");
const pgPool = require("../pg-pool");

const custRouter = express.Router();

const accPointsQuery = `SELECT acc_points FROM Customers
                        WHERE uid = $1`;
const lastFiveDeliveryLocations = `SELECT LastFiveLocations($1)`;

custRouter.get("/points", async (req, res) => {
    const { rows } = await pgPool.query(accPointsQuery, [req.cookies.uid]);
    res.send(String(rows[0].acc_points));
});

custRouter.get("/locations", async (req, res) => {
    const { rows } = await pgPool.query(lastFiveDeliveryLocations, [req.cookies.uid]);
    res.send(rows);
})

module.exports = custRouter;