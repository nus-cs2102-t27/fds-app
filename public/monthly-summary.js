$.ajax(`/api/monthsum/orders`, { dataType: "json" }).done(rows => {
    rows.forEach(row => {
        $("#staffmonthlysummary").append(`
            <tr>
              <td>${monthNames[row.month]}</td>
              <td>${row.orders}</td>
              <td>$${row.costs}</td>
              <td>${row.name}</td>
            </tr>
        `);
    })
})

const monthNames = ["", "Jan", "Feb", "Mar", "Apr", "May", "Jun",
  "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];