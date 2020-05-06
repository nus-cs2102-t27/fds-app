$.ajax("/api/res/categories").done(categories => {
  categories.forEach(category => {
    $("#category").append(`
      <option value='${category.category}'>${category.category}</option>
    `);
  })
})

$("#category").change(() => {
    $.ajax("/api/res/cat/" + $("#category").val()).done(res => {
        $("#restaurants").empty();
        res.forEach(restaurant => {
            $("#restaurants").append(`
                <a href="/app/menu.html?rid=${restaurant.rid}">${restaurant.name}</a>
                <a href="/app/reviews.html?rid=${restaurant.rid}">Reviews</a>
           `);
        })
    })
})