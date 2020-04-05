const express = require("express");
const pgPool = require("../pg-pool");

const menuRouter = express.Router();

menuRouter.get("/:rid", async (req, res) => {
    const rid = req.params.rid;
    const { rows } = await pgPool.query(getFood(), [rid]);
    if (rows.length === 0) {
        console.log("No food found");
        res.sendStatus(404);
        return;
    }
    res.send(rows);
})

function getFood() {
    return "SELECT * FROM Food WHERE rid = $1";
}

module.exports = menuRouter;
