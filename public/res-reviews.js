$.ajax("/api/res/resreviews").done(orders => {
    orders.forEach(order => {
        $("#reviews").append(`
            <tr>
              <td>${order.name}</td>
              <td>
                <table class="table-borderless">
                  ${order.food.map((f) => `
                    <tr>
                      <td>${f.qty} x ${f.name}</td>
                      <td>$${f.price}</td>
                    </tr>
                  `).join("")}
                </table>
              </td>
              <td>${order.review}</td>
            </tr>
        `);
    })
})