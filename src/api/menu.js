const express = require("express");
const pgPool = require("../pg-pool");

const menuRouter = express.Router();

const getFoodQuery = `SELECT * FROM GetFood($1)`;
const getFoodForStaff = 
    `SELECT f.fid, name, category, price, food_limit, 
     COALESCE(sum(qty), 0) as total_sold
     FROM Food f LEFT OUTER JOIN FoodOrders fo
     ON f.fid = fo.fid
     WHERE rid = $1 AND isRemoved = False
     GROUP BY f.fid, name, category, price, food_limit
     ORDER BY fid`;
const getRestaurantFromStaff = 
    `SELECT rid FROM RestaurantStaff
     WHERE uid = $1`;
const RemoveFood = 
    `UPDATE Food
    SET isRemoved = True
    WHERE fid = $1`;
const AddFood =
    `INSERT INTO Food(rid, name, category, price, food_limit, isRemoved)
     VALUES ($1, $2, $3, $4, $5, False)`;

menuRouter.get("/staffmenu", async (req, res) => {
    const { rows: restaurant } = await pgPool.query(getRestaurantFromStaff, [req.cookies.uid]);
    const rid = restaurant[0].rid;
    const { rows } = await pgPool.query(getFoodForStaff, [rid]);
    res.send(rows);
});

menuRouter.post("/remove", async (req, res) => {
    const { fid } = req.body;
    await pgPool.query(RemoveFood, [fid]);
    res.redirect('/app/modify-menu.html');
});

menuRouter.post("/new", async (req, res) => {
    const { rows: restaurant } = await pgPool.query(getRestaurantFromStaff, [req.cookies.uid]);
    const rid = restaurant[0].rid;
    const { name, category, price, food_limit } = req.body;
    await pgPool.query(AddFood, [rid, name, category, parseFloat(price), parseInt(food_limit)]);
    res.redirect('/app/modify-menu.html');
})

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
