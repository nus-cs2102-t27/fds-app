const express = require("express");
const pgPool = require("../pg-pool");

const menuRouter = express.Router();

const getFoodQuery = `SELECT * FROM GetFood($1)`;
const getFoodForStaff = `SELECT f.fid, name, category, price, food_limit, 
                         COALESCE(sum(qty), 0) as total_sold
                         FROM Food f LEFT OUTER JOIN FoodOrders fo
                         ON f.fid = fo.fid
                         WHERE rid = $1
                         GROUP BY f.fid, name, category, price, food_limit
                         ORDER BY fid`;
const getRestaurantFromStaff = `SELECT rid FROM RestaurantStaff
                                WHERE uid = $1`;

menuRouter.get("/staffmenu", async (req, res) => {
    const { rows: restaurant } = await pgPool.query(getRestaurantFromStaff, [req.cookies.uid]);
    const rid = restaurant[0].rid;
    const { rows } = await pgPool.query(getFoodForStaff, [rid]);
    res.send(rows);
});

menuRouter.get("/:rid", async (req, res) => {
    const rid = req.params.rid;
    const { rows } = await pgPool.query(getFoodQuery, [rid]);
    if (rows.length === 0) {
        console.log("No food found");
        res.sendStatus(404);
        return;
    }
    res.send(rows);
});


module.exports = menuRouter;
