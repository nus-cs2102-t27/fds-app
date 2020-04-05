const express = require("express");
const pgPool = require("../pg-pool");

const resRouter = express.Router();

resRouter.get("/all", async (req, res) => {
    const { rows } = await pgPool.query(getRestaurants());
    if (rows.length === 0) {
        console.log("No restaurants found");
        res.sendStatus(404);
        return;
    }
    res.send(rows);
})

function getRestaurants() {
    return "SELECT rid, name FROM Restaurants";
}

module.exports = resRouter;