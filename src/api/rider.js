const express = require("express");
const pgPool = require("../pg-pool");

const ridRouter = express.Router();

const FTStatusQuery = `SELECT FTWorkingNow($1)`;
const PTStatusQuery = 
    `SELECT * FROM PTWorkSchedules
     WHERE uid = $1 AND start_time < now() AND end_time > now()`;

ridRouter.get("/ftwork", async (req, res) => {
    const { rows } = await pgPool.query(FTStatusQuery, [req.cookies.uid]);
    console.log(rows);
    res.send(rows[0].ftworkingnow);
});

ridRouter.get("/ptwork", async (req, res) => {
    const { rows } = await pgPool.query(PTStatusQuery, [req.cookies.uid]);
    if (rows.length === 0) {
        res.send(false);
    } else {
        res.send(true);
    }
})

module.exports = ridRouter;