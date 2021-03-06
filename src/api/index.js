const express = require("express");
const auth = require("./auth");
const res = require("./restaurants");
const menu = require("./menu");
const ord = require("./orders");
const del = require("./delivery");
const cust = require("./customer");
const rid = require("./rider");
const sum = require("./summary");
const ptridersum = require("./ptrider-summary");
const ftridersum = require("./ftrider-summary");
const promo = require("./promo");
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
apiRouter.use("/rid", rid);
apiRouter.use("/sum", sum);
apiRouter.use("/ptridersum", ptridersum);
apiRouter.use("/ftridersum", ftridersum);
apiRouter.use("/promo", promo);
apiRouter.use("/monthsum", monthsum);
apiRouter.use("/promosum", promosum);

module.exports = apiRouter;
