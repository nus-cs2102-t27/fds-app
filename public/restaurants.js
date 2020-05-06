$.ajax("/api/res/categories").done(categories => {
  categories.forEach(category => {
    $("#category").append(`
      <option value='${category.category}'>${category.category}</option>
    `);
  });
});

$.ajax("/api/res/all/").done(res => populateRestaurants(res));

$("#category").change(() => {
    $.ajax("/api/res/cat/" + $("#category").val()).done(res => {
        $("#restaurants").empty();
        populateRestaurants(res);
    });
});

function populateRestaurants(res) {
  res.forEach(restaurant => {
      $("#restaurants").append(`
          <a href="/app/menu.html?rid=${restaurant.rid}">${restaurant.name}</a>
          <a href="/app/reviews.html?rid=${restaurant.rid}">Reviews</a>
     `);
  });
}