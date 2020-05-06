const express = require("express");
const auth = require("./auth");
const res = require("./restaurants");
const menu = require("./menu");
const ord = require("./orders");
const del = require("./delivery");
const cust = require("./customer");
const sum = require("./summary");
const monthsum = require("./monthly-summary");
const promosum = require("./promotion-summary");

const apiRouter = express.Router();

apiRouter.get("/health", (req, res) => {
    res.sendStatus(200);
});
apiRouter.use("/auth", auth);
apiRouter.use("/res", res);
apiRouter.use("/menu", menu);
apiRouter.use("/ord", ord);
apiRouter.use("/del", del);
apiRouter.use("/cust", cust);
apiRouter.use("/sum", sum);
apiRouter.use("/monthsum", monthsum);
apiRouter.use("/promosum", promosum);

module.exports = apiRouter;
