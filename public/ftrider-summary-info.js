$.ajax(`/api/ftridersum/ftrider`, { dataType: "json" }).done(rows => {
    rows.forEach(row => {
        $("#ftrider").append(`
            <tr>
              <td>${row.ordersThisMonth}</td>
              <td>${row.hoursWorkedThisMonth}</td>
              <td>${row.salary}</td>
              <td>${row.lifetime_salary}</td>
            </tr>
        `);
    })
})

const monthNames = ["", "Jan", "Feb", "Mar", "Apr", "May", "Jun",
  "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];