const express = require("express");
const pgPool = require("../pg-pool");

const promoRouter = express.Router();

const addRPromoQuery = `SELECT NewRPromo($1, $2, $3, $4, $5)`;
const addFDSPromoQuery = `SELECT NewFDSPromo($1, $2, $3, $4, $5)`;
const getAllRestaurantPromos = 
    `SELECT * FROM Promos NATURAL JOIN RPromos
     NATURAL JOIN RestaurantStaff NATURAL JOIN Users
     WHERE rid = $1 ORDER BY start_date DESC`;
const getAllFDSPromos = 
    `SELECT * FROM Promos NATURAL JOIN FDSPromos
     NATURAL JOIN FDSManagers NATURAL JOIN Users
     ORDER BY start_date DESC`;
const getRestaurantFromStaff = `SELECT rid FROM RestaurantStaff WHERE uid = $1`;
const getOrdersByPromo = `SELECT COUNT(*) FROM Orders WHERE pid = $1`;

promoRouter.post("/res", async (req, res) => {
    const {
        start,
        end,
        promo_type,
        discount
    } = req.body;
    await pgPool.query(addRPromoQuery, [req.cookies.uid, start, end, promo_type, discount]);
    res.redirect('/app/rpromo.html');
});

promoRouter.post("/fds", async (req, res) => {
    const {
        start,
        end,
        promo_type,
        discount
    } = req.body;
    await pgPool.query(addFDSPromoQuery, [req.cookies.uid, start, end, promo_type, discount]);
    res.redirect('/app/fdspromo.html');
});

promoRouter.get("/allres", async (req, res) => {
    const { rows: restaurant } = await pgPool.query(getRestaurantFromStaff, [req.cookies.uid]);
    const rid = restaurant[0].rid;
    const { rows: promos }  = await pgPool.query(getAllRestaurantPromos, [rid]);
    for (let index in promos) {
        const pid = promos[index].pid;
        const { rows: total_orders } = await pgPool.query(getOrdersByPromo, [pid]);
        promos[index].total = total_orders[0].count;
    }
    res.send(promos);
});

promoRouter.get("/allfds", async (req, res) => {
    const { rows: promos }  = await pgPool.query(getAllFDSPromos);
    for (let index in promos) {
        const pid = promos[index].pid;
        const { rows: total_orders } = await pgPool.query(getOrdersByPromo, [pid]);
        promos[index].total = total_orders[0].count;
    }
    res.send(promos);
});

module.exports = promoRouter;