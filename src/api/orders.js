const express = require("express");
const pgPool = require("../pg-pool");

const ordRouter = express.Router();

const getUnreviewedOrdersQuery = 
    `SELECT oid, order_time, Restaurants.name as restaurant, SUM(price * qty) AS total_price
     FROM FoodOrders NATURAL JOIN Food NATURAL JOIN Orders
     INNER JOIN Restaurants
     ON Food.rid = Restaurants.rid
     WHERE uid = $1 AND review IS NULL AND oid IN (
         SELECT oid FROM Deliveries
     )
     GROUP BY oid, order_time, Restaurants.name`;
const getOrdersQuery = 
    `SELECT oid, order_time, Restaurants.rid, Restaurants.name as restaurant, discount, review, SUM(price * qty) AS total_price
     FROM FoodOrders NATURAL JOIN Food NATURAL JOIN Orders
     INNER JOIN Restaurants
     ON Food.rid = Restaurants.rid
     WHERE uid = $1
     GROUP BY oid, order_time, Restaurants.rid, Restaurants.name, discount, review`;
const getFoodInOrderQuery = `SELECT * FROM Food NATURAL JOIN FoodOrders WHERE oid = $1`;
const addReviewQuery = `UPDATE Orders SET review = $2 WHERE oid = $1`;
const addRatingQuery = `UPDATE Deliveries SET rating = $2 WHERE oid = $1`;
const addOrderQuery = `SELECT NewOrder($1, $2, $3, $4, $5, $6, $7)`;
const getUserDefaultPayment = `SELECT default_payment FROM Customers WHERE uid = $1`;
const getRestaurantDeliveryFee = `SELECT delivery_fee FROM Restaurants WHERE rid = $1`;

ordRouter.get("/all", async (req, res) => {
    const { rows: orderRows } = await pgPool.query(getOrdersQuery, [req.cookies.uid]);
    const queries = orderRows.map((order) => pgPool.query(getFoodInOrderQuery, [order.oid]));
    for (let index in orderRows) {
        orderRows[index].food = (await queries[index]).rows;
    }
    const queries2 = orderRows.map((order) => pgPool.query(getRestaurantDeliveryFee, [order.rid]));
    for (let index in orderRows) {
        orderRows[index].delivery_fee = (await queries2[index]).rows[0].delivery_fee;
        // orderRows[index].total_price = (parseFloat(orderRows[index].total_price) + parseFloat(orderRows[index].delivery_fee)).toFixed(2);
        console.log(orderRows[index].discount)
        if (orderRows[index].discount === "") {
            orderRows[index].discount = "  -";
            continue;
        }

        let value = 0;
        if (!isNaN(orderRows[index].discount)) {
            // redeemed points
            value = parseFloat(orderRows[index].discount);
        } else {
            const arr = orderRows[index].discount.split(",");
            const promo_type = arr[0];
            const discount_type = arr[1];
            const discount = arr[2];
            switch (promo_type) {
                case "0":
                    value = discount_type === "0" ? discount : parseInt(discount)/100 * orderRows[index].delivery_fee;
                    console.log("value", value);
                    break;
                case "1":
                    value = discount_type === "0" ? discount : parseInt(discount)/100 * orderRows[index].total_price;
                    break;
            }
        }
        orderRows[index].discount = String(parseFloat(value).toFixed(2));
    }

    res.send(orderRows);
});

ordRouter.get("/review", async (req, res) => {
    const { rows: orderRows } = await pgPool.query(getUnreviewedOrdersQuery, [req.cookies.uid]);
    const queries = orderRows.map((order) => pgPool.query(getFoodInOrderQuery, [order.oid]));
    for (let index in orderRows) {
        orderRows[index].food = (await queries[index]).rows;
    }

    res.send(orderRows);
});

ordRouter.post("/", async (req, res) => {
    try{
    const { location } = req.body;
    let { discount_type, discount_value, payment } = req.body;
    let promo = null;
    let discount = "";
    let usedpoints = 0;
    const foods = {};
    for (const fid in req.body) {
        if (!isNaN(fid) && req.body[fid] !== '0') {
            foods[fid] = req.body[fid];
        }
    }

    if (discount_type === "Promo ID") {
        promo = discount_value;
        const { rows } = await pgPool.query(`SELECT * FROM Promos WHERE pid = $1`, [promo]);
        const p = rows[0];
        discount = [p.promo_type, p.discount_type, p.discount].join(",");
        console.log(discount);
    }

    if (discount_type === "Redeem Points") {
        usedpoints = discount_value;
        discount = String(usedpoints/100);
    }

    if (payment === 2) { // if payment is Default
        payment = getDefaultPayment(req.cookies.uid);
    }

    let hstore = "";
    let isFirst = true;

    for (const food in foods) {
        const string = '"' + food + '"=>"' + foods[food] + '"';
        if (isFirst) {
            isFirst = false;
            hstore = string;
        } else {
            hstore = hstore.concat(',' + string);
        }
    }

    await pgPool.query(addOrderQuery, [req.cookies.uid, location, promo, payment, usedpoints, discount, hstore]);
    res.redirect('/app/order-success.html');
}catch(e){
    console.log(e);
}
});

ordRouter.post("/makereview", async (req, res) => {
    const { oid, review, rating } = req.body;
    await pgPool.query(addReviewQuery, [oid, review]);
    await pgPool.query(addRatingQuery, [oid, rating]);
    res.redirect('/app/review-success.html');
    return;
});

async function getDefaultPayment(uid) {
    const { rows } = await pgPool.query(getUserDefaultPayment, [uid]);
    return rows[0].default_payment;
}

module.exports = ordRouter;
