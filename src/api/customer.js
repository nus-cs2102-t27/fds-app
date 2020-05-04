const express = require("express");
const pgPool = require("../pg-pool");

const custRouter = express.Router();

const accPointsQuery = `SELECT acc_points FROM Customers
                        WHERE uid = $1`;

custRouter.get("/points", async (req, res) => {
    const { rows } = await pgPool.query(accPointsQuery, [req.cookies.uid]);
    res.send(String(rows[0].acc_points));
});

module.exports = custRouter;