const express = require("express");
const api = require("./api");

const app = express();

app.use("/app", express.static("public"));
app.use("/api", api);

app.listen(3000, () => {
    console.log("listening on port 3000")
});
