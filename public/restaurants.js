$.ajax("/api/res/all", { dataType: "json" }).done(res => {
    res.forEach(restaurant => {
        $("#restaurants").append(`
            <a href="/app/menu.html?rid=${restaurant.rid}">${restaurant.name}</a>
            <a href="/app/reviews.html?rid=${restaurant.rid}">Reviews</a>
        `);
    })
})