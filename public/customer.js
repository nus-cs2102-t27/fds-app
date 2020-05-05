let status = "";

$("#cust-name").load("/api/auth/me/name");

$.ajax("/api/del/custstatus").done(s => {
    status = s;
    $("#status").text(status);
    if (status === "Your delivery has arrived!") {
        $("#cust-button").append(`
            <form action="/api/del/collect" method="post">
                <input class="btn btn-success submit-btn" type="submit" value="Collected Order"></input>
            </form`);
    }

    if (status === "No current order") {
        $("#cust-order").append(`
            <a href="/app/restaurants.html">Make an order</a>
        `);
    }
});