$("#staff-res-name").load("/api/res/name");

$.ajax("/api/menu/staffmenu", { dataType: "json"}).done(menu => {
    menu.forEach(food => {
        $("#staff-food").append(`
            <div class="menu-row">
              <div class="m-name-column">${food.name}</div>
              <div class="m-category-column">${food.category}</div>
              <div class="m-price-column">$${food.price}</div>
              <div class="m-limit-column">${food.food_limit}</div>
              <div class="m-sold-column">${food.total_sold}</div>
              <div class="m-remove-column">
                <form class="menu-form" action="/api/menu/remove" method="post">
                  <input type="hidden" name="fid" value="${food.fid}">
                  <input type="submit" class="btn btn-danger submit-btn" value="Remove">
                </form>
              </div>
            </div>
            <hr>
        `)
    });
})