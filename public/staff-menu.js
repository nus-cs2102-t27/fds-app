$("#staff-res-name").load("/api/res/name");

$.ajax("/api/menu/staffmenu", { dataType: "json"}).done(menu => {
    menu.forEach(food => {
        $("#staff-food").append(`
            <tr>
              <td>${food.name}</td>
              <td>${food.category}</td>
              <td>$${food.price}</td>
              <td>${food.food_limit}</td>
              <td>${food.total_sold}</td>
            </tr>
        `)
    });
})