const monthNames = ["Jan", "Feb", "Mar", "Apr", "May", "Jun",
  "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];

function formatDate(date) {
    var year = date.getFullYear(),
        month = monthNames[date.getMonth()];
        day = date.getDate()

    return `${day} ${month} ${year}`;
}

$.ajax("/api/promo/allfds", { dataType: "json"}).done(promos => {
    promos.forEach(promo => {
        $("#promos").append(`
            <tr>
              <td>${promo.name}</td>
              <td>${formatDate(new Date(promo.start_date))}</td>
              <td>${formatDate(new Date(promo.end_date))}</td>
              <td>
                ${promo.discount_type === 0 ?
                    "Actual Discount" :
                    "Percentage Discount"}
              </td>
              <td>
                ${promo.discount_type === 0 ?
                    `$${promo.discount} off total cost (excluding delivery fee)` :
                    `${promo.discount}% off all food items`}
              </td>
              <td>${promo.total}</td>
            </tr>
        `);
    })
})