const rid = (new URL(location.href)).searchParams.get("rid");

$("#res-name").load(`/api/res/${rid}/name`);

const monthNames = ["Jan", "Feb", "Mar", "Apr", "May", "Jun",
  "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];

function formatDate(date) {
    var year = date.getFullYear(),
        month = monthNames[date.getMonth()];
        day = date.getDate();

    return `${day} ${month} ${year}`;
}

$.ajax(`/api/res/${rid}/reviews`).done(orders => {
    orders.forEach(order => {
        $("#reviews").append(`
            <tr>
              <td>${formatDate(new Date(order.order_time))}</td>
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