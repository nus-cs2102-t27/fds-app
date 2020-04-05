const express = require("express");

const apiRouter = express.Router();

apiRouter.get("/health", (req, res) => {
    res.sendStatus(200);
});

module.exports = apiRouter;
